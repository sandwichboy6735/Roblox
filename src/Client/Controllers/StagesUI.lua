--------------------------------------------------------------------------------
-- StagesUI - teleport back to any checkpoint you've reached, grouped by world.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)

local StagesUI = {}

local window
local list: ScrollingFrame
local progressLabel: TextLabel

local function rebuild()
	if not window or not window.IsOpen() then
		return
	end
	UIKit.ClearChildren(list)
	local current = State.Get("Stage", 1)
	local total = Config.TotalStages()
	progressLabel.Text = string.format("You're on stage <font color='#FFC400'>%d / %d</font>. Tap a stage to go back to it.", current, total)

	local order = 0
	for worldIndex, world in ipairs(Config.Worlds) do
		local start = Config.GetWorldStart(worldIndex)
		local unlocked = current >= start
		order += 1
		UIKit.Label({
			Size = UDim2.new(1, 0, 0, 30),
			Text = string.format("WORLD %d: %s%s", worldIndex, string.upper(world.Name), if unlocked then "" else "  <font color='#A5AAC8'>(locked)</font>"),
			Font = UIKit.Fonts.Title,
			TextSize = 20,
			TextColor3 = if unlocked then world.Theme.Accent else UIKit.Colors.Muted,
			LayoutOrder = order,
			Parent = list,
		})
		order += 1
		local rows = math.ceil(world.Stages / 10)
		local holder = UIKit.Frame({ Size = UDim2.new(1, 0, 0, rows * 50), BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
		UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(56, 42), CellPadding = UDim2.fromOffset(6, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
		for i = 1, world.Stages do
			local stage = start + i - 1
			local reached = stage <= current
			local button = UIKit.Button({
				Text = tostring(stage),
				TextSize = 17,
				Color = if stage == current then UIKit.Colors.Accent elseif reached then world.Theme.Platform else UIKit.Colors.PanelLight,
				LayoutOrder = i,
				Radius = 10,
			}, function()
				if reached then
					Remotes.Get("TeleportStage"):FireServer(stage)
					window.Close()
				end
			end)
			if not reached then
				UIKit.SetButtonEnabled(button, false)
			end
			button.Parent = holder
		end
	end
end

function StagesUI.Init()
	window = UIController.CreateWindow("Stages", "STAGES", UDim2.fromOffset(700, 520), UIKit.Colors.Info)
	progressLabel = UIKit.Label({ Size = UDim2.new(1, 0, 0, 26), TextSize = 16, Parent = window.Content })
	local holder = UIKit.Frame({ Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), BackgroundColor3 = UIKit.Colors.PanelDark, Parent = window.Content })
	UIKit.Corner(holder, 12)
	UIKit.Padding(holder, 10)
	list = UIKit.ScrollList(holder, nil, 4)
	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end

	window.OnOpen = rebuild
	State.Changed:Connect(function(patch)
		if patch.Stage ~= nil then
			rebuild()
		end
	end)

	UIController.AddSideButton("Stages", "STAGES", UIKit.Colors.Info, 4, function()
		UIController.Toggle("Stages")
	end)
end

return StagesUI
