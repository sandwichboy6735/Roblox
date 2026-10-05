--------------------------------------------------------------------------------
-- BreakableService - coin piles, crates and chests that equipped pets break.
--
-- Players click a breakable (ClickDetector) to send their pets at it. Damage
-- is worked out here every tick from the player's equipped pets, so clients
-- can't fake it. Rewards are split by damage dealt, which makes helping on a
-- Giant Chest worthwhile. When a breakable pops, pets move on to the nearest
-- one close to their owner.
--
-- Clients read: player attribute "BreakTarget" (breakable name or ""), and
-- each breakable model's attributes Kind, Zone, HP, MaxHP, Radius.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MapBuilder = require(script.Parent.MapBuilder)
local PetService = require(script.Parent.PetService)
local BreakableLooks = require(script.Parent.BreakableLooks)

local BreakableService = {}

local TICK = 0.25
local ARRIVE_DELAY = 0.6 -- pets need a moment to run over before they hit
local MIN_GAP = 8 -- studs between breakables

type Record = {
	Id: string,
	Model: Model,
	Kind: string,
	Zone: number,
	HP: number,
	MaxHP: number,
	Position: Vector3,
	Radius: number,
	Damage: { [Player]: number },
}

local records: { [string]: Record } = {}
local liveCount: { [number]: number } = {} -- small breakables alive per zone
local pending: { [number]: number } = {} -- small breakables waiting to respawn
local targets: { [Player]: Record } = {}
local targetSince: { [Player]: number } = {}
local hinted: { [Player]: boolean } = {}
local folder: Folder
local nextId = 0
local rng = Random.new()
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }

local function notify(player: Player, message: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, message, kind or "info")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or (humanoid and humanoid.Health <= 0) then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flatDistance(a: Vector3, b: Vector3): number
	return ((a - b) * Vector3.new(1, 0, 1)).Magnitude
end

--------------------------------------------------------------------------------
-- Damage
--------------------------------------------------------------------------------

-- Damage per second of a player's team (the player plus their equipped pets).
function BreakableService.GetDamage(player: Player): number
	local profile = DataService:GetProfile(player)
	if not profile then
		return 0
	end
	local equipped = {}
	for _, petData in ipairs(profile.Data.Pets) do
		if petData.Equipped then
			table.insert(equipped, petData)
		end
	end
	return Config.GetTeamDamage(equipped, PetService.GetSlotCount(player))
end

--------------------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------------------

local function pickKind(): string
	local total = 0
	for _, spec in pairs(Config.Breakables.Kinds) do
		total += spec.Weight
	end
	local roll = rng:NextNumber(0, total)
	local names = {}
	for name in pairs(Config.Breakables.Kinds) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		roll -= Config.Breakables.Kinds[name].Weight
		if roll <= 0 then
			return name
		end
	end
	return names[1]
end

local function groundY(x: number, z: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), groundParams)
	return if hit then hit.Position.Y else 0
end

local function spotIsFree(position: Vector3, radius: number): boolean
	if MapBuilder.IsSpotBlocked(position) then
		return false
	end
	for _, record in pairs(records) do
		if flatDistance(record.Position, position) < record.Radius + radius + MIN_GAP then
			return false
		end
	end
	return true
end

local function place(kind: string, zoneIndex: number, position: Vector3?): Record?
	local zone = Config.Zones[zoneIndex]
	local bounds = MapBuilder.GetZoneBounds(zoneIndex)
	if not zone or not bounds then
		return nil
	end
	local model, radius = BreakableLooks.Build(kind, zone.Theme.Accent, rng)

	local spot = position
	if not spot then
		for _ = 1, 12 do
			local candidate = Vector3.new(rng:NextNumber(bounds.MinX + 4, bounds.MaxX - 4), 0, rng:NextNumber(bounds.MinZ + 4, bounds.MaxZ - 4))
			if spotIsFree(candidate, radius) then
				spot = candidate
				break
			end
		end
	end
	if not spot then
		model:Destroy()
		return nil
	end
	local ground = groundY(spot.X, spot.Z)
	local finalPosition = Vector3.new(spot.X, ground, spot.Z)
	model:PivotTo(CFrame.new(finalPosition) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))

	nextId += 1
	local id = "B" .. nextId
	local maxHP = Config.GetBreakableHP(kind, zoneIndex)
	model.Name = id
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Zone", zoneIndex)
	model:SetAttribute("HP", maxHP)
	model:SetAttribute("MaxHP", maxHP)
	model:SetAttribute("Radius", radius)

	local record: Record = {
		Id = id,
		Model = model,
		Kind = kind,
		Zone = zoneIndex,
		HP = maxHP,
		MaxHP = maxHP,
		Position = finalPosition,
		Radius = radius,
		Damage = {},
	}

	local clicker = Instance.new("ClickDetector")
	clicker.MaxActivationDistance = Config.Breakables.MaxDistance
	clicker.Parent = model.PrimaryPart
	clicker.MouseClick:Connect(function(player)
		BreakableService.SetTarget(player, record)
	end)

	records[id] = record
	model.Parent = folder
	return record
end

local function spawnSmall(zoneIndex: number)
	if place(pickKind(), zoneIndex, nil) then
		liveCount[zoneIndex] = (liveCount[zoneIndex] or 0) + 1
	end
end

local function spawnGiant(zoneIndex: number)
	place("Giant", zoneIndex, MapBuilder.GetGiantChestSpot(zoneIndex))
end

-- Keeps each zone stocked: more breakables when more players stand in it.
local function rebalance()
	local playersIn: { [number]: number } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(player)
		local zoneIndex = root and MapBuilder.GetZoneAt(root.Position)
		if zoneIndex then
			playersIn[zoneIndex] = (playersIn[zoneIndex] or 0) + 1
		end
	end
	local settings = Config.Breakables
	for zoneIndex in ipairs(Config.Zones) do
		local extra = math.max(0, (playersIn[zoneIndex] or 0) - 1)
		local target = math.min(settings.PerZone + extra * settings.ExtraPerPlayer, settings.MaxPerZone)
		local missing = target - (liveCount[zoneIndex] or 0) - (pending[zoneIndex] or 0)
		for _ = 1, math.min(missing, 4) do
			spawnSmall(zoneIndex)
		end
	end
end

--------------------------------------------------------------------------------
-- Targeting
--------------------------------------------------------------------------------

local function clearTarget(player: Player)
	targets[player] = nil
	targetSince[player] = nil
	if player.Parent then
		player:SetAttribute("BreakTarget", "")
	end
end

function BreakableService.SetTarget(player: Player, record: Record)
	if records[record.Id] ~= record then
		return
	end
	local profile = DataService:GetProfile(player)
	local root = rootOf(player)
	if not profile or not root then
		return
	end
	if record.Zone > profile.Data.ZonesUnlocked then
		notify(player, "Unlock " .. Config.Zones[record.Zone].Name .. " first!", "error")
		return
	end
	if flatDistance(root.Position, record.Position) > Config.Breakables.MaxDistance then
		return
	end
	if targets[player] == record then
		return
	end
	targets[player] = record
	targetSince[player] = os.clock()
	player:SetAttribute("BreakTarget", record.Id)

	if not hinted[player] then
		local anyEquipped = false
		for _, petData in ipairs(profile.Data.Pets) do
			if petData.Equipped then
				anyEquipped = true
				break
			end
		end
		if not anyEquipped then
			hinted[player] = true
			notify(player, "Hatch an egg! Pets break things MUCH faster than you can.", "info")
		end
	end
end

-- After a break, send the player's pets to the nearest breakable close by.
local function retarget(player: Player, zoneIndex: number)
	local root = rootOf(player)
	if not root then
		clearTarget(player)
		return
	end
	local best, bestDistance = nil, Config.Breakables.AutoTargetRange
	for _, record in pairs(records) do
		if record.Zone == zoneIndex then
			local distance = flatDistance(record.Position, root.Position)
			if distance < bestDistance then
				best, bestDistance = record, distance
			end
		end
	end
	if best then
		BreakableService.SetTarget(player, best)
	else
		clearTarget(player)
	end
end

--------------------------------------------------------------------------------
-- Breaking
--------------------------------------------------------------------------------

local function rollGems(range: { number }): number
	return rng:NextInteger(range[1], range[2])
end

local function breakRecord(record: Record)
	records[record.Id] = nil
	local isGiant = record.Kind == "Giant"
	local spec = if isGiant then Config.Breakables.Giant else Config.Breakables.Kinds[record.Kind]
	local zone = Config.Zones[record.Zone]
	record.Model:Destroy()

	-- The biggest contributor gets the gem roll on small breakables.
	local topPlayer, topDamage = nil, 0
	for player, damage in pairs(record.Damage) do
		if damage > topDamage then
			topPlayer, topDamage = player, damage
		end
	end

	for player, damage in pairs(record.Damage) do
		local profile = DataService:GetProfile(player)
		if profile and player.Parent then
			local share = math.clamp(damage / record.MaxHP, 0, 1)
			local coinShare = share
			local gems = 0
			if isGiant then
				if share >= spec.MinShare then
					-- Helping out pays: everyone gets a solid base plus their share.
					coinShare = 0.3 + 0.7 * share
					gems = rollGems(spec.Gems)
				end
			elseif player == topPlayer and rng:NextNumber() < spec.GemChance then
				gems = rollGems(spec.Gems)
			end
			local coins = 0
			if coinShare > 0 then
				coins = EconomyService.AddCoins(player, spec.Reward * zone.OrbValue * coinShare, true)
			end
			if gems > 0 then
				EconomyService.AddGems(player, gems)
			end
			if share >= 0.25 or (isGiant and share >= spec.MinShare) then
				profile.Data.Stats.BreakablesBroken += 1
				DataService:Replicate(player, { Stats = profile.Data.Stats })
			end
			Remotes.Get("BreakableBroken"):FireClient(player, record.Position, coins, gems, record.Kind)
		end
	end

	for player, target in pairs(targets) do
		if target == record then
			retarget(player, record.Zone)
		end
	end

	if isGiant then
		task.delay(Config.Breakables.Giant.Respawn, spawnGiant, record.Zone)
	else
		liveCount[record.Zone] = math.max(0, (liveCount[record.Zone] or 1) - 1)
		pending[record.Zone] = (pending[record.Zone] or 0) + 1
		task.delay(rng:NextNumber(Config.Breakables.RespawnMin, Config.Breakables.RespawnMax), function()
			pending[record.Zone] -= 1
			spawnSmall(record.Zone)
		end)
	end
end

local function tick(dt: number)
	local now = os.clock()
	for player, record in pairs(targets) do
		local profile = DataService:GetProfile(player)
		local root = rootOf(player)
		if records[record.Id] ~= record or not profile or not root or record.Zone > profile.Data.ZonesUnlocked or flatDistance(root.Position, record.Position) > Config.Breakables.MaxDistance then
			clearTarget(player)
		elseif now - (targetSince[player] or now) >= ARRIVE_DELAY then
			local damage = math.min(BreakableService.GetDamage(player) * dt, record.HP)
			record.Damage[player] = (record.Damage[player] or 0) + damage
			record.HP -= damage
			if record.HP <= 0.001 then
				breakRecord(record)
			else
				record.Model:SetAttribute("HP", math.ceil(record.HP))
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function BreakableService.Init()
	local existing = Workspace:FindFirstChild("Breakables")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Breakables"
	folder.Parent = Workspace

	for zoneIndex in ipairs(Config.Zones) do
		spawnGiant(zoneIndex)
		for _ = 1, Config.Breakables.PerZone do
			spawnSmall(zoneIndex)
		end
	end

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			tick(math.min(now - last, 1))
			last = now
		end
	end)
	task.spawn(function()
		while true do
			task.wait(3)
			rebalance()
		end
	end)

	local function watch(player: Player)
		player:SetAttribute("BreakTarget", "")
		player.CharacterAdded:Connect(function()
			clearTarget(player)
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		targets[player] = nil
		targetSince[player] = nil
		hinted[player] = nil
		for _, record in pairs(records) do
			record.Damage[player] = nil
		end
	end)
end

return BreakableService
