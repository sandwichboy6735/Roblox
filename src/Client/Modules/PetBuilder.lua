--------------------------------------------------------------------------------
-- PetBuilder - builds detailed pet models from PetStyles, entirely from parts
-- (no uploaded assets needed). Used for pets in the world and 3D UI previews.
--
--   PetBuilder.Build(petName, tier, { Effects = bool, Weld = bool, Scale = n })
--     -> { Model, Root, Height, Flappers, RainbowParts }
--   PetBuilder.CreateViewport(petName, tier, props) -> ViewportFrame, Model
--
-- Model pivot (Root) sits on the ground under the pet; the pet faces -Z.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PetStyles = require(Shared.PetStyles)

local PetBuilder = {}

local V = Vector3.new
local GOLD = Color3.fromRGB(255, 212, 70)
local DARK = Color3.fromRGB(22, 20, 28)
local WHITE = Color3.new(1, 1, 1)

local RARITY_SCALE = {
	Common = 1,
	Uncommon = 1.05,
	Rare = 1.1,
	Epic = 1.18,
	Legendary = 1.28,
	Mythic = 1.4,
}

PetBuilder.TierNames = { [0] = "", [1] = "Golden", [2] = "Rainbow" }

export type Flapper = { Part: BasePart, Hinge: CFrame, Side: number, Amount: number, Speed: number, Joint: Motor6D? }
export type Built = {
	Model: Model,
	Root: BasePart,
	Height: number,
	Flappers: { Flapper },
	RainbowParts: { BasePart },
}

--------------------------------------------------------------------------------
-- Builder context
--------------------------------------------------------------------------------

local Ctx = {}
Ctx.__index = Ctx

local function material(name: string?): Enum.Material?
	if not name then
		return nil
	end
	local ok, result = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok then result else nil
end

local function newCtx(model: Model, root: BasePart, scale: number, style, tier: number)
	local self = setmetatable({}, Ctx)
	self.Model = model
	self.Root = root
	self.S = scale
	self.Style = style
	self.Tier = tier
	self.Flappers = {} :: { Flapper }
	self.Rainbow = {} :: { BasePart }
	self.BodyIndex = 0
	-- Anchor points (unscaled, set by each archetype)
	self.BodyCenter = V(0, 1.2, 0)
	self.BodySize = V(1.5, 1.4, 2)
	self.HeadCenter = V(0, 2.2, -0.8)
	self.HeadSize = 1.4
	self.HeadTop = V(0, 2.9, -0.8)
	self.TailTip = V(0, 1.6, 1.4)
	self.BodyPart = nil :: BasePart?
	self.TailPart = nil :: BasePart?
	return self
end

function Ctx:color(key: any): Color3
	if typeof(key) == "Color3" then
		return key
	end
	return self.Style[key] or WHITE
end

-- kind: "Ball" | "Ellipsoid" | "Cylinder" | "Block" | "Wedge"
-- cf: unscaled CFrame relative to the pet's ground pivot.
function Ctx:addCF(kind: string, size: Vector3, cf: CFrame, colorKey: any, opts: { [string]: any }?): BasePart
	local o = opts or {}
	local part: BasePart
	if kind == "Wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = o.Shadow == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local s = self.S
	local scaled = size * s
	if kind == "Ball" then
		(part :: Part).Shape = Enum.PartType.Ball
		scaled = V(scaled.X, scaled.X, scaled.X)
	elseif kind == "Cylinder" then
		(part :: Part).Shape = Enum.PartType.Cylinder
		scaled = V(scaled.X, scaled.Y, scaled.Y)
	elseif kind == "Ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Size = scaled
	part.CFrame = CFrame.new(cf.Position * s) * cf.Rotation

	-- Colour / material, including Golden & Rainbow tiers
	local role = o.Role or ((colorKey == "Primary" or colorKey == "Secondary") and "Body" or "Detail")
	local color = self:color(colorKey)
	local mat = material(o.Material) or (role == "Body" and material(self.Style.Material)) or Enum.Material.SmoothPlastic
	local transparency = o.Transparency or (role == "Body" and self.Style.Transparency) or 0

	if role ~= "Eye" and not o.KeepColor then
		if self.Tier == 1 then
			color = color:Lerp(GOLD, if role == "Body" then 0.72 else 0.45)
			if role == "Body" then
				mat = Enum.Material.Foil
				transparency = 0
			end
		elseif self.Tier >= 2 and role == "Body" then
			self.BodyIndex += 1
			color = Color3.fromHSV((self.BodyIndex * 0.13) % 1, 0.6, 1)
			mat = Enum.Material.SmoothPlastic
			transparency = 0
			table.insert(self.Rainbow, part)
		end
	end
	part.Color = color
	part.Material = mat
	part.Transparency = transparency
	part.Name = o.Name or kind
	part:SetAttribute("Role", role)
	part.Parent = self.Model
	return part
end

function Ctx:add(kind: string, size: Vector3, pos: Vector3, rot: Vector3?, colorKey: any, opts: { [string]: any }?): BasePart
	local cf = CFrame.new(pos)
	if rot then
		cf *= CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	end
	return self:addCF(kind, size, cf, colorKey, opts)
end

-- Mirrored pair across the X axis (rotations about Y and Z are mirrored).
function Ctx:pair(kind: string, size: Vector3, pos: Vector3, rot: Vector3?, colorKey: any, opts: { [string]: any }?): (BasePart, BasePart)
	local right = self:add(kind, size, pos, rot, colorKey, opts)
	local mirrorRot = if rot then V(rot.X, -rot.Y, -rot.Z) else nil
	local left = self:add(kind, size, V(-pos.X, pos.Y, pos.Z), mirrorRot, colorKey, opts)
	return right, left
end

-- Ellipsoid / cylinder stretched between two points.
function Ctx:segment(kind: string, from: Vector3, to: Vector3, thickness: number, colorKey: any, opts: { [string]: any }?): BasePart
	local center = (from + to) / 2
	local length = (to - from).Magnitude
	local look = CFrame.lookAt(center, to)
	if kind == "Cylinder" then
		return self:addCF("Cylinder", V(length, thickness, thickness), look * CFrame.Angles(0, math.rad(90), 0), colorKey, opts)
	end
	return self:addCF("Ellipsoid", V(thickness, thickness, length), look, colorKey, opts)
end

function Ctx:segmentPair(kind: string, from: Vector3, to: Vector3, thickness: number, colorKey: any, opts: { [string]: any }?)
	local a = self:segment(kind, from, to, thickness, colorKey, opts)
	local b = self:segment(kind, V(-from.X, from.Y, from.Z), V(-to.X, to.Y, to.Z), thickness, colorKey, opts)
	return a, b
end

-- Isosceles triangle (two wedges). Faces forward; yaw 90 makes it face sideways.
function Ctx:triangle(center: Vector3, width: number, height: number, thickness: number, tilt: number, colorKey: any, yaw: number?, opts: { [string]: any }?)
	local base = CFrame.new(center) * CFrame.Angles(0, math.rad(yaw or 0), math.rad(tilt))
	self:addCF("Wedge", V(thickness, height, width / 2), base * CFrame.new(-width / 4, 0, 0) * CFrame.Angles(0, math.rad(90), 0), colorKey, opts)
	self:addCF("Wedge", V(thickness, height, width / 2), base * CFrame.new(width / 4, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), colorKey, opts)
end

function Ctx:trianglePair(center: Vector3, width: number, height: number, thickness: number, tilt: number, colorKey: any, opts: { [string]: any }?)
	self:triangle(center, width, height, thickness, -tilt, colorKey, nil, opts)
	self:triangle(V(-center.X, center.Y, center.Z), width, height, thickness, tilt, colorKey, nil, opts)
end

-- Big cute eyes with a highlight. light = white sclera for dark faces.
function Ctx:eyes(center: Vector3, spacing: number, size: number, light: boolean?)
	for _, side in ipairs({ -1, 1 }) do
		local p = center + V(side * spacing, 0, 0)
		if light then
			self:add("Ellipsoid", V(size * 0.95, size * 1.1, size * 0.5), p, nil, WHITE, { Role = "Eye" })
			self:add("Ellipsoid", V(size * 0.6, size * 0.75, size * 0.4), p + V(0, -size * 0.05, -size * 0.12), nil, DARK, { Role = "Eye" })
		else
			self:add("Ellipsoid", V(size * 0.8, size, size * 0.5), p, nil, DARK, { Role = "Eye" })
		end
		self:add("Ball", V(size * 0.3, 0, 0), p + V(-side * size * 0.12, size * 0.2, -size * 0.24), nil, WHITE, { Role = "Eye", Material = "Neon" })
	end
end

function Ctx:flap(part: BasePart, hinge: Vector3, side: number, amount: number, speed: number)
	table.insert(self.Flappers, {
		Part = part,
		Hinge = CFrame.new(hinge * self.S),
		Side = side,
		Amount = math.rad(amount),
		Speed = speed,
		Joint = nil,
	})
end

--------------------------------------------------------------------------------
-- Shared body parts
--------------------------------------------------------------------------------

local function legs4(c, front: number, back: number, x: number, h: number, w: number)
	for _, z in ipairs({ front, back }) do
		c:pair("Ellipsoid", V(w, h, w), V(x, h / 2, z), nil, "Primary")
		c:pair("Ellipsoid", V(w * 1.15, h * 0.35, w * 1.3), V(x, h * 0.16, z - w * 0.15), nil, "Secondary")
	end
end

--------------------------------------------------------------------------------
-- Archetypes
--------------------------------------------------------------------------------

local Archetypes = {}

local function dogLike(c, wolf: boolean)
	c.BodyPart = c:add("Ellipsoid", V(1.6, 1.4, 2.2), V(0, 1.3, 0.25), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(1.25, 1.0, 1.7), V(0, 1.12, 0.05), nil, "Secondary")
	legs4(c, -0.5, 0.95, 0.48, 0.85, 0.5)
	local head = V(0, 2.35, -0.85)
	c:add("Ellipsoid", V(1.5, 1.4, 1.4), head, nil, "Primary", { Name = "Head" })
	local snout = if wolf then 0.95 else 0.7
	c:add("Ellipsoid", V(0.85, 0.62, snout), head + V(0, -0.25, -0.62 - (snout - 0.7) / 2), nil, "Secondary")
	c:add("Ball", V(0.26, 0, 0), head + V(0, -0.1, -0.97 - (snout - 0.7)), nil, DARK, { Role = "Eye" })
	c:eyes(head + V(0, 0.18, -0.58), 0.34, 0.32)
	if wolf then
		c:trianglePair(head + V(0.42, 0.82, 0), 0.5, 0.7, 0.16, 12, "Primary")
		c:trianglePair(head + V(0.42, 0.78, -0.07), 0.3, 0.45, 0.06, 12, "Secondary")
		c.TailPart = c:add("Ellipsoid", V(0.6, 0.6, 1.35), V(0, 1.85, 1.5), V(-40, 0, 0), "Primary")
		c:add("Ellipsoid", V(0.48, 0.48, 0.5), V(0, 2.3, 2.0), V(-40, 0, 0), "Secondary")
		c:add("Ellipsoid", V(0.9, 0.8, 0.5), V(0, 1.75, -0.55), nil, "Secondary") -- chest fluff
		c.TailTip = V(0, 2.35, 2.05)
	else
		c:pair("Ellipsoid", V(0.32, 0.85, 0.52), head + V(0.72, 0.02, 0.1), V(0, 0, 18), "Accent")
		c.TailPart = c:add("Ellipsoid", V(0.28, 0.28, 0.95), V(0, 1.85, 1.38), V(-45, 0, 0), "Primary")
		c.TailTip = V(0, 2.15, 1.7)
	end
	c.BodyCenter, c.BodySize = V(0, 1.3, 0.25), V(1.6, 1.4, 2.2)
	c.HeadCenter, c.HeadSize, c.HeadTop = head, 1.5, head + V(0, 0.7, 0)
end

Archetypes.Dog = function(c)
	dogLike(c, false)
end
Archetypes.Wolf = function(c)
	dogLike(c, true)
end

local function catLike(c, fox: boolean)
	c.BodyPart = c:add("Ellipsoid", V(1.35, 1.2, 2.0), V(0, 1.15, 0.25), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(1.0, 0.85, 1.5), V(0, 1.0, 0.05), nil, "Secondary")
	legs4(c, -0.45, 0.85, 0.4, 0.8, 0.42)
	local head = V(0, 2.1, -0.75)
	c:add("Ellipsoid", V(1.55, 1.3, 1.3), head, nil, "Primary", { Name = "Head" })
	if fox then
		c:add("Ellipsoid", V(0.62, 0.46, 0.85), head + V(0, -0.25, -0.72), nil, "Secondary")
		c:add("Ball", V(0.2, 0, 0), head + V(0, -0.17, -1.12), nil, DARK, { Role = "Eye" })
	else
		c:add("Ellipsoid", V(0.72, 0.42, 0.4), head + V(0, -0.28, -0.55), nil, "Secondary")
		c:add("Ball", V(0.16, 0, 0), head + V(0, -0.12, -0.67), nil, "Accent")
	end
	c:eyes(head + V(0, 0.12, -0.55), 0.33, 0.34)
	local earW, earH = if fox then 0.62 else 0.52, if fox then 0.78 else 0.58
	c:trianglePair(head + V(0.45, 0.72, 0), earW, earH, 0.16, 14, "Primary")
	c:trianglePair(head + V(0.45, 0.68, -0.07), earW * 0.55, earH * 0.6, 0.06, 14, if fox then "Accent" else "Accent")
	if fox then
		c.TailPart = c:add("Ellipsoid", V(0.78, 0.78, 1.55), V(0, 1.6, 1.55), V(-35, 0, 0), "Primary")
		c:add("Ellipsoid", V(0.64, 0.64, 0.6), V(0, 2.12, 2.22), V(-35, 0, 0), "Secondary")
		c.TailTip = V(0, 2.2, 2.3)
	else
		c.TailPart = c:add("Ellipsoid", V(0.24, 0.24, 0.95), V(0, 1.35, 1.32), V(-30, 0, 0), "Primary")
		c:add("Ellipsoid", V(0.24, 0.24, 0.78), V(0, 1.95, 1.62), V(-70, 0, 0), "Primary")
		c.TailTip = V(0, 2.3, 1.7)
	end
	c.BodyCenter, c.BodySize = V(0, 1.15, 0.25), V(1.35, 1.2, 2.0)
	c.HeadCenter, c.HeadSize, c.HeadTop = head, 1.5, head + V(0, 0.65, 0)
end

Archetypes.Cat = function(c)
	catLike(c, false)
end
Archetypes.Fox = function(c)
	catLike(c, true)
end

Archetypes.Bunny = function(c)
	c.BodyPart = c:add("Ellipsoid", V(1.5, 1.35, 1.6), V(0, 0.95, 0.15), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(1.1, 1.0, 0.8), V(0, 0.85, -0.35), nil, "Secondary")
	local head = V(0, 2.0, -0.45)
	c:add("Ellipsoid", V(1.35, 1.2, 1.2), head, nil, "Primary", { Name = "Head" })
	c:add("Ellipsoid", V(0.55, 0.35, 0.3), head + V(0, -0.25, -0.52), nil, "Secondary")
	c:add("Ball", V(0.15, 0, 0), head + V(0, -0.12, -0.62), nil, "Accent")
	c:eyes(head + V(0, 0.12, -0.5), 0.3, 0.3)
	c:pair("Ellipsoid", V(0.34, 1.25, 0.22), head + V(0.28, 1.05, 0.05), V(0, 0, -12), "Primary")
	c:pair("Ellipsoid", V(0.2, 0.95, 0.1), head + V(0.28, 1.0, -0.06), V(0, 0, -12), "Accent")
	c:pair("Ellipsoid", V(0.45, 0.28, 0.8), V(0.42, 0.14, -0.35), nil, "Secondary")
	c.TailPart = c:add("Ball", V(0.55, 0, 0), V(0, 0.95, 0.98), nil, WHITE)
	c.BodyCenter, c.BodySize = V(0, 0.95, 0.15), V(1.5, 1.35, 1.6)
	c.HeadCenter, c.HeadSize, c.HeadTop = head, 1.3, head + V(0, 0.6, 0)
	c.TailTip = V(0, 0.95, 1.05)
end

local function horseLike(c, unicorn: boolean)
	c.BodyPart = c:add("Ellipsoid", V(1.35, 1.25, 2.3), V(0, 1.85, 0.25), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(1.0, 0.8, 1.8), V(0, 1.62, 0.2), nil, if unicorn then "Primary" else "Secondary")
	for _, z in ipairs({ -0.6, 1.05 }) do
		c:pair("Ellipsoid", V(0.36, 1.45, 0.36), V(0.42, 0.75, z), nil, "Primary")
		c:pair("Ellipsoid", V(0.42, 0.25, 0.45), V(0.42, 0.1, z - 0.02), nil, if unicorn then GOLD else "Accent")
	end
	c:add("Ellipsoid", V(0.62, 1.25, 0.68), V(0, 2.65, -0.75), V(-25, 0, 0), "Primary")
	local head = V(0, 3.3, -1.1)
	c:add("Ellipsoid", V(0.85, 0.8, 1.25), head, nil, "Primary", { Name = "Head" })
	c:add("Ellipsoid", V(0.65, 0.55, 0.6), head + V(0, -0.12, -0.6), nil, "Secondary")
	c:pair("Ball", V(0.1, 0, 0), head + V(0.14, -0.05, -0.9), nil, DARK, { Role = "Eye" })
	c:eyes(head + V(0, 0.15, -0.32), 0.34, 0.28)
	c:pair("Ellipsoid", V(0.18, 0.45, 0.15), head + V(0.25, 0.5, 0.25), V(0, 0, -15), "Primary")
	if unicorn then
		-- spiral horn (three tapering segments)
		local base = head + V(0, 0.42, -0.32)
		local dir = V(0, 0.82, -0.57).Unit
		local thick = { 0.26, 0.19, 0.12 }
		for i = 1, 3 do
			local a = base + dir * ((i - 1) * 0.32)
			local b = base + dir * (i * 0.32)
			c:segment("Cylinder", a, b, thick[i], GOLD, { Material = "Foil", Name = "Horn" })
		end
		-- rainbow mane and tail
		local mane = { Color3.fromRGB(255, 120, 200), Color3.fromRGB(190, 120, 255), Color3.fromRGB(110, 190, 255) }
		for i, y in ipairs({ 3.15, 2.75, 2.35 }) do
			c:add("Ellipsoid", V(0.3, 0.7, 0.48), V(0, y, -0.95 + i * 0.17), V(-25, 0, 0), mane[i])
		end
		c.TailPart = c:add("Ellipsoid", V(0.36, 1.0, 0.36), V(0, 1.85, 1.5), V(-30, 0, 0), mane[1])
		c:add("Ellipsoid", V(0.3, 0.8, 0.3), V(0, 1.45, 1.75), V(-15, 0, 0), mane[3])
	else
		-- antlers
		c:segmentPair("Cylinder", head + V(0.22, 0.45, 0.15), head + V(0.42, 1.15, 0.25), 0.11, "Accent")
		c:segmentPair("Cylinder", head + V(0.35, 0.85, 0.2), head + V(0.62, 1.05, 0.0), 0.09, "Accent")
		c:segmentPair("Cylinder", head + V(0.4, 1.05, 0.24), head + V(0.35, 1.4, 0.45), 0.08, "Accent")
		c.TailPart = c:add("Ellipsoid", V(0.32, 0.6, 0.32), V(0, 2.1, 1.42), V(-40, 0, 0), "Secondary")
	end
	c.BodyCenter, c.BodySize = V(0, 1.85, 0.25), V(1.35, 1.25, 2.3)
	c.HeadCenter, c.HeadSize, c.HeadTop = head, 1.0, head + V(0, 0.55, 0.1)
	c.TailTip = V(0, 1.5, 1.8)
end

Archetypes.Deer = function(c)
	horseLike(c, false)
end
Archetypes.Unicorn = function(c)
	horseLike(c, true)
end

Archetypes.Bear = function(c)
	c.BodyPart = c:add("Ellipsoid", V(1.8, 1.75, 1.65), V(0, 1.1, 0.1), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(1.15, 1.2, 0.5), V(0, 1.05, -0.62), nil, "Secondary")
	local head = V(0, 2.4, -0.15)
	c:add("Ellipsoid", V(1.5, 1.35, 1.3), head, nil, "Primary", { Name = "Head" })
	c:pair("Ball", V(0.52, 0, 0), head + V(0.55, 0.58, 0.05), nil, "Primary")
	c:pair("Ball", V(0.3, 0, 0), head + V(0.55, 0.58, -0.12), nil, "Secondary")
	c:add("Ellipsoid", V(0.72, 0.5, 0.42), head + V(0, -0.25, -0.58), nil, "Secondary")
	c:add("Ellipsoid", V(0.3, 0.2, 0.15), head + V(0, -0.12, -0.8), nil, DARK, { Role = "Eye" })
	c:eyes(head + V(0, 0.12, -0.56), 0.32, 0.28)
	c:pair("Ellipsoid", V(0.5, 0.95, 0.5), V(0.88, 1.25, -0.3), V(0, 0, 25), "Primary")
	c:pair("Ellipsoid", V(0.62, 0.38, 0.75), V(0.45, 0.19, -0.35), nil, "Secondary")
	c.TailPart = c:add("Ball", V(0.4, 0, 0), V(0, 0.8, 0.95), nil, "Primary")
	c.BodyCenter, c.BodySize = V(0, 1.1, 0.1), V(1.8, 1.75, 1.65)
	c.HeadCenter, c.HeadSize, c.HeadTop = head, 1.45, head + V(0, 0.68, 0)
	c.TailTip = V(0, 0.8, 1.0)
end

Archetypes.Lamb = function(c)
	local wool = { V(0, 1.4, 0.2), V(0.48, 1.15, 0), V(-0.48, 1.15, 0), V(0.48, 1.15, 0.55), V(-0.48, 1.15, 0.55), V(0, 1.05, 0.8), V(0, 1.1, -0.25) }
	for i, p in ipairs(wool) do
		local part = c:add("Ball", V(1.05, 0, 0), p, nil, "Primary", { Shadow = i == 1, Name = if i == 1 then "Body" else "Wool" })
		if i == 1 then
			c.BodyPart = part
		end
	end
	c:pair("Ellipsoid", V(0.28, 0.8, 0.28), V(0.4, 0.4, -0.3), nil, "Secondary")
	c:pair("Ellipsoid", V(0.28, 0.8, 0.28), V(0.4, 0.4, 0.7), nil, "Secondary")
	local head = V(0, 1.75, -0.85)
	c:add("Ellipsoid", V(0.85, 0.85, 0.95), head, nil, "Secondary", { Name = "Head" })
	c:add("Ball", V(0.6, 0, 0), head + V(0, 0.45, 0.05), nil, "Primary")
	c:pair("Ellipsoid", V(0.55, 0.2, 0.3), head + V(0.5, 0.1, 0.05), V(0, 0, -20), "Secondary")
	c:eyes(head + V(0, 0.08, -0.42), 0.22, 0.26, true)
	c.TailPart = c:add("Ball", V(0.45, 0, 0), V(0, 1.2, 1.05), nil, "Primary")
	c.BodyCenter, c.BodySize = V(0, 1.2, 0.25), V(1.6, 1.3, 1.6)
	c.HeadCenter, c.HeadSize, c.HeadTop = head, 0.95, head + V(0, 0.75, 0)
	c.TailTip = V(0, 1.2, 1.1)
end

Archetypes.Owl = function(c)
	c.BodyPart = c:add("Ellipsoid", V(1.5, 1.9, 1.4), V(0, 1.2, 0), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(1.05, 1.35, 0.55), V(0, 1.05, -0.5), nil, "Secondary")
	c:pair("Ball", V(0.62, 0, 0), V(0.32, 1.72, -0.52), nil, WHITE, { Role = "Eye" })
	c:pair("Ball", V(0.4, 0, 0), V(0.32, 1.72, -0.72), nil, "Accent", { Role = "Eye" })
	c:pair("Ball", V(0.22, 0, 0), V(0.32, 1.72, -0.84), nil, DARK, { Role = "Eye" })
	c:pair("Ball", V(0.08, 0, 0), V(0.27, 1.79, -0.93), nil, WHITE, { Role = "Eye", Material = "Neon" })
	c:add("Ellipsoid", V(0.2, 0.32, 0.22), V(0, 1.45, -0.72), nil, "Accent")
	c:trianglePair(V(0.45, 2.15, -0.1), 0.36, 0.48, 0.12, 22, "Primary")
	local r, l = c:pair("Ellipsoid", V(0.3, 1.25, 0.95), V(0.8, 1.25, 0.05), V(0, 0, 8), "Secondary")
	c:flap(r, V(0.7, 1.8, 0.05), 1, 25, 6)
	c:flap(l, V(-0.7, 1.8, 0.05), -1, 25, 6)
	c:pair("Ellipsoid", V(0.3, 0.18, 0.4), V(0.3, 0.1, -0.3), nil, "Accent")
	c.TailPart = c:add("Ellipsoid", V(0.5, 0.25, 0.6), V(0, 0.55, 0.7), V(-30, 0, 0), "Secondary")
	c.BodyCenter, c.BodySize = V(0, 1.2, 0), V(1.5, 1.9, 1.4)
	c.HeadCenter, c.HeadSize, c.HeadTop = V(0, 1.75, -0.2), 1.4, V(0, 2.2, 0)
	c.TailTip = V(0, 0.55, 0.9)
end

Archetypes.Penguin = function(c)
	c.BodyPart = c:add("Ellipsoid", V(1.4, 1.95, 1.3), V(0, 1.2, 0), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(1.0, 1.5, 0.55), V(0, 1.05, -0.45), nil, "Secondary")
	c:eyes(V(0, 1.85, -0.52), 0.26, 0.26, true)
	c:add("Ellipsoid", V(0.32, 0.18, 0.45), V(0, 1.65, -0.72), nil, "Accent")
	local r, l = c:pair("Ellipsoid", V(0.22, 1.0, 0.55), V(0.78, 1.25, 0), V(0, 0, 18), "Primary")
	c:flap(r, V(0.68, 1.7, 0), 1, 30, 5)
	c:flap(l, V(-0.68, 1.7, 0), -1, 30, 5)
	c:pair("Ellipsoid", V(0.38, 0.16, 0.55), V(0.3, 0.08, -0.35), nil, "Accent")
	c.TailPart = c:add("Ellipsoid", V(0.4, 0.2, 0.4), V(0, 0.35, 0.65), nil, "Primary")
	c.BodyCenter, c.BodySize = V(0, 1.2, 0), V(1.4, 1.95, 1.3)
	c.HeadCenter, c.HeadSize, c.HeadTop = V(0, 1.85, -0.1), 1.3, V(0, 2.2, 0)
	c.TailTip = V(0, 0.35, 0.8)
end

Archetypes.Phoenix = function(c)
	c.BodyPart = c:add("Ellipsoid", V(1.15, 1.25, 1.6), V(0, 1.65, 0.1), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(0.85, 0.9, 0.6), V(0, 1.55, -0.48), nil, "Secondary")
	local head = V(0, 2.55, -0.55)
	c:add("Ball", V(1.0, 0, 0), head, nil, "Primary", { Name = "Head" })
	c:add("Ellipsoid", V(0.26, 0.22, 0.5), head + V(0, -0.1, -0.55), nil, "Accent")
	c:eyes(head + V(0, 0.1, -0.4), 0.25, 0.25)
	for i, rx in ipairs({ -10, -30, -50 }) do
		c:add("Ellipsoid", V(0.13, 0.62, 0.26), head + V(0, 0.55, -0.05 + i * 0.13), V(rx, 0, 0), "Secondary")
	end
	local r, l = c:pair("Ellipsoid", V(0.22, 0.95, 1.7), V(0.85, 1.95, 0.15), V(0, 0, -30), "Secondary")
	c:flap(r, V(0.55, 1.95, 0.15), 1, 35, 7)
	c:flap(l, V(-0.55, 1.95, 0.15), -1, 35, 7)
	c.TailPart = c:add("Ellipsoid", V(0.34, 0.15, 1.55), V(0, 1.4, 1.3), V(15, 0, 0), "Accent")
	c:add("Ellipsoid", V(0.3, 0.14, 1.4), V(0.32, 1.38, 1.2), V(15, -18, 0), "Secondary")
	c:add("Ellipsoid", V(0.3, 0.14, 1.4), V(-0.32, 1.38, 1.2), V(15, 18, 0), "Secondary")
	c:pair("Ellipsoid", V(0.15, 0.85, 0.15), V(0.25, 0.55, 0.05), nil, "Accent")
	c:pair("Ellipsoid", V(0.32, 0.1, 0.38), V(0.25, 0.08, -0.05), nil, "Accent")
	c.BodyCenter, c.BodySize = V(0, 1.65, 0.1), V(1.15, 1.25, 1.6)
	c.HeadCenter, c.HeadSize, c.HeadTop = head, 1.0, head + V(0, 0.75, 0.1)
	c.TailTip = V(0, 1.25, 1.95)
end

Archetypes.Dragon = function(c)
	c.BodyPart = c:add("Ellipsoid", V(1.55, 1.45, 2.2), V(0, 1.4, 0.3), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(1.1, 1.05, 1.85), V(0, 1.2, 0.15), nil, "Secondary")
	legs4(c, -0.35, 1.0, 0.55, 0.85, 0.52)
	c:add("Ellipsoid", V(0.75, 1.1, 0.8), V(0, 2.2, -0.65), V(-30, 0, 0), "Primary")
	local head = V(0, 2.85, -1.05)
	c:add("Ellipsoid", V(1.25, 1.05, 1.35), head, nil, "Primary", { Name = "Head" })
	c:add("Ellipsoid", V(0.85, 0.6, 0.85), head + V(0, -0.18, -0.75), nil, "Primary")
	c:pair("Ball", V(0.1, 0, 0), head + V(0.18, -0.05, -1.15), nil, DARK, { Role = "Eye" })
	c:eyes(head + V(0, 0.18, -0.56), 0.34, 0.3)
	c:segmentPair("Ellipsoid", head + V(0.3, 0.38, -0.05), head + V(0.48, 1.05, 0.55), 0.2, "Accent")
	for i, z in ipairs({ -0.05, 0.5, 1.02 }) do
		c:triangle(V(0, 2.12 - i * 0.04, z), 0.42, 0.45, 0.1, 0, "Accent", 90)
	end
	local membraneR, membraneL = c:pair("Ellipsoid", V(0.12, 1.75, 2.2), V(1.25, 2.65, 0.45), V(0, 0, -40), "Secondary")
	local armR, armL = c:segmentPair("Cylinder", V(0.55, 2.0, 0.15), V(1.8, 3.4, 0.0), 0.14, "Accent")
	c:flap(membraneR, V(0.6, 2.0, 0.2), 1, 28, 5)
	c:flap(membraneL, V(-0.6, 2.0, 0.2), -1, 28, 5)
	c:flap(armR, V(0.6, 2.0, 0.2), 1, 28, 5)
	c:flap(armL, V(-0.6, 2.0, 0.2), -1, 28, 5)
	c:add("Ellipsoid", V(0.6, 0.6, 1.05), V(0, 1.35, 1.55), V(10, 0, 0), "Primary")
	c.TailPart = c:add("Ellipsoid", V(0.42, 0.42, 0.95), V(0, 1.45, 2.3), V(-10, 0, 0), "Primary")
	c:triangle(V(0, 1.45, 2.85), 0.5, 0.5, 0.1, 0, "Accent", 90)
	c.BodyCenter, c.BodySize = V(0, 1.4, 0.3), V(1.55, 1.45, 2.2)
	c.HeadCenter, c.HeadSize, c.HeadTop = head, 1.25, head + V(0, 0.55, 0.1)
	c.TailTip = V(0, 1.45, 2.85)
end

Archetypes.Seal = function(c)
	c.BodyPart = c:add("Ellipsoid", V(1.25, 1.05, 2.4), V(0, 0.65, 0.3), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(0.95, 0.7, 1.9), V(0, 0.5, 0.2), nil, "Secondary")
	local head = V(0, 1.35, -0.85)
	c:add("Ellipsoid", V(1.1, 1.0, 1.0), head, nil, "Primary", { Name = "Head" })
	c:add("Ellipsoid", V(0.62, 0.38, 0.35), head + V(0, -0.22, -0.45), nil, "Secondary")
	c:add("Ellipsoid", V(0.2, 0.14, 0.12), head + V(0, -0.12, -0.6), nil, DARK, { Role = "Eye" })
	c:eyes(head + V(0, 0.12, -0.42), 0.3, 0.3)
	c:pair("Ellipsoid", V(0.22, 0.18, 0.75), V(0.7, 0.3, -0.4), V(0, 35, 0), "Primary")
	c.TailPart = c:add("Ellipsoid", V(0.5, 0.15, 0.7), V(0.25, 0.35, 1.55), V(0, -35, 0), "Primary")
	c:add("Ellipsoid", V(0.5, 0.15, 0.7), V(-0.25, 0.35, 1.55), V(0, 35, 0), "Primary")
	c.BodyCenter, c.BodySize = V(0, 0.65, 0.3), V(1.25, 1.05, 2.4)
	c.HeadCenter, c.HeadSize, c.HeadTop = head, 1.05, head + V(0, 0.5, 0)
	c.TailTip = V(0, 0.4, 1.7)
end

Archetypes.Crab = function(c)
	c.BodyPart = c:add("Ellipsoid", V(2.0, 0.95, 1.5), V(0, 0.95, 0), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(1.2, 0.1, 0.2), V(0, 1.42, -0.1), V(0, 20, 0), "Secondary", { Material = "Neon" })
	c:add("Ellipsoid", V(0.9, 0.1, 0.16), V(0.1, 1.4, 0.3), V(0, -25, 0), "Secondary", { Material = "Neon" })
	c:segmentPair("Cylinder", V(0.35, 1.3, -0.45), V(0.4, 1.85, -0.5), 0.12, "Primary")
	c:pair("Ball", V(0.32, 0, 0), V(0.4, 1.95, -0.5), nil, WHITE, { Role = "Eye" })
	c:pair("Ball", V(0.16, 0, 0), V(0.4, 1.97, -0.64), nil, DARK, { Role = "Eye" })
	c:segmentPair("Ellipsoid", V(0.85, 0.95, -0.35), V(1.25, 1.15, -0.85), 0.32, "Primary")
	c:pair("Ellipsoid", V(0.65, 0.5, 0.75), V(1.35, 1.25, -1.1), nil, "Primary")
	c:pair("Ellipsoid", V(0.25, 0.2, 0.5), V(1.3, 1.52, -1.25), nil, "Accent")
	for _, z in ipairs({ -0.05, 0.3, 0.62 }) do
		c:segmentPair("Ellipsoid", V(0.8, 0.85, z), V(1.3, 0.12, z + 0.1), 0.16, "Primary")
	end
	c.TailPart = c.BodyPart
	c.BodyCenter, c.BodySize = V(0, 0.95, 0), V(2.0, 0.95, 1.5)
	c.HeadCenter, c.HeadSize, c.HeadTop = V(0, 1.3, -0.4), 1.4, V(0, 1.6, 0)
	c.TailTip = V(0, 1.2, 0.5)
end

Archetypes.Lizard = function(c)
	c.BodyPart = c:add("Ellipsoid", V(1.05, 0.75, 2.0), V(0, 0.65, 0.2), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(0.8, 0.5, 1.7), V(0, 0.5, 0.15), nil, "Secondary")
	local head = V(0, 0.95, -1.15)
	c:add("Ellipsoid", V(0.9, 0.65, 1.1), head, nil, "Primary", { Name = "Head" })
	c:eyes(head + V(0, 0.25, -0.22), 0.32, 0.27)
	c:segmentPair("Ellipsoid", V(0.4, 0.55, -0.45), V(0.85, 0.12, -0.75), 0.27, "Primary")
	c:segmentPair("Ellipsoid", V(0.4, 0.55, 0.75), V(0.85, 0.12, 1.0), 0.27, "Primary")
	c:add("Ellipsoid", V(0.5, 0.4, 1.0), V(0, 0.55, 1.55), V(0, 10, 0), "Primary")
	c:add("Ellipsoid", V(0.32, 0.28, 0.9), V(0.15, 0.45, 2.35), V(0, 25, 0), "Primary")
	c.TailPart = c:add("Ellipsoid", V(0.18, 0.16, 0.7), V(0.4, 0.38, 2.95), V(0, 40, 0), "Secondary")
	for i, z in ipairs({ -0.25, 0.2, 0.65 }) do
		c:triangle(V(0, 1.02 - i * 0.02, z), 0.26, 0.3, 0.08, 0, "Secondary", 90)
	end
	c.BodyCenter, c.BodySize = V(0, 0.65, 0.2), V(1.05, 0.75, 2.0)
	c.HeadCenter, c.HeadSize, c.HeadTop = head, 0.9, head + V(0, 0.4, 0)
	c.TailTip = V(0.4, 0.4, 3.0)
end

Archetypes.Capybara = function(c)
	c.BodyPart = c:add("Ellipsoid", V(1.6, 1.4, 2.3), V(0, 1.05, 0.2), nil, "Primary", { Shadow = true, Name = "Body" })
	c:add("Ellipsoid", V(1.2, 0.9, 1.8), V(0, 0.85, 0.15), nil, "Secondary")
	local head = V(0, 1.65, -1.05)
	c:add("Ellipsoid", V(1.15, 1.1, 1.35), head, nil, "Primary", { Name = "Head" })
	c:add("Ellipsoid", V(1.0, 0.8, 0.72), head + V(0, -0.12, -0.62), nil, "Primary")
	c:pair("Ellipsoid", V(0.12, 0.08, 0.06), head + V(0.18, 0.06, -0.97), nil, DARK, { Role = "Eye" })
	-- sleepy, chill eyes
	c:pair("Ellipsoid", V(0.3, 0.1, 0.12), head + V(0.32, 0.25, -0.52), nil, DARK, { Role = "Eye" })
	c:pair("Ball", V(0.32, 0, 0), head + V(0.38, 0.55, 0.3), nil, "Accent")
	legs4(c, -0.5, 0.85, 0.48, 0.55, 0.42)
	c.TailPart = c.BodyPart
	c.BodyCenter, c.BodySize = V(0, 1.05, 0.2), V(1.6, 1.4, 2.3)
	c.HeadCenter, c.HeadSize, c.HeadTop = head, 1.2, head + V(0, 0.6, 0.05)
	c.TailTip = V(0, 1.1, 1.3)
end

--------------------------------------------------------------------------------
-- Extras
--------------------------------------------------------------------------------

local function addExtras(c, extras: { string })
	local set = {}
	for _, name in ipairs(extras) do
		set[name] = true
	end

	if set.Stripes then
		local b, sz = c.BodyCenter, c.BodySize
		for _, dz in ipairs({ -0.5, 0, 0.5 }) do
			c:add("Ellipsoid", V(sz.X * 1.03, sz.Y * 1.03, 0.22), b + V(0, 0, dz * sz.Z * 0.6), nil, "Accent", { Role = "Detail" })
		end
	end
	if set.Spots then
		local b, sz = c.BodyCenter, c.BodySize
		local glow = set.Glow == true
		for _, o in ipairs({ V(0.25, 0.47, -0.25), V(-0.3, 0.45, 0.1), V(0.15, 0.48, 0.35), V(-0.1, 0.5, -0.05) }) do
			c:add("Ellipsoid", V(0.36, 0.12, 0.36), b + V(o.X * sz.X, o.Y * sz.Y, o.Z * sz.Z), nil, "Secondary", { Role = "Detail", Material = if glow then "Neon" else nil })
		end
	end
	if set.Sprinkles then
		local colors = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 230, 80), Color3.fromRGB(120, 255, 140) }
		local b, sz = c.BodyCenter, c.BodySize
		for i = 1, 8 do
			local angle = i * 2.4
			local p = b + V(math.cos(angle) * sz.X * 0.28, sz.Y * 0.47, math.sin(angle) * sz.Z * 0.3)
			c:add("Block", V(0.08, 0.06, 0.25), p, V(0, i * 47, 0), colors[(i % #colors) + 1], { Role = "Detail" })
		end
	end
	if set.Aurora then
		local b, sz = c.BodyCenter, c.BodySize
		for i, dz in ipairs({ 0.05, 0.25, 0.45 }) do
			local band = c:add("Ellipsoid", V(sz.X * 0.8, 0.3, 0.32), b + V(0, sz.Y * 0.38 - dz * 0.4, dz * sz.Z), V(-20, 0, 0), "Accent", { Role = "Detail", Material = "Neon", KeepColor = true })
			band:SetAttribute("AuroraPhase", i * 0.25)
			table.insert(c.Rainbow, band)
		end
	end
	if set.Crown then
		local top = c.HeadTop
		c:add("Cylinder", V(0.32, 0.85, 0.85), top + V(0, 0.16, 0), V(0, 0, 90), GOLD, { Material = "Foil", Role = "Detail", KeepColor = true })
		for i = 0, 4 do
			local angle = i * (math.pi * 2 / 5)
			c:add("Ellipsoid", V(0.14, 0.32, 0.14), top + V(math.cos(angle) * 0.36, 0.42, math.sin(angle) * 0.36), nil, GOLD, { Material = "Foil", Role = "Detail", KeepColor = true })
		end
		c:add("Ball", V(0.17, 0, 0), top + V(0, 0.2, -0.43), nil, Color3.fromRGB(255, 50, 90), { Material = "Neon", Role = "Detail", KeepColor = true })
	end
	if set.Halo then
		local center = c.HeadTop + V(0, 0.3, 0)
		for i = 0, 11 do
			local angle = i * (math.pi * 2 / 12)
			c:add("Ball", V(0.13, 0, 0), center + V(math.cos(angle) * 0.45, 0, math.sin(angle) * 0.45), nil, Color3.fromRGB(255, 235, 140), { Material = "Neon", Role = "Detail", KeepColor = true })
		end
	end
	if set.Helmet then
		c:add("Ball", V(c.HeadSize * 1.45, 0, 0), c.HeadCenter + V(0, 0.08, 0), nil, Color3.fromRGB(190, 230, 255), { Material = "Glass", Transparency = 0.7, Role = "Detail", KeepColor = true })
	end
	if set.Antenna then
		local top = c.HeadTop
		c:segment("Cylinder", top, top + V(0.05, 0.7, 0.1), 0.07, DARK, { Role = "Detail", KeepColor = true })
		c:add("Ball", V(0.24, 0, 0), top + V(0.05, 0.78, 0.1), nil, "Accent", { Material = "Neon", Role = "Detail" })
	end
	if set.AngelWings then
		local b, sz = c.BodyCenter, c.BodySize
		local r, l = c:pair("Ellipsoid", V(0.12, 1.0, 1.15), b + V(0.75, sz.Y * 0.45 + 0.3, 0.25), V(0, 0, -58), WHITE, { Role = "Detail", KeepColor = true })
		c:flap(r, b + V(0.4, sz.Y * 0.45, 0.25), 1, 22, 4)
		c:flap(l, b + V(-0.4, sz.Y * 0.45, 0.25), -1, 22, 4)
	end
	if set.Lollipop then
		local b = c.BodyCenter
		c:segment("Cylinder", b + V(0.55, 0.35, 0.45), b + V(0.75, 1.4, 0.6), 0.09, WHITE, { Role = "Detail", KeepColor = true })
		c:add("Cylinder", V(0.14, 0.8, 0.8), b + V(0.8, 1.7, 0.62), V(0, 90, 0), "Accent", { Role = "Detail" })
		c:add("Cylinder", V(0.16, 0.45, 0.45), b + V(0.8, 1.7, 0.6), V(0, 90, 0), WHITE, { Role = "Detail", KeepColor = true })
	end
end

local function addEffects(c, def, extras: { string })
	local body = c.BodyPart
	if not body then
		return
	end
	local set = {}
	for _, name in ipairs(extras) do
		set[name] = true
	end
	local rarity = Config.Rarities[def.Rarity]
	local order = rarity and rarity.Order or 1

	if set.Glow then
		local light = Instance.new("PointLight")
		light.Color = c:color("Secondary")
		light.Range = 7 * c.S
		light.Brightness = 0.9
		light.Shadows = false
		light.Parent = body
	end
	if set.Fire and c.TailPart then
		local fire = Instance.new("Fire")
		fire.Size = 2.2 * c.S
		fire.Heat = 4
		fire.Color = c:color("Secondary")
		fire.SecondaryColor = c:color("Primary")
		fire.Parent = c.TailPart
	end

	local sparkle: Color3? = nil
	if c.Tier == 1 then
		sparkle = GOLD
	elseif c.Tier >= 2 then
		sparkle = Color3.fromRGB(255, 255, 255)
	elseif order >= Config.Rarities.Legendary.Order and rarity then
		sparkle = rarity.Color
	end
	if sparkle then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(sparkle)
		emitter.LightEmission = 1
		emitter.Rate = if order >= Config.Rarities.Mythic.Order or c.Tier >= 2 then 10 else 5
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32 * c.S), NumberSequenceKeypoint.new(1, 0) })
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = body
	end
	if order >= Config.Rarities.Mythic.Order and rarity then
		local aura = Instance.new("ParticleEmitter")
		aura.Color = ColorSequence.new(rarity.Color, c:color("Secondary"))
		aura.LightEmission = 0.8
		aura.Rate = 4
		aura.Lifetime = NumberRange.new(1.2, 1.8)
		aura.Speed = NumberRange.new(0.1, 0.4)
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * c.S), NumberSequenceKeypoint.new(1, 0.2) })
		aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		aura.Parent = body
		local light = body:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 9 * c.S
		light.Brightness = 1.2
		light.Parent = body
	end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

local customModels: Instance? = nil

local function prepareCustom(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
end

local function weld(built: Built)
	local root = built.Root
	local flapping: { [BasePart]: Flapper } = {}
	for _, flapper in ipairs(built.Flappers) do
		flapping[flapper.Part] = flapper
	end
	for _, part in ipairs(built.Model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= root then
			local flapper = flapping[part]
			if flapper then
				-- Part = Root * C0 * C1^-1 ; animate by rotating C0 at the hinge.
				local partRel = root.CFrame:ToObjectSpace(part.CFrame)
				local motor = Instance.new("Motor6D")
				motor.Part0 = root
				motor.Part1 = part
				motor.C0 = flapper.Hinge
				motor.C1 = partRel:Inverse() * flapper.Hinge
				motor.Parent = part
				flapper.Joint = motor
			else
				local constraint = Instance.new("WeldConstraint")
				constraint.Part0 = root
				constraint.Part1 = part
				constraint.Parent = part
			end
			part.Anchored = false
		end
	end
end

-- opts: Effects (particles/lights/fire), Weld (for moving pets), Scale
function PetBuilder.Build(petName: string, tier: number?, opts: { [string]: any }?): Built
	local o = opts or {}
	local tierValue = tier or 0
	local def = Config.Pets[petName]
	local style = PetStyles.Pets[petName]
	local rarityScale = def and RARITY_SCALE[def.Rarity] or 1
	local scale = (o.Scale or 1) * rarityScale

	local model = Instance.new("Model")
	model.Name = petName

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local built: Built = { Model = model, Root = root, Height = 3 * scale, Flappers = {}, RainbowParts = {} }

	if not customModels then
		customModels = ReplicatedStorage:FindFirstChild("PetModels")
	end
	local custom = customModels and customModels:FindFirstChild(petName)
	if custom and custom:IsA("Model") then
		local clone = custom:Clone()
		prepareCustom(clone)
		-- Move the model so its bounding box sits on the ground at the origin.
		local cf, size = clone:GetBoundingBox()
		local target = CFrame.new(0, size.Y / 2, 0) * cf.Rotation
		clone:PivotTo(target * cf:Inverse() * clone:GetPivot())
		for _, child in ipairs(clone:GetChildren()) do
			child.Parent = model
		end
		clone:Destroy()
		built.Height = size.Y
		if o.Weld then
			weld(built)
		end
		return built
	end

	local fallbackColor = def and def.Color or Color3.fromRGB(200, 200, 200)
	local resolvedStyle = style or { Archetype = "Dog", Primary = fallbackColor, Secondary = fallbackColor:Lerp(WHITE, 0.5), Accent = fallbackColor:Lerp(DARK, 0.4) }
	local c = newCtx(model, root, scale, resolvedStyle, tierValue)
	local archetype = Archetypes[resolvedStyle.Archetype] or Archetypes.Dog
	archetype(c)
	local extras = resolvedStyle.Extras or {}
	addExtras(c, extras)
	if o.Effects then
		addEffects(c, def or { Rarity = "Common" }, extras)
	end

	built.Flappers = c.Flappers
	built.RainbowParts = c.Rainbow
	local _, size = model:GetBoundingBox()
	built.Height = size.Y
	if tierValue >= 2 then
		model:SetAttribute("Rainbow", true)
	end
	if o.Weld then
		weld(built)
	end
	return built
end

-- Animates flapping wings and rainbow colours. Call every frame (or less).
function PetBuilder.Animate(built: Built, t: number, phase: number)
	for _, flapper in ipairs(built.Flappers) do
		if flapper.Joint then
			local angle = math.sin(t * flapper.Speed + phase) * flapper.Amount * flapper.Side
			flapper.Joint.C0 = flapper.Hinge * CFrame.Angles(0, 0, angle)
		end
	end
	for index, part in ipairs(built.RainbowParts) do
		local aurora = part:GetAttribute("AuroraPhase")
		if typeof(aurora) == "number" then
			local hue = 0.38 + math.sin(t * 0.8 + aurora * 6) * 0.17
			part.Color = Color3.fromHSV(hue, 0.7, 1)
		else
			part.Color = Color3.fromHSV((t * 0.25 + index * 0.13) % 1, 0.6, 1)
		end
	end
end

--------------------------------------------------------------------------------
-- 3D previews for UI
--------------------------------------------------------------------------------

-- Frames a camera so the whole model is visible from the front-left.
function PetBuilder.FrameCamera(viewport: ViewportFrame, model: Model, zoom: number?)
	local camera = viewport.CurrentCamera
	if not camera then
		local newCamera = Instance.new("Camera")
		newCamera.Parent = viewport
		viewport.CurrentCamera = newCamera
		camera = newCamera
	end
	local cam = camera :: Camera
	cam.FieldOfView = 30
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(cam.FieldOfView / 2)) * (zoom or 1.05)
	local direction = V(-0.55, 0.35, -1).Unit
	cam.CFrame = CFrame.lookAt(cf.Position + direction * distance, cf.Position)
end

-- props: any ViewportFrame properties, plus Silhouette = true for "???" pets.
function PetBuilder.CreateViewport(petName: string, tier: number?, props: { [string]: any }?): (ViewportFrame, Model)
	local p = props or {}
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(170, 170, 185)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = V(-0.6, -1, -0.7)
	for key, value in pairs(p) do
		if key ~= "Silhouette" and key ~= "Zoom" and key ~= "Parent" then
			(viewport :: any)[key] = value
		end
	end
	local built = PetBuilder.Build(petName, tier, { Effects = false, Weld = false })
	built.Model.Parent = viewport
	PetBuilder.FrameCamera(viewport, built.Model, p.Zoom)
	if p.Silhouette then
		viewport.ImageColor3 = Color3.new(0, 0, 0)
		viewport.Ambient = Color3.new(0, 0, 0)
		viewport.LightColor = Color3.new(0, 0, 0)
	end
	if p.Parent then
		viewport.Parent = p.Parent
	end
	return viewport, built.Model
end

-- Display name including tier, e.g. "Golden Dog".
function PetBuilder.DisplayName(petName: string, tier: number?): string
	local prefix = PetBuilder.TierNames[tier or 0] or ""
	if prefix == "" then
		return petName
	end
	return prefix .. " " .. petName
end

return PetBuilder
