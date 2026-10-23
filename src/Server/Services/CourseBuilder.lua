--------------------------------------------------------------------------------
-- CourseBuilder - generates the whole obby from Config (no uploaded assets):
-- a lobby, 100 stages of obstacles that get harder world by world, coins,
-- checkpoints, a finish portal, terrain, scenery and lighting.
--
-- The course is deterministic (Config.Course.Seed), so every server has the
-- same stages and saved checkpoint numbers always match.
--
-- Attributes other services and the client rely on:
--   Checkpoint trigger parts: "Stage" (number)      Finish trigger: "Finish" = true
--   Kill parts: "Kill" = true                        Coins: "CoinId", "Stage"
--   Jump pads: "Launch" (Vector3 velocity)          Movers: see MoverService
--   Stage models: "Stage", "FloorY" (lowest platform top, for fall respawns)
--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BrainrotBuilder = require(Shared.BrainrotBuilder)

local CourseDecor = require(script.Parent.CourseDecor)

local CourseBuilder = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local Terrain = Workspace.Terrain

local PAD_SIZE = 12
local MAX_Z = 48 -- the course meanders inside this corridor

local checkpoints: { [number]: CFrame } = {}
local floorY: { [number]: number } = {}
local stageStartX: { [number]: number } = {}
local worldRange: { [number]: { Min: number, Max: number } } = {}
local leaderboardBoards: { [string]: Part } = {}
local courseFolder: Folder

CourseBuilder.Folders = {}

--------------------------------------------------------------------------------
-- Part helpers
--------------------------------------------------------------------------------

local function part(props: { [string]: any }, parent: Instance?): BasePart
	local p: BasePart
	if props.Wedge then
		p = Instance.new("WedgePart")
	elseif props.Truss then
		p = Instance.new("TrussPart")
	else
		p = Instance.new("Part")
	end
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		if key ~= "Wedge" and key ~= "Truss" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * math.clamp(t, 0, 1)
end

-- Builder state for one stage.
type Ctx = {
	Model: Model,
	Theme: any,
	D: number, -- difficulty 0..1
	Rng: Random,
	Stage: number,
	Walkables: { BasePart }, -- platforms coins may sit on
	MinY: number,
}

local function walkable(c: Ctx, p: BasePart)
	table.insert(c.Walkables, p)
	c.MinY = math.min(c.MinY, p.Position.Y + p.Size.Y / 2)
end

-- A platform with a darker rim so edges read clearly from above.
local function platform(c: Ctx, cf: CFrame, size: Vector3, color: Color3?): BasePart
	local p = part({ Name = "Platform", CFrame = cf, Size = size, Color = color or c.Theme.Platform }, c.Model)
	part({
		Name = "Rim",
		CFrame = cf * CFrame.new(0, -size.Y / 2 - 0.2, 0),
		Size = V(size.X + 0.6, 0.4, size.Z + 0.6),
		Color = c.Theme.Trim,
		CanCollide = false,
		CastShadow = false,
	}, c.Model)
	walkable(c, p)
	return p
end

local function kill(c: Ctx, cf: CFrame, size: Vector3, name: string?): BasePart
	local p = part({
		Name = name or "Lava",
		CFrame = cf,
		Size = size,
		Color = c.Theme.Hazard,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	}, c.Model)
	p:SetAttribute("Kill", true)
	CollectionService:AddTag(p, "Kill")
	return p
end

-- Lava pool: a glowing neon slab a little below the platforms.
local function lavaPool(c: Ctx, center: Vector3, size: Vector3)
	local pool = kill(c, CFrame.new(center), size, "LavaPool")
	pool.Transparency = 0.1
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Color = ColorSequence.new(c.Theme.Hazard:Lerp(Color3.new(1, 1, 1), 0.4))
	bubbles.LightEmission = 1
	bubbles.Rate = math.clamp(size.X * size.Z / 60, 2, 12)
	bubbles.Lifetime = NumberRange.new(0.8, 1.4)
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	bubbles.Parent = pool
end

--------------------------------------------------------------------------------
-- Obstacle sections. Each takes the cursor (ground-level start point, x axis is
-- forward) and returns the cursor where the next section begins.
--------------------------------------------------------------------------------

local Sections = {}

-- Platforms with growing gaps.
Sections.Jumps = function(c: Ctx, cursor: Vector3): Vector3
	local count = c.Rng:NextInteger(3, 5)
	local size = lerp(8, 4.5, c.D)
	local gap = lerp(4, 9, c.D)
	local x = cursor.X
	local y = cursor.Y
	local z = cursor.Z
	for i = 1, count do
		x += gap + c.Rng:NextNumber(-0.5, 0.8) + size / 2
		y += c.Rng:NextNumber(-1, 1.5) * c.D
		z += c.Rng:NextNumber(-3, 3) * c.D
		platform(c, CFrame.new(x, y - 0.5, z), V(size, 1, size))
		x += size / 2
	end
	return V(x, y, z)
end

-- Stepping stones across a lava pool.
Sections.LavaSteps = function(c: Ctx, cursor: Vector3): Vector3
	local count = c.Rng:NextInteger(4, 7)
	local spacing = lerp(4.5, 7.5, c.D)
	local size = lerp(5, 2.8, c.D)
	local length = count * spacing + 8
	lavaPool(c, V(cursor.X + length / 2, cursor.Y - 4, cursor.Z), V(length + 6, 1, 26))
	local x, z = cursor.X + 4, cursor.Z
	for i = 1, count do
		x += spacing
		z += c.Rng:NextNumber(-4, 4) * (0.4 + c.D)
		platform(c, CFrame.new(x, cursor.Y - 0.5, z), V(size, 1, size))
	end
	return V(x + size / 2 + 2, cursor.Y, z)
end

-- Platforms that slide back and forth over a gap.
Sections.Movers = function(c: Ctx, cursor: Vector3): Vector3
	local count = c.Rng:NextInteger(2, 3)
	local span = lerp(14, 20, c.D)
	local size = lerp(7, 4.5, c.D)
	lavaPool(c, V(cursor.X + (span * count) / 2 + 4, cursor.Y - 5, cursor.Z), V(span * count + 10, 1, 30))
	local x = cursor.X + 2
	for i = 1, count do
		x += span
		local sideways = c.Rng:NextNumber() < 0.5
		local p = platform(c, CFrame.new(x - span / 2 + 2, cursor.Y - 0.5, cursor.Z), V(size, 1, size), c.Theme.Accent)
		p.Name = "MovingPlatform"
		p:SetAttribute("MoveKind", "Slide")
		p:SetAttribute("MoveAxis", if sideways then V(0, 0, 1) else V(1, 0, 0))
		p:SetAttribute("MoveDistance", if sideways then lerp(6, 10, c.D) else span - size - 2)
		p:SetAttribute("MovePeriod", lerp(4.5, 2.6, c.D))
		p:SetAttribute("MovePhase", c.Rng:NextNumber(0, 1))
	end
	return V(x + 2, cursor.Y, cursor.Z)
end

-- A round arena with spinning kill bars.
Sections.Spinner = function(c: Ctx, cursor: Vector3): Vector3
	local radius = lerp(9, 11, c.D)
	local center = V(cursor.X + radius + 1, cursor.Y - 0.5, cursor.Z)
	local disc = part({ Name = "Arena", Shape = Enum.PartType.Cylinder, Size = V(1, radius * 2, radius * 2), CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Color = c.Theme.Platform }, c.Model)
	walkable(c, disc)
	part({ Name = "Rim", Shape = Enum.PartType.Cylinder, Size = V(0.4, radius * 2 + 0.8, radius * 2 + 0.8), CFrame = CFrame.new(center - V(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = c.Theme.Trim, CanCollide = false, CastShadow = false }, c.Model)
	local hub = part({ Name = "Hub", Shape = Enum.PartType.Cylinder, Size = V(3, 2.4, 2.4), CFrame = CFrame.new(center + V(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = c.Theme.Trim }, c.Model)
	hub.CanCollide = true
	local bars = if c.D > 0.6 then 2 else 1
	for i = 1, bars do
		local bar = kill(c, CFrame.new(center + V(0, 1.6, 0)) * CFrame.Angles(0, (i - 1) * math.pi / 2, 0), V(radius * 2 - 1, 1.6, 1.2), "SpinBar")
		bar.CanCollide = true
		bar:SetAttribute("MoveKind", "Spin")
		bar:SetAttribute("SpinSpeed", lerp(55, 140, c.D) * (if i == 2 then -1 else 1))
	end
	return V(center.X + radius, cursor.Y, cursor.Z)
end

-- Platforms that fade out on a timer.
Sections.Vanish = function(c: Ctx, cursor: Vector3): Vector3
	local count = c.Rng:NextInteger(5, 8)
	local size = lerp(6, 4, c.D)
	local spacing = size + lerp(2.5, 5, c.D)
	local x, z = cursor.X, cursor.Z
	for i = 1, count do
		x += spacing
		z += c.Rng:NextNumber(-2, 2) * c.D
		local p = platform(c, CFrame.new(x, cursor.Y - 0.5, z), V(size, 1, size), c.Theme.Accent)
		p.Name = "VanishPlatform"
		p:SetAttribute("MoveKind", "Vanish")
		p:SetAttribute("VanishPeriod", lerp(3.2, 2.2, c.D))
		p:SetAttribute("VanishPhase", (i % 2) * 0.5)
	end
	return V(x + size / 2 + 1, cursor.Y, z)
end

-- Conveyor belts over lava with blocks to dodge.
Sections.Conveyor = function(c: Ctx, cursor: Vector3): Vector3
	local length = lerp(22, 30, c.D)
	local width = 7
	local center = V(cursor.X + length / 2 + 2, cursor.Y - 0.5, cursor.Z)
	lavaPool(c, V(center.X, cursor.Y - 4, cursor.Z), V(length + 8, 1, 26))
	local backwards = c.Rng:NextNumber() < 0.6
	local belt = part({ Name = "Conveyor", CFrame = CFrame.new(center), Size = V(length, 1, width), Color = c.Theme.Trim }, c.Model)
	walkable(c, belt)
	local speed = lerp(8, 18, c.D)
	belt.AssemblyLinearVelocity = if backwards then V(-speed, 0, 0) else V(0, 0, (if c.Rng:NextNumber() < 0.5 then speed else -speed))
	belt:SetAttribute("Conveyor", true)
	-- arrows painted on the belt so the direction is obvious
	for x = -length / 2 + 3, length / 2 - 3, 4 do
		part({ Name = "Arrow", Wedge = true, Size = V(2, 0.1, 1.4), CFrame = CFrame.new(center + V(x, 0.55, 0)) * CFrame.Angles(0, if backwards then math.rad(-90) else 0, 0), Color = c.Theme.Accent, CanCollide = false, CastShadow = false }, c.Model)
	end
	local blocks = c.Rng:NextInteger(2, 4)
	for i = 1, blocks do
		local bx = center.X - length / 2 + (i / (blocks + 1)) * length
		local bz = cursor.Z + c.Rng:NextNumber(-width / 2 + 1, width / 2 - 1)
		local block = kill(c, CFrame.new(bx, cursor.Y + 1.2, bz), V(2, 2.4, 2), "KillBlock")
		block.CanCollide = true
		block.Material = Enum.Material.Neon
	end
	return V(center.X + length / 2 + 1, cursor.Y, cursor.Z)
end

-- A wall of ledges with truss ladders that gains a lot of height.
Sections.Climb = function(c: Ctx, cursor: Vector3): Vector3
	local steps = c.Rng:NextInteger(3, 4)
	local rise = lerp(4, 6, c.D)
	local x, y, z = cursor.X + 3, cursor.Y, cursor.Z
	for i = 1, steps do
		local ledge = platform(c, CFrame.new(x + 3, y - 0.5, z), V(7, 1, 7))
		if i < steps then
			-- a ladder leaning up to the next ledge
			part({ Name = "Ladder", Truss = true, Size = V(2, rise + 1, 2), CFrame = CFrame.new(x + 6.5, y + rise / 2, z + (if i % 2 == 0 then 2 else -2)), Color = c.Theme.Trim }, c.Model)
		end
		ledge.Size = V(7, 1, 7)
		x += 7
		y += rise
	end
	y -= rise
	platform(c, CFrame.new(x + 2, y - 0.5, z), V(6, 1, 8))
	return V(x + 5, y, z)
end

-- Narrow beams over lava.
Sections.Beams = function(c: Ctx, cursor: Vector3): Vector3
	local width = lerp(2.2, 0.9, c.D)
	local length = lerp(16, 24, c.D)
	lavaPool(c, V(cursor.X + length + 4, cursor.Y - 4, cursor.Z), V(length * 2 + 12, 1, 30))
	local x = cursor.X + 1
	local beam = part({ Name = "Beam", CFrame = CFrame.new(x + length / 2, cursor.Y - 0.5, cursor.Z), Size = V(length, 1, width), Color = c.Theme.Accent }, c.Model)
	walkable(c, beam)
	x += length
	local dz = (if c.Rng:NextNumber() < 0.5 then 1 else -1) * lerp(4, 8, c.D)
	-- a side step: second beam offset in Z, joined by a tiny landing
	local landing = platform(c, CFrame.new(x + 2, cursor.Y - 0.5, cursor.Z), V(3, 1, 3))
	landing.Name = "Landing"
	local beam2 = part({ Name = "Beam", CFrame = CFrame.new(x + 2, cursor.Y - 0.5, cursor.Z + dz / 2), Size = V(width, 1, math.abs(dz)), Color = c.Theme.Accent }, c.Model)
	walkable(c, beam2)
	local beam3 = part({ Name = "Beam", CFrame = CFrame.new(x + 2 + length * 0.6 / 2, cursor.Y - 0.5, cursor.Z + dz), Size = V(length * 0.6, 1, width), Color = c.Theme.Accent }, c.Model)
	walkable(c, beam3)
	return V(x + 2 + length * 0.6, cursor.Y, cursor.Z + dz)
end

-- A jump pad that launches you over a big gap.
Sections.Pads = function(c: Ctx, cursor: Vector3): Vector3
	local gap = lerp(18, 26, c.D)
	local launch = platform(c, CFrame.new(cursor.X + 4, cursor.Y - 0.5, cursor.Z), V(8, 1, 8))
	launch.Name = "LaunchPlatform"
	local pad = part({ Name = "JumpPad", Shape = Enum.PartType.Cylinder, Size = V(0.4, 5, 5), CFrame = CFrame.new(cursor.X + 5.5, cursor.Y + 0.2, cursor.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = c.Theme.Accent, Material = Enum.Material.Neon, CanCollide = false }, c.Model)
	-- Flight time with gravity 196.2: pick vertical speed for a nice arc, then
	-- horizontal speed to cover the gap.
	local up = 62
	local flight = 2 * up / Workspace.Gravity
	local forward = (gap + 4) / flight
	pad:SetAttribute("Launch", V(forward, up, 0))
	local glow = Instance.new("PointLight")
	glow.Color = c.Theme.Accent
	glow.Range = 8
	glow.Parent = pad
	lavaPool(c, V(cursor.X + 8 + gap / 2, cursor.Y - 6, cursor.Z), V(gap + 2, 1, 24))
	local landing = platform(c, CFrame.new(cursor.X + 8 + gap + 6, cursor.Y - 0.5, cursor.Z), V(12, 1, 12))
	landing.Name = "Landing"
	return V(cursor.X + 8 + gap + 12, cursor.Y, cursor.Z)
end

-- Tall pillars of different heights.
Sections.Pillars = function(c: Ctx, cursor: Vector3): Vector3
	local count = c.Rng:NextInteger(4, 7)
	local spacing = lerp(5, 7.5, c.D)
	local top = lerp(3.5, 2.2, c.D)
	local x, z = cursor.X, cursor.Z
	local y = cursor.Y
	for i = 1, count do
		x += spacing
		z += c.Rng:NextNumber(-2.5, 2.5)
		y = cursor.Y + c.Rng:NextNumber(-1, 3) * (0.5 + c.D)
		local height = 10 + (y - cursor.Y)
		local pillar = part({ Name = "Pillar", CFrame = CFrame.new(x, y - height / 2, z), Size = V(top, height, top), Color = c.Theme.Platform }, c.Model)
		walkable(c, pillar)
		part({ Name = "Cap", CFrame = CFrame.new(x, y + 0.05, z), Size = V(top + 0.4, 0.1, top + 0.4), Color = c.Theme.Accent, CanCollide = false, CastShadow = false }, c.Model)
	end
	return V(x + top / 2 + 1, y, z)
end

-- A corridor with walls sliding across it.
Sections.Walls = function(c: Ctx, cursor: Vector3): Vector3
	local length = lerp(22, 30, c.D)
	local width = 10
	local floor = platform(c, CFrame.new(cursor.X + length / 2 + 1, cursor.Y - 0.5, cursor.Z), V(length, 1, width))
	floor.Name = "Corridor"
	local count = c.Rng:NextInteger(2, 4)
	for i = 1, count do
		local x = cursor.X + 1 + (i / (count + 1)) * length
		local wall = kill(c, CFrame.new(x, cursor.Y + 2, cursor.Z - width / 2), V(1.2, 4, width * 0.55), "SlidingWall")
		wall.CanCollide = true
		wall:SetAttribute("MoveKind", "Slide")
		wall:SetAttribute("MoveAxis", V(0, 0, 1))
		wall:SetAttribute("MoveDistance", width)
		wall:SetAttribute("MovePeriod", lerp(3, 1.8, c.D))
		wall:SetAttribute("MovePhase", (i % 2) * 0.5 + c.Rng:NextNumber(0, 0.2))
	end
	return V(cursor.X + length + 1, cursor.Y, cursor.Z)
end

-- Which sections are allowed at a difficulty, with weights.
local SECTION_TABLE = {
	{ Name = "Jumps", Min = 0, Weight = 3 },
	{ Name = "LavaSteps", Min = 0.05, Weight = 3 },
	{ Name = "Pillars", Min = 0.12, Weight = 2 },
	{ Name = "Pads", Min = 0.15, Weight = 1.5 },
	{ Name = "Beams", Min = 0.2, Weight = 2 },
	{ Name = "Vanish", Min = 0.3, Weight = 2 },
	{ Name = "Movers", Min = 0.3, Weight = 2 },
	{ Name = "Climb", Min = 0.35, Weight = 1.5 },
	{ Name = "Conveyor", Min = 0.4, Weight = 2 },
	{ Name = "Spinner", Min = 0.45, Weight = 2 },
	{ Name = "Walls", Min = 0.55, Weight = 2 },
}

local function pickSection(c: Ctx, used: { [string]: boolean }): string
	local candidates, weights = {}, {}
	for _, entry in ipairs(SECTION_TABLE) do
		if c.D >= entry.Min and not used[entry.Name] then
			table.insert(candidates, entry.Name)
			table.insert(weights, entry.Weight)
		end
	end
	local total = 0
	for _, w in ipairs(weights) do
		total += w
	end
	local roll = c.Rng:NextNumber(0, total)
	for index, w in ipairs(weights) do
		roll -= w
		if roll <= 0 then
			return candidates[index]
		end
	end
	return candidates[#candidates] or "Jumps"
end

--------------------------------------------------------------------------------
-- Checkpoints, coins and the finish
--------------------------------------------------------------------------------

local function billboard(adornee: BasePart, title: string, subtitle: string?, color: Color3, offsetY: number, size: UDim2?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = size or UDim2.fromOffset(220, 80)
	gui.StudsOffset = V(0, offsetY, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0.58, 0)
	titleLabel.Font = Enum.Font.LuckiestGuy
	titleLabel.Text = title
	titleLabel.TextColor3 = color
	titleLabel.TextScaled = true
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextStrokeColor3 = rgb(30, 22, 40)
	titleLabel.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Name = "Subtitle"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.new(0, 0, 0.58, 0)
	sub.Size = UDim2.new(1, 0, 0.42, 0)
	sub.Font = Enum.Font.FredokaOne
	sub.RichText = true
	sub.Text = subtitle or ""
	sub.TextColor3 = rgb(255, 245, 210)
	sub.TextScaled = true
	sub.TextStrokeTransparency = 0
	sub.TextStrokeColor3 = rgb(30, 22, 40)
	sub.Parent = gui
	gui.Parent = adornee
	return gui
end

local function buildCheckpoint(c: Ctx, cursor: Vector3, stage: number)
	local pad = platform(c, CFrame.new(cursor.X + PAD_SIZE / 2, cursor.Y - 0.5, cursor.Z), V(PAD_SIZE, 1, PAD_SIZE))
	pad.Name = "CheckpointPad"
	-- glowing ring + beacon
	local ring = part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = V(0.2, 7, 7), CFrame = CFrame.new(pad.Position + V(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = c.Theme.Accent, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, c.Model)
	ring.Name = "CheckpointRing"
	local trigger = part({ Name = "Checkpoint", CFrame = CFrame.new(pad.Position + V(0, 4, 0)), Size = V(PAD_SIZE, 7, PAD_SIZE), Transparency = 1, CanCollide = false, CastShadow = false }, c.Model)
	trigger.CanQuery = false
	trigger:SetAttribute("Stage", stage)
	CollectionService:AddTag(trigger, "Checkpoint")
	local beacon = part({ Name = "Beacon", Size = V(0.6, 14, 0.6), CFrame = CFrame.new(pad.Position + V(0, 7.5, -PAD_SIZE / 2 + 0.8)), Color = c.Theme.Trim, CanCollide = false }, c.Model)
	local lamp = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = V(2, 2, 2), CFrame = CFrame.new(beacon.Position + V(0, 7.5, 0)), Color = c.Theme.Accent, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, c.Model)
	local light = Instance.new("PointLight")
	light.Color = c.Theme.Accent
	light.Range = 18
	light.Brightness = 1.4
	light.Parent = lamp
	local world, inWorld = Config.GetWorld(stage)
	local worldIndex = Config.GetWorldForStage(stage)
	billboard(lamp, "STAGE " .. stage, if inWorld == 1 then world.Name else "", c.Theme.Accent, 3, UDim2.fromOffset(260, 90))
	if inWorld == 1 then
		-- a big arch announcing the world
		local archX = pad.Position.X - PAD_SIZE / 2 - 1
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "ArchPost", Size = V(2, 16, 2), CFrame = CFrame.new(archX, cursor.Y + 8, cursor.Z + side * 9), Color = c.Theme.Trim }, c.Model)
		end
		local top = part({ Name = "ArchTop", Size = V(2.4, 2.4, 20), CFrame = CFrame.new(archX, cursor.Y + 17, cursor.Z), Color = c.Theme.Accent, Material = Enum.Material.Neon }, c.Model)
		billboard(top, world.Name, "WORLD " .. worldIndex, c.Theme.Accent, 4, UDim2.fromOffset(420, 110))
	end
	checkpoints[stage] = CFrame.new(pad.Position + V(0, 3.5, 0))
	return V(cursor.X + PAD_SIZE, cursor.Y, cursor.Z)
end

local function placeCoins(c: Ctx)
	if #c.Walkables == 0 then
		return
	end
	local count = c.Rng:NextInteger(Config.Course.CoinsPerStage[1], Config.Course.CoinsPerStage[2])
	local folder = Instance.new("Folder")
	folder.Name = "Coins"
	folder.Parent = c.Model
	for i = 1, count do
		local base = c.Walkables[c.Rng:NextInteger(1, #c.Walkables)]
		local size = base.Size
		local offset = V(c.Rng:NextNumber(-size.X * 0.3, size.X * 0.3), 0, c.Rng:NextNumber(-size.Z * 0.3, size.Z * 0.3))
		if base.Shape == Enum.PartType.Cylinder then
			offset = V(0, 0, c.Rng:NextNumber(-size.Y * 0.3, size.Y * 0.3)) -- arena discs lie on their side
		end
		local coin = part({
			Name = "Coin",
			Shape = Enum.PartType.Cylinder,
			Size = V(0.4, 2.2, 2.2),
			CFrame = CFrame.new(base.Position + V(0, size.Y / 2, 0) + offset + V(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(255, 205, 40),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			CastShadow = false,
		}, folder)
		coin:SetAttribute("CoinId", "S" .. c.Stage .. "_" .. i)
		coin:SetAttribute("Stage", c.Stage)
		CollectionService:AddTag(coin, "Coin")
	end
end

local function buildFinish(c: Ctx, cursor: Vector3)
	local pad = platform(c, CFrame.new(cursor.X + 10, cursor.Y - 0.5, cursor.Z), V(20, 1, 20), rgb(255, 215, 80))
	pad.Name = "FinishPad"
	local purple = rgb(190, 90, 255)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Pillar", Size = V(2.5, 16, 2.5), CFrame = CFrame.new(cursor.X + 10, cursor.Y + 8, cursor.Z + side * 7.5), Color = rgb(60, 45, 95) }, c.Model)
	end
	local ring = part({ Name = "Portal", Shape = Enum.PartType.Cylinder, Size = V(1.5, 13, 13), CFrame = CFrame.new(cursor.X + 10, cursor.Y + 8.5, cursor.Z) * CFrame.Angles(0, 0, math.rad(0)), Color = purple, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, c.Model)
	local core = part({ Name = "Core", Shape = Enum.PartType.Cylinder, Size = V(0.6, 11, 11), CFrame = ring.CFrame, Color = rgb(255, 120, 255), Material = Enum.Material.ForceField, Transparency = 0.2, CanCollide = false, CastShadow = false }, c.Model)
	core.CanQuery = false
	local swirl = Instance.new("ParticleEmitter")
	swirl.Color = ColorSequence.new(rgb(255, 140, 255), rgb(140, 90, 255))
	swirl.LightEmission = 1
	swirl.Rate = 30
	swirl.Lifetime = NumberRange.new(1, 1.8)
	swirl.Speed = NumberRange.new(2, 4)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	swirl.Parent = core
	local light = Instance.new("PointLight")
	light.Color = purple
	light.Range = 30
	light.Brightness = 2
	light.Parent = ring
	local trigger = part({ Name = "Finish", CFrame = CFrame.new(cursor.X + 10, cursor.Y + 6, cursor.Z), Size = V(6, 12, 12), Transparency = 1, CanCollide = false, CastShadow = false }, c.Model)
	trigger.CanQuery = false
	trigger:SetAttribute("Finish", true)
	CollectionService:AddTag(trigger, "Finish")
	billboard(ring, "FINISH!", "Walk through to PRESTIGE", purple, 9, UDim2.fromOffset(320, 100))
end

--------------------------------------------------------------------------------
-- Stages
--------------------------------------------------------------------------------

local function buildStage(stage: number, cursor: Vector3, parent: Instance): Vector3
	local world, worldIndex = Config.GetWorld(stage)
	local _, inWorld = Config.GetWorldForStage(stage)
	local isBoss = inWorld == world.Stages
	local rng = Random.new(Config.Course.Seed + stage * 7919)
	local model = Instance.new("Model")
	model.Name = "Stage" .. stage
	model:SetAttribute("Stage", stage)
	model:SetAttribute("World", worldIndex)

	local c: Ctx = {
		Model = model,
		Theme = world.Theme,
		D = Config.GetDifficulty(stage),
		Rng = rng,
		Stage = stage,
		Walkables = {},
		MinY = cursor.Y,
	}
	stageStartX[stage] = cursor.X

	local pos = buildCheckpoint(c, cursor, stage)
	local length = rng:NextNumber(Config.Course.StageLengthMin, Config.Course.StageLengthMax)
	if isBoss then
		length += 40
	end
	local targetX = cursor.X + length
	local used = {}
	local sections = 0
	while pos.X < targetX - 18 and sections < 3 do
		local name = pickSection(c, used)
		used[name] = true
		sections += 1
		pos = Sections[name](c, pos)
		-- a small landing between sections
		if pos.X < targetX - 18 then
			local landing = platform(c, CFrame.new(pos.X + 3, pos.Y - 0.5, pos.Z), V(6, 1, 8))
			landing.Name = "Landing"
			pos = V(pos.X + 6, pos.Y, pos.Z)
		end
	end
	-- keep the course rising gently and inside the corridor
	local nextY = pos.Y + Config.Course.RisePerStage
	local nextZ = math.clamp(pos.Z + rng:NextNumber(-10, 10), -MAX_Z, MAX_Z)
	-- a short ramp platform bridges any Y/Z change into the next checkpoint
	local bridge = platform(c, CFrame.new(pos.X + 4, (pos.Y + nextY) / 2 - 0.5, (pos.Z + nextZ) / 2), V(8, 1, 10))
	bridge.Name = "Bridge"
	bridge.CFrame = CFrame.lookAt(bridge.Position, V(pos.X + 8, nextY - 0.5, nextZ)) * CFrame.Angles(0, math.rad(-90), 0)
	placeCoins(c)
	model:SetAttribute("FloorY", c.MinY)
	floorY[stage] = c.MinY
	model.Parent = parent
	return V(pos.X + 8, nextY, nextZ)
end

--------------------------------------------------------------------------------
-- Lobby
--------------------------------------------------------------------------------

local function buildLeaderboard(parent: Instance, key: string, title: string, cf: CFrame)
	local board = part({ Name = key, Size = V(18, 12, 1), CFrame = cf, Color = rgb(30, 32, 45) }, parent) :: Part
	part({ Name = "Frame", Size = V(19, 13, 0.8), CFrame = cf * CFrame.new(0, 0, 0.2), Color = rgb(255, 200, 60) }, parent)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Post", Size = V(1.2, 16, 1.2), CFrame = cf * CFrame.new(side * 9.5, -2, 0.5), Color = rgb(110, 80, 55) }, parent)
	end
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
	titleLabel.Size = UDim2.new(1, 0, 0, 80)
	titleLabel.Font = Enum.Font.LuckiestGuy
	titleLabel.Text = title
	titleLabel.TextColor3 = rgb(255, 210, 80)
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextScaled = true
	titleLabel.Parent = gui
	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 16, 0, 90)
	list.Size = UDim2.new(1, -32, 1, -100)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, 0, 0, 36)
	status.Font = Enum.Font.FredokaOne
	status.Text = "Loading..."
	status.TextColor3 = rgb(200, 200, 210)
	status.TextScaled = true
	status.Parent = list
	gui.Parent = board
	leaderboardBoards[key] = board
end

local function buildStatue(parent: Instance, name: string, cf: CFrame, label: string)
	local pedestal = part({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = V(1.5, 7, 7), CFrame = cf * CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(235, 235, 245) }, parent)
	part({ Name = "PedestalTrim", Shape = Enum.PartType.Cylinder, Size = V(0.3, 7.4, 7.4), CFrame = cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(255, 205, 60), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, parent)
	local ok, built = pcall(BrainrotBuilder.Build, name, { Effects = true, Weld = false, Scale = 1.8 })
	if ok and built then
		built.Model.Name = "Statue_" .. name
		built.Model:PivotTo(cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(180), 0))
		built.Model.Parent = parent
		billboard(pedestal, name, label, rgb(255, 230, 120), 9, UDim2.fromOffset(260, 80))
	end
end

local function buildLobby(parent: Instance, theme)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local length = Config.Course.LobbyLength
	local x0 = -length
	-- plaza floor
	part({ Name = "Floor", Size = V(length, 2, 90), CFrame = CFrame.new(x0 + length / 2, -1, 0), Color = theme.Platform }, lobby)
	part({ Name = "Path", Size = V(length, 0.2, 14), CFrame = CFrame.new(x0 + length / 2, 0.1, 0), Color = theme.Trim }, lobby)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Edge", Size = V(length, 1, 1.2), CFrame = CFrame.new(x0 + length / 2, 0.5, side * 45), Color = theme.Trim }, lobby)
	end

	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = V(12, 0.5, 12)
	spawn.CFrame = CFrame.new(x0 + 25, 0.25, 0)
	spawn.Color = rgb(255, 255, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby
	part({ Name = "SpawnRing", Shape = Enum.PartType.Cylinder, Size = V(0.2, 9, 9), CFrame = CFrame.new(x0 + 25, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = theme.Accent, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, lobby)

	-- big title sign
	local signPost = part({ Name = "SignPost", Size = V(1.5, 20, 1.5), CFrame = CFrame.new(x0 + 25, 10, -30), Color = theme.Trim }, lobby)
	local signBoard = part({ Name = "TitleSign", Size = V(0.8, 8, 30), CFrame = CFrame.new(x0 + 25, 17, -30), Color = rgb(30, 22, 40) }, lobby)
	billboard(signBoard, "BRAINROT OBBY", "100 stages  -  6 worlds  -  collect every brainrot!", rgb(255, 215, 60), 0, UDim2.fromOffset(640, 150))
	signPost.CastShadow = false

	-- how-to sign near the path
	local howTo = part({ Name = "HowToSign", Size = V(0.5, 4, 10), CFrame = CFrame.new(x0 + 50, 4, -11), Color = rgb(150, 110, 70) }, lobby)
	billboard(howTo, "HOW TO PLAY", "Touch the glowing pads to save your spot.\nCollect coins. Buy brainrots that jump higher!", rgb(255, 240, 180), 2, UDim2.fromOffset(420, 120))
	for _, dz in ipairs({ -4, 4 }) do
		part({ Name = "Post", Size = V(0.6, 6, 0.6), CFrame = CFrame.new(x0 + 50, 3, -11 + dz), Color = rgb(120, 85, 55) }, lobby)
	end

	-- leaderboards at the back
	local boards = Instance.new("Folder")
	boards.Name = "Leaderboards"
	boards.Parent = lobby
	buildLeaderboard(boards, "BestStage", "TOP STAGES", CFrame.new(x0 + 6, 9, -22) * CFrame.Angles(0, math.rad(-90), 0))
	buildLeaderboard(boards, "Prestige", "TOP PRESTIGE", CFrame.new(x0 + 6, 9, 0) * CFrame.Angles(0, math.rad(-90), 0))
	buildLeaderboard(boards, "BestTime", "FASTEST RUNS", CFrame.new(x0 + 6, 9, 22) * CFrame.Angles(0, math.rad(-90), 0))

	-- brainrot statues to show off what you can unlock
	local statues = Instance.new("Folder")
	statues.Name = "Statues"
	statues.Parent = lobby
	buildStatue(statues, "Sneaker Shark", CFrame.new(x0 + 45, 0, 22), "Rare - 6,500 coins")
	buildStatue(statues, "Tralala Titan", CFrame.new(x0 + 62, 0, 30), "Legendary")
	buildStatue(statues, "Omega Brainrot", CFrame.new(x0 + 80, 0, 22), "Mythic - Prestige 1")
	buildStatue(statues, "Ballerina Latte", CFrame.new(x0 + 45, 0, -22), "Epic")
	buildStatue(statues, "Nuke Nonna", CFrame.new(x0 + 62, 0, -30), "Legendary")
	buildStatue(statues, "Galaxy Gnocchi", CFrame.new(x0 + 80, 0, -22), "Legendary")

	-- arrow on the floor pointing at stage 1
	for i = 0, 4 do
		part({ Name = "FloorArrow", Wedge = true, Size = V(4, 0.15, 3), CFrame = CFrame.new(x0 + 70 + i * 7, 0.25, 0) * CFrame.Angles(0, math.rad(-90), 0), Color = theme.Accent, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, lobby)
	end

	lobby.Parent = parent
end

--------------------------------------------------------------------------------
-- Terrain, scenery and lighting
--------------------------------------------------------------------------------

local GROUND_DEPTH = 45

local function buildWorldScenery(parent: Instance, worldIndex: number)
	local world = Config.Worlds[worldIndex]
	local range = worldRange[worldIndex]
	local baseY = -GROUND_DEPTH + (Config.GetWorldStart(worldIndex) - 1) * Config.Course.RisePerStage
	local material = (Enum.Material :: any)[world.Theme.Ground] or Enum.Material.Grass
	local minX = if worldIndex == 1 then -Config.Course.LobbyLength - 150 else range.Min
	local maxX = if worldIndex == #Config.Worlds then range.Max + 150 else range.Max
	local center = V((minX + maxX) / 2, baseY - 10, 0)
	if world.Theme.Decor ~= "Void" and world.Theme.Decor ~= "Sky" then
		Terrain:FillBlock(CFrame.new(center), V(maxX - minX, 20, 520), material)
	end
	if world.Theme.Decor == "Beach" then
		Terrain:FillBlock(CFrame.new(center + V(0, 4, 0)), V(maxX - minX, 6, 520), Enum.Material.Water)
		Terrain:FillBlock(CFrame.new(center + V(0, 4, 0)), V(maxX - minX, 7, 120), material)
	end
	local rng = Random.new(Config.Course.Seed + worldIndex * 104729)
	CourseDecor.Fill(world.Theme.Decor, parent, minX, maxX, baseY, rng)
end

local function setupLighting()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	local sky = Instance.new("Sky")
	sky.StarCount = 2500
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.2
	atmosphere.Color = rgb(205, 222, 245)
	atmosphere.Decay = rgb(120, 140, 170)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 0.8
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 24
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "WorldColor"
	color.Saturation = 0.28
	color.Contrast = 0.1
	color.Brightness = 0.02
	color.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.7
	rays.Parent = Lighting
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Terrain:SetMaterialColor(Enum.Material.Grass, rgb(112, 202, 72))
	Terrain:SetMaterialColor(Enum.Material.LeafyGrass, rgb(70, 150, 60))
	Terrain:SetMaterialColor(Enum.Material.Sand, rgb(248, 225, 160))
	Terrain:SetMaterialColor(Enum.Material.Concrete, rgb(150, 130, 125))
	Terrain:SetMaterialColor(Enum.Material.Snow, rgb(240, 246, 255))
	Terrain:SetMaterialColor(Enum.Material.Basalt, rgb(45, 30, 70))
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function CourseBuilder.Build()
	for _, name in ipairs({ "Course", "Baseplate", "SpawnLocation" }) do
		local existing = Workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	Terrain:Clear()

	courseFolder = Instance.new("Folder")
	courseFolder.Name = "Course"
	local stages = Instance.new("Folder")
	stages.Name = "Stages"
	stages.Parent = courseFolder

	buildLobby(courseFolder, Config.Worlds[1].Theme)

	local cursor = V(0, 0, 0)
	local total = Config.TotalStages()
	for stage = 1, total do
		local worldIndex = Config.GetWorldForStage(stage)
		local range = worldRange[worldIndex] or { Min = cursor.X, Max = cursor.X }
		range.Min = math.min(range.Min, cursor.X)
		cursor = buildStage(stage, cursor, stages)
		range.Max = cursor.X
		worldRange[worldIndex] = range
	end
	-- finish after the last stage
	local lastWorld = Config.Worlds[#Config.Worlds]
	local finishModel = Instance.new("Model")
	finishModel.Name = "Finish"
	local fc: Ctx = { Model = finishModel, Theme = lastWorld.Theme, D = 1, Rng = Random.new(1), Stage = total + 1, Walkables = {}, MinY = cursor.Y }
	buildFinish(fc, cursor)
	finishModel.Parent = courseFolder
	checkpoints[total + 1] = CFrame.new(cursor.X + 10, cursor.Y + 3.5, cursor.Z)
	floorY[total + 1] = cursor.Y

	for worldIndex in ipairs(Config.Worlds) do
		courseFolder:SetAttribute("World" .. worldIndex .. "StartX", stageStartX[Config.GetWorldStart(worldIndex)])
	end
	courseFolder:SetAttribute("CourseEndX", cursor.X + 30)

	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = courseFolder
	for worldIndex in ipairs(Config.Worlds) do
		buildWorldScenery(scenery, worldIndex)
	end

	courseFolder.Parent = Workspace
	CourseBuilder.Folders.Course = courseFolder
	CourseBuilder.Folders.Stages = stages
	setupLighting()
end

-- Where a player respawns for a checkpoint (above the pad).
function CourseBuilder.GetCheckpoint(stage: number): CFrame?
	return checkpoints[stage]
end

-- Lowest platform top of a stage (fall detection).
function CourseBuilder.GetFloorY(stage: number): number
	return floorY[stage] or 0
end

function CourseBuilder.GetStageStartX(stage: number): number
	return stageStartX[stage] or 0
end

function CourseBuilder.GetLeaderboardBoards(): { [string]: Part }
	return leaderboardBoards
end

return CourseBuilder
