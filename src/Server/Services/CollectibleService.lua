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

-- Pickup throughput: bursts of BUCKET_SIZE, then PICKUP_RATE per second. A
-- walking player (even with Auto Collect) averages well under this.
local BUCKET_SIZE = 12
local PICKUP_RATE = 6
-- Movement sanity check between accepted pickups (the client owns its
-- character, so a teleporting exploiter could otherwise farm every orb).
local SPEED_TOLERANCE = 1.6
local MOVE_SLACK = 6

local records: { [BasePart]: any } = {}
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

	local value
	if kind == "Gem" then
		orb.Shape = Enum.PartType.Block
		orb.Size = Vector3.new(1.8, 2.6, 1.8)
		orb.Color = GEM_COLOR
		value = rng:NextInteger(1, 3)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = GEM_COLOR
		sparkles.Parent = orb
	elseif kind == "Big" then
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(3.8, 3.8, 3.8)
		orb.Color = zone.Theme.Orb
		value = math.floor(zone.OrbValue * Config.Orbs.BigOrbMultiplier)
		local light = Instance.new("PointLight")
		light.Color = orb.Color
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = orb
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = orb.Color
		sparkles.Parent = orb
	else
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(2.4, 2.4, 2.4)
		orb.Color = zone.Theme.Orb
		value = math.max(1, math.floor(zone.OrbValue * rng:NextNumber(0.8, 1.25)))
	end

	local position
	for _ = 1, 10 do
		position = Vector3.new(rng:NextNumber(bounds.MinX, bounds.MaxX), bounds.Y, rng:NextNumber(bounds.MinZ, bounds.MaxZ))
		if not MapBuilder.IsSpotBlocked(position) then
			break
		end
	end
	orb.CFrame = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), if kind == "Gem" then math.rad(45) else 0)

	orb:SetAttribute("Zone", zoneIndex)
	orb:SetAttribute("Value", value)
	orb:SetAttribute("Kind", kind)
	CollectionService:AddTag(orb, ORB_TAG)

	records[orb] = { Zone = zoneIndex, Value = value, Kind = kind }
	orb.Parent = folder
end

local function respawnLater(zoneIndex: number)
	task.delay(rng:NextNumber(Config.Orbs.RespawnMin, Config.Orbs.RespawnMax), spawnOrb, zoneIndex)
end

-- Forget the last pickup position (server teleports, respawns).
function CollectibleService.NoteTeleport(player: Player)
	lastPickup[player] = nil
end

local function movedPlausibly(player: Player, root: BasePart, humanoid: Humanoid?, reach: number): boolean
	local last = lastPickup[player]
	if not last then
		return true
	end
	local elapsed = os.clock() - last.Time
	local walkSpeed = humanoid and humanoid.WalkSpeed or 16
	-- Between two pickups the player can walk, plus reach out to both orbs.
	local allowed = walkSpeed * SPEED_TOLERANCE * elapsed + reach * 2 + MOVE_SLACK
	return (root.Position - last.Position).Magnitude <= allowed
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
	if not movedPlausibly(player, root, humanoid, maxDistance) then
		return
	end
	if not RateLimiter.Allow(player, "CollectOrb", BUCKET_SIZE, PICKUP_RATE) then
		return
	end
	lastPickup[player] = { Position = root.Position, Time = os.clock() }

	-- Claim it first so two fast requests can't double-collect.
	records[orb] = nil
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
		for _ = 1, zone.OrbCount do
			spawnOrb(zoneIndex)
		end
	end

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
