--------------------------------------------------------------------------------
-- ZonesUI - teleport between unlocked zones / see unlock costs.
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

local ZonesUI = {}

local window
local list: ScrollingFrame

local function rebuild()
	if not window or not window.IsOpen() then
		return
	end
	UIKit.ClearChildren(list)
	local unlocked = State.Get("ZonesUnlocked", 1)
	local coins = State.Get("Coins", 0)

	for index, zone in ipairs(Config.Zones) do
		local row = UIKit.Frame({
			Size = UDim2.new(1, 0, 0, 66),
			BackgroundColor3 = UIKit.Colors.Panel,
			LayoutOrder = index,
			Parent = list,
		})
		UIKit.Corner(row, 12)
		UIKit.Stroke(row, index <= unlocked and zone.Theme.Accent or UIKit.Colors.Stroke, 1.5)

		local swatch = UIKit.Frame({
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = zone.Theme.Ground,
			Parent = row,
		})
		UIKit.Corner(swatch, 10)
		UIKit.Stroke(swatch, zone.Theme.Accent, 2)

		UIKit.Label({
			Position = UDim2.fromOffset(68, 8),
			Size = UDim2.new(1, -240, 0, 28),
			Text = string.format("%d. %s", index, zone.Name),
			TextSize = 20,
			Font = UIKit.Fonts.Title,
			Parent = row,
		})
		local status
		if index <= unlocked then
			status = string.format("Orbs worth ~%s coins", Util.FormatNumber(zone.OrbValue))
		elseif index == unlocked + 1 then
			status = "Unlock for " .. Util.FormatNumber(zone.Cost) .. " coins"
		else
			status = "Locked - unlock previous zones first"
		end
		UIKit.Label({
			Position = UDim2.fromOffset(68, 36),
			Size = UDim2.new(1, -240, 0, 22),
			Text = status,
			TextSize = 14,
			Font = UIKit.Fonts.Body,
			TextColor3 = UIKit.Colors.Muted,
			Parent = row,
		})

		local button
		if index <= unlocked then
			button = UIKit.Button({ Text = "TELEPORT", Color = UIKit.Colors.Info, Size = UDim2.fromOffset(150, 40), TextSize = 16 }, function()
				Remotes.Get("TeleportZone"):FireServer(index)
				UIController.Close("Zones")
			end)
		elseif index == unlocked + 1 then
			button = UIKit.Button({ Text = "UNLOCK", Color = UIKit.Colors.Success, Size = UDim2.fromOffset(150, 40), TextSize = 16 }, function()
				Remotes.Get("UnlockZone"):FireServer(index)
			end)
			if coins < zone.Cost then
				UIKit.SetButtonEnabled(button, false, Util.FormatNumber(zone.Cost))
				button:SetAttribute("Disabled", false) -- still clickable: server explains what's missing
			end
		else
			button = UIKit.Button({ Text = "LOCKED", Color = UIKit.Colors.PanelLight, Size = UDim2.fromOffset(150, 40), TextSize = 16 })
			UIKit.SetButtonEnabled(button, false)
		end
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -12, 0.5, 0)
		button.Parent = row
	end
end

function ZonesUI.Init()
	window = UIController.CreateWindow("Zones", "ZONES", UDim2.fromOffset(560, 460), UIKit.Colors.Info)
	local holder = UIKit.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIKit.Colors.PanelDark,
		Parent = window.Content,
	})
	UIKit.Corner(holder, 12)
	UIKit.Padding(holder, 10)
	list = UIKit.ScrollList(holder, nil, 8)

	window.OnOpen = rebuild
	State.Changed:Connect(function(patch)
		if patch.ZonesUnlocked ~= nil or patch.Coins ~= nil then
			rebuild()
		end
	end)

	UIController.AddSideButton("Zones", "ZONES", UIKit.Colors.Info, 3, function()
		UIController.Toggle("Zones")
	end)
end

return ZonesUI
