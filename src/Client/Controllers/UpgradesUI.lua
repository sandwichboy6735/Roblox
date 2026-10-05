--------------------------------------------------------------------------------
-- UpgradesUI - spend gems on permanent upgrades (speed, magnet, coin boost).
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)

local UpgradesUI = {}

local COLORS = { WalkSpeed = UIKit.Colors.Info, Magnet = UIKit.Colors.Pink, CoinBoost = UIKit.Colors.Accent }

type Card = { Key: string, Pips: { Frame }, Bonus: TextLabel, Button: TextButton }

local window
local cards: { Card } = {}

local function formatBonus(key: string, value: number): string
	if key == "CoinBoost" then
		return string.format("+%d%% coins", math.floor(value * 100 + 0.5))
	elseif key == "WalkSpeed" then
		return string.format("+%d speed", value)
	end
	return string.format("+%.1f studs range", value)
end

local function refresh()
	if not window or not window.IsOpen() then
		return
	end
	local levels = State.Get("Upgrades", {})
	local gems = State.Get("Gems", 0)
	for _, card in ipairs(cards) do
		local upgrade = Config.Upgrades[card.Key]
		local level = levels[card.Key] or 0
		for index, pip in ipairs(card.Pips) do
			pip.BackgroundColor3 = if index <= level then COLORS[card.Key] else UIKit.Colors.PanelDark
		end
		card.Bonus.Text = "Now: " .. formatBonus(card.Key, level * upgrade.PerLevel)
		local cost = upgrade.Costs[level + 1]
		if not cost then
			UIKit.SetButtonEnabled(card.Button, false, "MAXED")
		else
			UIKit.SetButtonEnabled(card.Button, gems >= cost, cost .. " GEMS")
			card.Button.Text = cost .. " GEMS"
			card.Button:SetAttribute("Disabled", false) -- server explains if short
		end
	end
end

function UpgradesUI.Init()
	window = UIController.CreateWindow("Upgrades", "UPGRADES", UDim2.fromOffset(660, 330), UIKit.Colors.Gems)
	local row = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = window.Content })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = row })

	local keys = {}
	for key in pairs(Config.Upgrades) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return Config.Upgrades[a].Order < Config.Upgrades[b].Order
	end)

	for order, key in ipairs(keys) do
		local upgrade = Config.Upgrades[key]
		local color = COLORS[key] or UIKit.Colors.Info
		local card = UIKit.Frame({ Size = UDim2.new(1 / #keys, -9, 1, 0), BackgroundColor3 = UIKit.Colors.Panel, LayoutOrder = order, Parent = row })
		UIKit.Corner(card, 12)
		UIKit.Stroke(card, color, 2)
		UIKit.Padding(card, 12, 10)
		UIKit.Label({ Size = UDim2.new(1, 0, 0, 30), Text = upgrade.Name, Font = UIKit.Fonts.Title, TextSize = 24, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		UIKit.Label({ Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 40), Text = upgrade.Description, Font = UIKit.Fonts.Body, TextSize = 14, TextWrapped = true, TextColor3 = UIKit.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		local pipRow = UIKit.Frame({ Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Parent = card })
		UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = pipRow })
		local pips = {}
		for i = 1, #upgrade.Costs do
			local pip = UIKit.Frame({ Size = UDim2.fromOffset(26, 14), BackgroundColor3 = UIKit.Colors.PanelDark, LayoutOrder = i, Parent = pipRow })
			UIKit.Corner(pip, 4)
			pips[i] = pip
		end
		local bonus = UIKit.Label({ Position = UDim2.fromOffset(0, 110), Size = UDim2.new(1, 0, 0, 22), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		local button = UIKit.Button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 44), Color = color, TextSize = 17 }, function()
			Remotes.Get("BuyUpgrade"):FireServer(key)
		end)
		button.Parent = card
		table.insert(cards, { Key = key, Pips = pips, Bonus = bonus, Button = button })
	end

	window.OnOpen = refresh
	State.Changed:Connect(function(patch)
		if patch.Upgrades ~= nil or patch.Gems ~= nil then
			refresh()
		end
	end)
	UIController.AddSideButton("Upgrades", "UPGRADES", UIKit.Colors.Gems:Lerp(UIKit.Colors.Info, 0.4), 5, function()
		UIController.Toggle("Upgrades")
	end)
end

return UpgradesUI
