--------------------------------------------------------------------------------
-- PetFollowController - renders equipped pets following every player.
-- Purely visual and client-side (zero server cost). Reads the "EquippedPets"
-- player attribute (JSON list of pet names) that the server keeps updated.
--
-- To use real art: put a Model named exactly like the pet (e.g. "Dog") inside
-- ReplicatedStorage.PetModels. Otherwise a cute placeholder is generated.
--------------------------------------------------------------------------------

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local PetFollowController = {}

local RENDER_DISTANCE = 200
local FOLLOW_SPEED = 10
local ROW_SIZE = 4
local SPACING = 4.5

type PetVisual = { Model: Model, Current: CFrame, Phase: number, Height: number }
type Owner = { Pets: { PetVisual }, Connection: RBXScriptConnection? }

local owners: { [Player]: Owner } = {}
local petFolder: Folder
local modelsFolder: Instance? = nil

--------------------------------------------------------------------------------
-- Model creation
--------------------------------------------------------------------------------

local function prepareModel(model: Model)
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

local function makePart(props: { [string]: any }, parent: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function placeholderModel(def): Model
	local model = Instance.new("Model")
	model.Name = def.Name

	local isBall = def.Shape == "Ball"
	local body = makePart({
		Name = "Body",
		Shape = isBall and Enum.PartType.Ball or Enum.PartType.Block,
		Size = isBall and Vector3.new(2.2, 2.2, 2.2) or Vector3.new(2, 1.8, 2.3),
		Color = def.Color,
		Material = Enum.Material.SmoothPlastic,
	}, model)
	model.PrimaryPart = body

	local front = body.Size.Z / 2
	for _, x in ipairs({ -0.45, 0.45 }) do
		local eye = makePart({
			Name = "Eye",
			Size = Vector3.new(0.38, 0.45, 0.2),
			Color = Color3.new(0.05, 0.05, 0.05),
			Material = Enum.Material.SmoothPlastic,
			-- Ball pets are round, so pull the eyes in to sit on the curved surface.
			CFrame = body.CFrame * CFrame.new(x, 0.25, -front + (isBall and 0.25 or 0.02)),
		}, model)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = eye
	end

	-- little ears for block pets
	if not isBall then
		for _, x in ipairs({ -0.6, 0.6 }) do
			makePart({
				Name = "Ear",
				Size = Vector3.new(0.45, 0.6, 0.3),
				Color = def.Color:Lerp(Color3.new(0, 0, 0), 0.2),
				Material = Enum.Material.SmoothPlastic,
				CFrame = body.CFrame * CFrame.new(x, 1.15, -0.3),
			}, model)
		end
	end

	local rarity = Config.Rarities[def.Rarity]
	if rarity and rarity.Order >= Config.Rarities.Legendary.Order then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = body

		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(rarity.Color)
		particles.LightEmission = 1
		particles.Rate = 6
		particles.Lifetime = NumberRange.new(0.6, 1)
		particles.Speed = NumberRange.new(0.5, 1.5)
		particles.Size = NumberSequence.new(0.35, 0)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Parent = body
	end

	return model
end

local function createPet(petName: string): PetVisual?
	local def = Config.Pets[petName]
	if not def then
		return nil
	end
	local model: Model
	local custom = modelsFolder and modelsFolder:FindFirstChild(petName)
	if custom and custom:IsA("Model") then
		model = custom:Clone()
		prepareModel(model)
	else
		model = placeholderModel(def)
	end

	local rarity = Config.Rarities[def.Rarity]
	if rarity and rarity.Order >= Config.Rarities.Epic.Order then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(120, 24)
		gui.StudsOffset = Vector3.new(0, 2.2, 0)
		gui.MaxDistance = 45
		gui.LightInfluence = 0
		gui.Adornee = model.PrimaryPart
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.Text = def.Name
		label.TextColor3 = rarity.Color
		label.TextScaled = true
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
		gui.Parent = model
	end

	local _, size = model:GetBoundingBox()
	model.Parent = petFolder
	return { Model = model, Current = model:GetPivot(), Phase = math.random() * math.pi * 2, Height = size.Y }
end

--------------------------------------------------------------------------------
-- Owners
--------------------------------------------------------------------------------

local function clearPets(owner: Owner)
	for _, pet in ipairs(owner.Pets) do
		pet.Model:Destroy()
	end
	table.clear(owner.Pets)
end

local function rebuild(player: Player)
	local owner = owners[player]
	if not owner then
		return
	end
	clearPets(owner)

	local raw = player:GetAttribute("EquippedPets")
	if type(raw) ~= "string" or raw == "" then
		return
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(list) ~= "table" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, petName in ipairs(list) do
		if type(petName) == "string" then
			local pet = createPet(petName)
			if pet then
				if root then
					pet.Current = root.CFrame
				end
				table.insert(owner.Pets, pet)
			end
		end
	end
end

local function addOwner(player: Player)
	if owners[player] then
		return
	end
	local owner: Owner = { Pets = {}, Connection = nil }
	owners[player] = owner
	owner.Connection = player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

local function removeOwner(player: Player)
	local owner = owners[player]
	if not owner then
		return
	end
	if owner.Connection then
		owner.Connection:Disconnect()
	end
	clearPets(owner)
	owners[player] = nil
end

--------------------------------------------------------------------------------
-- Follow
--------------------------------------------------------------------------------

local function slotOffset(index: number, count: number): Vector3
	local row = (index - 1) // ROW_SIZE
	local column = (index - 1) % ROW_SIZE
	local inRow = math.min(ROW_SIZE, count - row * ROW_SIZE)
	local x = (column - (inRow - 1) / 2) * SPACING
	local z = 5 + row * SPACING
	return Vector3.new(x, 0, z)
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position or Vector3.zero
	local t = os.clock()
	local alpha = math.clamp(dt * FOLLOW_SPEED, 0, 1)

	for player, owner in pairs(owners) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and #owner.Pets > 0 then
			local far = (root.Position - cameraPosition).Magnitude > RENDER_DISTANCE
			local flat = CFrame.lookAlong(root.Position, root.CFrame.LookVector * Vector3.new(1, 0, 1) + Vector3.new(0, 0, 1e-4))
			local count = #owner.Pets
			for index, pet in ipairs(owner.Pets) do
				if far then
					if pet.Model.Parent then
						pet.Model.Parent = nil
					end
				else
					if not pet.Model.Parent then
						pet.Model.Parent = petFolder
					end
					local offset = slotOffset(index, count)
					local bob = math.sin(t * 3 + pet.Phase) * 0.35
					-- Hover just above the ground (root is ~3 studs above the floor).
					local target = flat * CFrame.new(offset.X, -3 + pet.Height / 2 + 0.6 + bob, offset.Z)
					local distance = (pet.Current.Position - target.Position).Magnitude
					if distance > 60 then
						pet.Current = target -- teleported: snap
					else
						pet.Current = pet.Current:Lerp(target, alpha)
					end
					pet.Model:PivotTo(pet.Current)
				end
			end
		end
	end
end

function PetFollowController.Init()
	petFolder = Instance.new("Folder")
	petFolder.Name = "ClientPets"
	petFolder.Parent = Workspace

	modelsFolder = ReplicatedStorage:FindFirstChild("PetModels")

	for _, player in ipairs(Players:GetPlayers()) do
		addOwner(player)
	end
	Players.PlayerAdded:Connect(addOwner)
	Players.PlayerRemoving:Connect(removeOwner)

	RunService.RenderStepped:Connect(update)
end

return PetFollowController
