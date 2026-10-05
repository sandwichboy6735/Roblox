--------------------------------------------------------------------------------
-- AmbienceController - per-zone lighting, sky, clouds and weather particles.
-- Smoothly blends between zone moods as the player walks between zones.
--------------------------------------------------------------------------------

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local player = Players.LocalPlayer

local AmbienceController = {}

local rgb = Color3.fromRGB
local BLEND = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

type Preset = {
	Lighting: { [string]: any },
	Atmosphere: { [string]: any },
	Color: { [string]: any },
	Clouds: { [string]: any },
	Weather: string?,
}

-- Keyed by Config.Zones[i].Theme.Decor
local PRESETS: { [string]: Preset } = {
	Trees = {
		Lighting = { ClockTime = 14, Brightness = 2.6, Ambient = rgb(95, 95, 105), OutdoorAmbient = rgb(140, 140, 150), ExposureCompensation = 0 },
		Atmosphere = { Density = 0.28, Color = rgb(199, 212, 232), Decay = rgb(110, 120, 140), Haze = 1, Glare = 0.15 },
		Color = { TintColor = rgb(255, 255, 255), Saturation = 0.18, Contrast = 0.08 },
		Clouds = { Cover = 0.55, Density = 0.7, Color = rgb(255, 255, 255) },
		Weather = "Pollen",
	},
	Candy = {
		Lighting = { ClockTime = 15.5, Brightness = 2.7, Ambient = rgb(135, 105, 125), OutdoorAmbient = rgb(170, 140, 160), ExposureCompensation = 0.05 },
		Atmosphere = { Density = 0.34, Color = rgb(255, 205, 232), Decay = rgb(255, 150, 205), Haze = 1.6, Glare = 0.25 },
		Color = { TintColor = rgb(255, 242, 250), Saturation = 0.28, Contrast = 0.06 },
		Clouds = { Cover = 0.62, Density = 0.75, Color = rgb(255, 210, 236) },
		Weather = "Sparkles",
	},
	Ice = {
		Lighting = { ClockTime = 13, Brightness = 2.4, Ambient = rgb(120, 140, 170), OutdoorAmbient = rgb(150, 170, 200), ExposureCompensation = 0.1 },
		Atmosphere = { Density = 0.42, Color = rgb(212, 230, 255), Decay = rgb(150, 182, 222), Haze = 2.2, Glare = 0.1 },
		Color = { TintColor = rgb(236, 246, 255), Saturation = 0.02, Contrast = 0.1 },
		Clouds = { Cover = 0.8, Density = 0.8, Color = rgb(230, 238, 250) },
		Weather = "Snow",
	},
	Rock = {
		Lighting = { ClockTime = 18.1, Brightness = 2.2, Ambient = rgb(125, 72, 62), OutdoorAmbient = rgb(150, 92, 72), ExposureCompensation = 0 },
		Atmosphere = { Density = 0.45, Color = rgb(255, 140, 95), Decay = rgb(120, 42, 30), Haze = 2.4, Glare = 0.45 },
		Color = { TintColor = rgb(255, 228, 212), Saturation = 0.12, Contrast = 0.14 },
		Clouds = { Cover = 0.75, Density = 0.85, Color = rgb(95, 62, 60) },
		Weather = "Embers",
	},
	Crystal = {
		Lighting = { ClockTime = 0, Brightness = 1.6, Ambient = rgb(95, 85, 140), OutdoorAmbient = rgb(115, 105, 165), ExposureCompensation = 0.25 },
		Atmosphere = { Density = 0.2, Color = rgb(70, 50, 130), Decay = rgb(25, 12, 65), Haze = 0.6, Glare = 0 },
		Color = { TintColor = rgb(232, 222, 255), Saturation = 0.22, Contrast = 0.12 },
		Clouds = { Cover = 0, Density = 0, Color = rgb(60, 50, 110) },
		Weather = "Stars",
	},
}

local WEATHER = {
	Pollen = { Color = ColorSequence.new(rgb(255, 250, 200)), Size = 0.18, Rate = 30, Speed = NumberRange.new(0.3, 1), Accel = Vector3.new(0.6, -0.4, 0.3), Life = NumberRange.new(5, 8), Light = 0.6, Height = 12 },
	Sparkles = { Color = ColorSequence.new(rgb(255, 170, 225), rgb(190, 230, 255)), Size = 0.3, Rate = 35, Speed = NumberRange.new(0.2, 0.8), Accel = Vector3.new(0, 0.3, 0), Life = NumberRange.new(4, 7), Light = 1, Height = 6 },
	Snow = { Color = ColorSequence.new(rgb(255, 255, 255)), Size = 0.32, Rate = 160, Speed = NumberRange.new(3, 6), Accel = Vector3.new(1.5, -3, 0.5), Life = NumberRange.new(5, 7), Light = 0.3, Height = 28 },
	Embers = { Color = ColorSequence.new(rgb(255, 160, 50), rgb(255, 60, 20)), Size = 0.25, Rate = 70, Speed = NumberRange.new(2, 4), Accel = Vector3.new(0.5, 3, 0), Life = NumberRange.new(3, 5), Light = 1, Height = -4 },
	Stars = { Color = ColorSequence.new(rgb(200, 220, 255), rgb(220, 160, 255)), Size = 0.22, Rate = 40, Speed = NumberRange.new(0, 0.4), Accel = Vector3.new(0, 0, 0), Life = NumberRange.new(2, 4), Light = 1, Height = 8 },
}

local currentTheme: string? = nil
local clock = Instance.new("NumberValue")
clock.Changed:Connect(function(value)
	Lighting.ClockTime = value % 24
end)
local weatherPart: Part
local emitter: ParticleEmitter
local activeTweens: { Tween } = {}

local function themeAt(position: Vector3): string
	local spacing = Config.Map.ZoneSpacing
	-- Nearest zone (so the mood changes halfway across each bridge).
	local index = math.clamp(math.floor(position.X / spacing + 0.5) + 1, 1, #Config.Zones)
	return Config.Zones[index].Theme.Decor
end

local function tween(instance: Instance?, props: { [string]: any })
	if not instance then
		return
	end
	local t = TweenService:Create(instance, BLEND, props)
	table.insert(activeTweens, t)
	t:Play()
end

local function applyWeather(name: string?)
	local spec = name and WEATHER[name]
	if not spec then
		emitter.Enabled = false
		return
	end
	emitter.Enabled = true
	emitter.Color = spec.Color
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.Size), NumberSequenceKeypoint.new(0.8, spec.Size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Rate = spec.Rate
	emitter.Speed = spec.Speed
	emitter.Acceleration = spec.Accel
	emitter.Lifetime = spec.Life
	emitter.LightEmission = spec.Light
	emitter.EmissionDirection = if spec.Height < 0 then Enum.NormalId.Top else Enum.NormalId.Bottom
	weatherPart:SetAttribute("Height", spec.Height)
end

local function applyTheme(theme: string)
	if theme == currentTheme then
		return
	end
	currentTheme = theme
	local preset = PRESETS[theme] or PRESETS.Trees
	for _, t in ipairs(activeTweens) do
		t:Cancel()
	end
	table.clear(activeTweens)

	-- ClockTime wraps at 24, so tween a helper value along the shorter way round
	-- the clock (e.g. 14:00 -> 24:00 instead of rewinding through the day).
	local lightingProps = table.clone(preset.Lighting)
	local targetClock = lightingProps.ClockTime
	lightingProps.ClockTime = nil
	local current = Lighting.ClockTime
	clock.Value = current
	local delta = ((targetClock - current + 12) % 24) - 12
	tween(clock, { Value = current + delta })
	tween(Lighting, lightingProps)
	tween(Lighting:FindFirstChildOfClass("Atmosphere"), preset.Atmosphere)
	tween(Lighting:FindFirstChild("ZoneColor"), preset.Color)
	tween(Workspace.Terrain:FindFirstChildOfClass("Clouds"), preset.Clouds)
	applyWeather(preset.Weather)
end

function AmbienceController.Init()
	weatherPart = Instance.new("Part")
	weatherPart.Name = "WeatherEmitter"
	weatherPart.Anchored = true
	weatherPart.CanCollide = false
	weatherPart.CanQuery = false
	weatherPart.CanTouch = false
	weatherPart.Transparency = 1
	weatherPart.Size = Vector3.new(90, 1, 90)
	weatherPart.Parent = Workspace

	emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Weather"
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Enabled = false
	emitter.Parent = weatherPart

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = Workspace.CurrentCamera
		local focus = if root then root.Position elseif camera then camera.CFrame.Position else nil
		if not focus then
			return
		end
		local height = weatherPart:GetAttribute("Height")
		weatherPart.CFrame = CFrame.new(focus + Vector3.new(0, if type(height) == "number" then height else 20, 0))
		accumulator += dt
		if accumulator >= 0.5 then
			accumulator = 0
			applyTheme(themeAt(focus))
		end
	end)
end

return AmbienceController
