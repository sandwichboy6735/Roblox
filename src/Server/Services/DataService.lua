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
local store: any = nil

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
	else
		DataService.UsingMock = true
		store = MockStore.new()
		warn("[DataService] DataStores unavailable (" .. tostring(result) .. "). Using in-memory store; progress will NOT persist.")
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

	local ok, err = retry(function()
		lockedElsewhere = false
		saved = store:UpdateAsync(key, function(current)
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
			Multiplier = nil,
		},
		Loaded = true,
		Saving = false,
	}

	log("Loaded", player.Name)
	return profile
end

local function saveProfile(profile, release: boolean): boolean
	if profile.Saving then
		-- Wait for the in-flight save so a release never races an autosave.
		repeat
			task.wait(0.1)
		until not profile.Saving
	end
	profile.Saving = true

	local data = profile.Data
	local ok, err = retry(function()
		store:UpdateAsync(profile.Key, function(current)
			if current and lockedByOther(current.Lock) then
				return nil -- another live server owns this profile now
			end
			return {
				Data = data,
				Lock = if release then nil else newLock(),
				SavedAt = os.time(),
			}
		end)
	end)

	profile.Saving = false
	if ok then
		log(release and "Released" or "Saved", profile.Player.Name)
	else
		warn("[DataService] Failed to save " .. profile.Player.Name .. ": " .. tostring(err))
	end
	return ok
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

local function onPlayerRemoving(player: Player)
	local profile = DataService.Profiles[player]
	if not profile then
		return
	end
	DataService.ProfileReleasing:Fire(player, profile)
	DataService.Profiles[player] = nil
	saveProfile(profile, true)
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

	Remotes.Get("RequestData").OnServerEvent:Connect(function(player)
		DataService:SendSnapshot(player)
	end)

	-- Autosave loop (staggered so we don't burst requests)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player, profile in pairs(DataService.Profiles) do
				if player:IsDescendantOf(Players) then
					task.spawn(saveProfile, profile, false)
					task.wait(0.5)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and DataService.UsingMock then
			return
		end
		local pending = 0
		for player, profile in pairs(DataService.Profiles) do
			pending += 1
			task.spawn(function()
				DataService.Profiles[player] = nil
				saveProfile(profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
