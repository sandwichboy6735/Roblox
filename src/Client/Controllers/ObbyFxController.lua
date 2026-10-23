--------------------------------------------------------------------------------
-- ObbyFxController - the juice: checkpoint celebrations, world banners,
-- death flash, prestige confetti and pulsing checkpoint rings.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local FloatingText = require(Modules.FloatingText)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local ObbyFxController = {}

local fxPart: Part
local confetti: ParticleEmitter
local CONFETTI_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 140)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 70)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 220, 255)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(140, 240, 120)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)),
})

local function effectsOn(): boolean
	local settings = State.Get("Settings", {})
	return settings.Effects ~= false
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

function ObbyFxController.Confetti(amount: number?)
	local position = rootPosition()
	if not position or not effectsOn() then
		return
	end
	fxPart.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	confetti:Emit(amount or 80)
end

local function screenFlash(color: Color3, transparency: number)
	if not effectsOn() then
		return
	end
	local flash = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = transparency, ZIndex = 140, Parent = UIController.Root })
	UIKit.Tween(flash, { BackgroundTransparency = 1 }, 0.6)
	task.delay(0.65, function()
		flash:Destroy()
	end)
end

local function onStageReached(stage: number, isNew: boolean, reward: number)
	local world, worldIndex = Config.GetWorld(stage)
	local _, inWorld = Config.GetWorldForStage(stage)
	UIController.PlaySound("Checkpoint", 0.6)
	local position = rootPosition()
	if position and isNew and reward > 0 then
		FloatingText.Show(position + Vector3.new(0, 3, 0), "+" .. Util.FormatNumber(reward), Color3.fromRGB(255, 215, 60), Vector2.new(170, 48))
	end
	if inWorld == 1 and stage > 1 then
		UIController.Banner("WORLD " .. worldIndex, world.Name, world.Theme.Accent)
		ObbyFxController.Confetti(120)
		screenFlash(world.Theme.Accent, 0.6)
	elseif isNew then
		ObbyFxController.Confetti(25)
		if stage % 10 == 0 then
			UIController.Banner("STAGE " .. stage .. "!", "Keep going!", Color3.fromRGB(255, 220, 80))
		end
	end
end

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			screenFlash(Color3.fromRGB(255, 60, 60), 0.55)
			UIController.PlaySound("Death", 0.5)
		end)
	end
end

local rings: { BasePart } = {}

local function pulseRings()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local t = os.clock()
	local cameraPosition = camera.CFrame.Position
	local current = State.Get("Stage", 1)
	for _, ring in ipairs(rings) do
		if (ring.Position - cameraPosition).Magnitude < 150 then
			local stage = ring.Parent and ring.Parent:GetAttribute("Stage")
			local isNext = stage == current + 1
			ring.Transparency = if isNext then 0.1 + math.sin(t * 5) * 0.1 else 0.45
			ring.Color = if isNext then Color3.fromRGB(255, 240, 120) elseif stage and stage <= current then Color3.fromRGB(110, 235, 120) else ring.Color
		end
	end
end

function ObbyFxController.Init()
	fxPart = Instance.new("Part")
	fxPart.Name = "CelebrationFx"
	fxPart.Anchored = true
	fxPart.CanCollide = false
	fxPart.CanQuery = false
	fxPart.CanTouch = false
	fxPart.Transparency = 1
	fxPart.Size = Vector3.new(2, 2, 2)
	fxPart.Parent = Workspace

	confetti = Instance.new("ParticleEmitter")
	confetti.Rate = 0
	confetti.Color = CONFETTI_COLORS
	confetti.Lifetime = NumberRange.new(1.4, 2.4)
	confetti.Speed = NumberRange.new(16, 28)
	confetti.SpreadAngle = Vector2.new(55, 55)
	confetti.Acceleration = Vector3.new(0, -26, 0)
	confetti.Drag = 1.5
	confetti.RotSpeed = NumberRange.new(-300, 300)
	confetti.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.35) })
	confetti.LightEmission = 0.4
	confetti.EmissionDirection = Enum.NormalId.Top
	confetti.Parent = fxPart

	Remotes.Get("StageReached").OnClientEvent:Connect(onStageReached)

	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

	local lastPrestige: number? = nil
	State.OnLoaded(function()
		lastPrestige = State.Get("Prestige", 0)
	end)
	State.Changed:Connect(function(patch)
		if patch.Prestige ~= nil and lastPrestige ~= nil and patch.Prestige > lastPrestige then
			lastPrestige = patch.Prestige
			UIController.Banner("PRESTIGE " .. patch.Prestige .. "!", "+" .. math.floor(Config.Prestige.CoinMultiplierPerPrestige * 100) .. "% coins forever", Color3.fromRGB(255, 110, 190))
			ObbyFxController.Confetti(200)
			screenFlash(Color3.fromRGB(255, 120, 220), 0.5)
		end
	end)

	task.spawn(function()
		local course = Workspace:WaitForChild("Course")
		for _, descendant in ipairs(course:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Name == "CheckpointRing" then
				table.insert(rings, descendant)
			end
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			accumulator = 0
			pulseRings()
		end
	end)
end

return ObbyFxController
