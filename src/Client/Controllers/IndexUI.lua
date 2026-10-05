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
local UIController = require(script.Parent.UIController)

local IndexUI = {}

local CELL_W, CELL_H, PAD, COLUMNS = 96, 112, 8, 6

local window
local list: ScrollingFrame
local progressLabel: TextLabel

-- Groups: one per egg (in zone order), then pets that come from no egg.
local function buildGroups()
	local groups = {}
	local seen = {}
	for _, entry in ipairs(Config.GetEggsSortedByZone()) do
		local names = {}
		for _, item in ipairs(entry.Egg.Pets) do
			table.insert(names, item.Pet)
			seen[item.Pet] = true
		end
		table.insert(groups, { Title = entry.Egg.Name, Color = entry.Egg.Color, Pets = names })
	end
	local exclusive = {}
	for name in pairs(Config.Pets) do
		if not seen[name] then
			table.insert(exclusive, name)
		end
	end
	table.sort(exclusive)
	if #exclusive > 0 then
		table.insert(groups, { Title = "Exclusive Rewards", Color = UIKit.Colors.Accent, Pets = exclusive })
	end
	return groups
end

local function cell(parent: Instance, petName: string, order: number, discovered: boolean)
	local def = Config.Pets[petName]
	local rarityColor = Config.Rarities[def.Rarity].Color
	local frame = UIKit.Frame({
		BackgroundColor3 = discovered and UIKit.Colors.Panel or UIKit.Colors.PanelDark,
		LayoutOrder = order,
		Parent = parent,
	})
	UIKit.Corner(frame, 10)
	UIKit.Stroke(frame, rarityColor, 1.5, discovered and 0 or 0.6)

	local swatch = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = discovered and def.Color or Color3.fromRGB(15, 15, 22),
		Parent = frame,
	})
	UIKit.Corner(swatch, def.Shape == "Ball" and 22 or 9)

	UIKit.Label({
		Position = UDim2.fromOffset(4, 56),
		Size = UDim2.new(1, -8, 0, 32),
		Text = discovered and def.Name or "???",
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = discovered and UIKit.Colors.Text or UIKit.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	UIKit.Label({
		Position = UDim2.fromOffset(4, 88),
		Size = UDim2.new(1, -8, 0, 18),
		Text = def.Rarity,
		TextSize = 12,
		TextColor3 = rarityColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
end

local function rebuild()
	if not window or not window.IsOpen() then
		return
	end
	UIKit.ClearChildren(list)
	local discovered = State.Get("Discovered", {})
	local found, total = 0, 0
	for name in pairs(Config.Pets) do
		total += 1
		if discovered[name] then
			found += 1
		end
	end
	progressLabel.Text = string.format("Discovered <font color='#FFC400'>%d / %d</font> pets", found, total)

	local order = 0
	for _, group in ipairs(buildGroups()) do
		local groupFound = 0
		for _, name in ipairs(group.Pets) do
			if discovered[name] then
				groupFound += 1
			end
		end
		order += 1
		UIKit.Label({
			Size = UDim2.new(1, 0, 0, 28),
			Text = string.format("%s  <font color='#A5AAC8'>%d/%d</font>", group.Title, groupFound, #group.Pets),
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
			cell(grid, name, index, discovered[name] == true)
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
