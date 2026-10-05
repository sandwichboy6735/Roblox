--------------------------------------------------------------------------------
-- DataService
-- Loads / saves player profiles with:
--   * session locking (prevents two servers writing the same player)
--   * retries with backoff
--   * autosave + save on leave + BindToClose
--   * automatic in-memory fallback when DataStores are unavailable (Studio)
--------------------------------------------------------------------------------

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Signal = require(Shared.Signal)
local Remotes = require(Shared.Remotes)

local DataService = {}
DataService.Profiles = {} :: { [Player]: any }
DataService.ProfileLoaded = Signal.new() -- (player, profile)
DataService.ProfileReleasing = Signal.new() -- (player, profile)
DataService.UsingMock = false

local LOCK_TIMEOUT = 120 -- seconds before a stale lock can be stolen
local RETRY_ATTEMPTS = 4
local LOCK_WAIT_ATTEMPTS = 8 -- when another server still holds the lock (~45s)
local LOCK_WAIT_SECONDS = 6 -- DataStores allow one write per key every 6s
local store: any = nil
local activeSaves = 0 -- every in-flight save, so shutdown can wait for all of them
local releasing: { [number]: boolean } = {} -- userIds whose release save is running here

local function log(...)
	if Config.Debug.VerboseData then
		print("[DataService]", ...)
	end
end

--------------------------------------------------------------------------------
-- In-memory mock store (used when DataStore API access is unavailable)
--------------------------------------------------------------------------------

local MockStore = {}
MockStore.__index = MockStore

function MockStore.new()
	return setmetatable({ data = {} }, MockStore)
end

function MockStore:GetAsync(key)
	return Util.DeepCopy(self.data[key])
end

function MockStore:SetAsync(key, value)
	self.data[key] = Util.DeepCopy(value)
end

function MockStore:UpdateAsync(key, transform)
	local newValue = transform(Util.DeepCopy(self.data[key]))
	if newValue ~= nil then
		self.data[key] = Util.DeepCopy(newValue)
	end
	return Util.DeepCopy(newValue)
end

--------------------------------------------------------------------------------
-- Internals
--------------------------------------------------------------------------------

local function retry(fn)
	local lastError
	for attempt = 1, RETRY_ATTEMPTS do
		local ok, err = pcall(fn)
		if ok then
			return true, nil
		end
		lastError = err
		warn(string.format("[DataService] attempt %d failed: %s", attempt, tostring(err)))
		if attempt < RETRY_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

local function initStore()
	local ok, result = pcall(function()
		local realStore = DataStoreService:GetDataStore(Config.DataStoreName)
		realStore:GetAsync("__probe__")
		return realStore
	end)

	if ok then
		store = result
	elseif RunService:IsStudio() then
		-- Studio without "Enable Studio Access to API Services".
		DataService.UsingMock = true
		store = MockStore.new()
		warn("[DataService] DataStores unavailable in Studio (" .. tostring(result) .. "). Using an in-memory store; progress will NOT persist.")
	else
		-- Live server: never fall back to a fake store. A failed probe is usually
		-- transient; per-player loads retry and kick if DataStores stay down.
		warn("[DataService] DataStore probe failed (" .. tostring(result) .. "). Continuing with the real store.")
		store = DataStoreService:GetDataStore(Config.DataStoreName)
	end
end

local function newLock()
	return { JobId = game.JobId, Time = os.time() }
end

local function lockedByOther(lock)
	return lock ~= nil and lock.JobId ~= game.JobId and (os.time() - (lock.Time or 0)) < LOCK_TIMEOUT
end

local function migrate(data)
	-- Add migrations here when Config.Version changes, e.g.
	-- if data.Version < 2 then ... end
	data.Version = Config.Version
end

local function buildSnapshot(profile)
	local snapshot = Util.DeepCopy(profile.Data)
	snapshot.Purchases = nil -- client doesn't need receipt ids
	for key, value in pairs(profile.Runtime) do
		snapshot[key] = value
	end
	snapshot.ServerTime = os.time()
	return snapshot
end

--------------------------------------------------------------------------------
-- Load / Save
--------------------------------------------------------------------------------

local function loadProfile(player: Player)
	local key = "Player_" .. player.UserId
	local lockedElsewhere = false
	local saved = nil

	local ok, err
	-- A player who just left another server may still be saving there. Wait a
	-- little for that server to release the lock instead of kicking at once.
	for attempt = 1, LOCK_WAIT_ATTEMPTS do
		ok, err = retry(function()
			saved = store:UpdateAsync(key, function(current)
				lockedElsewhere = false
				if current == nil then
					current = { Data = Util.DeepCopy(Config.DataTemplate) }
				end
				if lockedByOther(current.Lock) then
					lockedElsewhere = true
					return nil
				end
				current.Lock = newLock()
				return current
			end)
		end)
		if not ok or not lockedElsewhere or not player:IsDescendantOf(Players) then
			break
		end
		if attempt < LOCK_WAIT_ATTEMPTS then
			task.wait(LOCK_WAIT_SECONDS)
		end
	end

	if not player:IsDescendantOf(Players) then
		-- Player left while we were loading: release the lock we just took.
		if ok and not lockedElsewhere then
			pcall(function()
				store:UpdateAsync(key, function(current)
					if current and current.Lock and current.Lock.JobId == game.JobId then
						current.Lock = nil
					end
					return current
				end)
			end)
		end
		return nil
	end

	if lockedElsewhere then
		player:Kick("Your data is still saving from another server. Please rejoin in a minute.")
		return nil
	end

	if not ok or saved == nil then
		player:Kick("We couldn't load your data (" .. tostring(err) .. "). Please rejoin.")
		return nil
	end

	local data = saved.Data or Util.DeepCopy(Config.DataTemplate)
	Util.Reconcile(data, Config.DataTemplate)
	migrate(data)

	if data.FirstJoin == 0 then
		data.FirstJoin = os.time()
	end
	data.Stats.Joins += 1

	local profile = {
		Player = player,
		Key = key,
		Data = data,
		Runtime = {
			SessionStart = os.time(),
			Gamepasses = {},
			PlaytimeClaimed = {},
			InGroup = false,
			PetSlots = Config.BasePetSlots,
			PaidRandomRestricted = true, -- until PolicyService confirms otherwise
			Multiplier = nil,
		},
		Loaded = true,
		Saving = false,
		Released = false,
		UnsavedReceipts = {}, -- [PurchaseId] = true when granted but not yet saved
	}

	log("Loaded", player.Name)
	return profile
end

-- Returns true only if the data was actually written.
local function saveProfile(profile, release: boolean): boolean
	activeSaves += 1
	local success = false
	local ok, problem = pcall(function()
		while profile.Saving do
			-- One save at a time per profile, so a release never races an autosave.
			task.wait(0.1)
		end
		if profile.Released then
			-- The final save already ran; never re-lock after it. Report failure so
			-- a receipt is retried next session, where the dedupe list decides.
			return
		end
		profile.Saving = true
		if release then
			profile.Released = true
		end

		local data = profile.Data
		-- Receipts granted before this point are inside `data` and get written now.
		local includedReceipts = table.clone(profile.UnsavedReceipts)
		local cancelled = false
		local saved, err = retry(function()
			cancelled = false
			store:UpdateAsync(profile.Key, function(current)
				if current and lockedByOther(current.Lock) then
					cancelled = true
					return nil -- another live server owns this profile now
				end
				cancelled = false
				return {
					Data = data,
					Lock = if release then nil else newLock(),
					SavedAt = os.time(),
				}
			end)
		end)
		profile.Saving = false

		if saved and not cancelled then
			success = true
			for purchaseId in pairs(includedReceipts) do
				profile.UnsavedReceipts[purchaseId] = nil
			end
			log(release and "Released" or "Saved", profile.Player.Name)
		elseif cancelled then
			warn("[DataService] " .. profile.Player.Name .. "'s data is owned by another server; not saving here.")
			local player = profile.Player
			if not release and player and player:IsDescendantOf(Players) then
				player:Kick("Your data was opened in another server. Please rejoin.")
			end
		else
			warn("[DataService] Failed to save " .. profile.Player.Name .. ": " .. tostring(err))
		end
	end)
	activeSaves -= 1
	if not ok then
		profile.Saving = false
		warn("[DataService] Save error: " .. tostring(problem))
	end
	return success
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function DataService:GetProfile(player: Player)
	return self.Profiles[player]
end

function DataService:WaitForProfile(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 15)
	while os.clock() < deadline do
		local profile = self.Profiles[player]
		if profile then
			return profile
		end
		if not player:IsDescendantOf(Players) then
			return nil
		end
		task.wait(0.1)
	end
	return nil
end

-- Sends a partial state update to the owning client.
function DataService:Replicate(player: Player, patch: { [string]: any })
	Remotes.Get("DataChanged"):FireClient(player, patch)
end

-- Convenience: replicate specific keys straight from profile.Data.
function DataService:ReplicateKeys(player: Player, keys: { string })
	local profile = self.Profiles[player]
	if not profile then
		return
	end
	local patch = {}
	for _, key in ipairs(keys) do
		patch[key] = profile.Data[key]
	end
	self:Replicate(player, patch)
end

function DataService:SendSnapshot(player: Player)
	local profile = self.Profiles[player]
	if profile then
		Remotes.Get("DataLoaded"):FireClient(player, buildSnapshot(profile))
	end
end

-- Forces an immediate save (used after Robux purchases). Returns success.
function DataService:Save(player: Player): boolean
	local profile = self.Profiles[player]
	if not profile then
		return false
	end
	return saveProfile(profile, false)
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	-- Rejoined the same server before their release save finished: wait for it.
	local deadline = os.clock() + 30
	while releasing[player.UserId] and os.clock() < deadline and player:IsDescendantOf(Players) do
		task.wait(0.2)
	end
	local profile = loadProfile(player)
	if not profile then
		return
	end
	if not player:IsDescendantOf(Players) then
		saveProfile(profile, true)
		return
	end

	DataService.Profiles[player] = profile
	DataService.ProfileLoaded:Fire(player, profile)
	-- Give listeners a moment to fill Runtime (gamepasses, group) before the snapshot.
	task.delay(0.1, function()
		if DataService.Profiles[player] == profile then
			DataService:SendSnapshot(player)
		end
	end)
end

local function releaseProfile(player: Player, profile)
	DataService.ProfileReleasing:Fire(player, profile)
	DataService.Profiles[player] = nil
	releasing[player.UserId] = true
	saveProfile(profile, true)
	releasing[player.UserId] = nil
end

local function onPlayerRemoving(player: Player)
	local profile = DataService.Profiles[player]
	if profile then
		releaseProfile(player, profile)
	end
end

function DataService.Init()
	initStore()

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	local lastRequest: { [Player]: number } = {}
	Remotes.Get("RequestData").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if (lastRequest[player] or 0) + 1 > now then
			return
		end
		lastRequest[player] = now
		DataService:SendSnapshot(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)

	-- Autosave loop (staggered so we don't burst requests). The profile list is
	-- copied first because the loop yields and players may join meanwhile.
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			local queue = {}
			for player, profile in pairs(DataService.Profiles) do
				table.insert(queue, { Player = player, Profile = profile })
			end
			for _, entry in ipairs(queue) do
				if DataService.Profiles[entry.Player] == entry.Profile then
					task.spawn(saveProfile, entry.Profile, false)
					task.wait(0.5)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and DataService.UsingMock then
			return
		end
		local remaining = {}
		for player, profile in pairs(DataService.Profiles) do
			table.insert(remaining, { Player = player, Profile = profile })
		end
		for _, entry in ipairs(remaining) do
			task.spawn(releaseProfile, entry.Player, entry.Profile)
		end
		-- Wait for EVERY in-flight save (including ones started by PlayerRemoving
		-- or purchases), within Roblox's 30 second shutdown window.
		task.wait()
		local deadline = os.clock() + 27
		while activeSaves > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
