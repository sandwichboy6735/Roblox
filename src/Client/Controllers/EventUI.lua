--------------------------------------------------------------------------------
-- EventUI - shows the running server event (or the countdown to the next one)
-- and celebrates when an event starts.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)
local EffectsController = require(script.Parent.EffectsController)

local EventUI = {}

local chip: Frame
local label: TextLabel
local stroke: UIStroke

local function refresh()
	local name = ReplicatedStorage:GetAttribute("EventName")
	local now = State.Now()
	local event = type(name) == "string" and Config.Events.List[name] or nil
	if event then
		local endsAt = ReplicatedStorage:GetAttribute("EventEndsAt")
		local left = if type(endsAt) == "number" then math.max(0, endsAt - now) else 0
		label.Text = string.format("%s  %s", event.Name, Util.FormatTime(left))
		label.TextColor3 = event.Color
		stroke.Color = event.Color
		chip.Visible = true
	else
		local nextAt = ReplicatedStorage:GetAttribute("NextEventAt")
		if type(nextAt) == "number" then
			label.Text = "Next event in " .. Util.FormatTime(math.max(0, nextAt - now))
			label.TextColor3 = UIKit.Colors.Muted
			stroke.Color = UIKit.Colors.Stroke
			chip.Visible = true
		else
			chip.Visible = false
		end
	end
end

function EventUI.Init()
	chip = UIKit.Frame({
		Name = "EventChip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 134),
		Size = UDim2.fromOffset(250, 30),
		BackgroundColor3 = UIKit.Colors.Background,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = UIController.Root,
	})
	UIKit.Corner(chip, 15)
	stroke = UIKit.Stroke(chip, UIKit.Colors.Stroke, 2)
	label = UIKit.Label({ Size = UDim2.fromScale(1, 1), TextSize = 15, Font = UIKit.Fonts.Black, TextXAlignment = Enum.TextXAlignment.Center, Parent = chip })

	ReplicatedStorage:GetAttributeChangedSignal("EventName"):Connect(function()
		local name = ReplicatedStorage:GetAttribute("EventName")
		local event = type(name) == "string" and Config.Events.List[name] or nil
		if event then
			UIController.Banner(event.Name .. "!", event.Description, event.Color)
			EffectsController.Confetti(80)
		end
		refresh()
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(1)
		end
	end)
end

return EventUI
