--------------------------------------------------------------------------------
-- IndexUI - the pet collection book. Undiscovered pets show as "???", which
-- gives players a clear completion goal for every egg.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local PetBuilder = require(Modules.PetBuilder)
local UIController = require(script.Parent.UIController)

local IndexUI = {}

local CELL_W, CELL_H, PAD, COLUMNS = 96, 120, 8, 6

local window
local list: ScrollingFrame
local progressLabel: TextLabel

type Cell = { Frame: Frame, Stroke: UIStroke, View: ViewportFrame, Name: TextLabel, Discovered: boolean? }
type Group = { Title: string, Color: Color3, Pets: { string }, Header: TextLabel? }

local groups: { Group } = {}
local cells: { [string]: Cell } = {}
local built = false

-- Groups: one per egg (in zone order), then pets that come from no egg.
local function buildGroups(): { Group }
	local result: { Group } = {}
	local seen = {}
	for _, entry in ipairs(Config.GetEggsSortedByZone()) do
		local names = {}
		for _, item in ipairs(entry.Egg.Pets) do
			table.insert(names, item.Pet)
			seen[item.Pet] = true
		end
		table.insert(result, { Title = entry.Egg.Name, Color = entry.Egg.Color, Pets = names })
	end
	local exclusive = {}
	for name in pairs(Config.Pets) do
		if not seen[name] then
			table.insert(exclusive, name)
		end
	end
	table.sort(exclusive)
	if #exclusive > 0 then
		table.insert(result, { Title = "Exclusive Rewards", Color = UIKit.Colors.Accent, Pets = exclusive })
	end
	return result
end

local function createCell(parent: Instance, petName: string, order: number): Cell
	local def = Config.Pets[petName]
	local rarityColor = Config.Rarities[def.Rarity].Color
	local frame = UIKit.Frame({
		BackgroundColor3 = UIKit.Colors.Panel,
		LayoutOrder = order,
		Parent = parent,
	})
	UIKit.Corner(frame, 10)
	local stroke = UIKit.Stroke(frame, rarityColor, 1.5)

	local backdrop = UIKit.Frame({ Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = rarityColor, Parent = frame })
	UIKit.Corner(backdrop, 8)
	UIKit.Gradient(backdrop, rarityColor:Lerp(Color3.new(0, 0, 0), 0.5), rarityColor:Lerp(Color3.new(0, 0, 0), 0.82), 90)
	local view = PetBuilder.CreateViewport(petName, 0, { Size = UDim2.fromScale(1, 1), Parent = backdrop })

	local nameLabel = UIKit.Label({
		Position = UDim2.fromOffset(4, 72),
		Size = UDim2.new(1, -8, 0, 26),
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	UIKit.Label({
		Position = UDim2.fromOffset(4, 98),
		Size = UDim2.new(1, -8, 0, 16),
		Text = def.Rarity,
		TextSize = 12,
		TextColor3 = rarityColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	return { Frame = frame, Stroke = stroke, View = view, Name = nameLabel }
end

local function setDiscovered(petName: string, cellData: Cell, discovered: boolean)
	if cellData.Discovered == discovered then
		return
	end
	cellData.Discovered = discovered
	cellData.Frame.BackgroundColor3 = if discovered then UIKit.Colors.Panel else UIKit.Colors.PanelDark
	cellData.Stroke.Transparency = if discovered then 0 else 0.6
	cellData.Name.Text = if discovered then Config.Pets[petName].Name else "???"
	cellData.Name.TextColor3 = if discovered then UIKit.Colors.Text else UIKit.Colors.Muted
	PetBuilder.SetSilhouette(cellData.View, not discovered)
end

-- The book (with its 3D previews) is built once; later refreshes only flip
-- discovered state and counters.
local function buildBook()
	built = true
	groups = buildGroups()
	local order = 0
	for _, group in ipairs(groups) do
		order += 1
		group.Header = UIKit.Label({
			Size = UDim2.new(1, 0, 0, 28),
			Font = UIKit.Fonts.Title,
			TextSize = 20,
			TextColor3 = group.Color,
			LayoutOrder = order,
			Parent = list,
		})
		order += 1
		local rows = math.ceil(#group.Pets / COLUMNS)
		local grid = UIKit.Frame({
			Size = UDim2.new(1, 0, 0, rows * (CELL_H + PAD)),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = list,
		})
		UIKit.Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CELL_W, CELL_H),
			CellPadding = UDim2.fromOffset(PAD, PAD),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = grid,
		})
		for index, name in ipairs(group.Pets) do
			if not cells[name] then
				cells[name] = createCell(grid, name, index)
			end
		end
	end
end

local function rebuild()
	if not window or not window.IsOpen() then
		return
	end
	if not built then
		buildBook()
	end
	local discovered = State.Get("Discovered", {})
	local found, total = 0, 0
	for name in pairs(Config.Pets) do
		total += 1
		if discovered[name] then
			found += 1
		end
	end
	progressLabel.Text = string.format("Discovered <font color='#FFC400'>%d / %d</font> pets", found, total)

	for name, cellData in pairs(cells) do
		setDiscovered(name, cellData, discovered[name] == true)
	end
	for _, group in ipairs(groups) do
		local groupFound = 0
		for _, name in ipairs(group.Pets) do
			if discovered[name] then
				groupFound += 1
			end
		end
		if group.Header then
			local done = groupFound == #group.Pets
			group.Header.Text = string.format("%s  <font color='%s'>%d/%d%s</font>", group.Title, if done then "#50DC78" else "#A5AAC8", groupFound, #group.Pets, if done then "  COMPLETE!" else "")
		end
	end
end

function IndexUI.Init()
	window = UIController.CreateWindow("Index", "PET INDEX", UDim2.fromOffset(680, 500), UIKit.Colors.Info)
	progressLabel = UIKit.Label({
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 18,
		Parent = window.Content,
	})
	local holder = UIKit.Frame({
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundColor3 = UIKit.Colors.PanelDark,
		Parent = window.Content,
	})
	UIKit.Corner(holder, 12)
	UIKit.Padding(holder, 10)
	list = UIKit.ScrollList(holder, nil, 4)
	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end

	window.OnOpen = rebuild
	State.Changed:Connect(function(patch)
		if patch.Discovered ~= nil then
			rebuild()
		end
	end)

	UIController.AddSideButton("Index", "INDEX", UIKit.Colors.Info:Lerp(UIKit.Colors.Purple, 0.5), 6, function()
		UIController.Toggle("Index")
	end)
end

return IndexUI
