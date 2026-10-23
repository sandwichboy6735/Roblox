--------------------------------------------------------------------------------
-- StageService - checkpoints, respawning, falling, kill parts, stage skips,
-- the finish portal and prestige. All progress is validated here.
--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GamepassService = require(script.Parent.GamepassService)
local CourseBuilder = require(script.Parent.CourseBuilder)
local RateLimiter = require(script.Parent.RateLimiter)
local EventService = require(script.Parent.EventService)

local StageService = {}
StageService.StageChanged = Signal.new() -- (player, stage)
StageService.Prestiged = Signal.new() -- (player, newPrestige)

local lastStageTime: { [Player]: number } = {} -- when the player last gained a stage
local lastDeath: { [Player]: number } = {}
local prestiging: { [Player]: boolean } = {}

local function notify(player: Player, message: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, message, kind or "info")
end

local function playerFromHit(hit: BasePart): (Player?, Model?)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	return player, character
end

--------------------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------------------

-- Teleports the character to their checkpoint (a frame later so physics settle).
function StageService.SendToCheckpoint(player: Player, stage: number?)
	local profile = DataService:GetProfile(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local target = stage or profile.Data.Stage
	local cf = CourseBuilder.GetCheckpoint(target)
	if cf then
		character:PivotTo(cf)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local profile = DataService:WaitForProfile(player, 30)
	if not profile or player.Character ~= character then
		return
	end
	-- Wait for the root so PivotTo moves the whole rig.
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait()
	-- Stage 1 players spawn in the lobby (the SpawnLocation), everyone else at
	-- their checkpoint.
	if profile.Data.Stage > 1 then
		StageService.SendToCheckpoint(player)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			lastDeath[player] = os.clock()
			profile.Data.Stats.Deaths += 1
		end)
	end
end

--------------------------------------------------------------------------------
-- Checkpoints
--------------------------------------------------------------------------------

local function maxSpeedFor(player: Player): number
	local profile = DataService:GetProfile(player)
	local def = profile and Config.Brainrots[profile.Data.Equipped]
	local speed = if def then def.Speed else 16
	if GamepassService.Owns(player, "SpeedBoost") then
		speed *= Config.Gamepasses.SpeedBoost.SpeedMultiplier
	end
	if def and def.Perk == "Dash" then
		speed += def.Value * 0.3
	end
	return speed
end

-- Grants stage `stage` to the player if it is the next one and reachable.
function StageService.ReachStage(player: Player, stage: number, viaSkip: boolean?)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	if stage ~= data.Stage + 1 then
		return
	end
	if not viaSkip then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local cf = CourseBuilder.GetCheckpoint(stage)
		if not root or not cf then
			return
		end
		if (root.Position - cf.Position).Magnitude > Config.AntiCheat.CheckpointRadius then
			return
		end
		-- Too fast for this stage's length? Ignore it (speed exploits).
		local length = CourseBuilder.GetStageStartX(stage) - CourseBuilder.GetStageStartX(data.Stage)
		local minTime = length / (maxSpeedFor(player) * Config.AntiCheat.MaxSpeedFactor)
		local since = os.clock() - (lastStageTime[player] or 0)
		if since < minTime then
			return
		end
	end
	lastStageTime[player] = os.clock()
	data.Stage = stage
	local isNew = false
	local total = Config.TotalStages()
	local absolute = data.Prestige * total + stage
	if absolute > (data.Stats.BestStage or 1) then
		data.Stats.BestStage = absolute
		isNew = true
	end
	local reward = 0
	data.Stats.CheckpointsTouched += 1
	if isNew and not viaSkip then
		data.Stats.StagesCleared += 1
		-- the stage you just finished (stage - 1) pays; boss stages pay 4x
		local finished = stage - 1
		local world, _ = Config.GetWorld(finished)
		local _, inWorld = Config.GetWorldForStage(finished)
		local amount = Config.GetStageReward(finished) * EventService.GetStageMultiplier()
		if inWorld == world.Stages then
			amount *= 4
		end
		reward = EconomyService.AddCoins(player, amount, true)
	end
	DataService:Replicate(player, { Stage = stage, Stats = data.Stats })
	EconomyService.UpdateLeaderstats(player, data)
	Remotes.Get("StageReached"):FireClient(player, stage, isNew, reward)
	StageService.StageChanged:Fire(player, stage)
end

-- Developer product: skip ahead (never past the finish).
function StageService.Skip(player: Player, count: number)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local total = Config.TotalStages()
	local skipped = 0
	for _ = 1, count do
		if profile.Data.Stage >= total then
			break
		end
		StageService.ReachStage(player, profile.Data.Stage + 1, true)
		skipped += 1
	end
	profile.Data.Stats.StagesSkipped += skipped
	StageService.SendToCheckpoint(player)
	notify(player, string.format("Skipped %d stage%s! You're on stage %d.", skipped, if skipped == 1 then "" else "s", profile.Data.Stage), "success")
end

--------------------------------------------------------------------------------
-- Prestige
--------------------------------------------------------------------------------

function StageService.Prestige(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile or prestiging[player] then
		return
	end
	local data = profile.Data
	if data.Stage < Config.Prestige.FinalStage then
		notify(player, "Beat all " .. Config.Prestige.FinalStage .. " stages to prestige!", "error")
		return
	end
	prestiging[player] = true
	-- Record the run time (fastest run leaderboard).
	local runTime = os.time() - (data.Stats.RunStart or os.time())
	if runTime > 30 and (data.Stats.BestTime == 0 or runTime < data.Stats.BestTime) then
		data.Stats.BestTime = runTime
	end
	data.Prestige += 1
	data.Stage = 1
	data.Stats.RunStart = os.time()
	local reward = EconomyService.AddCoins(player, Config.Prestige.Reward, false)
	DataService:Replicate(player, { Prestige = data.Prestige, Stage = 1, Stats = data.Stats })
	EconomyService.RefreshMultiplier(player)
	EconomyService.UpdateLeaderstats(player, data)
	StageService.SendToCheckpoint(player, 1)
	notify(player, string.format("PRESTIGE %d! +%s coins and +%d%% coins forever. Run time: %s", data.Prestige, Util.FormatNumber(reward), math.floor(Config.Prestige.CoinMultiplierPerPrestige * 100), Util.FormatTime(runTime)), "reward")
	StageService.Prestiged:Fire(player, data.Prestige)
	StageService.StageChanged:Fire(player, 1)
	prestiging[player] = nil
end

--------------------------------------------------------------------------------
-- Falling / kill parts
--------------------------------------------------------------------------------

local function killCharacter(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

local function fallCheck()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService:GetProfile(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if profile and root then
			local stage = profile.Data.Stage
			local floor = math.min(CourseBuilder.GetFloorY(stage), CourseBuilder.GetFloorY(stage + 1))
			-- the lobby floor is at 0; stage floors rise from there
			if root.Position.Y < math.min(floor, 0) - Config.Course.FallDepth then
				killCharacter(player)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function StageService.Init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		lastStageTime[player] = nil
		lastDeath[player] = nil
		prestiging[player] = nil
	end)

	DataService.ProfileLoaded:Connect(function(player, profile)
		if (profile.Data.Stats.RunStart or 0) == 0 then
			profile.Data.Stats.RunStart = os.time()
		end
		lastStageTime[player] = os.clock() - 60
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end)

	for _, trigger in ipairs(CollectionService:GetTagged("Checkpoint")) do
		local stage = trigger:GetAttribute("Stage")
		if type(stage) == "number" and trigger:IsA("BasePart") then
			trigger.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				if player then
					StageService.ReachStage(player, stage)
				end
			end)
		end
	end
	for _, killPart in ipairs(CollectionService:GetTagged("Kill")) do
		if killPart:IsA("BasePart") then
			killPart.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				if player then
					killCharacter(player)
				end
			end)
		end
	end
	for _, finish in ipairs(CollectionService:GetTagged("Finish")) do
		if finish:IsA("BasePart") then
			finish.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				if player and RateLimiter.Allow(player, "Finish", 1, 0.2) then
					StageService.Prestige(player)
				end
			end)
		end
	end

	-- fall detection a few times a second
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.25 then
			accumulator = 0
			fallCheck()
		end
	end)

	Remotes.Get("TeleportStage").OnServerEvent:Connect(function(player, stage)
		if type(stage) ~= "number" or stage ~= math.floor(stage) or not RateLimiter.Allow(player, "TeleportStage", 3, 1) then
			return
		end
		local profile = DataService:GetProfile(player)
		if not profile or stage < 1 or stage > profile.Data.Stage then
			return
		end
		-- Going back is free; the saved checkpoint stays where it was.
		StageService.SendToCheckpoint(player, stage)
	end)

	Remotes.Get("ResetCharacter").OnServerEvent:Connect(function(player)
		if RateLimiter.Allow(player, "Reset", 3, 1) then
			killCharacter(player)
		end
	end)

	Remotes.Get("Prestige").OnServerEvent:Connect(function(player)
		if RateLimiter.Allow(player, "Prestige", 1, 0.2) then
			StageService.Prestige(player)
		end
	end)
end

return StageService
