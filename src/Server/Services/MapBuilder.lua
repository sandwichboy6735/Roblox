--------------------------------------------------------------------------------
-- MapBuilder - procedurally builds the whole world from Config.Zones so the
-- game works with ZERO external assets: smooth terrain (themed ground, hills,
-- rivers, lava), structures (plaza, fountain, gates, egg stands, portal,
-- leaderboards) and lighting. Scenery props live in MapDecor.
--
-- Gameplay only depends on these, so decorate freely in Studio:
--   Gate parts:       Attribute "Zone" (number)
--   Egg stand parts:  Attribute "EggId" (string) + ProximityPrompt "HatchPrompt"
--   Rebirth portal:   Attribute "Portal" = "Rebirth" + ProximityPrompt "RebirthPrompt"
--------------------------------------------------------------------------------

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local EggLooks = require(Shared.EggLooks)
local MapDecor = require(script.Parent.MapDecor)

local MapBuilder = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local Terrain = Workspace.Terrain

local ZONE_SIZE = Config.Map.ZoneSize
local ZONE_SPACING = Config.Map.ZoneSpacing
local HALF = ZONE_SIZE / 2
local BRIDGE_WIDTH = 30
local WALL_HEIGHT = 40
local GROUND_DEPTH = 12

local zoneSpawns: { CFrame } = {}
local blockedSpots: { { Position: Vector3, Radius: number } } = {}
local zoneBounds: { any } = {}
local eggStandPositions: { [string]: Vector3 } = {}
local leaderboardBoards: { [string]: Part } = {}

MapBuilder.Folders = {}

-- Terrain materials per theme (Config.Zones[i].Theme.Decor).
local TERRAIN = {
	Trees = { Ground = Enum.Material.Grass, Hill = Enum.Material.LeafyGrass, Path = Enum.Material.Ground, River = Enum.Material.Water },
	Candy = { Ground = Enum.Material.Salt, Hill = Enum.Material.Sandstone, Path = Enum.Material.Pavement, River = Enum.Material.Water },
	Ice = { Ground = Enum.Material.Snow, Hill = Enum.Material.Glacier, Path = Enum.Material.Limestone, River = Enum.Material.Water },
	Rock = { Ground = Enum.Material.Basalt, Hill = Enum.Material.Basalt, Path = Enum.Material.Mud, River = Enum.Material.CrackedLava },
	Crystal = { Ground = Enum.Material.Asphalt, Hill = Enum.Material.Slate, Path = Enum.Material.Concrete, River = nil },
}

local MATERIAL_COLORS = {
	{ Enum.Material.Grass, rgb(112, 202, 72) },
	{ Enum.Material.LeafyGrass, rgb(82, 168, 60) },
	{ Enum.Material.Ground, rgb(226, 186, 122) },
	{ Enum.Material.Rock, rgb(128, 122, 118) },
	{ Enum.Material.Cobblestone, rgb(176, 168, 158) },
	{ Enum.Material.Salt, rgb(255, 190, 222) },
	{ Enum.Material.Sandstone, rgb(222, 170, 255) },
	{ Enum.Material.Pavement, rgb(255, 238, 215) },
	{ Enum.Material.Snow, rgb(238, 246, 255) },
	{ Enum.Material.Glacier, rgb(150, 205, 245) },
	{ Enum.Material.Limestone, rgb(205, 228, 245) },
	{ Enum.Material.Basalt, rgb(58, 50, 52) },
	{ Enum.Material.CrackedLava, rgb(255, 112, 30) },
	{ Enum.Material.Mud, rgb(96, 64, 52) },
	{ Enum.Material.Asphalt, rgb(52, 42, 84) },
	{ Enum.Material.Slate, rgb(74, 62, 112) },
	{ Enum.Material.Concrete, rgb(122, 112, 165) },
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function part(props: { [string]: any }, parent: Instance?): BasePart
	local p: BasePart
	if props.Wedge then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
	end
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	for key, value in pairs(props) do
		if key ~= "Wedge" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function cylinder(parent: Instance, base: Vector3, height: number, radius: number, color: Color3, mat: Enum.Material, props: { [string]: any }?): BasePart
	local p = {
		Shape = Enum.PartType.Cylinder,
		Size = V(height, radius * 2, radius * 2),
		CFrame = CFrame.new(base + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = mat,
	}
	for key, value in pairs(props or {}) do
		p[key] = value
	end
	return part(p, parent)
end

local function light(parentPart: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parentPart
end

local function zoneCenterX(index: number): number
	return (index - 1) * ZONE_SPACING
end

local function billboard(adornee: BasePart, title: string, subtitle: string?, color: Color3?, size: UDim2?, offsetY: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = size or UDim2.fromOffset(260, 90)
	gui.StudsOffset = V(0, offsetY or 5, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Adornee = adornee

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.Font = Enum.Font.LuckiestGuy
	titleLabel.Text = title
	titleLabel.TextColor3 = color or Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextStrokeColor3 = rgb(30, 22, 40)
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Font = Enum.Font.FredokaOne
	subLabel.RichText = true
	subLabel.Text = subtitle or ""
	subLabel.TextColor3 = rgb(255, 235, 150)
	subLabel.TextScaled = true
	subLabel.TextStrokeTransparency = 0.2
	subLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	subLabel.Parent = gui

	gui.Parent = adornee
	return gui
end

-- Areas kept clear of scenery (zone-local coordinates).
local function isReserved(zoneIndex: number, localX: number, z: number): boolean
	if math.abs(z) < 12 then
		return true -- main path
	end
	if z > -62 and z < -20 and math.abs(localX) < 40 then
		return true -- egg stands and their path
	end
	if math.abs(localX) < 8 and z < 0 and z > -42 then
		return true
	end
	if math.abs(localX - 44) < 13 and math.abs(z - 36) < 13 then
		return true -- Giant Chest
	end
	if zoneIndex == 1 then
		if z < -70 then
			return true -- leaderboards
		end
		if localX < -36 and math.abs(z) < 28 then
			return true -- spawn plaza
		end
		if z > 40 and math.abs(localX) < 16 then
			return true -- rebirth portal
		end
		if math.abs(localX) < 8 and z > 0 then
			return true -- portal path
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Terrain
--------------------------------------------------------------------------------

local function setupTerrain()
	Terrain:Clear()
	for _, entry in ipairs(MATERIAL_COLORS) do
		Terrain:SetMaterialColor(entry[1], entry[2])
	end
	Terrain.WaterColor = rgb(60, 160, 230)
	Terrain.WaterTransparency = 0.45
	Terrain.WaterReflectance = 0.6
	Terrain.WaterWaveSize = 0.12
	Terrain.WaterWaveSpeed = 8

	local clouds = Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.7
	clouds.Color = rgb(255, 255, 255)
	clouds.Parent = Terrain
end

local function buildZoneTerrain(index: number, cx: number, mats, rng: Random)
	-- Flat playable ground, top surface at y = 0.
	Terrain:FillBlock(CFrame.new(cx, -GROUND_DEPTH / 2, 0), V(ZONE_SIZE + 8, GROUND_DEPTH, ZONE_SIZE + 8), mats.Ground)
	-- Paths: main lane, egg area, and (zone 1) portal path
	Terrain:FillBlock(CFrame.new(cx, -2, 0), V(ZONE_SIZE + 8, 4, 12), mats.Path)
	Terrain:FillBlock(CFrame.new(cx, -2, -22), V(10, 4, 36), mats.Path)
	Terrain:FillCylinder(CFrame.new(cx, -2, -42), 4, 24, mats.Path)
	if index == 1 then
		Terrain:FillBlock(CFrame.new(cx, -2, 30), V(10, 4, 50), mats.Path)
		Terrain:FillCylinder(CFrame.new(cx - 62, -2, 0), 4, 22, Enum.Material.Cobblestone)
	end

	-- Rolling hills just outside the walls frame every zone.
	local outer = HALF + 24
	for x = cx - HALF, cx + HALF, 22 do
		for _, side in ipairs({ -1, 1 }) do
			Terrain:FillBall(V(x + rng:NextNumber(-6, 6), rng:NextNumber(-8, -2), side * (outer + rng:NextNumber(-3, 6))), rng:NextNumber(18, 27), mats.Hill)
		end
	end
	-- Big hills only on the outer edges of the world; between zones a narrow
	-- ridge fills the gap so hills never spill into the neighbouring zone.
	for z = -HALF, HALF, 22 do
		for _, side in ipairs({ -1, 1 }) do
			local isWorldEdge = (side < 0 and index == 1) or (side > 0 and index == #Config.Zones)
			if isWorldEdge then
				Terrain:FillBall(V(cx + side * (outer + rng:NextNumber(-3, 6)), rng:NextNumber(-8, -2), z + rng:NextNumber(-6, 6)), rng:NextNumber(18, 27), mats.Hill)
			end
		end
	end

	-- River / lava under the bridge to the next zone.
	local nextZone = Config.Zones[index + 1]
	if nextZone then
		local gapX = cx + ZONE_SPACING / 2
		local nextMats = TERRAIN[nextZone.Theme.Decor] or TERRAIN.Trees
		local liquid = nextMats.River
		if liquid then
			Terrain:FillBlock(CFrame.new(gapX, -12, 0), V(ZONE_SPACING - ZONE_SIZE + 8, 4, ZONE_SIZE + 20), mats.Hill)
			Terrain:FillBlock(CFrame.new(gapX, -6, 0), V(ZONE_SPACING - ZONE_SIZE + 4, 8, ZONE_SIZE + 20), liquid)
		end
		-- Ridge along the gap, leaving the bridge corridor open.
		for z = -HALF - 10, HALF + 10, 11 do
			if math.abs(z) > 30 then
				Terrain:FillBall(V(gapX + rng:NextNumber(-1.5, 1.5), rng:NextNumber(-3, 0), z), rng:NextNumber(9, 11), mats.Hill)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Structures
--------------------------------------------------------------------------------

local function buildWalls(zoneModel: Model, index: number, cx: number)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = zoneModel

	local function wall(size: Vector3, position: Vector3)
		part({ Name = "Wall", Size = size, Position = position, Transparency = 1, CanCollide = true, CastShadow = false }, walls)
	end

	wall(V(ZONE_SIZE + 2, WALL_HEIGHT, 2), V(cx, WALL_HEIGHT / 2, -(HALF + 1)))
	wall(V(ZONE_SIZE + 2, WALL_HEIGHT, 2), V(cx, WALL_HEIGHT / 2, HALF + 1))

	local segmentLength = HALF - BRIDGE_WIDTH / 2
	local segmentCenter = BRIDGE_WIDTH / 2 + segmentLength / 2
	for _, side in ipairs({ -1, 1 }) do
		local x = cx + side * (HALF + 1)
		local closed = (side < 0 and index == 1) or (side > 0 and index == #Config.Zones)
		if closed then
			wall(V(2, WALL_HEIGHT, ZONE_SIZE), V(x, WALL_HEIGHT / 2, 0))
		else
			for _, zSide in ipairs({ -1, 1 }) do
				wall(V(2, WALL_HEIGHT, segmentLength), V(x, WALL_HEIGHT / 2, zSide * segmentCenter))
			end
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
	local isSpace = theme.Decor == "Crystal"

	local bridges = mapFolder:FindFirstChild("Bridges") or Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = mapFolder

	-- Deck of planks (or a glowing glass walkway into space)
	local deckLength = gapWidth + 12
	if isSpace then
		part({ Name = "Bridge" .. index, Size = V(deckLength, 2, BRIDGE_WIDTH), Position = V(gapCenter, -1, 0), Color = rgb(120, 200, 255), Material = Enum.Material.Glass, Transparency = 0.3 }, bridges)
		for _, z in ipairs({ -BRIDGE_WIDTH / 2 + 1, BRIDGE_WIDTH / 2 - 1 }) do
			part({ Size = V(deckLength, 0.3, 0.6), Position = V(gapCenter, 0.1, z), Color = rgb(170, 90, 255), Material = Enum.Material.Neon, CastShadow = false }, bridges)
		end
	else
		for i = 0, math.floor(deckLength / 2) - 1 do
			part({
				Name = "Plank",
				Size = V(1.9, 1, BRIDGE_WIDTH),
				Position = V(gapCenter - deckLength / 2 + 1 + i * 2, -0.5, 0),
				Color = if i % 2 == 0 then rgb(150, 105, 65) else rgb(135, 95, 58),
				Material = Enum.Material.SmoothPlastic,
			}, bridges)
		end
		part({ Name = "Bridge" .. index, Size = V(deckLength, 1, BRIDGE_WIDTH), Position = V(gapCenter, -1.5, 0), Color = rgb(110, 80, 50), Material = Enum.Material.SmoothPlastic }, bridges)
	end
	for _, side in ipairs({ -1, 1 }) do
		local z = side * (BRIDGE_WIDTH / 2 + 0.5)
		part({ Name = "Rail", Size = V(deckLength, WALL_HEIGHT, 1), Position = V(gapCenter, WALL_HEIGHT / 2, z), Transparency = 1, CastShadow = false }, bridges)
		part({ Name = "Handrail", Size = V(deckLength, 0.5, 0.6), Position = V(gapCenter, 3, z), Color = theme.Trim, Material = Enum.Material.SmoothPlastic }, bridges)
		for x = gapCenter - deckLength / 2 + 1, gapCenter + deckLength / 2 - 1, 4 do
			part({ Name = "Post", Size = V(0.6, 3, 0.6), Position = V(x, 1.5, z), Color = theme.Trim, Material = Enum.Material.SmoothPlastic }, bridges)
		end
	end

	-- Stone arch with a glowing barrier (the gate itself)
	local gates = mapFolder:FindFirstChild("Gates") or Instance.new("Folder")
	gates.Name = "Gates"
	gates.Parent = mapFolder
	local archX = gapCenter + gapWidth / 2 - 2
	local stone = if isSpace then rgb(80, 70, 120) else rgb(150, 145, 140)
	local stoneMat = if isSpace then Enum.Material.Metal else Enum.Material.SmoothPlastic
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Pillar", Size = V(5, 24, 5), Position = V(archX, 12, side * (BRIDGE_WIDTH / 2 + 2.5)), Color = stone, Material = stoneMat }, gates)
		part({ Name = "PillarCap", Size = V(6, 1.5, 6), Position = V(archX, 24.75, side * (BRIDGE_WIDTH / 2 + 2.5)), Color = theme.Trim, Material = stoneMat }, gates)
		local orb = part({ Name = "PillarOrb", Shape = Enum.PartType.Ball, Size = V(2.4, 2.4, 2.4), Position = V(archX, 26.8, side * (BRIDGE_WIDTH / 2 + 2.5)), Color = theme.Accent, Material = Enum.Material.Neon, CastShadow = false }, gates)
		light(orb, theme.Accent, 16, 1.2)
	end
	part({ Name = "Lintel", Size = V(5, 3, BRIDGE_WIDTH + 10), Position = V(archX, 23.5, 0), Color = stone, Material = stoneMat }, gates)
	part({ Name = "LintelTrim", Size = V(5.3, 0.6, BRIDGE_WIDTH + 10.5), Position = V(archX, 22, 0), Color = theme.Accent, Material = Enum.Material.Neon, CastShadow = false }, gates)

	local gate = part({
		Name = "Gate" .. (index + 1),
		Size = V(1.5, 22, BRIDGE_WIDTH),
		Position = V(archX, 11, 0),
		Color = theme.Accent,
		Material = Enum.Material.ForceField,
		Transparency = 0.15,
		CanCollide = true,
		CastShadow = false,
	}, gates)
	gate:SetAttribute("Zone", index + 1)
	billboard(gate, nextZone.Name, "Walk in to unlock: " .. Util.FormatNumber(nextZone.Cost) .. " Coins", theme.Accent, UDim2.fromOffset(340, 110), 15)
end

-- Nest colours per theme: { twigs, straw }.
local NEST_COLORS = {
	Trees = { rgb(150, 100, 55), rgb(225, 185, 95) },
	Candy = { rgb(255, 205, 140), rgb(255, 120, 175) },
	Ice = { rgb(170, 215, 255), rgb(240, 250, 255) },
	Rock = { rgb(55, 42, 42), rgb(255, 120, 40) },
	Crystal = { rgb(105, 105, 140), rgb(150, 100, 255) },
}

local function buildEggStand(parent: Instance, eggKey: string, egg, position: Vector3, trim: Color3, decor: string)
	local model = Instance.new("Model")
	model.Name = eggKey
	model:SetAttribute("EggId", eggKey)

	-- Chunky toy pedestal with glowing trims
	cylinder(model, position, 1.2, 7, trim:Lerp(rgb(60, 60, 70), 0.3), Enum.Material.SmoothPlastic)
	cylinder(model, position + V(0, 1.2, 0), 0.3, 7.25, egg.Color, Enum.Material.Neon, { CastShadow = false })
	cylinder(model, position + V(0, 1.2, 0), 1.2, 4.3, rgb(250, 250, 255), Enum.Material.SmoothPlastic)
	cylinder(model, position + V(0, 2.4, 0), 0.25, 4.55, egg.Color, Enum.Material.Neon, { CastShadow = false })
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local p = position + V(math.cos(angle) * 5.6, 1.2, math.sin(angle) * 5.6)
		cylinder(model, p, 4, 0.45, rgb(250, 250, 255), Enum.Material.SmoothPlastic)
		local orb = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = V(1.2, 1.2, 1.2), Position = p + V(0, 4.55, 0), Color = egg.Color, Material = Enum.Material.Neon, CastShadow = false }, model)
		orb.CanCollide = false
	end

	-- Nest of twigs around the egg's base
	local nest = NEST_COLORS[decor] or NEST_COLORS.Trees
	local nestRng = Random.new(#eggKey * 31)
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2
		local center = position + V(math.cos(angle) * 2.55, 2.85 + nestRng:NextNumber(-0.1, 0.25), math.sin(angle) * 2.55)
		part({
			Name = "Twig",
			Shape = Enum.PartType.Cylinder,
			Size = V(2.1, 0.5, 0.5),
			CFrame = CFrame.new(center) * CFrame.Angles(0, -(angle + math.pi / 2), 0) * CFrame.Angles(nestRng:NextNumber(-0.3, 0.3), 0, nestRng:NextNumber(-0.25, 0.25)),
			Color = if i % 3 == 0 then nest[2] else nest[1],
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
		}, model)
	end

	-- The egg itself (shared look with the hatch animation)
	local eggModel, eggPart = EggLooks.Build(egg)
	eggModel:PivotTo(CFrame.new(position + V(0, 2.55, 0)))
	eggPart:SetAttribute("EggId", eggKey)
	eggModel.Parent = model

	-- An invisible sphere inside the egg blocks players without square corners.
	local collider = part({ Name = "Collider", Shape = Enum.PartType.Ball, Size = V(5, 5, 5), Position = eggPart.Position - V(0, 0.4, 0), Transparency = 1, CastShadow = false }, model)
	collider.CanQuery = false

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(egg.Color:Lerp(Color3.new(1, 1, 1), 0.5))
	sparkles.LightEmission = 1
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(1, 1.6)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = eggPart

	-- Soft light pillar rising from the egg (visible from across the zone)
	local base = Instance.new("Attachment")
	base.Name = "PillarBase"
	base.Position = V(0, 2.6, 0)
	base.Parent = eggPart
	local top = Instance.new("Attachment")
	top.Name = "PillarTop"
	top.Position = V(0, 30, 0)
	top.Parent = eggPart
	local pillar = Instance.new("Beam")
	pillar.Name = "LightPillar"
	pillar.Attachment0 = base
	pillar.Attachment1 = top
	pillar.Color = ColorSequence.new(egg.Color:Lerp(Color3.new(1, 1, 1), 0.3))
	pillar.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	pillar.Width0 = 5
	pillar.Width1 = 3
	pillar.LightEmission = 1
	pillar.FaceCamera = true
	pillar.Segments = 1
	pillar.Parent = eggPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HatchPrompt"
	prompt.ActionText = "Hatch"
	prompt.ObjectText = egg.Name .. " - " .. Util.FormatNumber(egg.Cost) .. (if egg.Currency == "Gems" then " Gems" else " Coins")
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = eggPart

	local currencyLabel = if egg.Currency == "Gems" then " Gems" else " Coins"
	billboard(eggPart, egg.Name, Util.FormatNumber(egg.Cost) .. currencyLabel, egg.Color, UDim2.fromOffset(240, 90), 5.5)

	model.PrimaryPart = eggPart
	model.Parent = parent
	eggStandPositions[eggKey] = eggPart.Position
	table.insert(blockedSpots, { Position = position, Radius = 10 })
end

local function buildRebirthPortal(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "RebirthPortal"
	local purple = rgb(180, 90, 255)

	cylinder(model, position, 1, 9, rgb(45, 35, 70), Enum.Material.SmoothPlastic)
	cylinder(model, position + V(0, 1, 0), 0.3, 9.3, purple, Enum.Material.Neon, { CastShadow = false })
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Pillar", Size = V(2.2, 15, 2.2), Position = position + V(side * 7.5, 8.5, 0), Color = rgb(60, 45, 95), Material = Enum.Material.SmoothPlastic }, model)
		local top = part({ Name = "Crystal", Size = V(1.4, 3, 1.4), CFrame = CFrame.new(position + V(side * 7.5, 17.6, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = purple, Material = Enum.Material.Neon, CastShadow = false }, model)
		top.CanCollide = false
	end

	local ring = part({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = V(1.5, 12, 12),
		CFrame = CFrame.new(position + V(0, 8, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = purple,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	}, model)
	ring:SetAttribute("Portal", "Rebirth")

	local core = part({
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = V(0.6, 10, 10),
		CFrame = CFrame.new(position + V(0, 8, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = rgb(255, 120, 255),
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		CanCollide = false,
		CastShadow = false,
	}, model)
	core.CanQuery = false

	local swirl = Instance.new("ParticleEmitter")
	swirl.Color = ColorSequence.new(rgb(255, 140, 255), rgb(140, 90, 255))
	swirl.LightEmission = 1
	swirl.Rate = 25
	swirl.Lifetime = NumberRange.new(1, 1.8)
	swirl.Speed = NumberRange.new(2, 4)
	swirl.RotSpeed = NumberRange.new(-90, 90)
	swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Parent = core
	light(ring, purple, 24, 2)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RebirthPrompt"
	prompt.ActionText = "Rebirth"
	prompt.ObjectText = "Rebirth Portal"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = ring

	billboard(ring, "REBIRTH", "Reset for permanent +50% coins", purple, UDim2.fromOffset(300, 100), 9)

	model.PrimaryPart = ring
	model.Parent = parent
	table.insert(blockedSpots, { Position = position, Radius = 11 })
end

local function buildLeaderboard(parent: Instance, key: string, title: string, position: Vector3)
	local wood = rgb(110, 80, 55)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Post", Size = V(1.4, 17, 1.4), Position = position + V(side * 11.8, 8.5, 0.6), Color = wood, Material = Enum.Material.SmoothPlastic }, parent)
	end
	part({ Name = "Roof", Size = V(26, 1.2, 4), Position = position + V(0, 17.4, 0.6), Color = rgb(170, 60, 50), Material = Enum.Material.SmoothPlastic }, parent)

	local board = part({
		Name = key,
		Size = V(22, 15, 1),
		CFrame = CFrame.new(position + V(0, 9, 0)) * CFrame.Angles(0, math.pi, 0),
		Color = rgb(30, 32, 45),
		Material = Enum.Material.SmoothPlastic,
	}, parent) :: Part

	part({ Name = "Frame", Size = V(23, 16, 0.8), CFrame = board.CFrame * CFrame.new(0, 0, 0.2), Color = rgb(255, 200, 60), Material = Enum.Material.Metal }, parent)

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
	titleLabel.TextColor3 = rgb(255, 210, 80)
	titleLabel.TextScaled = true
	titleLabel.Parent = gui

	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 20, 0, 100)
	list.Size = UDim2.new(1, -40, 1, -110)
	list.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, 0, 0, 40)
	status.Font = Enum.Font.Gotham
	status.Text = "Loading..."
	status.TextColor3 = rgb(200, 200, 210)
	status.TextScaled = true
	status.Parent = list

	gui.Parent = board
	leaderboardBoards[key] = board
end

local function buildPlaza(zoneModel: Model, cx: number)
	local plaza = Instance.new("Folder")
	plaza.Name = "SpawnPlaza"
	plaza.Parent = zoneModel
	local center = V(cx - 62, 0, 0)

	-- Fountain at the west end of the plaza
	local fountain = center + V(-12, 0, 0)
	cylinder(plaza, fountain, 1.6, 7, rgb(205, 200, 195), Enum.Material.SmoothPlastic)
	cylinder(plaza, fountain + V(0, 1.2, 0), 0.5, 6.2, rgb(80, 170, 255), Enum.Material.Glass, { Transparency = 0.25, Reflectance = 0.25, CanCollide = false })
	cylinder(plaza, fountain + V(0, 1.6, 0), 4, 0.9, rgb(225, 220, 215), Enum.Material.SmoothPlastic)
	local bowl = cylinder(plaza, fountain + V(0, 5.4, 0), 0.8, 2.8, rgb(225, 220, 215), Enum.Material.SmoothPlastic)
	cylinder(plaza, fountain + V(0, 6.0, 0), 0.25, 2.4, rgb(80, 170, 255), Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(rgb(200, 235, 255))
	spray.LightEmission = 0.4
	spray.Rate = 60
	spray.Lifetime = NumberRange.new(0.9, 1.3)
	spray.Speed = NumberRange.new(9, 12)
	spray.SpreadAngle = Vector2.new(14, 14)
	spray.Acceleration = V(0, -22, 0)
	spray.EmissionDirection = Enum.NormalId.Right -- cylinder X axis points up
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.15) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.8) })
	spray.Parent = bowl

	-- Lamp posts around the plaza
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local p = center + V(math.cos(angle) * 17, 0, math.sin(angle) * 17)
		cylinder(plaza, p, 9, 0.35, rgb(45, 45, 55), Enum.Material.Metal)
		local lamp = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = V(1.8, 1.8, 1.8), Position = p + V(0, 9.6, 0), Color = rgb(255, 225, 160), Material = Enum.Material.Neon, CastShadow = false }, plaza)
		light(lamp, rgb(255, 220, 160), 16, 1)
	end

	-- Flower beds
	local colors = { rgb(255, 120, 170), rgb(255, 225, 80), rgb(185, 130, 255), rgb(255, 255, 255) }
	for i = 0, 7 do
		local angle = math.rad(i * 45 + 22.5)
		local p = center + V(math.cos(angle) * 21, 0, math.sin(angle) * 21)
		if p.X > center.X - 2 or math.abs(p.Z) > 8 then
			for j = 1, 4 do
				local f = p + V((j - 2.5) * 0.9, 0, (j % 2) * 0.8)
				cylinder(plaza, f, 1.1, 0.07, rgb(70, 150, 50), Enum.Material.SmoothPlastic, { CastShadow = false, CanCollide = false })
				part({ Shape = Enum.PartType.Ball, Size = V(0.7, 0.7, 0.7), Position = f + V(0, 1.25, 0), Color = colors[(i + j) % #colors + 1], Material = Enum.Material.SmoothPlastic, CanCollide = false, CastShadow = false }, plaza)
			end
		end
	end

	-- Welcome sign
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "SignPost", Size = V(0.6, 6, 0.6), Position = center + V(2, 3, -14 + side * 3.5), Color = rgb(120, 85, 55), Material = Enum.Material.SmoothPlastic }, plaza)
	end
	local signBoard = part({ Name = "WelcomeSign", Size = V(0.5, 3, 8), Position = center + V(2, 5.5, -14), Color = rgb(150, 110, 70), Material = Enum.Material.SmoothPlastic }, plaza)
	billboard(signBoard, "Welcome to " .. Config.GameName .. "!", "Collect coins > Hatch pets > Break chests > Unlock zones", rgb(255, 230, 120), UDim2.fromOffset(420, 120), 4)

	-- Spawn pad (players face +X, toward the zone)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = V(10, 0.4, 10)
	spawn.CFrame = CFrame.lookAt(center + V(4, 0.2, 0), center + V(10, 0.2, 0))
	spawn.Color = rgb(255, 255, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = zoneModel
	cylinder(plaza, center + V(4, 0.38, 0), 0.06, 4.6, rgb(255, 210, 80), Enum.Material.Neon, { CastShadow = false, CanCollide = false })
end

local function buildSpaceFloor(zoneModel: Model, cx: number)
	local grid = Instance.new("Folder")
	grid.Name = "NeonGrid"
	grid.Parent = zoneModel
	for offset = -75, 75, 30 do
		part({ Size = V(ZONE_SIZE - 10, 0.12, 0.35), Position = V(cx, 0.06, offset), Color = rgb(150, 90, 255), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, grid)
		part({ Size = V(0.35, 0.12, ZONE_SIZE - 10), Position = V(cx + offset, 0.06, 0), Color = rgb(90, 200, 255), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, grid)
	end
end

--------------------------------------------------------------------------------
-- Zone
--------------------------------------------------------------------------------

local function buildZone(mapFolder: Folder, index: number)
	local zone = Config.Zones[index]
	local theme = zone.Theme
	local cx = zoneCenterX(index)
	local rng = Random.new(index * 7919)
	local mats = TERRAIN[theme.Decor] or TERRAIN.Trees

	local zoneModel = Instance.new("Model")
	zoneModel.Name = "Zone" .. index
	zoneModel:SetAttribute("Zone", index)
	zoneModel:SetAttribute("ZoneName", zone.Name)

	buildZoneTerrain(index, cx, mats, rng)
	buildWalls(zoneModel, index, cx)
	if theme.Decor == "Crystal" then
		buildSpaceFloor(zoneModel, cx)
	end

	-- Scenery
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = zoneModel
	local placed, attempts = 0, 0
	local target = 46
	while placed < target and attempts < 300 do
		attempts += 1
		local localX = rng:NextNumber(-HALF + 9, HALF - 9)
		local z = rng:NextNumber(-HALF + 9, HALF - 9)
		if not isReserved(index, localX, z) then
			MapDecor.Place(theme.Decor, decor, V(cx + localX, 0, z), rng)
			placed += 1
		end
	end
	MapDecor.Backdrop(theme.Decor, decor, V(cx, 0, 0), rng)
	MapDecor.Clouds(theme.Decor, decor, V(cx, 0, 0), rng)
	table.insert(blockedSpots, { Position = V(cx + 44, 0, 36), Radius = 9 })

	-- Egg stands
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
		buildEggStand(stands, entry.Key, entry.Egg, V(cx + offset, 0, -42), theme.Trim, theme.Decor)
	end

	-- Zone sign at the entrance
	local signPos = V(cx - HALF + 14, 0, -16)
	for _, dz in ipairs({ -3, 3 }) do
		part({ Name = "SignPost", Size = V(0.7, 7, 0.7), Position = signPos + V(0, 3.5, dz), Color = theme.Trim, Material = Enum.Material.SmoothPlastic }, zoneModel)
	end
	local sign = part({ Name = "ZoneSign", Size = V(0.6, 3.2, 7.5), Position = signPos + V(0, 6.2, 0), Color = theme.Trim:Lerp(rgb(255, 255, 255), 0.2), Material = Enum.Material.SmoothPlastic }, zoneModel)
	billboard(sign, zone.Name, "Zone " .. index, theme.Accent, UDim2.fromOffset(260, 90), 4.5)

	if index == 1 then
		buildPlaza(zoneModel, cx)
		buildRebirthPortal(zoneModel, V(cx, 0, 62))
		local boards = Instance.new("Folder")
		boards.Name = "Leaderboards"
		boards.Parent = zoneModel
		buildLeaderboard(boards, "TotalCoins", "TOP COINS", V(cx - 36, 0, -84))
		buildLeaderboard(boards, "Rebirths", "TOP REBIRTHS", V(cx, 0, -84))
		buildLeaderboard(boards, "PetsHatched", "TOP HATCHERS", V(cx + 36, 0, -84))
	end

	zoneModel.Parent = mapFolder

	local spawnPos = V(cx - 60, 4, 0)
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
-- Lighting / atmosphere (the client tweens these per zone)
--------------------------------------------------------------------------------

local function setupLighting()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.StarCount = 3000
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = rgb(199, 212, 232)
	atmosphere.Decay = rgb(110, 120, 140)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.85
	bloom.Size = 24
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "ZoneColor"
	color.Saturation = 0.3
	color.Contrast = 0.12
	color.Brightness = 0.03
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.7
	rays.Parent = Lighting

	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.7
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
	table.clear(blockedSpots)

	setupTerrain()
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

-- Zone index containing this world position (nil on bridges / outside).
function MapBuilder.GetZoneAt(position: Vector3): number?
	return Config.GetZoneAtPosition(position)
end

-- True if an orb at this position would sit inside an egg stand or portal.
function MapBuilder.IsSpotBlocked(position: Vector3): boolean
	local flat = V(position.X, 0, position.Z)
	for _, spot in ipairs(blockedSpots) do
		local center = V(spot.Position.X, 0, spot.Position.Z)
		if (flat - center).Magnitude < spot.Radius then
			return true
		end
	end
	return false
end

-- Keeps orbs and breakables out of a circle (e.g. around a Giant Chest).
function MapBuilder.BlockSpot(position: Vector3, radius: number)
	table.insert(blockedSpots, { Position = position, Radius = radius })
end

-- Where each zone's Giant Chest sits (kept clear of stands, portal and plaza).
function MapBuilder.GetGiantChestSpot(index: number): Vector3
	return V(zoneCenterX(index) + 44, 0, 36)
end

function MapBuilder.GetEggStandPosition(eggKey: string): Vector3?
	return eggStandPositions[eggKey]
end

function MapBuilder.GetLeaderboardBoards(): { [string]: Part }
	return leaderboardBoards
end

return MapBuilder
