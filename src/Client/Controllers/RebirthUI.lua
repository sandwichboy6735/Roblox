--------------------------------------------------------------------------------
-- RebirthUI - prestige window.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)

local RebirthUI = {}

local window
local currentLabel: TextLabel
local nextLabel: TextLabel
local costLabel: TextLabel
local rebirthButton: TextButton

local getCost = Config.GetRebirthCost

local function refresh()
	if not window or not window.IsOpen() then
		return
	end
	local rebirths = State.Get("Rebirths", 0)
	local coins = State.Get("Coins", 0)
	local cost = getCost(rebirths)
	local per = Config.Rebirth.MultiplierPerRebirth

	currentLabel.Text = string.format("Rebirths: <font color='#FFC400'>%d</font>   Multiplier: <font color='#AF69FF'>x%.2f</font>", rebirths, 1 + rebirths * per)
	nextLabel.Text = string.format("Next: <font color='#AF69FF'>x%.2f</font> coins forever  +%d Gems", 1 + (rebirths + 1) * per, Config.Rebirth.GemsReward)
	costLabel.Text = string.format("Cost: <font color='#FFC400'>%s</font> coins   (you have %s)", Util.FormatNumber(cost), Util.FormatNumber(coins))

	if coins >= cost then
		UIKit.SetButtonEnabled(rebirthButton, true)
		rebirthButton.Text = "REBIRTH NOW"
	else
		UIKit.SetButtonEnabled(rebirthButton, false, "NEED " .. Util.FormatNumber(cost - coins) .. " MORE")
	end
end

function RebirthUI.Init()
	window = UIController.CreateWindow("Rebirth", "REBIRTH", UDim2.fromOffset(500, 360), UIKit.Colors.Purple)
	local content = window.Content

	UIKit.Label({
		Size = UDim2.new(1, 0, 0, 60),
		Text = "Reset your coins and zones for a PERMANENT coin multiplier.\nYou keep all pets, gems and gamepasses.",
		TextSize = 16,
		Font = UIKit.Fonts.Body,
		TextWrapped = true,
		TextColor3 = UIKit.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content,
	})

	currentLabel = UIKit.Label({
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content,
	})
	nextLabel = UIKit.Label({
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content,
	})
	costLabel = UIKit.Label({
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content,
	})

	rebirthButton = UIKit.Button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(280, 54),
		Color = UIKit.Colors.Purple,
		Text = "REBIRTH NOW",
		TextSize = 22,
		Font = UIKit.Fonts.Title,
	}, function()
		UIController.Confirm("Rebirth?", "Your coins will reset to 0 and zones will lock again. You keep pets & gems and gain a permanent multiplier.", function()
			Remotes.Get("Rebirth"):FireServer()
		end)
	end)
	rebirthButton.Parent = content

	window.OnOpen = refresh
	State.Changed:Connect(function(patch)
		if patch.Coins ~= nil or patch.Rebirths ~= nil then
			refresh()
		end
	end)

	UIController.AddSideButton("Rebirth", "REBIRTH", UIKit.Colors.Purple, 6, function()
		UIController.Toggle("Rebirth")
	end)
end

return RebirthUI
