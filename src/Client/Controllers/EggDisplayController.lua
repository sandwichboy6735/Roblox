--------------------------------------------------------------------------------
-- EggDisplayController - makes egg stands come alive: eggs float and turn, and
-- a board above each egg shows its pets in 3D with their exact odds (updated
-- live when luck boosts change them).
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local PetBuilder = require(Modules.PetBuilder)

local EggDisplayController = {}

local CELL = 62
local ANIMATE_DISTANCE = 120

type Piece = { Part: BasePart, Offset: CFrame }
type Stand = {
	EggKey: string,
	Egg: BasePart,
	EggBase: CFrame,
	Pieces: { Piece }, -- the rest of the egg (shell, pattern), moved with it
	Phase: number,
	Chances: { TextLabel },
}

local stands: { Stand } = {}

local function oddsFor(egg): { number }
	local luck = State.GetLuck()
	local weights = {}
	for index, entry in ipairs(egg.Pets) do
		local def = Config.Pets[entry.Pet]
		local weight = entry.Chance
		if def and Config.Rarities[def.Rarity] and Config.Rarities[def.Rarity].LuckAffected then
			weight *= luck
		end
		weights[index] = weight
	end
	return Util.ExactPercentages(weights, 2)
end

local function refreshOdds()
	for _, stand in ipairs(stands) do
		local egg = Config.Eggs[stand.EggKey]
		local odds = oddsFor(egg)
		for index, label in ipairs(stand.Chances) do
			label.Text = string.format("%.2f%%", odds[index] or 0)
		end
	end
end

local function buildBoard(stand: Stand)
	local egg = Config.Eggs[stand.EggKey]
	local count = #egg.Pets
	local gui = Instance.new("BillboardGui")
	gui.Name = "OddsBoard"
	gui.Size = UDim2.fromOffset(math.max(count * (CELL + 6) + 12, 240), CELL + 70)
	gui.StudsOffset = Vector3.new(0, 7.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Adornee = stand.Egg

	-- This board replaces the server's simple name/price label.
	local serverLabel = stand.Egg:FindFirstChild("Label")
	if serverLabel and serverLabel:IsA("BillboardGui") then
		serverLabel.Enabled = false
	end

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 34)
	header.Font = Enum.Font.FredokaOne
	header.RichText = true
	header.Text = string.format("%s  <font color='#FFE38A'>%s %s</font>", egg.Name, Util.FormatNumber(egg.Cost), if egg.Currency == "Gems" then "Gems" else "Coins")
	header.TextColor3 = egg.Color:Lerp(Color3.new(1, 1, 1), 0.35)
	header.TextStrokeTransparency = 0.2
	header.TextScaled = true
	header.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 36)
	back.Size = UDim2.new(1, 0, 1, -36)
	back.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	back.BackgroundTransparency = 0.25
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = egg.Color
	stroke.Thickness = 2
	stroke.Parent = back
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = back

	for index, entry in ipairs(egg.Pets) do
		local def = Config.Pets[entry.Pet]
		local rarityColor = Config.Rarities[def.Rarity].Color
		local cell = Instance.new("Frame")
		cell.Size = UDim2.fromOffset(CELL, CELL + 22)
		cell.BackgroundTransparency = 1
		cell.LayoutOrder = index
		cell.Parent = back

		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(CELL, CELL)
		frame.BackgroundColor3 = rarityColor:Lerp(Color3.new(0, 0, 0), 0.55)
		frame.BackgroundTransparency = 0.2
		frame.Parent = cell
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0, 10)
		fc.Parent = frame
		local fs = Instance.new("UIStroke")
		fs.Color = rarityColor
		fs.Thickness = 1.5
		fs.Parent = frame
		PetBuilder.CreateViewport(entry.Pet, 0, { Size = UDim2.fromScale(1, 1), Parent = frame })

		local chance = Instance.new("TextLabel")
		chance.BackgroundTransparency = 1
		chance.Position = UDim2.fromOffset(0, CELL + 2)
		chance.Size = UDim2.new(1, 0, 0, 18)
		chance.Font = Enum.Font.GothamBlack
		chance.TextColor3 = rarityColor
		chance.TextStrokeTransparency = 0.3
		chance.TextScaled = true
		chance.Text = ""
		chance.Parent = cell
		table.insert(stand.Chances, chance)
	end
	gui.Parent = stand.Egg
end

local function register(eggPart: Instance)
	if not eggPart:IsA("BasePart") or eggPart.Name ~= "Egg" then
		return
	end
	local eggKey = eggPart:GetAttribute("EggId")
	if type(eggKey) ~= "string" or not Config.Eggs[eggKey] then
		return
	end
	local stand: Stand = {
		EggKey = eggKey,
		Egg = eggPart,
		EggBase = eggPart.CFrame,
		Pieces = {},
		Phase = math.random() * math.pi * 2,
		Chances = {},
	}
	-- Every other part of the egg model follows the egg as it floats.
	local function collectPieces()
		local model = eggPart.Parent
		if not model then
			return
		end
		local pieces = {}
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") and child ~= eggPart then
				table.insert(pieces, { Part = child, Offset = stand.EggBase:ToObjectSpace(child.CFrame) })
			end
		end
		stand.Pieces = pieces
	end
	collectPieces()
	-- Parts can still be arriving from the server; pick up any stragglers.
	task.delay(2, function()
		local model = eggPart.Parent
		if model and #model:GetChildren() - 1 > #stand.Pieces then
			-- Late pieces haven't been moved yet, so they still sit at their
			-- original offset from the egg's base position.
			local known = {}
			for _, piece in ipairs(stand.Pieces) do
				known[piece.Part] = true
			end
			for _, child in ipairs(model:GetChildren()) do
				if child:IsA("BasePart") and child ~= eggPart and not known[child] then
					table.insert(stand.Pieces, { Part = child, Offset = stand.EggBase:ToObjectSpace(child.CFrame) })
				end
			end
		end
	end)
	table.insert(stands, stand)
	buildBoard(stand)
end

local function animate()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local t = os.clock()
	local parts, cframes = {}, {}
	for _, stand in ipairs(stands) do
		if (stand.EggBase.Position - cameraPosition).Magnitude < ANIMATE_DISTANCE then
			local offset = CFrame.new(0, math.sin(t * 1.6 + stand.Phase) * 0.35, 0) * CFrame.Angles(0, math.sin(t * 0.7 + stand.Phase) * 0.35, math.sin(t * 1.1 + stand.Phase) * 0.04)
			local eggCFrame = stand.EggBase * offset
			table.insert(parts, stand.Egg)
			table.insert(cframes, eggCFrame)
			for _, piece in ipairs(stand.Pieces) do
				table.insert(parts, piece.Part)
				table.insert(cframes, eggCFrame * piece.Offset)
			end
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function EggDisplayController.Init()
	task.spawn(function()
		local map = Workspace:WaitForChild("Map")
		for _, descendant in ipairs(map:GetDescendants()) do
			register(descendant)
		end
		map.DescendantAdded:Connect(register)
		refreshOdds()
	end)

	State.Changed:Connect(function(patch)
		if patch.Gamepasses ~= nil or patch.Boosts ~= nil then
			refreshOdds()
		end
	end)
	-- Luck boosts expire on their own; keep the boards honest.
	task.spawn(function()
		while true do
			task.wait(5)
			refreshOdds()
		end
	end)

	RunService.RenderStepped:Connect(animate)
end

return EggDisplayController
