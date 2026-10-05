--------------------------------------------------------------------------------
-- PetsUI - inventory with 3D pet cards and a detail panel to equip, craft
-- Golden/Rainbow versions, or delete.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local PetBuilder = require(Modules.PetBuilder)
local UIController = require(script.Parent.UIController)

local PetsUI = {}

local TIER_COLORS = { [1] = Color3.fromRGB(255, 205, 60), [2] = Color3.fromRGB(255, 120, 220) }

type Card = { Button: TextButton, Stroke: UIStroke, Tag: Frame, Key: string }

local window
local grid: ScrollingFrame
local equippedLabel: TextLabel
local storageLabel: TextLabel
local cards: { [string]: Card } = {}

-- detail panel
local detail: Frame
local detailViewport: ViewportFrame? = nil
local detailModel: Model? = nil
local detailName: TextLabel
local detailInfo: TextLabel
local equipButton: TextButton
local craftButton: TextButton
local deleteButton: TextButton
local selectedId: string? = nil

local function multiplierOf(petData): number
	return Config.GetPetMultiplier(petData.Type, petData.Tier)
end

local function findPet(id: string?)
	if not id then
		return nil
	end
	for _, petData in ipairs(State.Get("Pets", {})) do
		if petData.Id == id then
			return petData
		end
	end
	return nil
end

local function countSame(petData): number
	local count = 0
	for _, other in ipairs(State.Get("Pets", {})) do
		if other.Type == petData.Type and (other.Tier or 0) == (petData.Tier or 0) then
			count += 1
		end
	end
	return count
end

local function sortPets(pets)
	local sorted = table.clone(pets)
	table.sort(sorted, function(a, b)
		if a.Equipped ~= b.Equipped then
			return a.Equipped
		end
		local ma, mb = multiplierOf(a), multiplierOf(b)
		if ma ~= mb then
			return ma > mb
		end
		return (a.Hatched or 0) > (b.Hatched or 0)
	end)
	return sorted
end

--------------------------------------------------------------------------------
-- Detail panel
--------------------------------------------------------------------------------

local function refreshDetail()
	local petData = findPet(selectedId)
	detail.Visible = petData ~= nil
	if not petData then
		return
	end
	local def = Config.Pets[petData.Type]
	local tier = petData.Tier or 0
	local rarityColor = Config.Rarities[def.Rarity].Color

	local key = petData.Type .. "#" .. tier
	if not detailViewport or detailViewport:GetAttribute("Key") ~= key then
		if detailViewport then
			detailViewport:Destroy()
		end
		local viewport, model = PetBuilder.CreateViewport(petData.Type, tier, {
			Size = UDim2.new(1, 0, 0, 170),
			Zoom = 0.95,
			Parent = detail,
		})
		viewport:SetAttribute("Key", key)
		detailViewport = viewport
		detailModel = model
	end

	detailName.Text = PetBuilder.DisplayName(petData.Type, tier)
	detailName.TextColor3 = TIER_COLORS[tier] or rarityColor
	detailInfo.Text = string.format("<font color='#%s'>%s</font>\nx%.2f coins", rarityColor:ToHex(), string.upper(def.Rarity), multiplierOf(petData))

	equipButton.Text = if petData.Equipped then "UNEQUIP" else "EQUIP"
	UIKit.SetButtonColor(equipButton, if petData.Equipped then UIKit.Colors.Info else UIKit.Colors.Success)

	local recipe = Config.PetTiers[tier + 1]
	if recipe then
		local have = countSame(petData)
		craftButton.Visible = true
		craftButton.Text = string.format("MAKE %s %d/%d", string.upper(recipe.Name), have, recipe.Needed)
		UIKit.SetButtonColor(craftButton, TIER_COLORS[tier + 1])
		UIKit.SetButtonEnabled(craftButton, have >= recipe.Needed)
		if have < recipe.Needed then
			craftButton.Text = string.format("%s: %d/%d", string.upper(recipe.Name), have, recipe.Needed)
		end
	else
		craftButton.Visible = false
	end
end

local function buildDetail(parent: Instance)
	detail = UIKit.Frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 54),
		Size = UDim2.new(0, 220, 1, -54),
		BackgroundColor3 = UIKit.Colors.PanelDark,
		Visible = false,
		Parent = parent,
	})
	UIKit.Corner(detail, 12)
	UIKit.Padding(detail, 10)
	detailName = UIKit.Label({ Position = UDim2.fromOffset(0, 172), Size = UDim2.new(1, 0, 0, 26), Font = UIKit.Fonts.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Parent = detail })
	detailInfo = UIKit.Label({ Position = UDim2.fromOffset(0, 200), Size = UDim2.new(1, 0, 0, 40), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Parent = detail })

	local buttons = UIKit.Frame({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 132), BackgroundTransparency = 1, Parent = detail })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = buttons })
	equipButton = UIKit.Button({ Size = UDim2.new(1, 0, 0, 38), Color = UIKit.Colors.Success, TextSize = 16, LayoutOrder = 1 }, function()
		local petData = findPet(selectedId)
		if petData then
			Remotes.Get(if petData.Equipped then "UnequipPet" else "EquipPet"):FireServer(petData.Id)
		end
	end)
	equipButton.Parent = buttons
	craftButton = UIKit.Button({ Size = UDim2.new(1, 0, 0, 38), Color = TIER_COLORS[1], TextSize = 15, LayoutOrder = 2 }, function()
		local petData = findPet(selectedId)
		if petData then
			Remotes.Get("CraftPet"):FireServer(petData.Type, petData.Tier or 0)
		end
	end)
	craftButton.Parent = buttons
	deleteButton = UIKit.Button({ Size = UDim2.new(1, 0, 0, 34), Color = UIKit.Colors.Danger, Text = "DELETE", TextSize = 14, LayoutOrder = 3 }, function()
		local petData = findPet(selectedId)
		if not petData then
			return
		end
		UIController.Confirm("Delete pet?", string.format("Delete your %s (x%.2f)? This cannot be undone.", PetBuilder.DisplayName(petData.Type, petData.Tier), multiplierOf(petData)), function()
			Remotes.Get("DeletePet"):FireServer(petData.Id)
		end)
	end)
	deleteButton.Parent = buttons
end

--------------------------------------------------------------------------------
-- Cards
--------------------------------------------------------------------------------

local function createCard(petData): Card
	local def = Config.Pets[petData.Type]
	local tier = petData.Tier or 0
	local rarityColor = Config.Rarities[def.Rarity].Color
	local accent = TIER_COLORS[tier] or rarityColor

	local button = UIKit.Create("TextButton", {
		Name = petData.Id,
		BackgroundColor3 = UIKit.Colors.Panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = grid,
	}) :: TextButton
	UIKit.Corner(button, 12)
	local stroke = UIKit.Stroke(button, accent, 1.5)
	local backdrop = UIKit.Frame({ Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 76), BackgroundColor3 = accent:Lerp(Color3.new(0, 0, 0), 0.6), Parent = button })
	UIKit.Corner(backdrop, 10)
	UIKit.Gradient(backdrop, accent:Lerp(Color3.new(0, 0, 0), 0.4), accent:Lerp(Color3.new(0, 0, 0), 0.8), 90)
	PetBuilder.CreateViewport(petData.Type, tier, { Size = UDim2.fromScale(1, 1), Parent = backdrop })

	UIKit.Label({ Position = UDim2.fromOffset(4, 86), Size = UDim2.new(1, -8, 0, 18), Text = PetBuilder.DisplayName(petData.Type, tier), TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = if tier > 0 then accent else UIKit.Colors.Text, Parent = button })
	UIKit.Label({ Position = UDim2.fromOffset(4, 104), Size = UDim2.new(1, -8, 0, 20), Text = string.format("x%.2f", multiplierOf(petData)), TextSize = 15, Font = UIKit.Fonts.Black, TextColor3 = UIKit.Colors.Accent, TextXAlignment = Enum.TextXAlignment.Center, Parent = button })

	local tag = UIKit.Frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.fromOffset(78, 18), BackgroundColor3 = UIKit.Colors.Success, ZIndex = 3, Visible = false, Parent = button })
	UIKit.Corner(tag, 9)
	UIKit.Label({ Size = UDim2.fromScale(1, 1), Text = "EQUIPPED", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = tag })

	local id = petData.Id
	button.Activated:Connect(function()
		selectedId = id
		refreshDetail()
		for otherId, card in pairs(cards) do
			card.Stroke.Thickness = if otherId == id then 3.5 else 1.5
		end
	end)
	return { Button = button, Stroke = stroke, Tag = tag, Key = petData.Type .. "#" .. tier }
end

local function rebuild()
	if not window or not window.IsOpen() then
		return
	end
	local pets = State.Get("Pets", {})
	local slots = State.Get("PetSlots", Config.BasePetSlots)
	local equipped = 0
	local alive = {}
	for order, petData in ipairs(sortPets(pets)) do
		if Config.Pets[petData.Type] then
			alive[petData.Id] = true
			local card = cards[petData.Id]
			if card and card.Key ~= petData.Type .. "#" .. (petData.Tier or 0) then
				card.Button:Destroy()
				card = nil
			end
			if not card then
				card = createCard(petData)
				cards[petData.Id] = card
			end
			card.Button.LayoutOrder = order
			card.Tag.Visible = petData.Equipped == true
			if petData.Equipped then
				equipped += 1
			end
		end
	end
	for id, card in pairs(cards) do
		if not alive[id] then
			card.Button:Destroy()
			cards[id] = nil
		end
	end
	if selectedId and not alive[selectedId] then
		selectedId = nil
	end
	equippedLabel.Text = string.format("Equipped <font color='#50DC78'>%d / %d</font>", equipped, slots)
	storageLabel.Text = string.format("Storage %d / %d", #pets, Config.PetStorageLimit)
	refreshDetail()
end

function PetsUI.Init()
	window = UIController.CreateWindow("Pets", "PETS", UDim2.fromOffset(800, 500), UIKit.Colors.Success)
	local content = window.Content

	local topBar = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = content })
	equippedLabel = UIKit.Label({ Size = UDim2.fromOffset(200, 44), TextSize = 18, Parent = topBar })
	storageLabel = UIKit.Label({ Position = UDim2.fromOffset(200, 0), Size = UDim2.fromOffset(160, 44), TextSize = 15, TextColor3 = UIKit.Colors.Muted, Parent = topBar })
	local buttons = UIKit.Frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(250, 44), BackgroundTransparency = 1, Parent = topBar })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), Parent = buttons })
	local best = UIKit.Button({ Size = UDim2.fromOffset(116, 36), Text = "EQUIP BEST", TextSize = 14, Color = UIKit.Colors.Success, LayoutOrder = 1 }, function()
		Remotes.Get("EquipBest"):FireServer()
	end)
	best.Parent = buttons
	local unequip = UIKit.Button({ Size = UDim2.fromOffset(116, 36), Text = "UNEQUIP ALL", TextSize = 14, Color = UIKit.Colors.Info, LayoutOrder = 2 }, function()
		Remotes.Get("UnequipAll"):FireServer()
	end)
	unequip.Parent = buttons

	local gridHolder = UIKit.Frame({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, -230, 1, -54), BackgroundColor3 = UIKit.Colors.PanelDark, Parent = content })
	UIKit.Corner(gridHolder, 12)
	UIKit.Padding(gridHolder, 10)
	grid = UIKit.ScrollGrid(gridHolder, UDim2.fromOffset(116, 130), 10)
	buildDetail(content)

	window.OnOpen = rebuild
	State.Changed:Connect(function(patch)
		if patch.Pets ~= nil or patch.PetSlots ~= nil then
			rebuild()
		end
	end)

	-- Slowly spin the selected pet.
	RunService.RenderStepped:Connect(function()
		if detailModel and window.IsOpen() and detail.Visible then
			detailModel:PivotTo(CFrame.Angles(0, os.clock() * 0.8, 0))
		end
	end)

	UIController.AddSideButton("Pets", "PETS", UIKit.Colors.Success, 1, function()
		UIController.Toggle("Pets")
	end)
end

return PetsUI
