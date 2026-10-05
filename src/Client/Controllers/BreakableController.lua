--------------------------------------------------------------------------------
-- BreakableController - HP bars, hit wobble, break bursts and reward popups for
-- the coin piles, crates and chests (BreakableService). Clicking is handled by
-- the server's ClickDetectors; this script is only visuals.
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
local FloatingText = require(Modules.FloatingText)
local UIController = require(script.Parent.UIController)
local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer

local BreakableController = {}

local SHAKE_TIME = 0.18
local EFFECT_DISTANCE = 110
local GOLD = Color3.fromRGB(255, 205, 50)

type Tracked = {
	Model: Model,
	Base: CFrame,
	Position: Vector3,
	Fill: Frame,
	HPLabel: TextLabel,
	ShakeUntil: number,
	LastHP: number,
}

local tracked: { [Model]: Tracked } = {}
local fxPart: Part
local hitSparks: ParticleEmitter
local coinBurst: ParticleEmitter
local targetHighlight: Highlight

local function hpColor(fraction: number): Color3
	if fraction > 0.5 then
		return Color3.fromRGB(90, 225, 90):Lerp(Color3.fromRGB(255, 210, 60), (1 - fraction) * 2)
	end
	return Color3.fromRGB(255, 210, 60):Lerp(Color3.fromRGB(240, 70, 70), (0.5 - fraction) * 2)
end

local function displayName(kind: string): string
	if kind == "Giant" then
		return Config.Breakables.Giant.Name
	end
	local spec = Config.Breakables.Kinds[kind]
	return if spec then spec.Name else kind
end

local function refresh(info: Tracked)
	local hp = info.Model:GetAttribute("HP")
	local maxHP = info.Model:GetAttribute("MaxHP")
	if type(hp) ~= "number" or type(maxHP) ~= "number" or maxHP <= 0 then
		return
	end
	local fraction = math.clamp(hp / maxHP, 0, 1)
	info.Fill.Size = UDim2.fromScale(fraction, 1)
	info.Fill.BackgroundColor3 = hpColor(fraction)
	info.HPLabel.Text = Util.FormatNumber(hp) .. " / " .. Util.FormatNumber(maxHP)
	if hp < info.LastHP then
		info.ShakeUntil = os.clock() + SHAKE_TIME
		local camera = Workspace.CurrentCamera
		if camera and (camera.CFrame.Position - info.Position).Magnitude < EFFECT_DISTANCE then
			fxPart.CFrame = CFrame.new(info.Position + Vector3.new(0, 2, 0))
			hitSparks:Emit(4)
		end
	end
	info.LastHP = hp
end

local function track(model: Instance)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local hitbox = model.PrimaryPart
	if not hitbox then
		return
	end
	local kind = model:GetAttribute("Kind")
	local isGiant = kind == "Giant"

	local gui = Instance.new("BillboardGui")
	gui.Name = "HPBar"
	gui.Size = if isGiant then UDim2.fromOffset(260, 58) else UDim2.fromOffset(150, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, hitbox.Size.Y / 2 + (if isGiant then 3 else 1.6), 0)
	gui.MaxDistance = if isGiant then 160 else 45
	gui.LightInfluence = 0
	gui.Adornee = hitbox

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.5, 0)
	name.Font = Enum.Font.LuckiestGuy
	name.TextScaled = true
	name.Text = displayName(tostring(kind))
	name.TextColor3 = if isGiant then GOLD else Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0
	name.TextStrokeColor3 = Color3.fromRGB(30, 22, 40)
	name.Parent = gui

	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromScale(0.05, 0.55)
	bar.Size = UDim2.fromScale(0.9, 0.4)
	bar.BackgroundColor3 = Color3.fromRGB(30, 26, 40)
	bar.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bar
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 16, 28)
	stroke.Parent = bar

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = hpColor(1)
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	shine.Parent = fill

	local hpLabel = Instance.new("TextLabel")
	hpLabel.BackgroundTransparency = 1
	hpLabel.Size = UDim2.fromScale(1, 1)
	hpLabel.Font = Enum.Font.GothamBlack
	hpLabel.TextScaled = true
	hpLabel.TextColor3 = Color3.new(1, 1, 1)
	hpLabel.TextStrokeTransparency = 0.3
	hpLabel.ZIndex = 2
	hpLabel.Parent = bar

	gui.Parent = hitbox

	local pivot = model:GetPivot()
	local info: Tracked = {
		Model = model,
		Base = pivot,
		Position = pivot.Position,
		Fill = fill,
		HPLabel = hpLabel,
		ShakeUntil = 0,
		LastHP = math.huge,
	}
	tracked[model] = info
	refresh(info)
	model:GetAttributeChangedSignal("HP"):Connect(function()
		refresh(info)
	end)
end

local function untrack(model: Instance)
	local info = tracked[model :: Model]
	if not info then
		return
	end
	tracked[model :: Model] = nil
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - info.Position).Magnitude < EFFECT_DISTANCE then
		fxPart.CFrame = CFrame.new(info.Position + Vector3.new(0, 1.5, 0))
		coinBurst:Emit(if model:GetAttribute("Kind") == "Giant" then 120 else 24)
	end
end

local function animate()
	local now = os.clock()
	for model, info in pairs(tracked) do
		if info.ShakeUntil > 0 then
			if now < info.ShakeUntil then
				local k = (info.ShakeUntil - now) / SHAKE_TIME
				model:PivotTo(info.Base * CFrame.Angles(0, 0, math.sin(now * 60) * 0.08 * k))
			else
				info.ShakeUntil = 0
				model:PivotTo(info.Base)
			end
		end
	end
	-- Outline whatever this player's pets are attacking.
	local targetId = player:GetAttribute("BreakTarget")
	local folder = Workspace:FindFirstChild("Breakables")
	local target = if type(targetId) == "string" and targetId ~= "" and folder then folder:FindFirstChild(targetId) else nil
	if targetHighlight.Adornee ~= target then
		targetHighlight.Adornee = target
		targetHighlight.Enabled = target ~= nil
	end
end

local function onBroken(position: Vector3, coins: number, gems: number, kind: string)
	if typeof(position) ~= "Vector3" then
		return
	end
	local isGiant = kind == "Giant"
	if type(coins) == "number" and coins > 0 then
		FloatingText.Show(position + Vector3.new(0, 4, 0), "+" .. Util.FormatNumber(coins), GOLD, if isGiant then Vector2.new(260, 70) else Vector2.new(170, 48))
	end
	if type(gems) == "number" and gems > 0 then
		FloatingText.Show(position + Vector3.new(0, 6, 0), "+" .. gems .. " Gems", Color3.fromRGB(110, 250, 225))
	end
	if isGiant then
		UIController.Banner("GIANT CHEST!", "+" .. Util.FormatNumber(coins) .. " coins  +" .. tostring(gems) .. " gems", GOLD)
		EffectsController.Confetti(120)
		UIController.PlaySound("Rare")
	else
		UIController.PlaySound("Collect", 0.5)
	end
end

function BreakableController.Init()
	fxPart = Instance.new("Part")
	fxPart.Name = "BreakableFx"
	fxPart.Anchored = true
	fxPart.CanCollide = false
	fxPart.CanQuery = false
	fxPart.CanTouch = false
	fxPart.Transparency = 1
	fxPart.Size = Vector3.new(2, 2, 2)
	fxPart.Parent = Workspace

	hitSparks = Instance.new("ParticleEmitter")
	hitSparks.Rate = 0
	hitSparks.Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD)
	hitSparks.LightEmission = 1
	hitSparks.Lifetime = NumberRange.new(0.2, 0.4)
	hitSparks.Speed = NumberRange.new(8, 14)
	hitSparks.Drag = 5
	hitSparks.SpreadAngle = Vector2.new(180, 180)
	hitSparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	hitSparks.Parent = fxPart

	coinBurst = Instance.new("ParticleEmitter")
	coinBurst.Rate = 0
	coinBurst.Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 240, 160))
	coinBurst.LightEmission = 0.6
	coinBurst.Lifetime = NumberRange.new(0.6, 1.1)
	coinBurst.Speed = NumberRange.new(14, 24)
	coinBurst.Acceleration = Vector3.new(0, -40, 0)
	coinBurst.SpreadAngle = Vector2.new(60, 60)
	coinBurst.EmissionDirection = Enum.NormalId.Top
	coinBurst.RotSpeed = NumberRange.new(-300, 300)
	coinBurst.Squash = NumberSequence.new(-0.6)
	coinBurst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.4) })
	coinBurst.Parent = fxPart

	targetHighlight = Instance.new("Highlight")
	targetHighlight.Name = "BreakTargetOutline"
	targetHighlight.FillColor = GOLD
	targetHighlight.FillTransparency = 0.8
	targetHighlight.OutlineColor = Color3.fromRGB(255, 245, 180)
	targetHighlight.OutlineTransparency = 0
	targetHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	targetHighlight.Enabled = false
	targetHighlight.Parent = fxPart

	task.spawn(function()
		local folder = Workspace:WaitForChild("Breakables")
		for _, model in ipairs(folder:GetChildren()) do
			track(model)
		end
		folder.ChildAdded:Connect(function(model)
			-- Attributes and parts arrive together, but wait a frame to be safe.
			task.defer(track, model)
		end)
		folder.ChildRemoved:Connect(untrack)
	end)

	Remotes.Get("BreakableBroken").OnClientEvent:Connect(onBroken)
	RunService.RenderStepped:Connect(animate)
end

return BreakableController
