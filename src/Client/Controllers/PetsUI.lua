--------------------------------------------------------------------------------
-- PetsUI - inventory window: equip / unequip / delete / equip best.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)

local PetsUI = {}

local window
local grid: ScrollingFrame
local equippedLabel: TextLabel
local storageLabel: TextLabel
local deleteButton: TextButton
local deleteMode = false

local function sortPets(pets)
	local sorted = table.clone(pets)
	table.sort(sorted, function(a, b)
		if a.Equipped ~= b.Equipped then
			return a.Equipped
		end
		local defA = Config.Pets[a.Type]
		local defB = Config.Pets[b.Type]
		local rarityA = defA and Config.Rarities[defA.Rarity].Order or 0
		local rarityB = defB and Config.Rarities[defB.Rarity].Order or 0
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		local multA = defA and defA.Multiplier or 0
		local multB = defB and defB.Multiplier or 0
		if multA ~= multB then
			return multA > multB
		end
		return (a.Hatched or 0) > (b.Hatched or 0)
	end)
	return sorted
end

local function makeCard(petData, order: number)
	local def = Config.Pets[petData.Type]
	if not def then
		return
	end
	local rarity = Config.Rarities[def.Rarity]
	local rarityColor = rarity and rarity.Color or UIKit.Colors.Muted

	local card = UIKit.Create("TextButton", {
		Name = petData.Id,
		BackgroundColor3 = UIKit.Colors.Panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		Parent = grid,
	})
	UIKit.Corner(card, 12)
	UIKit.Stroke(card, petData.Equipped and UIKit.Colors.Success or rarityColor, petData.Equipped and 3 or 1.5)

	local swatch = UIKit.Frame({
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 64),
		BackgroundColor3 = rarityColor,
		Parent = card,
	})
	UIKit.Corner(swatch, 10)
	UIKit.RarityGradient(swatch, rarityColor)

	local body = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = def.Color,
		Parent = swatch,
	})
	UIKit.Corner(body, def.Shape == "Ball" and 18 or 8)
	UIKit.Stroke(body, Color3.new(0, 0, 0), 2, 0.6)

	UIKit.Label({
		Position = UDim2.fromOffset(6, 76),
		Size = UDim2.new(1, -12, 0, 20),
		Text = def.Name,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	UIKit.Label({
		Position = UDim2.fromOffset(6, 96),
		Size = UDim2.new(1, -12, 0, 18),
		Text = def.Rarity,
		TextSize = 13,
		TextColor3 = rarityColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	UIKit.Label({
		Position = UDim2.fromOffset(6, 114),
		Size = UDim2.new(1, -12, 0, 20),
		Text = string.format("x%.2f", def.Multiplier),
		TextSize = 16,
		Font = UIKit.Fonts.Black,
		TextColor3 = UIKit.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})

	if petData.Equipped then
		local tag = UIKit.Frame({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -8),
			Size = UDim2.fromOffset(80, 18),
			BackgroundColor3 = UIKit.Colors.Success,
			ZIndex = 3,
			Parent = card,
		})
		UIKit.Corner(tag, 9)
		UIKit.Label({
			Size = UDim2.fromScale(1, 1),
			Text = "EQUIPPED",
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 4,
			Parent = tag,
		})
	end

	card.Activated:Connect(function()
		if deleteMode then
			UIController.Confirm("Delete pet?", string.format("Delete your %s %s (x%.2f)? This cannot be undone.", def.Rarity, def.Name, def.Multiplier), function()
				Remotes.Get("DeletePet"):FireServer(petData.Id)
			end)
		elseif petData.Equipped then
			Remotes.Get("UnequipPet"):FireServer(petData.Id)
		else
			Remotes.Get("EquipPet"):FireServer(petData.Id)
		end
	end)
end

local function rebuild()
	if not window or not window.IsOpen() then
		return
	end
	UIKit.ClearChildren(grid)
	local pets = State.Get("Pets", {})
	local slots = State.Get("PetSlots", Config.BasePetSlots)
	local equipped = 0
	for _, petData in ipairs(pets) do
		if petData.Equipped then
			equipped += 1
		end
	end
	equippedLabel.Text = string.format("Equipped <font color='#50DC78'>%d / %d</font>", equipped, slots)
	storageLabel.Text = string.format("Storage %d / %d", #pets, Config.PetStorageLimit)

	for order, petData in ipairs(sortPets(pets)) do
		makeCard(petData, order)
	end

	if #pets == 0 then
		UIKit.Label({
			Size = UDim2.new(1, 0, 0, 60),
			Text = "No pets yet! Find an egg stand and press E to hatch.",
			TextSize = 18,
			TextColor3 = UIKit.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = grid,
		})
	end
end

function PetsUI.Init()
	window = UIController.CreateWindow("Pets", "PETS", UDim2.fromOffset(740, 480), UIKit.Colors.Success)
	local content = window.Content

	local topBar = UIKit.Frame({
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = content,
	})
	equippedLabel = UIKit.Label({
		Size = UDim2.fromOffset(200, 44),
		TextSize = 18,
		Parent = topBar,
	})
	storageLabel = UIKit.Label({
		Position = UDim2.fromOffset(200, 0),
		Size = UDim2.fromOffset(160, 44),
		TextSize = 15,
		TextColor3 = UIKit.Colors.Muted,
		Parent = topBar,
	})

	local buttons = UIKit.Frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(360, 44),
		BackgroundTransparency = 1,
		Parent = topBar,
	})
	UIKit.Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = buttons,
	})

	local best = UIKit.Button({ Size = UDim2.fromOffset(110, 36), Text = "EQUIP BEST", TextSize = 14, Color = UIKit.Colors.Success, LayoutOrder = 1 }, function()
		Remotes.Get("EquipBest"):FireServer()
	end)
	best.Parent = buttons
	local unequip = UIKit.Button({ Size = UDim2.fromOffset(110, 36), Text = "UNEQUIP ALL", TextSize = 14, Color = UIKit.Colors.Info, LayoutOrder = 2 }, function()
		Remotes.Get("UnequipAll"):FireServer()
	end)
	unequip.Parent = buttons
	deleteButton = UIKit.Button({ Size = UDim2.fromOffset(110, 36), Text = "DELETE: OFF", TextSize = 14, Color = UIKit.Colors.Danger, LayoutOrder = 3 }, function()
		deleteMode = not deleteMode
		deleteButton.Text = deleteMode and "DELETE: ON" or "DELETE: OFF"
		UIKit.SetButtonColor(deleteButton, deleteMode and UIKit.Colors.Pink or UIKit.Colors.Danger)
	end)
	deleteButton.Parent = buttons

	local gridHolder = UIKit.Frame({
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundColor3 = UIKit.Colors.PanelDark,
		Parent = content,
	})
	UIKit.Corner(gridHolder, 12)
	UIKit.Padding(gridHolder, 10)
	grid = UIKit.ScrollGrid(gridHolder, UDim2.fromOffset(124, 142), 10)

	window.OnOpen = function()
		deleteMode = false
		deleteButton.Text = "DELETE: OFF"
		UIKit.SetButtonColor(deleteButton, UIKit.Colors.Danger)
		rebuild()
	end

	State.Changed:Connect(function(patch)
		if patch.Pets ~= nil or patch.PetSlots ~= nil then
			rebuild()
		end
	end)

	UIController.AddSideButton("Pets", "PETS", UIKit.Colors.Success, 1, function()
		UIController.Toggle("Pets")
	end)
end

return PetsUI
