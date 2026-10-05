--------------------------------------------------------------------------------
-- CollectibleService - spawns coin / gem orbs in each zone and validates pickups.
--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local GamepassService = require(script.Parent.GamepassService)
local EconomyService = require(script.Parent.EconomyService)
local MapBuilder = require(script.Parent.MapBuilder)
local RateLimiter = require(script.Parent.RateLimiter)

local CollectibleService = {}

local ORB_TAG = "Orb"
local GEM_COLOR = Color3.fromRGB(255, 90, 210)
local COIN_COLOR = Color3.fromRGB(245, 185, 30)

-- Pickup throughput: bursts of BUCKET_SIZE, then PICKUP_RATE per second. A
-- walking player (even with Auto Collect) averages well under this.
local BUCKET_SIZE = 12
local PICKUP_RATE = 6
-- Movement sanity check between accepted pickups (the client owns its
-- character, so a teleporting exploiter could otherwise farm every orb).
local SPEED_TOLERANCE = 1.5
local MOVE_SLACK = 4 -- studs, for network jitter / bunched position updates

local records: { [BasePart]: any } = {}
local liveCount: { [number]: number } = {} -- live orbs per zone
local targetCount: { [number]: number } = {} -- desired orbs per zone
local pendingRespawns: { [number]: number } = {} -- collected orbs waiting to respawn
local lastPickup: { [Player]: { Position: Vector3, Time: number } } = {}
local rng = Random.new()

local function spawnOrb(zoneIndex: number)
	local zone = Config.Zones[zoneIndex]
	local bounds = MapBuilder.GetZoneBounds(zoneIndex)
	local folder = MapBuilder.Folders.Orbs
	if not zone or not bounds or not folder then
		return
	end

	local roll = rng:NextNumber()
	local kind = "Coin"
	if roll < Config.Orbs.GemOrbChance then
		kind = "Gem"
	elseif roll < Config.Orbs.GemOrbChance + Config.Orbs.BigOrbChance then
		kind = "Big"
	end

	local orb = Instance.new("Part")
	orb.Name = kind .. "Orb"
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanTouch = false
	orb.CanQuery = false
	orb.CastShadow = false
	orb.Material = Enum.Material.Neon
	orb.TopSurface = Enum.SurfaceType.Smooth
	orb.BottomSurface = Enum.SurfaceType.Smooth

	-- Coins are upright discs (Cylinder parts lie along X) that the client spins.
	local value
	if kind == "Gem" then
		orb.Shape = Enum.PartType.Block
		orb.Size = Vector3.new(1.5, 1.5, 1.5)
		orb.Color = GEM_COLOR
		value = rng:NextInteger(1, 3)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = GEM_COLOR
		sparkles.Parent = orb
	elseif kind == "Big" then
		orb.Shape = Enum.PartType.Cylinder
		orb.Size = Vector3.new(0.7, 4.2, 4.2)
		orb.Color = zone.Theme.Orb
		value = math.floor(zone.OrbValue * Config.Orbs.BigOrbMultiplier)
		local light = Instance.new("PointLight")
		light.Color = orb.Color
		light.Range = 10
		light.Brightness = 1.5
		light.Shadows = false
		light.Parent = orb
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = orb.Color
		sparkles.Parent = orb
	else
		orb.Shape = Enum.PartType.Cylinder
		orb.Size = Vector3.new(0.45, 2.6, 2.6)
		orb.Color = COIN_COLOR
		value = math.max(1, math.floor(zone.OrbValue * rng:NextNumber(0.8, 1.25)))
	end

	local position
	for _ = 1, 10 do
		position = Vector3.new(rng:NextNumber(bounds.MinX, bounds.MaxX), bounds.Y, rng:NextNumber(bounds.MinZ, bounds.MaxZ))
		if not MapBuilder.IsSpotBlocked(position) then
			break
		end
	end
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	orb.CFrame = if kind == "Gem" then CFrame.new(position) * yaw * CFrame.Angles(math.rad(45), 0, math.rad(45)) else CFrame.new(position) * yaw

	orb:SetAttribute("Zone", zoneIndex)
	orb:SetAttribute("Value", value)
	orb:SetAttribute("Kind", kind)
	CollectionService:AddTag(orb, ORB_TAG)

	records[orb] = { Zone = zoneIndex, Value = value, Kind = kind }
	liveCount[zoneIndex] = (liveCount[zoneIndex] or 0) + 1
	orb.Parent = folder
end

local function respawnLater(zoneIndex: number)
	pendingRespawns[zoneIndex] = (pendingRespawns[zoneIndex] or 0) + 1
	task.delay(rng:NextNumber(Config.Orbs.RespawnMin, Config.Orbs.RespawnMax), function()
		pendingRespawns[zoneIndex] -= 1
		-- Only refill up to the zone's current target (it shrinks when players leave).
		if (liveCount[zoneIndex] or 0) < (targetCount[zoneIndex] or 0) then
			spawnOrb(zoneIndex)
		end
	end)
end

-- Recomputes each zone's orb target from the players standing in it, and tops
-- zones up gradually when more players arrive.
local function rebalance()
	local playersIn: { [number]: number } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local zoneIndex = MapBuilder.GetZoneAt(root.Position)
			if zoneIndex then
				playersIn[zoneIndex] = (playersIn[zoneIndex] or 0) + 1
			end
		end
	end
	for zoneIndex, zone in ipairs(Config.Zones) do
		local extraPlayers = math.max(0, (playersIn[zoneIndex] or 0) - 1)
		local target = math.min(zone.OrbCount + extraPlayers * Config.Orbs.ExtraPerPlayer, Config.Orbs.MaxPerZone)
		targetCount[zoneIndex] = target
		-- Orbs already waiting to respawn will refill themselves on schedule.
		local missing = target - (liveCount[zoneIndex] or 0) - (pendingRespawns[zoneIndex] or 0)
		for _ = 1, math.min(missing, 6) do
			spawnOrb(zoneIndex)
		end
	end
end

-- Forget the last pickup position (server teleports, respawns).
function CollectibleService.NoteTeleport(player: Player)
	lastPickup[player] = nil
end

local function movedPlausibly(player: Player, root: BasePart, humanoid: Humanoid?): boolean
	local last = lastPickup[player]
	if not last then
		return true
	end
	local elapsed = os.clock() - last.Time
	local walkSpeed = humanoid and humanoid.WalkSpeed or 16
	-- Both points are the player's own position, so they can only have walked
	-- between them. Horizontal distance only, so jumps never count against them.
	local allowed = walkSpeed * SPEED_TOLERANCE * elapsed + walkSpeed * 0.5 + MOVE_SLACK
	local moved = (root.Position - last.Position) * Vector3.new(1, 0, 1)
	return moved.Magnitude <= allowed
end

local function onCollect(player: Player, orbArg: any)
	if typeof(orbArg) ~= "Instance" or not orbArg:IsA("BasePart") then
		return
	end
	local orb = orbArg :: BasePart
	local record = records[orb]
	if not record then
		return
	end
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	if record.Zone > profile.Data.ZonesUnlocked then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or (humanoid and humanoid.Health <= 0) then
		return
	end
	local maxDistance = Config.Orbs.MaxCollectDistance
	if GamepassService.Owns(player, "AutoCollect") then
		maxDistance = Config.Gamepasses.AutoCollect.Radius + 16
	end
	if (root.Position - orb.Position).Magnitude > maxDistance then
		return
	end
	if not movedPlausibly(player, root, humanoid) then
		return
	end
	if not RateLimiter.Allow(player, "CollectOrb", BUCKET_SIZE, PICKUP_RATE) then
		return
	end
	lastPickup[player] = { Position = root.Position, Time = os.clock() }

	-- Claim it first so two fast requests can't double-collect.
	records[orb] = nil
	liveCount[record.Zone] = math.max(0, (liveCount[record.Zone] or 1) - 1)
	orb:Destroy()

	if record.Kind == "Gem" then
		EconomyService.AddGems(player, record.Value)
	else
		EconomyService.AddCoins(player, record.Value, true)
	end
	profile.Data.Stats.OrbsCollected += 1

	respawnLater(record.Zone)
end

function CollectibleService.Init()
	for zoneIndex, zone in ipairs(Config.Zones) do
		targetCount[zoneIndex] = zone.OrbCount
		for _ = 1, zone.OrbCount do
			spawnOrb(zoneIndex)
		end
	end

	task.spawn(function()
		while true do
			task.wait(2)
			rebalance()
		end
	end)

	Remotes.Get("CollectOrb").OnServerEvent:Connect(onCollect)

	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			lastPickup[player] = nil
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		watchCharacter(player)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	Players.PlayerRemoving:Connect(function(player)
		lastPickup[player] = nil
	end)
end

return CollectibleService
