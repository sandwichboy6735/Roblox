--------------------------------------------------------------------------------
-- ShopUI - gamepasses and developer products.
--------------------------------------------------------------------------------

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local ShopUI = {}

local window
local list: ScrollingFrame
local CARD_W, CARD_H, PAD = 222, 160, 10
local COLUMNS = 3

local function sortedEntries(map)
	local entries = {}
	for key, item in pairs(map) do
		table.insert(entries, { Key = key, Item = item })
	end
	table.sort(entries, function(a, b)
		return (a.Item.Order or 0) < (b.Item.Order or 0)
	end)
	return entries
end

local function promptGamepass(key, pass)
	if Config.RestrictedPurchases[key] and State.Get("PaidRandomRestricted", false) then
		UIController.Notify("Sorry, this item is unavailable in your region.", "error")
		return
	end
	if not pass.Id or pass.Id == 0 then
		UIController.Notify("This gamepass isn't configured yet. Set Config.Gamepasses." .. key .. ".Id", "error")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.Id)
end

local function promptProduct(key, product)
	if Config.RestrictedPurchases[key] and State.Get("PaidRandomRestricted", false) then
		UIController.Notify("Sorry, this item is unavailable in your region.", "error")
		return
	end
	if not product.Id or product.Id == 0 then
		UIController.Notify("This product isn't configured yet. Set Config.Products." .. key .. ".Id", "error")
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
end

local function describeGrant(grant): string
	if grant.Coins then
		return Util.FormatNumber(grant.Coins) .. "+ Coins (scales with zone)"
	elseif grant.Gems then
		return "+" .. Util.FormatNumber(grant.Gems) .. " Gems"
	elseif grant.Boost then
		return string.format("x%s %s for %s", tostring(grant.Boost.Mult), grant.Boost.Type, Util.FormatTime(grant.Boost.Duration))
	elseif grant.Rebirths then
		return "+" .. grant.Rebirths .. " Rebirth, no reset!"
	end
	return ""
end

local function sectionHeader(text: string, order: number, color: Color3)
	UIKit.Label({
		Size = UDim2.new(1, 0, 0, 34),
		Text = text,
		Font = UIKit.Fonts.Title,
		TextSize = 24,
		TextColor3 = color,
		LayoutOrder = order,
		Parent = list,
	})
end

local function gridContainer(count: number, order: number): Frame
	local rows = math.ceil(count / COLUMNS)
	local holder = UIKit.Frame({
		Size = UDim2.new(1, 0, 0, rows * (CARD_H + PAD)),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = list,
	})
	UIKit.Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_W, CARD_H),
		CellPadding = UDim2.fromOffset(PAD, PAD),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = holder,
	})
	return holder
end

local function isBlocked(key: string): boolean
	return Config.RestrictedPurchases[key] == true and State.Get("PaidRandomRestricted", false) == true
end

local function card(parent: Instance, order: number, color: Color3, title: string, body: string, buttonText: string, onClick: () -> (), owned: boolean?, blocked: boolean?)
	local frame = UIKit.Frame({
		BackgroundColor3 = UIKit.Colors.Panel,
		LayoutOrder = order,
		Parent = parent,
	})
	UIKit.Corner(frame, 12)
	UIKit.Stroke(frame, color, 1.5)

	local header = UIKit.Frame({
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = color,
		Parent = frame,
	})
	UIKit.Corner(header, 12)
	UIKit.RarityGradient(header, color)
	UIKit.Label({
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = title,
		Font = UIKit.Fonts.Title,
		TextSize = 20,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeTransparency = 0.6,
		Parent = header,
	})

	UIKit.Label({
		Position = UDim2.fromOffset(10, 46),
		Size = UDim2.new(1, -20, 0, 60),
		Text = body,
		Font = UIKit.Fonts.Body,
		TextSize = 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UIKit.Colors.Muted,
		Parent = frame,
	})

	local button = UIKit.Button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 38),
		Color = owned and UIKit.Colors.PanelLight or UIKit.Colors.Success,
		Text = owned and "OWNED" or buttonText,
		TextSize = 17,
	}, onClick)
	button.Parent = frame
	if owned then
		UIKit.SetButtonEnabled(button, false, "OWNED")
	elseif blocked then
		UIKit.SetButtonEnabled(button, false, "UNAVAILABLE")
	end
end

local function rebuild()
	if not window or not window.IsOpen() then
		return
	end
	UIKit.ClearChildren(list)

	local passes = sortedEntries(Config.Gamepasses)
	sectionHeader("GAMEPASSES", 1, UIKit.Colors.Accent)
	local passGrid = gridContainer(#passes, 2)
	for index, entry in ipairs(passes) do
		local pass = entry.Item
		local blocked = isBlocked(entry.Key)
		local description = if blocked then "Not available in your region." else pass.Description
		card(passGrid, index, pass.Color or UIKit.Colors.Accent, pass.Name, description, "R$ " .. pass.Price, function()
			promptGamepass(entry.Key, pass)
		end, State.Owns(entry.Key), blocked)
	end

	local products = sortedEntries(Config.Products)
	sectionHeader("COINS, GEMS & BOOSTS", 3, UIKit.Colors.Gems)
	local productGrid = gridContainer(#products, 4)
	for index, entry in ipairs(products) do
		local product = entry.Item
		local color = UIKit.Colors.Info
		if product.Grant.Coins then
			color = UIKit.Colors.Accent
		elseif product.Grant.Gems then
			color = UIKit.Colors.Gems
		elseif product.Grant.Boost then
			color = UIKit.Colors.Purple
		elseif product.Grant.Rebirths then
			color = UIKit.Colors.Pink
		end
		local blocked = isBlocked(entry.Key)
		local description = if blocked then "Not available in your region." else describeGrant(product.Grant)
		card(productGrid, index, color, product.Name, description, "R$ " .. product.Price, function()
			promptProduct(entry.Key, product)
		end, false, blocked)
	end
end

function ShopUI.Init()
	window = UIController.CreateWindow("Shop", "SHOP", UDim2.fromOffset(760, 500), UIKit.Colors.Accent)
	local holder = UIKit.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIKit.Colors.PanelDark,
		Parent = window.Content,
	})
	UIKit.Corner(holder, 12)
	UIKit.Padding(holder, 12)
	list = UIKit.ScrollList(holder, nil, 8)

	window.OnOpen = rebuild
	State.Changed:Connect(function(patch)
		if patch.Gamepasses ~= nil or patch.PaidRandomRestricted ~= nil then
			rebuild()
		end
	end)

	UIController.AddSideButton("Shop", "SHOP", UIKit.Colors.Accent, 2, function()
		UIController.Toggle("Shop")
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, _, purchased)
		if purchased then
			UIController.PlaySound("Purchase")
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, _, purchased)
		if purchased then
			UIController.PlaySound("Purchase")
		end
	end)
end

return ShopUI
