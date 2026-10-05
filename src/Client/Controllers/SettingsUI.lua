--------------------------------------------------------------------------------
-- SettingsUI - music + hatch animation toggles (persisted on the server).
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)

local SettingsUI = {}

local SETTINGS = {
	{ Key = "Music", Label = "Background Music" },
	{ Key = "SkipHatchAnimation", Label = "Skip Hatch Animation" },
}

local window
local toggles: { [string]: TextButton } = {}
local music: Sound? = nil

local function getSetting(key: string): boolean
	local settings = State.Get("Settings", {})
	return settings[key] == true
end

local function applyMusic()
	if not Config.Sounds.Music or Config.Sounds.Music == 0 then
		return
	end
	if not music then
		local sound = Instance.new("Sound")
		sound.Name = "Music"
		sound.SoundId = "rbxassetid://" .. Config.Sounds.Music
		sound.Looped = true
		sound.Volume = 0.3
		sound.Parent = SoundService
		music = sound
	end
	local sound = music :: Sound
	if getSetting("Music") then
		if not sound.IsPlaying then
			sound:Play()
		end
	else
		sound:Stop()
	end
end

local function refresh()
	for key, button in pairs(toggles) do
		local on = getSetting(key)
		button.Text = on and "ON" or "OFF"
		UIKit.SetButtonColor(button, on and UIKit.Colors.Success or UIKit.Colors.Danger)
	end
end

function SettingsUI.Init()
	window = UIController.CreateWindow("Settings", "SETTINGS", UDim2.fromOffset(420, 240), UIKit.Colors.Stroke)
	local list = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = window.Content })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	for order, setting in ipairs(SETTINGS) do
		local row = UIKit.Frame({
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = UIKit.Colors.Panel,
			LayoutOrder = order,
			Parent = list,
		})
		UIKit.Corner(row, 10)
		UIKit.Label({
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -120, 1, 0),
			Text = setting.Label,
			TextSize = 18,
			Parent = row,
		})
		local button = UIKit.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(90, 36),
			Color = UIKit.Colors.Danger,
			Text = "OFF",
		}, function()
			local settings = State.Get("Settings", {})
			local newValue = not (settings[setting.Key] == true)
			settings[setting.Key] = newValue
			State.Apply({ Settings = settings })
			Remotes.Get("UpdateSetting"):FireServer(setting.Key, newValue)
		end)
		button.Parent = row
		toggles[setting.Key] = button
	end

	window.OnOpen = refresh
	State.Changed:Connect(function(patch)
		if patch.Settings ~= nil then
			refresh()
			applyMusic()
		end
	end)

	UIController.AddSideButton("Settings", "SETTINGS", UIKit.Colors.Stroke, 7, function()
		UIController.Toggle("Settings")
	end)
end

return SettingsUI
