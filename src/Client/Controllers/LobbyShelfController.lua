--------------------------------------------------------------------------------
-- LobbyShelfController - your own brainrots on display in the lobby, each on
-- a pedestal with a name card (like a base full of brainrots). Built on the
-- client, so it only shows your collection and costs the server nothing.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BrainrotBuilder = require(Shared.BrainrotBuilder)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)

local LobbyShelfController = {}

local MAX_SHOWN = 8
local INK = Color3.fromRGB(28, 22, 40)

local folder: Folder
local shown: { [string]: { Model: Model, Base: CFrame, Phase: number } } = {}
local slots: { CFrame } = {}

local function pedestal(cf: CFrame)
	local base = Instance.new("Part")
	base.Anchored = true
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(1, 5.5, 5.5)
	base.CFrame = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	base.Color = Color3.fromRGB(235, 235, 245)
	base.Material = Enum.Material.SmoothPlastic
	base.TopSurface = Enum.SurfaceType.Smooth
	base.Parent = folder
	local trim = base:Clone()
	trim.Size = Vector3.new(0.25, 5.9, 5.9)
	trim.CFrame = cf * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90))
	trim.Color = Color3.fromRGB(255, 205, 60)
	trim.Material = Enum.Material.Neon
	trim.CanCollide = false
	trim.CastShadow = false
	trim.Parent = folder
end

local function card(model: Model, name: string)
	local def = Config.Brainrots[name]
	if not def then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(6, 0, 1.6, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Adornee = model.PrimaryPart
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.6)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = name
	label.TextColor3 = Config.Rarities[def.Rarity].Color:Lerp(Color3.new(1, 1, 1), 0.3)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = INK
	label.Parent = gui
	local rarity = Instance.new("TextLabel")
	rarity.BackgroundTransparency = 1
	rarity.Position = UDim2.fromScale(0, 0.6)
	rarity.Size = UDim2.fromScale(1, 0.4)
	rarity.Font = Enum.Font.LuckiestGuy
	rarity.TextScaled = true
	rarity.Text = string.upper(def.Rarity)
	rarity.TextColor3 = Config.Rarities[def.Rarity].Color
	rarity.TextStrokeTransparency = 0
	rarity.TextStrokeColor3 = INK
	rarity.Parent = gui
	gui.Parent = model.PrimaryPart
	if model.PrimaryPart then
		gui.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
		gui.StudsOffset = Vector3.new(0, 0, 0)
		-- sit the card above the character's head
		local _, size = model:GetBoundingBox()
		gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y + 1, 0)
	end
end

local function rebuild()
	if not State.Loaded or #slots == 0 then
		return
	end
	local owned = State.Get("Owned", {})
	-- newest / rarest first: sort by Order descending
	local list = {}
	for name in pairs(owned) do
		if Config.Brainrots[name] then
			table.insert(list, name)
		end
	end
	table.sort(list, function(a, b)
		return (Config.Brainrots[a].Order or 0) > (Config.Brainrots[b].Order or 0)
	end)
	local wanted = {}
	for index = 1, math.min(#list, MAX_SHOWN) do
		wanted[list[index]] = index
	end
	for name, entry in pairs(shown) do
		if not wanted[name] then
			entry.Model:Destroy()
			shown[name] = nil
		end
	end
	for name, index in pairs(wanted) do
		local cf = slots[index]
		local entry = shown[name]
		if not entry then
			local ok, built = pcall(BrainrotBuilder.Build, name, { Effects = true, Weld = false, Scale = 1.5 })
			if ok and built then
				built.Model.Name = "Shelf_" .. name
				built.Model.Parent = folder
				card(built.Model, name)
				entry = { Model = built.Model, Base = cf * CFrame.new(0, 1, 0), Phase = index }
				shown[name] = entry
			end
		else
			entry.Base = cf * CFrame.new(0, 1, 0)
		end
	end
end

function LobbyShelfController.Init()
	folder = Instance.new("Folder")
	folder.Name = "MyBrainrotShelf"
	folder.Parent = Workspace
	-- pedestals along the back edge of the lobby, facing the path
	local x0 = -Config.Course.LobbyLength
	for index = 1, MAX_SHOWN do
		local cf = CFrame.new(x0 + 18 + (index - 1) * 11, 0, 38) * CFrame.Angles(0, math.rad(180), 0)
		slots[index] = cf
		pedestal(cf)
	end
	local sign = Instance.new("Part")
	sign.Anchored = true
	sign.Size = Vector3.new(26, 3, 0.5)
	sign.CFrame = CFrame.new(x0 + 56, 9, 43)
	sign.Color = INK
	sign.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(420, 70)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Adornee = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = "MY BRAINROTS"
	label.TextColor3 = Color3.fromRGB(255, 215, 60)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = INK
	label.Parent = gui
	gui.Parent = sign

	State.OnLoaded(rebuild)
	State.Changed:Connect(function(patch)
		if patch.Owned ~= nil then
			rebuild()
		end
	end)
	-- idle bob + slow turn
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, entry in pairs(shown) do
			entry.Model:PivotTo(entry.Base * CFrame.new(0, math.sin(t * 1.5 + entry.Phase) * 0.2, 0) * CFrame.Angles(0, math.sin(t * 0.5 + entry.Phase) * 0.5, 0))
		end
	end)
end

return LobbyShelfController
