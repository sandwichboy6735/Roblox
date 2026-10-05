--------------------------------------------------------------------------------
-- EggLooks - builds an egg from parts: a real egg silhouette (wide bottom,
-- tapered top) decorated with a pattern from Config.Eggs[key]:
--   Pattern      = "Spots" | "Stripes" | "Diamonds"
--   PatternColor = Color3 (defaults to a lighter shade of the egg)
--   PatternNeon  = true to make the pattern glow
--   Glass        = true for a see-through crystal shell
-- Used by the server (egg stands) and the client (hatch animation), so the
-- egg you hatch looks exactly like the one in the world.
--------------------------------------------------------------------------------

local EggLooks = {}

local V = Vector3.new

-- Two overlapping ellipsoids (unscaled, bottom of the egg at y = 0).
local BOTTOM = { Center = 2.6, Radius = V(2.6, 2.6, 2.6) }
local TOP = { Center = 3.3, Radius = V(2.45, 3.3, 2.45) }
EggLooks.Height = 6.6

-- Radius of the shell at height y, and the ellipsoid that forms it there.
local function surfaceAt(y: number)
	local best, bestRadius = BOTTOM, 0
	for _, shape in ipairs({ BOTTOM, TOP }) do
		local dy = (y - shape.Center) / shape.Radius.Y
		if math.abs(dy) < 1 then
			local r = shape.Radius.X * math.sqrt(1 - dy * dy)
			if r > bestRadius then
				best, bestRadius = shape, r
			end
		end
	end
	return bestRadius, best
end

-- A point on the shell plus the outward normal there.
local function surfacePoint(y: number, angle: number): (Vector3, Vector3)
	local r, shape = surfaceAt(y)
	local p = V(math.cos(angle) * r, y, math.sin(angle) * r)
	local a = shape.Radius
	local n = V(p.X / (a.X * a.X), (y - shape.Center) / (a.Y * a.Y), p.Z / (a.Z * a.Z)).Unit
	return p, n
end

local function newPart(model: Model, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, transparency: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.Parent = model
	return p
end

local function ellipsoid(model: Model, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, transparency: number?): Part
	local p = newPart(model, size, cf, color, material, transparency)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- egg: a Config.Eggs entry. scale: 1 = 6.6 studs tall.
-- Returns the model (pivot at the bottom of the egg) and its main shell part.
function EggLooks.Build(egg, scale: number?): (Model, BasePart)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "EggModel"

	local shellMaterial = if egg.Glass then Enum.Material.Glass else Enum.Material.SmoothPlastic
	local shellTransparency = if egg.Glass then 0.15 else 0
	local main = ellipsoid(model, TOP.Radius * 2 * s, CFrame.new(0, TOP.Center * s, 0), egg.Color, shellMaterial, shellTransparency)
	main.Name = "Egg"
	main.CastShadow = true
	ellipsoid(model, BOTTOM.Radius * 2 * s, CFrame.new(0, BOTTOM.Center * s, 0), egg.Color, shellMaterial, shellTransparency).Name = "Shell"

	if egg.Glass then
		-- a glowing core makes crystal eggs read from far away
		local core = ellipsoid(model, V(2.6, 3.4, 2.6) * s, CFrame.new(0, 3 * s, 0), egg.PatternColor or egg.Color, Enum.Material.Neon)
		core.Name = "Core"
	end

	local patternColor = egg.PatternColor or egg.Color:Lerp(Color3.new(1, 1, 1), 0.55)
	local patternMaterial = if egg.PatternNeon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local pattern = egg.Pattern or "Spots"
	local rng = Random.new(#egg.Name * 97 + #pattern)

	if pattern == "Stripes" then
		for _, y in ipairs({ 1.7, 3.0, 4.4, 5.6 }) do
			local r = surfaceAt(y)
			newPart(model, V(0.42, (r + 0.06) * 2, (r + 0.06) * 2) * s, CFrame.new(0, y * s, 0) * CFrame.Angles(0, 0, math.rad(90)), patternColor, patternMaterial).Shape = Enum.PartType.Cylinder
		end
	elseif pattern == "Diamonds" then
		local count = 12
		for i = 1, count do
			local angle = (i / count) * math.pi * 2
			local p, n = surfacePoint(3.0, angle)
			local cf = CFrame.lookAlong(p * s, n) * CFrame.Angles(0, 0, math.rad(45))
			newPart(model, V(0.95, 0.95, 0.3) * s, cf, patternColor, patternMaterial)
		end
		for _, y in ipairs({ 2.25, 3.75 }) do
			local r = surfaceAt(y)
			newPart(model, V(0.18, (r + 0.05) * 2, (r + 0.05) * 2) * s, CFrame.new(0, y * s, 0) * CFrame.Angles(0, 0, math.rad(90)), patternColor, patternMaterial).Shape = Enum.PartType.Cylinder
		end
	else
		-- Spots, spread evenly round the egg (golden-angle spiral).
		for i = 1, 13 do
			local y = 0.9 + (i / 13) * 4.9
			local angle = i * 2.39996 + rng:NextNumber(-0.2, 0.2)
			local p, n = surfacePoint(y, angle)
			local size = rng:NextNumber(0.75, 1.25)
			ellipsoid(model, V(size, size, 0.3) * s, CFrame.lookAlong((p - n * 0.04) * s, n), patternColor, patternMaterial)
		end
	end

	model.PrimaryPart = main
	model.WorldPivot = CFrame.new()
	return model, main
end

return EggLooks
