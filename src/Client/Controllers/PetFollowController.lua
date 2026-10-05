--------------------------------------------------------------------------------
-- PetFollowController - renders every player's equipped pets following them.
-- Purely visual and client-side. Reads the "EquippedPets" player attribute
-- (JSON list of {n = name, t = tier}) that the server keeps updated.
--
-- Pets hop when their owner walks, flying pets hover and flap their wings,
-- and Rainbow pets cycle colours.
--------------------------------------------------------------------------------

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetStyles = require(Shared.PetStyles)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local PetBuilder = require(Modules.PetBuilder)

local PetFollowController = {}

local RENDER_DISTANCE = 160
local ANIMATE_DISTANCE = 70
local FOLLOW_SPEED = 9
local ROW_SIZE = 4
local SPACING = 4.2
local WORLD_SCALE = 0.75
local FLYING = { Owl = true, Phoenix = true, Dragon = true }

type PetVisual = {
	Built: PetBuilder.Built,
	Current: CFrame,
	Phase: number,
	Flying: boolean,
}
type Owner = { Pets: { PetVisual }, Connection: RBXScriptConnection? }

local owners: { [Player]: Owner } = {}
local petFolder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

--------------------------------------------------------------------------------
-- Owners
--------------------------------------------------------------------------------

local function isFlying(petName: string): boolean
	local style = PetStyles.Pets[petName]
	if not style then
		return false
	end
	if FLYING[style.Archetype] then
		return true
	end
	for _, extra in ipairs(style.Extras or {}) do
		if extra == "AngelWings" then
			return true
		end
	end
	return false
end

local function clearPets(owner: Owner)
	for _, pet in ipairs(owner.Pets) do
		pet.Built.Model:Destroy()
	end
	table.clear(owner.Pets)
end

local function decode(raw: any): { { Name: string, Tier: number } }
	local result = {}
	if type(raw) ~= "string" or raw == "" then
		return result
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(list) ~= "table" then
		return result
	end
	for _, entry in ipairs(list) do
		if type(entry) == "string" then
			table.insert(result, { Name = entry, Tier = 0 })
		elseif type(entry) == "table" and type(entry.n) == "string" then
			table.insert(result, { Name = entry.n, Tier = tonumber(entry.t) or 0 })
		end
	end
	return result
end

local function rebuild(player: Player)
	local owner = owners[player]
	if not owner then
		return
	end
	clearPets(owner)
	for _, entry in ipairs(decode(player:GetAttribute("EquippedPets"))) do
		local ok, built = pcall(PetBuilder.Build, entry.Name, entry.Tier, { Effects = true, Weld = true, Scale = WORLD_SCALE })
		if ok and built then
			table.insert(owner.Pets, {
				Built = built,
				Current = CFrame.new(),
				Phase = math.random() * math.pi * 2,
				Flying = isFlying(entry.Name),
			})
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

local function groundHeight(position: Vector3, fallback: number): number
	local result = Workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -14, 0), rayParams)
	if result then
		return result.Position.Y
	end
	return fallback
end

local function hide(pet: PetVisual)
	if pet.Built.Model.Parent then
		pet.Built.Model.Parent = nil
	end
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position or Vector3.zero
	local t = os.clock()
	local alpha = math.clamp(dt * FOLLOW_SPEED, 0, 1)

	-- Never let pets stand on pets or players.
	local ignore: { Instance } = { petFolder }
	for player in pairs(owners) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore

	for player, owner in pairs(owners) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			for _, pet in ipairs(owner.Pets) do
				hide(pet)
			end
		elseif #owner.Pets > 0 then
			local distanceToCamera = (root.Position - cameraPosition).Magnitude
			local far = distanceToCamera > RENDER_DISTANCE
			local animate = distanceToCamera < ANIMATE_DISTANCE
			local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
			local moving = velocity.Magnitude > 2
			local flat = CFrame.lookAlong(root.Position, root.CFrame.LookVector * Vector3.new(1, 0, 1) + Vector3.new(0, 0, 1e-4))
			local count = #owner.Pets
			for index, pet in ipairs(owner.Pets) do
				if far then
					hide(pet)
				else
					local offset = slotOffset(index, count)
					local spot = flat * Vector3.new(offset.X, 0, offset.Z)
					local ground = groundHeight(spot, root.Position.Y - 3)
					local lift
					if pet.Flying then
						lift = 2.2 + math.sin(t * 2.4 + pet.Phase) * 0.45
					elseif moving then
						lift = math.abs(math.sin(t * 9 + pet.Phase)) * 0.9 -- hop along
					else
						lift = math.abs(math.sin(t * 2 + pet.Phase)) * 0.15
					end
					local tilt = if moving and not pet.Flying then CFrame.Angles(math.rad(-8), 0, 0) else CFrame.identity
					local target = CFrame.new(spot.X, ground + lift, spot.Z) * flat.Rotation * tilt

					local model = pet.Built.Model
					if not model.Parent then
						-- Appearing (new, or back in range): start in the slot.
						pet.Current = target
						model.Parent = petFolder
					elseif (pet.Current.Position - target.Position).Magnitude > 60 then
						pet.Current = target -- owner teleported: snap
					else
						pet.Current = pet.Current:Lerp(target, alpha)
					end
					pet.Built.Root.CFrame = pet.Current
					if animate then
						PetBuilder.Animate(pet.Built, t, pet.Phase)
					end
				end
			end
		end
	end
end

function PetFollowController.Init()
	petFolder = Instance.new("Folder")
	petFolder.Name = "ClientPets"
	petFolder.Parent = Workspace

	for _, player in ipairs(Players:GetPlayers()) do
		addOwner(player)
	end
	Players.PlayerAdded:Connect(addOwner)
	Players.PlayerRemoving:Connect(removeOwner)

	RunService.RenderStepped:Connect(update)
end

return PetFollowController
