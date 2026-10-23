--------------------------------------------------------------------------------
-- CourseDecor - themed scenery around each world, built from parts.
-- CourseDecor.Fill(theme, parent, minX, maxX, groundY, rng)
-- Props stand on the ground far below the course (so the obby feels high up)
-- and a few float near the path (clouds, planets).
--------------------------------------------------------------------------------

local CourseDecor = {}

local V = Vector3.new
local rgb = Color3.fromRGB

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p: BasePart
	if props.Wedge then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
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

local function pillar(parent: Instance, base: Vector3, height: number, radius: number, color: Color3)
	return part({ Shape = Enum.PartType.Cylinder, Size = V(height, radius * 2, radius * 2), CFrame = CFrame.new(base + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color }, parent)
end

local function ball(parent: Instance, center: Vector3, size: number, color: Color3, material: Enum.Material?)
	return part({ Shape = Enum.PartType.Ball, Size = V(size, size, size), Position = center, Color = color, Material = material or Enum.Material.SmoothPlastic }, parent)
end

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

--------------------------------------------------------------------------------
-- Props per theme (position = ground point)
--------------------------------------------------------------------------------

local GREENS = { rgb(80, 175, 60), rgb(110, 200, 75), rgb(60, 150, 55) }
local FLOWERS = { rgb(255, 120, 170), rgb(255, 225, 80), rgb(185, 130, 255), rgb(255, 255, 255) }

local function tree(parent, pos, rng)
	local h = rng:NextNumber(9, 14)
	pillar(parent, pos, h, rng:NextNumber(0.9, 1.3), rgb(125, 85, 55))
	local green = pick(GREENS, rng)
	local crown = rng:NextNumber(9, 13)
	ball(parent, pos + V(0, h + 1, 0), crown, green)
	ball(parent, pos + V(-1, h + 1 + crown * 0.28, -1), crown * 0.62, green:Lerp(rgb(235, 255, 160), 0.35))
end

local function flowers(parent, pos, rng)
	for _ = 1, rng:NextInteger(5, 9) do
		local p = pos + V(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
		pillar(parent, p, 1.4, 0.1, rgb(70, 150, 50))
		ball(parent, p + V(0, 1.6, 0), rng:NextNumber(0.7, 1), pick(FLOWERS, rng))
	end
end

local function palm(parent, pos, rng)
	local h = rng:NextNumber(12, 18)
	local lean = rng:NextNumber(-0.15, 0.15)
	for i = 0, 5 do
		local y = i * (h / 6)
		pillar(parent, pos + V(lean * y, y, 0), h / 6 + 0.1, 0.8 - i * 0.05, rgb(160, 120, 70))
	end
	local top = pos + V(lean * h, h, 0)
	for i = 1, 6 do
		local angle = i * (math.pi * 2 / 6)
		part({ Size = V(1.2, 0.3, 7), CFrame = CFrame.new(top + V(math.cos(angle) * 3.2, 0.5, math.sin(angle) * 3.2)) * CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.Angles(math.rad(-25), 0, 0), Color = rgb(70, 170, 70) }, parent)
	end
	ball(parent, top + V(0.6, -0.8, 0.4), 1.1, rgb(140, 95, 50))
end

local function umbrella(parent, pos, rng)
	pillar(parent, pos, 7, 0.15, rgb(240, 240, 240))
	local color = pick({ rgb(255, 90, 90), rgb(90, 160, 255), rgb(255, 210, 60) }, rng)
	part({ Sphere = true, Size = V(8, 2.6, 8), Position = pos + V(0, 7, 0), Color = color }, parent)
	part({ Size = V(4, 0.5, 2.5), Position = pos + V(3, 0.3, 2), Color = rgb(255, 255, 255) }, parent)
end

local function jungleTree(parent, pos, rng)
	local h = rng:NextNumber(18, 28)
	pillar(parent, pos, h, rng:NextNumber(1.2, 1.8), rgb(95, 65, 45))
	for i = 1, 3 do
		local angle = i * 2.1
		ball(parent, pos + V(math.cos(angle) * 4, h - i * 2, math.sin(angle) * 4), rng:NextNumber(9, 13), rgb(40, 130, 60))
	end
	ball(parent, pos + V(0, h + 3, 0), 12, rgb(60, 160, 70))
	-- hanging vine
	part({ Size = V(0.3, h * 0.5, 0.3), Position = pos + V(5, h * 0.6, 2), Color = rgb(90, 170, 80) }, parent)
end

local function bamboo(parent, pos, rng)
	for _ = 1, rng:NextInteger(3, 6) do
		local p = pos + V(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		local h = rng:NextNumber(10, 16)
		for i = 0, math.floor(h / 3) do
			pillar(parent, p + V(0, i * 3, 0), 2.8, 0.35, rgb(150, 200, 90))
		end
	end
end

local function building(parent, pos, rng)
	local w = rng:NextNumber(10, 18)
	local d = rng:NextNumber(10, 18)
	local h = rng:NextNumber(20, 55)
	local color = pick({ rgb(120, 90, 75), rgb(230, 210, 190), rgb(90, 80, 95), rgb(190, 150, 120) }, rng)
	part({ Size = V(w, h, d), Position = pos + V(0, h / 2, 0), Color = color, CastShadow = true }, parent)
	-- neon windows
	local neon = pick({ rgb(255, 230, 120), rgb(120, 220, 255), rgb(255, 120, 200) }, rng)
	for y = 4, h - 4, 5 do
		for x = -w / 2 + 2.5, w / 2 - 2.5, 4 do
			if rng:NextNumber() < 0.6 then
				part({ Size = V(1.8, 2.4, 0.2), Position = pos + V(x, y, -d / 2 - 0.1), Color = neon, Material = Enum.Material.Neon }, parent)
			end
		end
	end
	-- rooftop sign
	if rng:NextNumber() < 0.4 then
		part({ Size = V(w * 0.6, 3, 0.5), Position = pos + V(0, h + 2, 0), Color = neon, Material = Enum.Material.Neon }, parent)
	end
end

local function streetLamp(parent, pos, _rng)
	pillar(parent, pos, 10, 0.3, rgb(60, 60, 70))
	local lamp = ball(parent, pos + V(0, 10.6, 0), 1.6, rgb(255, 230, 160), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 220, 160)
	light.Range = 18
	light.Parent = lamp
end

local function cloud(parent, pos, rng)
	local width = rng:NextNumber(18, 36)
	for j = 1, rng:NextInteger(4, 6) do
		local t = (j - 1) / 5 - 0.5
		local size = rng:NextNumber(9, 15) * (1 - math.abs(t) * 0.7)
		ball(parent, pos + V(t * width, rng:NextNumber(-1, 2), rng:NextNumber(-4, 4)), size, rgb(255, 255, 255))
	end
end

local function skyIsland(parent, pos, rng)
	local size = rng:NextNumber(14, 26)
	part({ Sphere = true, Size = V(size, size * 0.6, size), Position = pos, Color = rgb(120, 90, 70) }, parent)
	part({ Sphere = true, Size = V(size * 1.05, size * 0.2, size * 1.05), Position = pos + V(0, size * 0.2, 0), Color = rgb(110, 200, 90) }, parent)
	if rng:NextNumber() < 0.6 then
		tree(parent, pos + V(0, size * 0.28, 0), rng)
	end
end

local function asteroid(parent, pos, rng)
	local size = rng:NextNumber(5, 14)
	part({ Size = V(size, size * rng:NextNumber(0.6, 1.1), size * rng:NextNumber(0.6, 1.1)), CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), Color = rgb(85, 70, 120) }, parent)
	if rng:NextNumber() < 0.5 then
		part({ Size = V(1.2, 2.4, 1.2), CFrame = CFrame.new(pos + V(0, size * 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = rgb(150, 255, 230), Material = Enum.Material.Neon }, parent)
	end
end

local function planet(parent, pos, rng)
	local size = rng:NextNumber(30, 60)
	local color = pick({ rgb(255, 150, 90), rgb(120, 180, 255), rgb(200, 120, 255), rgb(120, 255, 180) }, rng)
	local body = ball(parent, pos, size, color)
	if rng:NextNumber() < 0.6 then
		part({ Shape = Enum.PartType.Cylinder, Size = V(0.8, size * 1.9, size * 1.9), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.5), Transparency = 0.3 }, parent)
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 2
	light.Brightness = 0.6
	light.Parent = body
end

--------------------------------------------------------------------------------

local THEMES = {
	Meadow = { Ground = { tree, tree, flowers, flowers }, Density = 1 / 22 },
	Beach = { Ground = { palm, palm, umbrella }, Density = 1 / 26 },
	Jungle = { Ground = { jungleTree, jungleTree, bamboo }, Density = 1 / 20 },
	City = { Ground = { building, building, streetLamp }, Density = 1 / 24 },
	Sky = { Float = { cloud, cloud, skyIsland }, Density = 1 / 18 },
	Void = { Float = { asteroid, asteroid, asteroid, planet }, Density = 1 / 20 },
}

function CourseDecor.Fill(themeName: string, parent: Instance, minX: number, maxX: number, groundY: number, rng: Random)
	local theme = THEMES[themeName] or THEMES.Meadow
	local folder = Instance.new("Folder")
	folder.Name = themeName
	folder.Parent = parent
	local count = math.floor((maxX - minX) * theme.Density) * 2
	for _ = 1, count do
		local x = rng:NextNumber(minX, maxX)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		if theme.Ground then
			-- out past the course corridor, on the ground below
			local z = side * rng:NextNumber(70, 220)
			pick(theme.Ground, rng)(folder, V(x, groundY, z), rng)
		else
			-- floating around path height
			local z = side * rng:NextNumber(65, 200)
			local y = groundY + 45 + rng:NextNumber(-30, 40) + (x - minX) * 0.02
			pick(theme.Float, rng)(folder, V(x, y, z), rng)
		end
	end
	-- a few props close to the path on the ground (visible when looking down)
	if theme.Ground then
		for _ = 1, math.floor(count / 3) do
			local x = rng:NextNumber(minX, maxX)
			local z = rng:NextNumber(-60, 60)
			pick(theme.Ground, rng)(folder, V(x, groundY, z), rng)
		end
	end
end

--------------------------------------------------------------------------------
-- Backdrops: the big things on the horizon that give each world its skyline.
--------------------------------------------------------------------------------

local function mountains(folder, minX, maxX, groundY, rng, colors)
	for x = minX, maxX, 90 do
		for _, side in ipairs({ -1, 1 }) do
			local w = rng:NextNumber(90, 160)
			local h = rng:NextNumber(60, 130)
			part({ Sphere = true, Size = V(w, h, w * 0.8), Position = V(x + rng:NextNumber(-30, 30), groundY + h * 0.2, side * rng:NextNumber(260, 340)), Color = pick(colors, rng) }, folder)
		end
	end
end

local function skyline(folder, minX, maxX, groundY, rng)
	for x = minX, maxX, 22 do
		for _, side in ipairs({ -1, 1 }) do
			local w = rng:NextNumber(14, 22)
			local h = rng:NextNumber(50, 120)
			local z = side * rng:NextNumber(240, 300)
			part({ Size = V(w, h, 18), Position = V(x, groundY + h / 2, z), Color = pick({ rgb(60, 50, 70), rgb(80, 60, 75), rgb(50, 45, 65) }, rng) }, folder)
			for y = 6, h - 6, 7 do
				if rng:NextNumber() < 0.5 then
					part({ Size = V(w * 0.7, 2.2, 0.3), Position = V(x, groundY + y, z - side * 9.2), Color = pick({ rgb(255, 225, 120), rgb(120, 210, 255), rgb(255, 120, 200) }, rng), Material = Enum.Material.Neon }, folder)
				end
			end
		end
	end
end

local function sun(folder, x, y, z, color)
	local body = ball(folder, V(x, y, z), 70, color, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 200
	light.Brightness = 0.4
	light.Parent = body
end

function CourseDecor.Backdrop(themeName: string, parent: Instance, minX: number, maxX: number, groundY: number, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = themeName .. "Backdrop"
	folder.Parent = parent
	if themeName == "Meadow" then
		mountains(folder, minX, maxX, groundY, rng, { rgb(90, 180, 80), rgb(70, 150, 75), rgb(110, 195, 90) })
	elseif themeName == "Beach" then
		mountains(folder, minX, maxX, groundY - 10, rng, { rgb(230, 200, 150), rgb(210, 180, 130) })
		sun(folder, (minX + maxX) / 2, groundY + 260, 480, rgb(255, 230, 150))
	elseif themeName == "Jungle" then
		mountains(folder, minX, maxX, groundY, rng, { rgb(40, 110, 60), rgb(55, 130, 70) })
		-- giant trees towering over the course
		for x = minX, maxX, 120 do
			for _, side in ipairs({ -1, 1 }) do
				local z = side * rng:NextNumber(150, 220)
				pillar(folder, V(x, groundY, z), 120, 6, rgb(90, 60, 45))
				ball(folder, V(x, groundY + 125, z), 70, rgb(45, 140, 65))
			end
		end
	elseif themeName == "City" then
		skyline(folder, minX, maxX, groundY, rng)
		sun(folder, (minX + maxX) / 2, groundY + 120, 520, rgb(255, 150, 90))
	elseif themeName == "Sky" then
		for x = minX, maxX, 70 do
			for _, side in ipairs({ -1, 1 }) do
				cloud(folder, V(x + rng:NextNumber(-20, 20), groundY + 60 + rng:NextNumber(-20, 50) + (x - minX) * 0.02, side * rng:NextNumber(230, 330)), rng)
			end
		end
		sun(folder, (minX + maxX) / 2, groundY + 330, -420, rgb(255, 245, 200))
	elseif themeName == "Void" then
		for _ = 1, 4 do
			planet(folder, V(rng:NextNumber(minX, maxX), groundY + rng:NextNumber(120, 260), (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(260, 420)), rng)
		end
		-- a nebula of big soft blobs
		for _ = 1, 10 do
			part({ Sphere = true, Size = V(1, 1, 1) * rng:NextNumber(60, 140), Position = V(rng:NextNumber(minX, maxX), groundY + rng:NextNumber(0, 300), (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(300, 480)), Color = pick({ rgb(120, 60, 200), rgb(60, 40, 160), rgb(200, 80, 220) }, rng), Transparency = 0.6 }, folder)
		end
	end
end

return CourseDecor
