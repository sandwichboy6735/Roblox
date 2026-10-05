--------------------------------------------------------------------------------
-- MapBuilder - procedurally builds the whole world from Config.Zones so the
-- game works with ZERO external assets. Replace/decorate freely in Studio;
-- the gameplay only depends on the attributes set here:
--   Gate parts:       Attribute "Zone" (number)
--   Egg stand parts:  Attribute "EggId" (string) + ProximityPrompt
--   Rebirth portal:   Attribute "Portal" = "Rebirth" + ProximityPrompt
--------------------------------------------------------------------------------

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local MapBuilder = {}

local ZONE_SIZE = 180
local ZONE_SPACING = 200
local HALF = ZONE_SIZE / 2
local BRIDGE_WIDTH = 30
local WALL_HEIGHT = 40

local zoneSpawns: { CFrame } = {}
local zoneBounds: { any } = {}
local eggStandPositions: { [string]: Vector3 } = {}
local leaderboardBoards: { [string]: Part } = {}

MapBuilder.Folders = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function part(props: { [string]: any }, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function material(name: string): Enum.Material
	local ok, result = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	if ok and result then
		return result
	end
	return Enum.Material.SmoothPlastic
end

local function zoneCenterX(index: number): number
	return (index - 1) * ZONE_SPACING
end

local function billboard(adornee: BasePart, title: string, subtitle: string?, color: Color3?, size: UDim2?, offsetY: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = size or UDim2.fromOffset(260, 90)
	gui.StudsOffset = Vector3.new(0, offsetY or 5, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Adornee = adornee

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.Text = title
	titleLabel.TextColor3 = color or Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Font = Enum.Font.GothamBold
	subLabel.Text = subtitle or ""
	subLabel.TextColor3 = Color3.fromRGB(255, 235, 150)
	subLabel.TextScaled = true
	subLabel.TextStrokeTransparency = 0.2
	subLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	subLabel.Parent = gui

	gui.Parent = adornee
	return gui
end

--------------------------------------------------------------------------------
-- Decorations
--------------------------------------------------------------------------------

local function buildTree(parent: Instance, position: Vector3, theme, rng: Random)
	local height = rng:NextNumber(6, 10)
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.6, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = theme.Trim,
		Material = Enum.Material.Wood,
	}, parent)
	local leafSize = rng:NextNumber(6, 9)
	part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(leafSize, leafSize * 0.9, leafSize),
		Position = position + Vector3.new(0, height + leafSize * 0.3, 0),
		Color = theme.Accent,
		Material = Enum.Material.Grass,
	}, parent)
end

local function buildCandy(parent: Instance, position: Vector3, theme, rng: Random)
	if rng:NextNumber() < 0.5 then
		local height = rng:NextNumber(5, 9)
		part({
			Name = "Stick",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 0.8, 0.8),
			CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.SmoothPlastic,
		}, parent)
		local size = rng:NextNumber(4, 6)
		part({
			Name = "Lollipop",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, size, size),
			CFrame = CFrame.new(position + Vector3.new(0, height + size / 2 - 0.5, 0)) * CFrame.Angles(0, math.rad(90), 0),
			Color = if rng:NextNumber() < 0.5 then theme.Trim else theme.Accent,
			Material = Enum.Material.Neon,
		}, parent)
	else
		local size = rng:NextNumber(3, 6)
		part({
			Name = "Gumdrop",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * 0.8, size),
			Position = position + Vector3.new(0, size * 0.4, 0),
			Color = Color3.fromHSV(rng:NextNumber(), 0.6, 1),
			Material = Enum.Material.SmoothPlastic,
		}, parent)
	end
end

local function buildIce(parent: Instance, position: Vector3, theme, rng: Random)
	local count = rng:NextInteger(1, 3)
	for _ = 1, count do
		local height = rng:NextNumber(5, 12)
		local offset = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		part({
			Name = "IceSpike",
			Size = Vector3.new(rng:NextNumber(1.5, 3), height, rng:NextNumber(1.5, 3)),
			CFrame = CFrame.new(position + offset + Vector3.new(0, height / 2 - 0.5, 0))
				* CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-12, 12))),
			Color = theme.Accent,
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			Reflectance = 0.2,
		}, parent)
	end
end

local function buildRock(parent: Instance, position: Vector3, theme, rng: Random)
	if rng:NextNumber() < 0.3 then
		local size = rng:NextNumber(6, 12)
		local pool = part({
			Name = "LavaPool",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, size, size),
			CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = theme.Accent,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, parent)
		local light = Instance.new("PointLight")
		light.Color = theme.Accent
		light.Range = size
		light.Brightness = 1.5
		light.Parent = pool
	else
		local size = rng:NextNumber(3, 7)
		part({
			Name = "Rock",
			Size = Vector3.new(size, size * rng:NextNumber(0.6, 1.2), size * rng:NextNumber(0.7, 1.3)),
			CFrame = CFrame.new(position + Vector3.new(0, size * 0.35, 0))
				* CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-20, 20))),
			Color = theme.Trim,
			Material = Enum.Material.Basalt,
		}, parent)
	end
end

local function buildCrystal(parent: Instance, position: Vector3, theme, rng: Random)
	local height = rng:NextNumber(6, 14)
	local crystal = part({
		Name = "Crystal",
		Size = Vector3.new(rng:NextNumber(1.5, 3), height, rng:NextNumber(1.5, 3)),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2 - 1, 0))
			* CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-15, 15))),
		Color = if rng:NextNumber() < 0.5 then theme.Accent else theme.Trim,
		Material = Enum.Material.Neon,
	}, parent)
	local light = Instance.new("PointLight")
	light.Color = crystal.Color
	light.Range = 12
	light.Brightness = 0.8
	light.Parent = crystal
end

local DECOR_BUILDERS = {
	Trees = buildTree,
	Candy = buildCandy,
	Ice = buildIce,
	Rock = buildRock,
	Crystal = buildCrystal,
}

local function isReserved(zoneIndex: number, localX: number, z: number): boolean
	if math.abs(z) < 14 then
		return true -- central walking lane
	end
	if z < -58 and z > -24 and math.abs(localX) < 45 then
		return true -- egg stands
	end
	if zoneIndex == 1 then
		if z < -72 then
			return true -- leaderboards
		end
		if localX < -40 and math.abs(z) < 26 then
			return true -- spawn
		end
		if z > 48 and math.abs(localX) < 16 then
			return true -- rebirth portal
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Zone pieces
--------------------------------------------------------------------------------

local function buildWalls(zoneModel: Model, index: number, cx: number, theme)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = zoneModel

	local function wall(size: Vector3, position: Vector3)
		part({
			Name = "Wall",
			Size = size,
			Position = position,
			Transparency = 1,
			CanCollide = true,
		}, walls)
	end
	local function fence(size: Vector3, position: Vector3)
		part({
			Name = "Fence",
			Size = size,
			Position = position,
			Color = theme.Trim,
			Material = Enum.Material.SmoothPlastic,
		}, walls)
	end

	-- North / South
	wall(Vector3.new(ZONE_SIZE + 2, WALL_HEIGHT, 2), Vector3.new(cx, WALL_HEIGHT / 2, -(HALF + 1)))
	wall(Vector3.new(ZONE_SIZE + 2, WALL_HEIGHT, 2), Vector3.new(cx, WALL_HEIGHT / 2, HALF + 1))
	fence(Vector3.new(ZONE_SIZE + 2, 2.5, 1.5), Vector3.new(cx, 1.25, -(HALF + 1)))
	fence(Vector3.new(ZONE_SIZE + 2, 2.5, 1.5), Vector3.new(cx, 1.25, HALF + 1))

	local segmentLength = HALF - BRIDGE_WIDTH / 2
	local segmentCenter = BRIDGE_WIDTH / 2 + segmentLength / 2

	-- West
	if index == 1 then
		wall(Vector3.new(2, WALL_HEIGHT, ZONE_SIZE), Vector3.new(cx - (HALF + 1), WALL_HEIGHT / 2, 0))
		fence(Vector3.new(1.5, 2.5, ZONE_SIZE), Vector3.new(cx - (HALF + 1), 1.25, 0))
	else
		for _, sign in ipairs({ -1, 1 }) do
			wall(Vector3.new(2, WALL_HEIGHT, segmentLength), Vector3.new(cx - (HALF + 1), WALL_HEIGHT / 2, sign * segmentCenter))
			fence(Vector3.new(1.5, 2.5, segmentLength), Vector3.new(cx - (HALF + 1), 1.25, sign * segmentCenter))
		end
	end

	-- East
	if index == #Config.Zones then
		wall(Vector3.new(2, WALL_HEIGHT, ZONE_SIZE), Vector3.new(cx + HALF + 1, WALL_HEIGHT / 2, 0))
		fence(Vector3.new(1.5, 2.5, ZONE_SIZE), Vector3.new(cx + HALF + 1, 1.25, 0))
	else
		for _, sign in ipairs({ -1, 1 }) do
			wall(Vector3.new(2, WALL_HEIGHT, segmentLength), Vector3.new(cx + HALF + 1, WALL_HEIGHT / 2, sign * segmentCenter))
			fence(Vector3.new(1.5, 2.5, segmentLength), Vector3.new(cx + HALF + 1, 1.25, sign * segmentCenter))
		end
	end
end

local function buildBridgeAndGate(mapFolder: Folder, index: number)
	local nextZone = Config.Zones[index + 1]
	if not nextZone then
		return
	end
	local cx = zoneCenterX(index)
	local gapCenter = cx + ZONE_SPACING / 2
	local gapWidth = ZONE_SPACING - ZONE_SIZE
	local theme = nextZone.Theme

	local bridges = mapFolder:FindFirstChild("Bridges") or Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = mapFolder

	part({
		Name = "Bridge" .. index,
		Size = Vector3.new(gapWidth + 2, 2, BRIDGE_WIDTH),
		Position = Vector3.new(gapCenter, -1, 0),
		Color = theme.Trim,
		Material = Enum.Material.WoodPlanks,
	}, bridges)
	for _, sign in ipairs({ -1, 1 }) do
		part({
			Name = "Rail",
			Size = Vector3.new(gapWidth + 2, WALL_HEIGHT, 1),
			Position = Vector3.new(gapCenter, WALL_HEIGHT / 2, sign * (BRIDGE_WIDTH / 2 + 0.5)),
			Transparency = 1,
		}, bridges)
		part({
			Name = "RailVisible",
			Size = Vector3.new(gapWidth + 2, 3, 1),
			Position = Vector3.new(gapCenter, 1.5, sign * (BRIDGE_WIDTH / 2 + 0.5)),
			Color = theme.Trim,
			Material = Enum.Material.Wood,
		}, bridges)
	end

	local gates = mapFolder:FindFirstChild("Gates") or Instance.new("Folder")
	gates.Name = "Gates"
	gates.Parent = mapFolder

	local gate = part({
		Name = "Gate" .. (index + 1),
		Size = Vector3.new(2, 18, BRIDGE_WIDTH),
		Position = Vector3.new(gapCenter, 9, 0),
		Color = theme.Accent,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		CanCollide = true,
	}, gates)
	gate:SetAttribute("Zone", index + 1)
	billboard(
		gate,
		nextZone.Name,
		"Unlock: " .. Util.FormatNumber(nextZone.Cost) .. " Coins",
		theme.Accent,
		UDim2.fromOffset(320, 110),
		12
	)
end

local function buildEggStand(parent: Instance, eggKey: string, egg, position: Vector3)
	local model = Instance.new("Model")
	model.Name = eggKey
	model:SetAttribute("EggId", eggKey)

	part({
		Name = "Pedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, 10, 10),
		CFrame = CFrame.new(position + Vector3.new(0, 0.75, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Marble,
	}, model)

	local eggPart = part({
		Name = "Egg",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 6.5, 5),
		Position = position + Vector3.new(0, 1.5 + 3.25, 0),
		Color = egg.Color,
		Material = Enum.Material.SmoothPlastic,
	}, model)
	eggPart:SetAttribute("EggId", eggKey)

	local spots = part({
		Name = "Spots",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5.2, 5.2, 5.2),
		Position = position + Vector3.new(0, 1.5 + 2.6, 0),
		Color = egg.Color:Lerp(Color3.new(1, 1, 1), 0.4),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.55,
		CanCollide = false,
	}, model)
	spots.CanQuery = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HatchPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = egg.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = eggPart

	local currencyLabel = egg.Currency == "Gems" and " Gems" or " Coins"
	billboard(eggPart, egg.Name, Util.FormatNumber(egg.Cost) .. currencyLabel, egg.Color, UDim2.fromOffset(240, 90), 5.5)

	model.PrimaryPart = eggPart
	model.Parent = parent
	eggStandPositions[eggKey] = eggPart.Position
end

local function buildRebirthPortal(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "RebirthPortal"

	part({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 14, 14),
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(40, 30, 60),
		Material = Enum.Material.Marble,
	}, model)

	local ring = part({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, 12, 12),
		CFrame = CFrame.new(position + Vector3.new(0, 7, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(180, 90, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, model)
	ring:SetAttribute("Portal", "Rebirth")

	local core = part({
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 9.5, 9.5),
		CFrame = CFrame.new(position + Vector3.new(0, 7, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(255, 120, 255),
		Material = Enum.Material.ForceField,
		Transparency = 0.3,
		CanCollide = false,
	}, model)
	core.CanQuery = false

	local light = Instance.new("PointLight")
	light.Color = ring.Color
	light.Range = 20
	light.Brightness = 2
	light.Parent = ring

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RebirthPrompt"
	prompt.ActionText = "Rebirth"
	prompt.ObjectText = "Rebirth Portal"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = ring

	billboard(ring, "REBIRTH", "Reset for permanent +50% coins", ring.Color, UDim2.fromOffset(300, 100), 8)

	model.PrimaryPart = ring
	model.Parent = parent
end

local function buildLeaderboard(parent: Instance, key: string, title: string, position: Vector3)
	local board = part({
		Name = key,
		Size = Vector3.new(22, 15, 1),
		CFrame = CFrame.new(position + Vector3.new(0, 8.5, 0)) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(30, 32, 45),
		Material = Enum.Material.SmoothPlastic,
	}, parent)

	part({
		Name = "Frame",
		Size = Vector3.new(23, 16, 0.8),
		CFrame = board.CFrame * CFrame.new(0, 0, 0.2),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Metal,
	}, parent)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.ClipsDescendants = true
	gui.Adornee = board

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 90)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 210, 80)
	titleLabel.TextScaled = true
	titleLabel.Parent = gui

	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 20, 0, 100)
	list.Size = UDim2.new(1, -40, 1, -110)
	list.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, 0, 0, 40)
	status.Font = Enum.Font.Gotham
	status.Text = "Loading..."
	status.TextColor3 = Color3.fromRGB(200, 200, 210)
	status.TextScaled = true
	status.Parent = list

	gui.Parent = board
	leaderboardBoards[key] = board
end

local function buildWelcomeSign(parent: Instance, position: Vector3)
	local post = part({
		Name = "WelcomeSign",
		Size = Vector3.new(0.6, 7, 0.6),
		Position = position + Vector3.new(0, 3.5, 0),
		Color = Color3.fromRGB(140, 100, 60),
		Material = Enum.Material.Wood,
	}, parent)
	billboard(
		post,
		"Welcome to " .. Config.GameName .. "!",
		"Walk into orbs for coins  >  Hatch eggs  >  Unlock zones  >  Rebirth!",
		Color3.fromRGB(255, 230, 120),
		UDim2.fromOffset(420, 120),
		5
	)
end

--------------------------------------------------------------------------------
-- Zone
--------------------------------------------------------------------------------

local function buildZone(mapFolder: Folder, index: number)
	local zone = Config.Zones[index]
	local theme = zone.Theme
	local cx = zoneCenterX(index)
	local rng = Random.new(index * 7919)

	local zoneModel = Instance.new("Model")
	zoneModel.Name = "Zone" .. index
	zoneModel:SetAttribute("Zone", index)
	zoneModel:SetAttribute("ZoneName", zone.Name)

	part({
		Name = "Ground",
		Size = Vector3.new(ZONE_SIZE, 4, ZONE_SIZE),
		Position = Vector3.new(cx, -2, 0),
		Color = theme.Ground,
		Material = material(theme.Material),
	}, zoneModel)

	-- Path along the lane so players know where to go.
	part({
		Name = "Path",
		Size = Vector3.new(ZONE_SIZE, 0.2, 10),
		Position = Vector3.new(cx, 0.1, 0),
		Color = theme.Trim,
		Material = Enum.Material.Cobblestone,
		CanCollide = false,
	}, zoneModel)

	buildWalls(zoneModel, index, cx, theme)

	-- Decorations
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = zoneModel
	local builder = DECOR_BUILDERS[theme.Decor] or buildTree
	local placed = 0
	local attempts = 0
	while placed < 26 and attempts < 200 do
		attempts += 1
		local localX = rng:NextNumber(-HALF + 10, HALF - 10)
		local z = rng:NextNumber(-HALF + 10, HALF - 10)
		if not isReserved(index, localX, z) then
			builder(decor, Vector3.new(cx + localX, 0, z), theme, rng)
			placed += 1
		end
	end

	-- Egg stands for this zone
	local stands = Instance.new("Folder")
	stands.Name = "EggStands"
	stands.Parent = zoneModel
	local eggsHere = {}
	for _, entry in ipairs(Config.GetEggsSortedByZone()) do
		if entry.Egg.Zone == index then
			table.insert(eggsHere, entry)
		end
	end
	for i, entry in ipairs(eggsHere) do
		local offset = (i - (#eggsHere + 1) / 2) * 26
		buildEggStand(stands, entry.Key, entry.Egg, Vector3.new(cx + offset, 0, -42))
	end

	-- Zone title sign at the entrance
	local signPos = Vector3.new(cx - HALF + 14, 0, -20)
	local sign = part({
		Name = "ZoneSign",
		Size = Vector3.new(0.6, 8, 0.6),
		Position = signPos + Vector3.new(0, 4, 0),
		Color = theme.Trim,
		Material = Enum.Material.Wood,
	}, zoneModel)
	billboard(sign, zone.Name, "Zone " .. index, theme.Accent, UDim2.fromOffset(260, 90), 5.5)

	if index == 1 then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(14, 1, 14)
		spawn.Position = Vector3.new(cx - 62, 0.5, 0)
		spawn.Color = Color3.fromRGB(255, 255, 255)
		spawn.Material = Enum.Material.Neon
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = zoneModel

		buildWelcomeSign(zoneModel, Vector3.new(cx - 62, 0, -12))
		buildRebirthPortal(zoneModel, Vector3.new(cx, 0, 62))

		local boards = Instance.new("Folder")
		boards.Name = "Leaderboards"
		boards.Parent = zoneModel
		buildLeaderboard(boards, "TotalCoins", "TOP COINS", Vector3.new(cx - 36, 0, -84))
		buildLeaderboard(boards, "Rebirths", "TOP REBIRTHS", Vector3.new(cx, 0, -84))
		buildLeaderboard(boards, "PetsHatched", "TOP HATCHERS", Vector3.new(cx + 36, 0, -84))
	end

	zoneModel.Parent = mapFolder

	local spawnPos = Vector3.new(cx - 60, 4, 0)
	zoneSpawns[index] = CFrame.lookAt(spawnPos, spawnPos + Vector3.xAxis)
	zoneBounds[index] = {
		MinX = cx - HALF + 8,
		MaxX = cx + HALF - 8,
		MinZ = -HALF + 8,
		MaxZ = HALF - 8,
		Y = 3,
	}
end

--------------------------------------------------------------------------------
-- Lighting / atmosphere (asset-free)
--------------------------------------------------------------------------------

local function setupLighting()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 199, 210)
	atmosphere.Decay = Color3.fromRGB(106, 112, 125)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.15
	color.Contrast = 0.08
	color.Brightness = 0.02
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.8
	rays.Parent = Lighting

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function MapBuilder.Build()
	-- Clean any previous build (e.g. default baseplate) so Rojo sync into an
	-- existing place still produces a clean world.
	for _, name in ipairs({ "Map", "Orbs", "Baseplate", "SpawnLocation" }) do
		local existing = Workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"

	for index = 1, #Config.Zones do
		buildZone(mapFolder, index)
		buildBridgeAndGate(mapFolder, index)
	end

	mapFolder.Parent = Workspace

	local orbs = Instance.new("Folder")
	orbs.Name = "Orbs"
	orbs.Parent = Workspace

	MapBuilder.Folders.Map = mapFolder
	MapBuilder.Folders.Orbs = orbs

	setupLighting()
end

function MapBuilder.GetZoneSpawn(index: number): CFrame
	return zoneSpawns[math.clamp(index, 1, #zoneSpawns)]
end

function MapBuilder.GetZoneBounds(index: number)
	return zoneBounds[index]
end

function MapBuilder.GetEggStandPosition(eggKey: string): Vector3?
	return eggStandPositions[eggKey]
end

function MapBuilder.GetLeaderboardBoards(): { [string]: Part }
	return leaderboardBoards
end

return MapBuilder
