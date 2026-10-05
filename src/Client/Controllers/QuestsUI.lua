--------------------------------------------------------------------------------
-- QuestsUI - daily quests window plus a compact on-screen tracker.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local RewardText = require(Modules.RewardText)
local UIController = require(script.Parent.UIController)

local QuestsUI = {}

type Row = { Frame: Frame, Title: TextLabel, Fill: Frame, Count: TextLabel, Reward: TextLabel, Button: TextButton }

local window
local rows: { Row } = {}
local bonusLabel: TextLabel
local resetLabel: TextLabel
local tracker: Frame
local trackerRows: { { Label: TextLabel, Fill: Frame } } = {}

local function questState()
	local quests = State.Get("Quests")
	local stats = State.Get("Stats", {})
	local list = {}
	if not quests or not quests.Ids then
		return list, quests
	end
	for slot, id in ipairs(quests.Ids) do
		local quest = Config.GetQuest(id)
		if quest then
			local raw = (stats[quest.Stat] or 0) - ((quests.Baseline or {})[quest.Stat] or 0)
			local progress = math.clamp(math.floor(raw / (quest.Scale or 1)), 0, quest.Goal)
			table.insert(list, {
				Slot = slot,
				Quest = quest,
				Progress = progress,
				Done = progress >= quest.Goal,
				Claimed = (quests.Claimed or {})[id] == true,
			})
		end
	end
	return list, quests
end

local function refresh()
	local list, quests = questState()
	local claimable = false
	for index, row in ipairs(rows) do
		local entry = list[index]
		row.Frame.Visible = entry ~= nil
		if entry then
			local quest = entry.Quest
			row.Title.Text = string.format(quest.Text, quest.Goal)
			row.Fill.Size = UDim2.fromScale(entry.Progress / quest.Goal, 1)
			row.Count.Text = string.format("%d / %d", entry.Progress, quest.Goal)
			row.Reward.Text = RewardText.Describe(quest.Reward, 1, "  ")
			if entry.Claimed then
				UIKit.SetButtonEnabled(row.Button, false, "DONE")
			elseif entry.Done then
				UIKit.SetButtonEnabled(row.Button, true)
				row.Button.Text = "CLAIM"
				claimable = true
			else
				UIKit.SetButtonEnabled(row.Button, false, "IN PROGRESS")
			end
		end
		local trackerRow = trackerRows[index]
		if trackerRow then
			trackerRow.Label.Parent.Visible = entry ~= nil and not entry.Claimed
			if entry then
				trackerRow.Label.Text = string.format("%s  %d/%d", string.format(entry.Quest.Text, entry.Quest.Goal), entry.Progress, entry.Quest.Goal)
				trackerRow.Fill.Size = UDim2.fromScale(entry.Progress / entry.Quest.Goal, 1)
				trackerRow.Fill.BackgroundColor3 = if entry.Done then UIKit.Colors.Success else UIKit.Colors.Accent
			end
		end
	end
	local bonusText = RewardText.Describe(Config.Quests.BonusReward, 1, "  ")
	if quests and quests.BonusClaimed then
		bonusLabel.Text = "All quests done today!  Bonus claimed: " .. bonusText
	else
		bonusLabel.Text = "Finish all " .. Config.Quests.PerDay .. " quests for a bonus: " .. bonusText
	end
	local now = State.Now()
	local nextReset = (Util.DayNumber(now) + 1) * 86400
	resetLabel.Text = "New quests in " .. Util.FormatTime(nextReset - now)
	UIController.SetBadge("Quests", claimable)
	tracker.Visible = State.Loaded and #list > 0
end

local function buildRow(parent: Instance, order: number): Row
	local frame = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 84), BackgroundColor3 = UIKit.Colors.Panel, LayoutOrder = order, Parent = parent })
	UIKit.Corner(frame, 12)
	UIKit.Padding(frame, 12, 8)
	local title = UIKit.Label({ Size = UDim2.new(1, -150, 0, 24), TextSize = 18, Parent = frame })
	local bar = UIKit.Frame({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, -150, 0, 16), BackgroundColor3 = UIKit.Colors.PanelDark, Parent = frame })
	UIKit.Corner(bar, 8)
	local fill = UIKit.Frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = UIKit.Colors.Accent, Parent = bar })
	UIKit.Corner(fill, 8)
	local count = UIKit.Label({ Size = UDim2.fromScale(1, 1), TextSize = 12, Font = UIKit.Fonts.Black, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2, TextStrokeTransparency = 0.5, Parent = bar })
	local reward = UIKit.Label({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, -150, 0, 20), TextSize = 14, Parent = frame })
	local button = UIKit.Button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(136, 44), Color = UIKit.Colors.Success, TextSize = 15 }, function()
		Remotes.Get("ClaimQuest"):FireServer(order)
	end)
	button.Parent = frame
	return { Frame = frame, Title = title, Fill = fill, Count = count, Reward = reward, Button = button }
end

local function buildTracker()
	tracker = UIKit.Frame({
		Name = "QuestTracker",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 170),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UIKit.Colors.Background,
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = UIController.Root,
	})
	UIKit.Corner(tracker, 10)
	UIKit.Padding(tracker, 8, 6)
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tracker })
	local header = UIKit.Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = UIKit.Fonts.Title,
		TextSize = 16,
		TextColor3 = UIKit.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "DAILY QUESTS  >",
		LayoutOrder = 0,
		Parent = tracker,
	})
	header.Activated:Connect(function()
		UIController.Toggle("Quests")
	end)
	for index = 1, Config.Quests.PerDay do
		local row = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = index, Parent = tracker })
		local label = UIKit.Label({ Size = UDim2.new(1, 0, 0, 16), TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
		local bar = UIKit.Frame({ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = UIKit.Colors.PanelDark, Parent = row })
		UIKit.Corner(bar, 3)
		local fill = UIKit.Frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = UIKit.Colors.Accent, Parent = bar })
		UIKit.Corner(fill, 3)
		trackerRows[index] = { Label = label, Fill = fill }
	end
end

function QuestsUI.Init()
	window = UIController.CreateWindow("Quests", "DAILY QUESTS", UDim2.fromOffset(620, 430), UIKit.Colors.Accent)
	local list = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = window.Content })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for index = 1, Config.Quests.PerDay do
		rows[index] = buildRow(list, index)
	end
	bonusLabel = UIKit.Label({ Size = UDim2.new(1, 0, 0, 26), TextSize = 15, TextWrapped = true, LayoutOrder = 10, Parent = list })
	resetLabel = UIKit.Label({ Size = UDim2.new(1, 0, 0, 20), TextSize = 13, TextColor3 = UIKit.Colors.Muted, LayoutOrder = 11, Parent = list })

	buildTracker()
	window.OnOpen = refresh
	State.Changed:Connect(function(patch)
		if patch.Quests ~= nil or patch.Stats ~= nil or patch.Multiplier ~= nil then
			refresh()
		end
	end)
	UIController.AddSideButton("Quests", "QUESTS", UIKit.Colors.Success:Lerp(UIKit.Colors.Accent, 0.5), 4, function()
		UIController.Toggle("Quests")
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if window.IsOpen() then
				refresh()
			end
		end
	end)
end

return QuestsUI
