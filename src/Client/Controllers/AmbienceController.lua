--------------------------------------------------------------------------------
-- AmbienceController - sky, lighting and weather per world, blended smoothly
-- as the player moves along the course.
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
local BLEND = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- Keyed by Config.Worlds[i].Theme.Decor
local PRESETS = {
	Meadow = {
		Lighting = { ClockTime = 14, Brightness = 3, Ambient = rgb(120, 120, 132), OutdoorAmbient = rgb(168, 168, 180), ExposureCompensation = 0.1 },
		Atmosphere = { Density = 0.22, Color = rgb(205, 222, 245), Decay = rgb(120, 140, 170), Haze = 0.6, Glare = 0.15 },
		Color = { TintColor = rgb(255, 255, 252), Saturation = 0.3, Contrast = 0.12 },
		Weather = "Pollen",
	},
	Beach = {
		Lighting = { ClockTime = 13, Brightness = 3.2, Ambient = rgb(130, 130, 140), OutdoorAmbient = rgb(180, 180, 190), ExposureCompensation = 0.15 },
		Atmosphere = { Density = 0.2, Color = rgb(215, 235, 255), Decay = rgb(130, 170, 210), Haze = 0.5, Glare = 0.3 },
		Color = { TintColor = rgb(255, 252, 240), Saturation = 0.35, Contrast = 0.1 },
		Weather = "Sparkles",
	},
	Jungle = {
		Lighting = { ClockTime = 15, Brightness = 2.6, Ambient = rgb(95, 125, 100), OutdoorAmbient = rgb(140, 170, 140), ExposureCompensation = 0.05 },
		Atmosphere = { Density = 0.38, Color = rgb(170, 215, 190), Decay = rgb(70, 120, 90), Haze = 1.8, Glare = 0.1 },
		Color = { TintColor = rgb(240, 255, 240), Saturation = 0.3, Contrast = 0.14 },
		Weather = "Leaves",
	},
	City = {
		Lighting = { ClockTime = 18, Brightness = 2.4, Ambient = rgb(150, 110, 100), OutdoorAmbient = rgb(190, 140, 120), ExposureCompensation = 0.05 },
		Atmosphere = { Density = 0.35, Color = rgb(255, 180, 130), Decay = rgb(150, 70, 60), Haze = 1.6, Glare = 0.4 },
		Color = { TintColor = rgb(255, 236, 220), Saturation = 0.28, Contrast = 0.16 },
		Weather = "Steam",
	},
	Sky = {
		Lighting = { ClockTime = 12, Brightness = 3.4, Ambient = rgb(150, 160, 185), OutdoorAmbient = rgb(195, 205, 230), ExposureCompensation = 0.2 },
		Atmosphere = { Density = 0.3, Color = rgb(225, 238, 255), Decay = rgb(160, 190, 235), Haze = 1.2, Glare = 0.2 },
		Color = { TintColor = rgb(245, 250, 255), Saturation = 0.2, Contrast = 0.12 },
		Weather = "Wind",
	},
	Void = {
		Lighting = { ClockTime = 0, Brightness = 1.8, Ambient = rgb(118, 106, 168), OutdoorAmbient = rgb(140, 126, 192), ExposureCompensation = 0.3 },
		Atmosphere = { Density = 0.2, Color = rgb(80, 58, 140), Decay = rgb(30, 15, 72), Haze = 0.6, Glare = 0 },
		Color = { TintColor = rgb(236, 226, 255), Saturation = 0.32, Contrast = 0.14 },
		Weather = "Stars",
	},
}

local WEATHER = {
	Pollen = { Color = ColorSequence.new(rgb(255, 250, 200)), Size = 0.18, Rate = 25, Speed = NumberRange.new(0.3, 1), Accel = Vector3.new(0.6, -0.4, 0.3), Life = NumberRange.new(5, 8), Light = 0.6, Height = 12 },
	Sparkles = { Color = ColorSequence.new(rgb(255, 255, 255), rgb(170, 230, 255)), Size = 0.25, Rate = 25, Speed = NumberRange.new(0.2, 0.8), Accel = Vector3.new(0, 0.3, 0), Life = NumberRange.new(4, 7), Light = 1, Height = 6 },
	Leaves = { Color = ColorSequence.new(rgb(120, 200, 80), rgb(230, 170, 60)), Size = 0.4, Rate = 30, Speed = NumberRange.new(1, 3), Accel = Vector3.new(1.2, -2, 0.4), Life = NumberRange.new(5, 8), Light = 0.1, Height = 22 },
	Steam = { Color = ColorSequence.new(rgb(255, 240, 230)), Size = 1.2, Rate = 12, Speed = NumberRange.new(1, 2), Accel = Vector3.new(0.3, 1.5, 0), Life = NumberRange.new(3, 5), Light = 0.2, Height = -6 },
	Wind = { Color = ColorSequence.new(rgb(255, 255, 255)), Size = 0.3, Rate = 40, Speed = NumberRange.new(10, 16), Accel = Vector3.new(6, 0, 0), Life = NumberRange.new(2, 3), Light = 0.5, Height = 4 },
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
local worldStarts: { number } = {}
local drifters: { { Part: BasePart, Base: CFrame, Phase: number, Kind: string } } = {}

local function worldAt(x: number): number
	local index = 1
	for i, startX in ipairs(worldStarts) do
		if x >= startX then
			index = i
		end
	end
	return index
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
	local preset = PRESETS[theme] or PRESETS.Meadow
	for _, t in ipairs(activeTweens) do
		t:Cancel()
	end
	table.clear(activeTweens)
	local lightingProps = table.clone(preset.Lighting)
	local targetClock = lightingProps.ClockTime
	lightingProps.ClockTime = nil
	local current = Lighting.ClockTime
	clock.Value = current
	local delta = ((targetClock - current + 12) % 24) - 12
	tween(clock, { Value = current + delta })
	tween(Lighting, lightingProps)
	tween(Lighting:FindFirstChildOfClass("Atmosphere"), preset.Atmosphere)
	tween(Lighting:FindFirstChild("WorldColor"), preset.Color)
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

	task.spawn(function()
		local course = Workspace:WaitForChild("Course")
		-- clouds drift and planets turn (client-side, so no network cost)
		local scenery = course:WaitForChild("Scenery", 30)
		if scenery then
			local rng = Random.new(7)
			for _, folder in ipairs(scenery:GetChildren()) do
				local name = folder.Name
				if name:find("Sky") or name:find("Void") then
					for _, part in ipairs(folder:GetChildren()) do
						if part:IsA("BasePart") and part.Size.X > 25 and #drifters < 160 then
							table.insert(drifters, { Part = part, Base = part.CFrame, Phase = rng:NextNumber(0, 6), Kind = if name:find("Void") then "Spin" else "Drift" })
						end
					end
				end
			end
		end
		for index in ipairs(Config.Worlds) do
			local startX = course:GetAttribute("World" .. index .. "StartX")
			worldStarts[index] = if type(startX) == "number" then startX else (index - 1) * 1000
		end
	end)

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
		if #drifters > 0 then
			local t = os.clock()
			local parts, cframes = {}, {}
			for _, drifter in ipairs(drifters) do
				if (drifter.Base.Position - focus).Magnitude < 900 then
					table.insert(parts, drifter.Part)
					if drifter.Kind == "Spin" then
						table.insert(cframes, drifter.Base * CFrame.Angles(0, t * 0.05 + drifter.Phase, 0))
					else
						table.insert(cframes, drifter.Base * CFrame.new(math.sin(t * 0.08 + drifter.Phase) * 18, math.sin(t * 0.15 + drifter.Phase) * 3, 0))
					end
				end
			end
			if #parts > 0 then
				Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			end
		end
		accumulator += dt
		if accumulator >= 0.5 and #worldStarts > 0 then
			accumulator = 0
			local world = Config.Worlds[worldAt(focus.X)]
			applyTheme(world.Theme.Decor)
		end
	end)
end

return AmbienceController
