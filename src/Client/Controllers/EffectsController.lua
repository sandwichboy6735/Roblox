--------------------------------------------------------------------------------
-- EffectsController - celebration effects: confetti + banner when a zone is
-- unlocked, a purple flash + banner on rebirth, and coin fountains for big
-- rewards. All client-side and purely visual.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local EffectsController = {}

local fxPart: Part
local confetti: ParticleEmitter
local CONFETTI_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 140)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 70)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 220, 255)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(140, 240, 120)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)),
})

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

function EffectsController.Confetti(amount: number?, colors: ColorSequence?)
	local position = rootPosition()
	if not position then
		return
	end
	fxPart.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	confetti.Color = colors or CONFETTI_COLORS
	confetti:Emit(amount or 90)
end

local function screenFlash(color: Color3)
	local flash = UIKit.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.25,
		ZIndex = 140,
		Parent = UIController.Root,
	})
	UIKit.Tween(flash, { BackgroundTransparency = 1 }, 0.8)
	task.delay(0.85, function()
		flash:Destroy()
	end)
end

function EffectsController.Init()
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
	confetti.Lifetime = NumberRange.new(1.6, 2.6)
	confetti.Speed = NumberRange.new(18, 30)
	confetti.SpreadAngle = Vector2.new(55, 55)
	confetti.Acceleration = Vector3.new(0, -26, 0)
	confetti.Drag = 1.5
	confetti.RotSpeed = NumberRange.new(-300, 300)
	confetti.Rotation = NumberRange.new(0, 360)
	confetti.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.35) })
	confetti.LightEmission = 0.4
	confetti.EmissionDirection = Enum.NormalId.Top
	confetti.Parent = fxPart

	local lastZones: number? = nil
	local lastRebirths: number? = nil
	State.OnLoaded(function()
		lastZones = State.Get("ZonesUnlocked", 1)
		lastRebirths = State.Get("Rebirths", 0)
	end)

	State.Changed:Connect(function(patch)
		if not State.Loaded then
			return
		end
		if patch.ZonesUnlocked ~= nil then
			local zones = patch.ZonesUnlocked
			if lastZones and zones > lastZones then
				local zone = Config.Zones[zones]
				UIController.Banner("ZONE UNLOCKED!", zone and zone.Name or "", zone and zone.Theme.Accent or nil)
				EffectsController.Confetti(120)
				UIController.PlaySound("Rare")
			end
			lastZones = zones
		end
		if patch.Rebirths ~= nil then
			local rebirths = patch.Rebirths
			if lastRebirths and rebirths > lastRebirths then
				screenFlash(Color3.fromRGB(190, 110, 255))
				UIController.Banner("REBIRTH " .. rebirths .. "!", string.format("Permanent x%.1f coins", 1 + rebirths * Config.Rebirth.MultiplierPerRebirth), Color3.fromRGB(200, 130, 255))
				EffectsController.Confetti(160, ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 160, 255)))
			end
			lastRebirths = rebirths
		end
	end)
end

return EffectsController
