--------------------------------------------------------------------------------
-- MapDecor - themed scenery for each zone, built from parts and terrain.
-- MapDecor.Place(themeName, parent, position, rng) builds one random prop.
-- MapDecor.Backdrop(themeName, parent, center) builds the big background set.
--------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")

local MapDecor = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local Terrain = Workspace.Terrain

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p: BasePart
	if props.Wedge then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
	end
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "Wedge" and key ~= "Sphere" then
			(p :: any)[key] = value
		end
	end
	if props.Sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = parent
	return p
end

-- Vertical cylinder standing on `base` (Cylinder parts lie along X).
local function pillar(parent: Instance, base: Vector3, height: number, radius: number, color: Color3, mat: Enum.Material, props: { [string]: any }?): BasePart
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

local function ball(parent: Instance, center: Vector3, size: number, color: Color3, mat: Enum.Material, props: { [string]: any }?): BasePart
	local p = { Shape = Enum.PartType.Ball, Size = V(size, size, size), Position = center, Color = color, Material = mat }
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

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

--------------------------------------------------------------------------------
-- Grassy Meadow
--------------------------------------------------------------------------------

local LEAF_GREENS = { rgb(80, 165, 60), rgb(100, 185, 70), rgb(65, 145, 55), rgb(120, 190, 80) }
local FLOWER_COLORS = { rgb(255, 120, 170), rgb(255, 225, 80), rgb(255, 255, 255), rgb(185, 130, 255), rgb(255, 150, 70) }

local function tree(parent: Instance, pos: Vector3, rng: Random)
	local h = rng:NextNumber(7, 10)
	pillar(parent, pos - V(0, 0.5, 0), h, rng:NextNumber(0.7, 1), rgb(120, 85, 55), Enum.Material.SmoothPlastic)
	local green = pick(LEAF_GREENS, rng)
	local top = pos + V(0, h, 0)
	local crown = rng:NextNumber(6.5, 8)
	ball(parent, top + V(0, 1, 0), crown, green, Enum.Material.SmoothPlastic)
	-- lighter "sunlit" puff on top gives the toy cel-shaded look
	ball(parent, top + V(-0.7, 1 + crown * 0.28, -0.7), crown * 0.62, green:Lerp(rgb(235, 255, 160), 0.35), Enum.Material.SmoothPlastic, { CastShadow = false })
	for i = 1, 3 do
		local angle = i * 2.1 + rng:NextNumber(0, 1)
		ball(parent, top + V(math.cos(angle) * 2.2, rng:NextNumber(-1.2, 0), math.sin(angle) * 2.2), rng:NextNumber(4.5, 6), green:Lerp(rgb(40, 110, 40), rng:NextNumber(0, 0.3)), Enum.Material.SmoothPlastic)
	end
	-- a few apples / blossoms
	if rng:NextNumber() < 0.5 then
		for i = 1, 4 do
			local angle = i * 1.6
			ball(parent, top + V(math.cos(angle) * 3.4, rng:NextNumber(-0.5, 1.5), math.sin(angle) * 3.4), 0.7, rgb(230, 50, 60), Enum.Material.SmoothPlastic, { CastShadow = false })
		end
	end
end

local function flowers(parent: Instance, pos: Vector3, rng: Random)
	local color = pick(FLOWER_COLORS, rng)
	for _ = 1, rng:NextInteger(5, 9) do
		local p = pos + V(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		local h = rng:NextNumber(0.8, 1.6)
		pillar(parent, p, h, 0.08, rgb(70, 150, 50), Enum.Material.SmoothPlastic, { CastShadow = false, CanCollide = false })
		ball(parent, p + V(0, h + 0.15, 0), rng:NextNumber(0.5, 0.75), color, Enum.Material.SmoothPlastic, { CastShadow = false, CanCollide = false })
		ball(parent, p + V(0, h + 0.2, 0), 0.25, rgb(255, 220, 60), Enum.Material.Neon, { CastShadow = false, CanCollide = false })
	end
end

local function bush(parent: Instance, pos: Vector3, rng: Random)
	local green = pick(LEAF_GREENS, rng)
	for i = 1, 3 do
		ball(parent, pos + V((i - 2) * 1.4, rng:NextNumber(0.6, 1.2), rng:NextNumber(-0.6, 0.6)), rng:NextNumber(2.4, 3.2), green, Enum.Material.SmoothPlastic)
	end
	if rng:NextNumber() < 0.6 then
		local berry = pick(FLOWER_COLORS, rng)
		for i = 1, 5 do
			ball(parent, pos + V(rng:NextNumber(-2, 2), rng:NextNumber(1.2, 2.2), rng:NextNumber(-1, 1)), 0.4, berry, Enum.Material.SmoothPlastic, { CastShadow = false })
		end
	end
end

local function mushroom(parent: Instance, pos: Vector3, rng: Random)
	local h = rng:NextNumber(1.6, 2.6)
	pillar(parent, pos, h, 0.45, rgb(245, 240, 225), Enum.Material.SmoothPlastic)
	local capSize = rng:NextNumber(2.4, 3.2)
	part({ Sphere = true, Size = V(capSize, capSize * 0.6, capSize), Position = pos + V(0, h + 0.1, 0), Color = rgb(225, 50, 50), Material = Enum.Material.SmoothPlastic }, parent)
	for i = 1, 5 do
		local angle = i * 1.25
		ball(parent, pos + V(math.cos(angle) * capSize * 0.3, h + capSize * 0.22, math.sin(angle) * capSize * 0.3), 0.35, rgb(255, 255, 255), Enum.Material.SmoothPlastic, { CastShadow = false })
	end
end

local function boulder(_parent: Instance, pos: Vector3, rng: Random, mat: Enum.Material)
	Terrain:FillBall(pos + V(0, -0.5, 0), rng:NextNumber(2, 3.6), mat)
end

--------------------------------------------------------------------------------
-- Candy Land
--------------------------------------------------------------------------------

local CANDY = { rgb(255, 90, 140), rgb(90, 200, 255), rgb(255, 220, 70), rgb(140, 230, 120), rgb(200, 120, 255), rgb(255, 150, 60) }

local function lollipop(parent: Instance, pos: Vector3, rng: Random)
	local h = rng:NextNumber(6, 10)
	pillar(parent, pos, h, 0.35, rgb(255, 255, 255), Enum.Material.SmoothPlastic)
	local size = rng:NextNumber(4.5, 6.5)
	local colorA, colorB = pick(CANDY, rng), pick(CANDY, rng)
	local center = pos + V(0, h + size / 2 - 0.4, 0)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	for i, ring in ipairs({ 1, 0.72, 0.46, 0.22 }) do
		part({
			Shape = Enum.PartType.Cylinder,
			Size = V(1 + i * 0.02, size * ring, size * ring),
			CFrame = CFrame.new(center) * yaw,
			Color = if i % 2 == 1 then colorA else colorB,
			Material = Enum.Material.SmoothPlastic,
		}, parent)
	end
end

local function candyCane(parent: Instance, pos: Vector3, rng: Random)
	local segments = 7
	local seg = 1.1
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	for i = 0, segments - 1 do
		pillar(parent, pos + V(0, i * seg, 0), seg + 0.02, 0.55, if i % 2 == 0 then rgb(235, 30, 50) else rgb(255, 255, 255), Enum.Material.SmoothPlastic)
	end
	-- hook
	local top = pos + V(0, segments * seg, 0)
	for i = 0, 5 do
		local a = math.rad(i * 36)
		local offset = (yaw * CFrame.new(math.cos(a) * 1.3 - 1.3, math.sin(a) * 1.3, 0)).Position
		ball(parent, top + offset, 1.15, if i % 2 == 0 then rgb(255, 255, 255) else rgb(235, 30, 50), Enum.Material.SmoothPlastic)
	end
end

local function gumdrop(parent: Instance, pos: Vector3, rng: Random)
	local color = pick(CANDY, rng)
	local size = rng:NextNumber(2.5, 4.5)
	part({ Sphere = true, Size = V(size, size * 0.85, size), Position = pos + V(0, size * 0.3, 0), Color = color, Material = Enum.Material.Glass, Transparency = 0.1 }, parent)
	for i = 1, 6 do
		local angle = i * 1.05
		ball(parent, pos + V(math.cos(angle) * size * 0.32, size * 0.62, math.sin(angle) * size * 0.32), 0.25, rgb(255, 255, 255), Enum.Material.SmoothPlastic, { CastShadow = false })
	end
end

local function cupcake(parent: Instance, pos: Vector3, rng: Random)
	local s = rng:NextNumber(0.9, 1.3)
	pillar(parent, pos, 2.2 * s, 1.6 * s, pick({ rgb(255, 160, 200), rgb(140, 200, 255), rgb(255, 230, 140) }, rng), Enum.Material.SmoothPlastic)
	local frosting = pick({ rgb(255, 245, 250), rgb(255, 190, 220), rgb(120, 70, 40) }, rng)
	ball(parent, pos + V(0, 2.6 * s, 0), 3.6 * s, frosting, Enum.Material.SmoothPlastic)
	ball(parent, pos + V(0, 3.9 * s, 0), 2.2 * s, frosting, Enum.Material.SmoothPlastic)
	ball(parent, pos + V(0, 5.0 * s, 0), 0.9 * s, rgb(220, 20, 50), Enum.Material.SmoothPlastic)
end

local function wrappedCandy(parent: Instance, pos: Vector3, rng: Random)
	local color = pick(CANDY, rng)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local center = CFrame.new(pos + V(0, 1.4, 0)) * yaw
	part({ Sphere = true, Size = V(3.4, 2.4, 2.4), CFrame = center, Color = color, Material = Enum.Material.SmoothPlastic }, parent)
	for _, side in ipairs({ -1, 1 }) do
		part({ Wedge = true, Size = V(0.3, 2.2, 1.4), CFrame = center * CFrame.new(side * 2.2, 0, 0) * CFrame.Angles(0, math.rad(90 * side), 0), Color = color:Lerp(rgb(255, 255, 255), 0.3), Material = Enum.Material.SmoothPlastic }, parent)
	end
end

--------------------------------------------------------------------------------
-- Frozen Peaks
--------------------------------------------------------------------------------

local function pineTree(parent: Instance, pos: Vector3, rng: Random)
	local s = rng:NextNumber(0.85, 1.25)
	pillar(parent, pos - V(0, 0.5, 0), 3 * s, 0.6 * s, rgb(100, 70, 50), Enum.Material.SmoothPlastic)
	local green = rgb(40, 110, 70)
	local y = 2.4 * s
	for i, radius in ipairs({ 3.6, 2.8, 1.9, 1.0 }) do
		local r = radius * s
		pillar(parent, pos + V(0, y, 0), 1.8 * s, r, green, Enum.Material.SmoothPlastic)
		pillar(parent, pos + V(0, y + 1.8 * s, 0), 0.35 * s, r * 0.85, rgb(245, 250, 255), Enum.Material.SmoothPlastic, { CastShadow = false })
		y += 1.55 * s
		if i == 4 then
			ball(parent, pos + V(0, y + 0.5 * s, 0), 0.9 * s, rgb(245, 250, 255), Enum.Material.SmoothPlastic)
		end
	end
end

local function snowman(parent: Instance, pos: Vector3, rng: Random)
	local yaw = rng:NextNumber(-0.6, 0.6)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local white = rgb(248, 250, 255)
	ball(parent, (base * CFrame.new(0, 1.6, 0)).Position, 3.4, white, Enum.Material.SmoothPlastic)
	ball(parent, (base * CFrame.new(0, 3.9, 0)).Position, 2.5, white, Enum.Material.SmoothPlastic)
	ball(parent, (base * CFrame.new(0, 5.6, 0)).Position, 1.8, white, Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -0.35, 0.35 }) do
		ball(parent, (base * CFrame.new(x, 5.85, -0.8)).Position, 0.25, rgb(25, 25, 30), Enum.Material.SmoothPlastic)
	end
	for i = 1, 3 do
		ball(parent, (base * CFrame.new(0, 3.3 + i * 0.4, -1.15)).Position, 0.25, rgb(25, 25, 30), Enum.Material.SmoothPlastic)
	end
	part({ Sphere = true, Size = V(0.3, 0.3, 1.0), CFrame = base * CFrame.new(0, 5.55, -1.2), Color = rgb(255, 140, 30), Material = Enum.Material.SmoothPlastic }, parent)
	-- hat + scarf
	pillar(parent, (base * CFrame.new(0, 6.3, 0)).Position, 0.2, 1.1, rgb(30, 30, 40), Enum.Material.SmoothPlastic)
	pillar(parent, (base * CFrame.new(0, 6.5, 0)).Position, 1.1, 0.7, rgb(30, 30, 40), Enum.Material.SmoothPlastic)
	pillar(parent, (base * CFrame.new(0, 4.75, 0)).Position, 0.45, 1.05, rgb(220, 40, 50), Enum.Material.SmoothPlastic)
	-- stick arms
	for _, side in ipairs({ -1, 1 }) do
		part({
			Size = V(2.2, 0.18, 0.18),
			CFrame = base * CFrame.new(side * 2.0, 4.3, 0) * CFrame.Angles(0, 0, math.rad(25 * side)),
			Color = rgb(110, 75, 45),
			Material = Enum.Material.SmoothPlastic,
		}, parent)
	end
end

local function iceCrystal(parent: Instance, pos: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(3, 8)
		part({
			Size = V(rng:NextNumber(1, 1.8), h, rng:NextNumber(1, 1.8)),
			CFrame = CFrame.new(pos + V(rng:NextNumber(-1.5, 1.5), h / 2 - 0.6, rng:NextNumber(-1.5, 1.5))) * CFrame.Angles(math.rad(rng:NextNumber(-18, 18)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-18, 18))),
			Color = rgb(170, 225, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			Reflectance = 0.15,
		}, parent)
	end
end

--------------------------------------------------------------------------------
-- Volcano
--------------------------------------------------------------------------------

local function torch(parent: Instance, pos: Vector3, _rng: Random)
	pillar(parent, pos, 5, 0.7, rgb(60, 55, 55), Enum.Material.SmoothPlastic)
	local bowl = pillar(parent, pos + V(0, 5, 0), 0.8, 1.2, rgb(45, 40, 40), Enum.Material.Metal)
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 9
	fire.Color = rgb(255, 120, 30)
	fire.SecondaryColor = rgb(255, 220, 80)
	fire.Parent = bowl
	light(bowl, rgb(255, 140, 60), 18, 1.6)
end

local function lavaPool(_parent: Instance, pos: Vector3, rng: Random)
	local radius = rng:NextNumber(4, 7)
	Terrain:FillCylinder(CFrame.new(pos + V(0, -1, 0)), 2, radius, Enum.Material.CrackedLava)
	Terrain:FillCylinder(CFrame.new(pos + V(0, -0.6, 0)), 1.6, radius + 1.2, Enum.Material.Basalt)
	Terrain:FillCylinder(CFrame.new(pos + V(0, -1, 0)), 2.2, radius, Enum.Material.CrackedLava)
end

local function obsidian(parent: Instance, pos: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(2, 4) do
		local h = rng:NextNumber(3, 7)
		part({
			Size = V(rng:NextNumber(1, 2), h, rng:NextNumber(1, 2)),
			CFrame = CFrame.new(pos + V(rng:NextNumber(-1.2, 1.2), h / 2 - 0.5, rng:NextNumber(-1.2, 1.2))) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-15, 15))),
			Color = rgb(30, 20, 35),
			Material = Enum.Material.Glass,
			Reflectance = 0.25,
		}, parent)
	end
end

local function vent(parent: Instance, pos: Vector3, _rng: Random)
	local cone = pillar(parent, pos - V(0, 0.4, 0), 1.6, 2.2, rgb(70, 50, 45), Enum.Material.SmoothPlastic)
	pillar(parent, pos + V(0, 1.2, 0), 0.1, 1.2, rgb(255, 110, 30), Enum.Material.Neon, { CastShadow = false })
	local smoke = Instance.new("Smoke")
	smoke.Color = rgb(90, 80, 80)
	smoke.Opacity = 0.25
	smoke.RiseVelocity = 6
	smoke.Size = 3
	smoke.Parent = cone
end

--------------------------------------------------------------------------------
-- Space Station
--------------------------------------------------------------------------------

local NEON_SPACE = { rgb(170, 90, 255), rgb(90, 220, 255), rgb(255, 110, 210) }

local function spaceCrystal(parent: Instance, pos: Vector3, rng: Random)
	local color = pick(NEON_SPACE, rng)
	local first
	for i = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(3, 9)
		local p = part({
			Size = V(rng:NextNumber(1, 1.8), h, rng:NextNumber(1, 1.8)),
			CFrame = CFrame.new(pos + V(rng:NextNumber(-1.3, 1.3), h / 2 - 0.8, rng:NextNumber(-1.3, 1.3))) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-20, 20))),
			Color = color,
			Material = Enum.Material.Neon,
			CastShadow = false,
		}, parent)
		if i == 1 then
			first = p
		end
	end
	if first and rng:NextNumber() < 0.45 then
		light(first, color, 14, 1)
	end
end

local function floatingRock(parent: Instance, pos: Vector3, rng: Random)
	local size = rng:NextNumber(4, 8)
	local y = rng:NextNumber(14, 26)
	local rock = part({
		Sphere = true,
		Size = V(size, size * 0.6, size * 0.9),
		CFrame = CFrame.new(pos + V(0, y, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-12, 12))),
		Color = rgb(70, 60, 100),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	}, parent)
	local color = pick(NEON_SPACE, rng)
	for _ = 1, 2 do
		part({
			Size = V(0.6, rng:NextNumber(1.5, 3), 0.6),
			CFrame = rock.CFrame * CFrame.new(rng:NextNumber(-1, 1), size * 0.3, rng:NextNumber(-1, 1)) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), 0, math.rad(rng:NextNumber(-20, 20))),
			Color = color,
			Material = Enum.Material.Neon,
			CastShadow = false,
			CanCollide = false,
		}, parent)
	end
end

local function antenna(parent: Instance, pos: Vector3, rng: Random)
	pillar(parent, pos, 7, 0.4, rgb(150, 150, 170), Enum.Material.Metal)
	local dish = part({
		Shape = Enum.PartType.Cylinder,
		Size = V(0.4, 5, 5),
		CFrame = CFrame.new(pos + V(0, 7.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(55)),
		Color = rgb(220, 220, 235),
		Material = Enum.Material.Metal,
	}, parent)
	ball(parent, dish.Position + V(0, 1.2, 0), 0.6, pick(NEON_SPACE, rng), Enum.Material.Neon, { CastShadow = false })
end

local function pylon(parent: Instance, pos: Vector3, rng: Random)
	local color = pick(NEON_SPACE, rng)
	pillar(parent, pos, 6, 0.6, rgb(60, 55, 80), Enum.Material.Metal)
	local orb = ball(parent, pos + V(0, 6.8, 0), 1.6, color, Enum.Material.Neon, { CastShadow = false })
	if rng:NextNumber() < 0.5 then
		light(orb, color, 16, 1.2)
	end
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

type Builder = (Instance, Vector3, Random) -> ()

local WEIGHTED: { [string]: { { Weight: number, Build: Builder } } } = {
	Trees = {
		{ Weight = 38, Build = tree },
		{ Weight = 24, Build = flowers },
		{ Weight = 16, Build = bush },
		{ Weight = 12, Build = mushroom },
		{ Weight = 10, Build = function(p, pos, rng) boulder(p, pos, rng, Enum.Material.Rock) end },
	},
	Candy = {
		{ Weight = 26, Build = lollipop },
		{ Weight = 22, Build = candyCane },
		{ Weight = 20, Build = gumdrop },
		{ Weight = 18, Build = cupcake },
		{ Weight = 14, Build = wrappedCandy },
	},
	Ice = {
		{ Weight = 40, Build = pineTree },
		{ Weight = 18, Build = snowman },
		{ Weight = 26, Build = iceCrystal },
		{ Weight = 16, Build = function(p, pos, rng) boulder(p, pos, rng, Enum.Material.Glacier) end },
	},
	Rock = {
		{ Weight = 16, Build = torch },
		{ Weight = 22, Build = lavaPool },
		{ Weight = 26, Build = obsidian },
		{ Weight = 14, Build = vent },
		{ Weight = 22, Build = function(p, pos, rng) boulder(p, pos, rng, Enum.Material.Basalt) end },
	},
	Crystal = {
		{ Weight = 34, Build = spaceCrystal },
		{ Weight = 26, Build = floatingRock },
		{ Weight = 18, Build = antenna },
		{ Weight = 22, Build = pylon },
	},
}

function MapDecor.Place(themeName: string, parent: Instance, position: Vector3, rng: Random)
	local options = WEIGHTED[themeName] or WEIGHTED.Trees
	local total = 0
	for _, option in ipairs(options) do
		total += option.Weight
	end
	local roll = rng:NextNumber() * total
	for _, option in ipairs(options) do
		roll -= option.Weight
		if roll <= 0 then
			option.Build(parent, position, rng)
			return
		end
	end
	options[1].Build(parent, position, rng)
end

-- Big background scenery behind the north edge of a zone (outside the walls).
function MapDecor.Backdrop(themeName: string, parent: Instance, center: Vector3, rng: Random)
	local north = center + V(0, 0, -150)
	if themeName == "Trees" then
		for i = -2, 2 do
			Terrain:FillBall(north + V(i * 45 + rng:NextNumber(-10, 10), -20, rng:NextNumber(-20, 10)), rng:NextNumber(40, 55), Enum.Material.LeafyGrass)
		end
		Terrain:FillBall(north + V(-30, 5, -50), 45, Enum.Material.Rock)
		Terrain:FillBall(north + V(-30, 38, -50), 16, Enum.Material.Snow)
	elseif themeName == "Candy" then
		for i = -2, 2 do
			Terrain:FillBall(north + V(i * 45, -20, rng:NextNumber(-20, 10)), rng:NextNumber(38, 52), Enum.Material.Sandstone)
		end
		-- giant lollipop landmark
		local base = north + V(25, 10, 10)
		pillar(parent, base, 40, 2, rgb(255, 255, 255), Enum.Material.SmoothPlastic)
		for i, ring in ipairs({ 1, 0.72, 0.46, 0.22 }) do
			part({
				Shape = Enum.PartType.Cylinder,
				Size = V(3 + i * 0.05, 30 * ring, 30 * ring),
				CFrame = CFrame.new(base + V(0, 52, 0)) * CFrame.Angles(0, math.rad(90), 0),
				Color = if i % 2 == 1 then rgb(255, 90, 160) else rgb(255, 230, 120),
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
			}, parent)
		end
	elseif themeName == "Ice" then
		for i = -2, 2 do
			local p = north + V(i * 42 + rng:NextNumber(-8, 8), -10, rng:NextNumber(-25, 5))
			local r = rng:NextNumber(38, 55)
			Terrain:FillBall(p, r, Enum.Material.Glacier)
			Terrain:FillBall(p + V(0, r * 0.62, 0), r * 0.45, Enum.Material.Snow)
		end
	elseif themeName == "Rock" then
		-- erupting volcano
		local base = north + V(0, -30, -20)
		Terrain:FillBall(base, 75, Enum.Material.Basalt)
		Terrain:FillBall(base + V(0, 40, 0), 45, Enum.Material.Basalt)
		Terrain:FillCylinder(CFrame.new(base + V(0, 82, 0)), 10, 16, Enum.Material.CrackedLava)
		local crater = part({ Size = V(20, 2, 20), Position = base + V(0, 90, 0), Transparency = 1, CanCollide = false }, parent)
		local fire = Instance.new("Fire")
		fire.Size = 30
		fire.Heat = 25
		fire.Color = rgb(255, 100, 20)
		fire.SecondaryColor = rgb(255, 220, 80)
		fire.Parent = crater
		local smoke = Instance.new("Smoke")
		smoke.Color = rgb(60, 50, 50)
		smoke.Opacity = 0.35
		smoke.RiseVelocity = 12
		smoke.Size = 25
		smoke.Parent = crater
		light(crater, rgb(255, 120, 40), 60, 3)
		for i = -1, 1, 2 do
			Terrain:FillBall(north + V(i * 80, -20, 10), 45, Enum.Material.Basalt)
		end
	elseif themeName == "Crystal" then
		-- planets hanging in the night sky
		ball(parent, center + V(60, 150, -340), 150, rgb(255, 150, 90), Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = false })
		part({
			Shape = Enum.PartType.Cylinder,
			Size = V(1, 290, 290),
			CFrame = CFrame.new(center + V(60, 150, -340)) * CFrame.Angles(math.rad(70), 0, math.rad(80)),
			Color = rgb(255, 220, 170),
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			CanCollide = false,
			CastShadow = false,
		}, parent)
		ball(parent, center + V(-170, 110, -260), 60, rgb(90, 170, 255), Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = false })
		ball(parent, center + V(200, 90, 240), 40, rgb(210, 210, 230), Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = false })
		for i = -2, 2 do
			Terrain:FillBall(north + V(i * 45, -25, rng:NextNumber(-20, 10)), rng:NextNumber(35, 48), Enum.Material.Slate)
		end
	end
end

-- Puffy cartoon clouds: clusters of white balls high above the zone.
local CLOUD_COLORS = {
	Trees = rgb(255, 255, 255),
	Candy = rgb(255, 228, 244),
	Ice = rgb(240, 247, 255),
	Rock = rgb(92, 78, 78),
}

function MapDecor.Clouds(themeName: string, parent: Instance, center: Vector3, rng: Random)
	local color = CLOUD_COLORS[themeName]
	if not color then
		return -- no clouds in space
	end
	local folder = Instance.new("Folder")
	folder.Name = "Clouds"
	folder.Parent = parent
	for i = 1, 7 do
		local angle = (i / 7) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local distance = rng:NextNumber(40, 150)
		local base = center + V(math.cos(angle) * distance, rng:NextNumber(75, 115), math.sin(angle) * distance)
		local width = rng:NextNumber(26, 44)
		for j = 1, rng:NextInteger(5, 7) do
			local t = (j - 1) / 6 - 0.5
			local size = rng:NextNumber(12, 20) * (1 - math.abs(t) * 0.8)
			ball(folder, base + V(t * width, rng:NextNumber(-1, 3) + size * 0.15, rng:NextNumber(-6, 6)), size, color, Enum.Material.SmoothPlastic, {
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			})
		end
	end
end

return MapDecor
