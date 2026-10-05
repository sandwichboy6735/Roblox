--------------------------------------------------------------------------------
-- BreakableLooks - builds the coin piles, crates and chests from parts.
-- Every model is built around the origin with the ground at y = 0, so the
-- caller only needs to PivotTo the spot on the ground.
--------------------------------------------------------------------------------

local BreakableLooks = {}

local V = Vector3.new
local rgb = Color3.fromRGB

local GOLD = rgb(255, 200, 40)
local GOLD_DARK = rgb(225, 150, 25)
local WOOD = rgb(196, 132, 70)
local WOOD_DARK = rgb(132, 82, 42)

type Builder = { Model: Model, Scale: number }

local function add(b: Builder, shape: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	local s = b.Scale
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "Ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Size = size * s
	p.CFrame = CFrame.new(cf.Position * s) * cf.Rotation
	for key, value in pairs(props or {}) do
		(p :: any)[key] = value
	end
	p.Parent = b.Model
	return p
end

-- Invisible box that receives clicks (ClickDetector) for the whole model.
local function hitbox(b: Builder, size: Vector3, centerY: number): BasePart
	local box = add(b, "Block", size, CFrame.new(0, centerY, 0), Color3.new(1, 1, 1), { Transparency = 1, CanQuery = true, CanCollide = true })
	box.Name = "Hitbox"
	b.Model.PrimaryPart = box
	return box
end

local function coin(b: Builder, position: Vector3, tilt: number, yaw: number)
	-- Cylinder parts lie along X; rotate so the coin's face points up-ish.
	add(b, "Cylinder", V(0.28, 1.5, 1.5), CFrame.new(position) * CFrame.Angles(0, yaw, math.rad(90) + tilt), GOLD, { Reflectance = 0.12 })
end

local function buildPile(b: Builder, rng: Random, accent: Color3): number
	add(b, "Ellipsoid", V(4.6, 2.4, 4.6), CFrame.new(0, 0.55, 0), GOLD_DARK)
	for i = 1, 11 do
		local angle = i * 2.39 + rng:NextNumber(0, 0.4)
		local r = math.sqrt(i / 11) * 1.75
		local y = 0.55 + 1.2 * math.sqrt(math.max(0, 1 - (r / 2.3) ^ 2)) + 0.05
		coin(b, V(math.cos(angle) * r, y, math.sin(angle) * r), rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi * 2))
	end
	-- a couple of gems poking out of the top
	for i = 1, 2 do
		local angle = i * 3.1
		add(b, "Block", V(0.6, 0.6, 0.6), CFrame.new(math.cos(angle) * 0.6, 1.85, math.sin(angle) * 0.6) * CFrame.Angles(math.rad(45), 0, math.rad(45)), accent, { Material = Enum.Material.Glass, Transparency = 0.1 })
	end
	hitbox(b, V(4.8, 2.9, 4.8), 1.45)
	return 2.5
end

local function buildCrate(b: Builder): number
	local body = add(b, "Block", V(3.6, 3.6, 3.6), CFrame.new(0, 1.8, 0), WOOD, { CastShadow = true })
	body.Name = "Body"
	local e = 0.36
	for _, y in ipairs({ 0.18, 3.42 }) do
		for _, z in ipairs({ -1.8, 1.8 }) do
			add(b, "Block", V(3.7, e, e), CFrame.new(0, y, z), WOOD_DARK)
		end
		for _, x in ipairs({ -1.8, 1.8 }) do
			add(b, "Block", V(e, e, 3.7), CFrame.new(x, y, 0), WOOD_DARK)
		end
	end
	for _, x in ipairs({ -1.8, 1.8 }) do
		for _, z in ipairs({ -1.8, 1.8 }) do
			add(b, "Block", V(e, 3.6, e), CFrame.new(x, 1.8, z), WOOD_DARK)
		end
	end
	-- diagonal braces on two faces
	for _, z in ipairs({ -1.82, 1.82 }) do
		add(b, "Block", V(0.4, 4.6, 0.2), CFrame.new(0, 1.8, z) * CFrame.Angles(0, 0, math.rad(45)), WOOD_DARK)
	end
	hitbox(b, V(3.9, 3.9, 3.9), 1.95)
	return 2.4
end

local function buildChest(b: Builder, glow: boolean): number
	local base = add(b, "Block", V(4.6, 2.4, 3.2), CFrame.new(0, 1.2, 0), WOOD, { CastShadow = true })
	base.Name = "Body"
	-- Half-round lid: a cylinder along X, half of it hidden inside the base.
	add(b, "Cylinder", V(4.6, 3.2, 3.2), CFrame.new(0, 2.4, 0), rgb(214, 146, 78), { CastShadow = true })
	local bandMat = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local bandProps = { Material = bandMat, Reflectance = if glow then 0 else 0.15 }
	add(b, "Block", V(4.75, 0.32, 3.35), CFrame.new(0, 2.4, 0), GOLD, bandProps)
	for _, x in ipairs({ -1.55, 1.55 }) do
		add(b, "Block", V(0.42, 2.45, 3.3), CFrame.new(x, 1.2, 0), GOLD, bandProps)
		add(b, "Cylinder", V(0.44, 3.32, 3.32), CFrame.new(x, 2.4, 0), GOLD, bandProps)
	end
	add(b, "Block", V(1, 1.1, 0.3), CFrame.new(0, 2.25, -1.68), GOLD, bandProps)
	add(b, "Block", V(0.22, 0.45, 0.1), CFrame.new(0, 2.15, -1.86), rgb(40, 28, 20))
	hitbox(b, V(4.9, 4.2, 3.6), 2.1)
	return 2.9
end

-- kind: "Pile" | "Crate" | "Chest" | "Giant". Returns the model and its radius.
function BreakableLooks.Build(kind: string, accent: Color3, rng: Random): (Model, number)
	local model = Instance.new("Model")
	model.Name = kind
	local b: Builder = { Model = model, Scale = 1 }
	local radius
	if kind == "Pile" then
		radius = buildPile(b, rng, accent)
	elseif kind == "Crate" then
		radius = buildCrate(b)
	elseif kind == "Giant" then
		b.Scale = 2.6
		radius = buildChest(b, true) * b.Scale
		-- spilled coins around the giant chest
		b.Scale = 1
		for i = 1, 14 do
			local angle = i * 0.45 - 1.2
			coin(b, V(math.cos(angle) * 6.2, 0.15, -math.abs(math.sin(angle)) * 5.2 - 0.8), rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6))
		end
		local hit = model.PrimaryPart :: BasePart
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 18
		light.Brightness = 1.6
		light.Shadows = false
		light.Parent = hit
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(rgb(255, 235, 140))
		sparkle.LightEmission = 1
		sparkle.Rate = 8
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Speed = NumberRange.new(1, 3)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Parent = hit
	else
		radius = buildChest(b, false)
	end
	model.WorldPivot = CFrame.new()
	return model, radius
end

return BreakableLooks
