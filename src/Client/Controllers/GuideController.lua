--------------------------------------------------------------------------------
-- GuideController - tells players exactly what to do next.
--
-- A card above the goal bar shows the current objective, and glowing arrows on
-- the ground lead to it, with a big bouncing arrow over the target. The steps
-- come from saved stats, so progress carries over between visits:
--   collect coins -> hatch an egg -> break coin piles -> fill your team ->
--   unlock the next zone. After that it only appears when there is something
--   to do (a gate you can afford, rebirth ready). Players can turn it off.
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
local UIController = require(script.Parent.UIController)
local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer

local GuideController = {}

local ARROW_COUNT = 7
local ARROW_SPACING = 5
local ARROW_SPEED = 7
local GOLD = Color3.fromRGB(255, 220, 60)
local FIRST_ORBS = 10
local FIRST_BREAKS = 3
local TEAM_SIZE = 3

type Step = { Id: string, Text: string, Progress: number?, Target: string?, Key: any? }

local card: Frame
local cardText: TextLabel
local cardFill: Frame
local cardBar: Frame
local folder: Folder
local chevrons: { Model } = {}
local marker: Model
local ring: Part
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local step: Step? = nil
local targetPosition: Vector3? = nil
local eggParts: { [string]: BasePart } = {}

--------------------------------------------------------------------------------
-- Steps
--------------------------------------------------------------------------------

local function firstCoinEgg(): (string, any)
	for _, entry in ipairs(Config.GetEggsSortedByZone()) do
		if entry.Egg.Currency == "Coins" then
			return entry.Key, entry.Egg
		end
	end
	return "Basic", Config.Eggs.Basic
end

local function computeStep(): Step?
	local stats = State.Get("Stats", {})
	local coins = State.Get("Coins", 0)
	local zones = State.Get("ZonesUnlocked", 1)
	local hatched = stats.PetsHatched or 0
	local broken = stats.BreakablesBroken or 0
	local rebirths = State.Get("Rebirths", 0)
	local tutorial = rebirths == 0 and zones < 2

	if tutorial then
		if hatched == 0 and (stats.OrbsCollected or 0) < FIRST_ORBS then
			return { Id = "orbs", Text = "Walk into the gold coins to collect them!", Progress = (stats.OrbsCollected or 0) / FIRST_ORBS, Target = "Orb" }
		end
		local eggKey, egg = firstCoinEgg()
		if hatched == 0 then
			if coins < egg.Cost then
				return { Id = "save1", Text = string.format("Collect %s coins for your first egg", Util.FormatNumber(egg.Cost)), Progress = coins / egg.Cost, Target = "Orb" }
			end
			return { Id = "hatch1", Text = "Go to the " .. egg.Name .. " and press E (or tap) to hatch it!", Target = "Egg", Key = eggKey }
		end
		if broken < FIRST_BREAKS then
			return { Id = "break", Text = string.format("Click a coin pile or chest. Your pets will break it! (%d/%d)", broken, FIRST_BREAKS), Progress = broken / FIRST_BREAKS, Target = "Breakable" }
		end
		if hatched < TEAM_SIZE then
			if coins < egg.Cost then
				return { Id = "save2", Text = string.format("Break coin piles to afford another egg (%d/%d pets)", hatched, TEAM_SIZE), Progress = coins / egg.Cost, Target = "Breakable" }
			end
			return { Id = "hatch3", Text = string.format("Hatch more pets for a stronger team (%d/%d)", hatched, TEAM_SIZE), Progress = hatched / TEAM_SIZE, Target = "Egg", Key = eggKey }
		end
	end

	local nextZone = Config.Zones[zones + 1]
	if nextZone then
		if coins >= nextZone.Cost then
			return { Id = "gate" .. (zones + 1), Text = "You can unlock " .. nextZone.Name .. "! Walk into the gate.", Target = "Gate", Key = zones + 1 }
		end
		if tutorial then
			return { Id = "save-zone", Text = string.format("Save up to unlock %s: %s / %s coins", nextZone.Name, Util.FormatNumber(coins), Util.FormatNumber(nextZone.Cost)), Progress = coins / nextZone.Cost, Target = "Breakable" }
		end
		return nil
	end
	if coins >= State.GetRebirthCost() then
		return { Id = "rebirth", Text = "Rebirth is ready! Go to the purple portal at spawn.", Target = "Portal" }
	end
	return nil
end

--------------------------------------------------------------------------------
-- Targets
--------------------------------------------------------------------------------

local function nearestChild(container: Instance?, from: Vector3, filter: (Instance) -> boolean): Vector3?
	if not container then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, child in ipairs(container:GetChildren()) do
		if filter(child) then
			local position = if child:IsA("Model") then child:GetPivot().Position elseif child:IsA("BasePart") then child.Position else nil
			if position then
				local distance = (position - from).Magnitude
				if distance < bestDistance then
					best, bestDistance = position, distance
				end
			end
		end
	end
	return best
end

local function findTarget(current: Step, from: Vector3): Vector3?
	local unlocked = State.Get("ZonesUnlocked", 1)
	if current.Target == "Orb" then
		return nearestChild(Workspace:FindFirstChild("Orbs"), from, function(orb)
			return orb:IsA("BasePart") and orb.Transparency < 1 and (orb:GetAttribute("Zone") or 1) <= unlocked
		end)
	elseif current.Target == "Breakable" then
		return nearestChild(Workspace:FindFirstChild("Breakables"), from, function(model)
			local zone = model:GetAttribute("Zone")
			return model:GetAttribute("Kind") ~= "Giant" and type(zone) == "number" and zone <= unlocked
		end)
	elseif current.Target == "Egg" then
		local egg = eggParts[tostring(current.Key)]
		return if egg then egg.Position else nil
	elseif current.Target == "Gate" then
		local map = Workspace:FindFirstChild("Map")
		local gates = map and map:FindFirstChild("Gates")
		local gate = gates and gates:FindFirstChild("Gate" .. tostring(current.Key))
		return if gate and gate:IsA("BasePart") then gate.Position - Vector3.new(0, gate.Size.Y / 2 - 3, 0) else nil
	elseif current.Target == "Portal" then
		local map = Workspace:FindFirstChild("Map")
		local zone1 = map and map:FindFirstChild("Zone1")
		local portal = zone1 and zone1:FindFirstChild("RebirthPortal")
		return if portal and portal:IsA("Model") then portal:GetPivot().Position else nil
	end
	return nil
end

--------------------------------------------------------------------------------
-- 3D arrows
--------------------------------------------------------------------------------

local function neon(size: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Size = size
	p.Parent = parent
	return p
end

-- A "V" whose tip points along the model's -Z (its look direction).
local function chevron(scale: number, stem: boolean): Model
	local model = Instance.new("Model")
	local armLength = 2 * scale
	local offset = Vector3.new(math.sin(math.rad(40)), 0, math.cos(math.rad(40))) * armLength / 2
	local right = neon(Vector3.new(0.4 * scale, 0.2 * scale, armLength), model)
	right.CFrame = CFrame.new(offset) * CFrame.Angles(0, math.rad(40), 0)
	local left = neon(Vector3.new(0.4 * scale, 0.2 * scale, armLength), model)
	left.CFrame = CFrame.new(-offset.X, 0, offset.Z) * CFrame.Angles(0, math.rad(-40), 0)
	if stem then
		local shaft = neon(Vector3.new(0.45 * scale, 0.25 * scale, 2.4 * scale), model)
		shaft.CFrame = CFrame.new(0, 0, 1.3 * scale)
	end
	model.WorldPivot = CFrame.new()
	model.Parent = folder
	return model
end

local function hideArrows()
	for _, model in ipairs(chevrons) do
		model.Parent = nil
	end
	marker.Parent = nil
	ring.Parent = nil
end

local function groundAt(position: Vector3, fallback: number): number
	local hit = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), rayParams)
	return if hit then hit.Position.Y else fallback
end

local function updateArrows()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local settings = State.Get("Settings", {})
	if not root or not targetPosition or settings.ShowGuide == false then
		hideArrows()
		return
	end
	local ignore: { Instance } = { folder, character }
	for _, name in ipairs({ "ClientPets", "Orbs", "Breakables", "FloatingText" }) do
		local found = Workspace:FindFirstChild(name)
		if found then
			table.insert(ignore, found)
		end
	end
	rayParams.FilterDescendantsInstances = ignore

	local t = os.clock()
	local from = root.Position
	local goal = targetPosition :: Vector3
	local flat = (goal - from) * Vector3.new(1, 0, 1)
	local length = flat.Magnitude
	local direction = if length > 0.01 then flat.Unit else Vector3.zAxis

	-- Ground arrows sliding toward the target.
	local loop = ARROW_COUNT * ARROW_SPACING
	for index, model in ipairs(chevrons) do
		local d = ((index - 1) * ARROW_SPACING + t * ARROW_SPEED) % loop + 3
		if d < length - 4 then
			local position = from + direction * d
			local y = groundAt(position, from.Y - 3) + 0.4
			model:PivotTo(CFrame.lookAlong(Vector3.new(position.X, y, position.Z), direction))
			model.Parent = folder
		else
			model.Parent = nil
		end
	end

	-- Bouncing arrow and pulsing ring at the target.
	local groundY = groundAt(goal, goal.Y)
	local bob = math.abs(math.sin(t * 3.2)) * 1.6
	marker:PivotTo(CFrame.new(goal.X, groundY + 9 + bob, goal.Z) * CFrame.Angles(0, t * 2, 0) * CFrame.Angles(math.rad(-90), 0, 0))
	marker.Parent = folder
	local pulse = 7 + math.sin(t * 4) * 1
	ring.Size = Vector3.new(0.2, pulse, pulse)
	ring.CFrame = CFrame.new(goal.X, groundY + 0.15, goal.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.35 + math.sin(t * 4) * 0.15
	ring.Parent = folder
end

--------------------------------------------------------------------------------
-- Objective card
--------------------------------------------------------------------------------

local function refreshCard()
	local settings = State.Get("Settings", {})
	local newStep = if State.Loaded and settings.ShowGuide ~= false then computeStep() else nil
	local changed = (newStep and newStep.Id) ~= (step and step.Id)
	local finishedOne = changed and step ~= nil
	step = newStep
	card.Visible = newStep ~= nil
	if not newStep then
		targetPosition = nil
		return
	end
	cardText.Text = newStep.Text
	cardBar.Visible = newStep.Progress ~= nil
	if newStep.Progress then
		UIKit.Tween(cardFill, { Size = UDim2.fromScale(math.clamp(newStep.Progress, 0, 1), 1) }, 0.2)
	end
	if changed then
		UIKit.Pop(card, 1.12)
		if finishedOne then
			EffectsController.Confetti(30)
		end
	end
end

local function buildCard()
	card = UIKit.Frame({
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -52),
		Size = UDim2.fromOffset(520, 58),
		BackgroundColor3 = UIKit.Colors.Background,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = UIController.Root,
	})
	UIKit.Corner(card, 16)
	UIKit.Stroke(card, GOLD, 3)

	local badge = UIKit.Frame({
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(42, 42),
		BackgroundColor3 = GOLD,
		Parent = card,
	})
	UIKit.Corner(badge, 21)
	UIKit.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "!",
		Font = UIKit.Fonts.Display,
		TextSize = 30,
		TextColor3 = UIKit.Colors.Background,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = badge,
	})

	cardText = UIKit.Label({
		Position = UDim2.fromOffset(60, 4),
		Size = UDim2.new(1, -100, 0, 34),
		Font = UIKit.Fonts.Title,
		TextSize = 19,
		TextWrapped = true,
		TextStrokeTransparency = 0.5,
		Parent = card,
	})

	cardBar = UIKit.Frame({
		Position = UDim2.new(0, 60, 1, -16),
		Size = UDim2.new(1, -104, 0, 8),
		BackgroundColor3 = UIKit.Colors.PanelLight,
		Parent = card,
	})
	UIKit.Corner(cardBar, 4)
	cardFill = UIKit.Frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD, Parent = cardBar })
	UIKit.Corner(cardFill, 4)

	local close = UIKit.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		Color = UIKit.Colors.PanelLight,
		Text = "X",
		TextSize = 14,
		Radius = 14,
	}, function()
		Remotes.Get("UpdateSetting"):FireServer("ShowGuide", false)
		local settings = table.clone(State.Get("Settings", {}))
		settings.ShowGuide = false
		State.Apply({ Settings = settings })
		UIController.Notify("Guide hidden. Turn it back on in Settings.", "info")
	end)
	close.Parent = card
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

local function registerEgg(part: Instance)
	if part:IsA("BasePart") and part.Name == "Egg" then
		local key = part:GetAttribute("EggId")
		if type(key) == "string" then
			eggParts[key] = part
		end
	end
end

function GuideController.Init()
	folder = Instance.new("Folder")
	folder.Name = "Guide"
	folder.Parent = Workspace
	for _ = 1, ARROW_COUNT do
		table.insert(chevrons, chevron(1, false))
	end
	marker = chevron(2.2, true)
	ring = neon(Vector3.new(0.2, 7, 7), folder)
	ring.Shape = Enum.PartType.Cylinder
	hideArrows()

	buildCard()

	task.spawn(function()
		local map = Workspace:WaitForChild("Map")
		for _, descendant in ipairs(map:GetDescendants()) do
			registerEgg(descendant)
		end
		map.DescendantAdded:Connect(registerEgg)
	end)

	State.OnLoaded(refreshCard)
	State.Changed:Connect(function(patch)
		if patch.Stats ~= nil or patch.Coins ~= nil or patch.ZonesUnlocked ~= nil or patch.Rebirths ~= nil or patch.Settings ~= nil then
			refreshCard()
		end
	end)

	-- Re-pick the target a few times a second (nearest orb / pile changes).
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		targetPosition = if step and root then findTarget(step, root.Position) else nil
	end)
	RunService.RenderStepped:Connect(updateArrows)
end

return GuideController
