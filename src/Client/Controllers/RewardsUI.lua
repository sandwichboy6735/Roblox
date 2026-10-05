--------------------------------------------------------------------------------
-- RewardsUI - daily streak, playtime gifts, group reward and promo codes.
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

local RewardsUI = {}

local window
local dailyCells: { Frame } = {}
local dailyButton: TextButton
local dailyStatus: TextLabel
local playtimeCells: { { Frame: Frame, Button: TextButton, Status: TextLabel, Reward: TextLabel } } = {}
local groupButton: TextButton?
local codeBox: TextBox
local redeeming = false

local function describe(reward, multiplier: number?): string
	local mult = multiplier or 1
	local parts = {}
	if reward.Coins then
		local amount = Config.ScaleCoins(reward.Coins, State.Get("ZonesUnlocked", 1), State.Get("Rebirths", 0)) * mult
		table.insert(parts, "<font color='#FFC400'>" .. Util.FormatNumber(amount) .. " Coins</font>")
	end
	if reward.Gems then
		table.insert(parts, "<font color='#6EFAE1'>" .. Util.FormatNumber(reward.Gems * mult) .. " Gems</font>")
	end
	if reward.Pet then
		table.insert(parts, "<font color='#FFAA00'>" .. reward.Pet .. "</font>")
	end
	return table.concat(parts, "\n")
end

local function sessionElapsed(): number
	local start = State.Get("SessionStart")
	if not start then
		return 0
	end
	return State.Now() - start
end

--------------------------------------------------------------------------------
-- Badge logic (runs even while the window is closed)
--------------------------------------------------------------------------------

local function anythingClaimable(): boolean
	if not State.Loaded then
		return false
	end
	local daily = Util.ComputeDaily(State.Get("Daily", { LastClaim = 0, Streak = 0 }), State.Now(), #Config.DailyRewards)
	if daily.Available then
		return true
	end
	local claimed = State.Get("PlaytimeClaimed", {})
	local elapsed = sessionElapsed()
	for index, reward in ipairs(Config.PlaytimeRewards) do
		if not claimed[tostring(index)] and elapsed >= reward.Minutes * 60 then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Refresh
--------------------------------------------------------------------------------

local function refreshDaily()
	local daily = Util.ComputeDaily(State.Get("Daily", { LastClaim = 0, Streak = 0 }), State.Now(), #Config.DailyRewards)
	local vipMult = State.Owns("VIP") and Config.Gamepasses.VIP.DailyRewardMultiplier or 1
	-- When today's reward is claimed, NextDay is the day just claimed.
	local claimedThrough = if daily.Available then daily.NextDay - 1 else daily.NextDay

	for day, cell in ipairs(dailyCells) do
		local stroke = cell:FindFirstChildOfClass("UIStroke")
		local reward = cell:FindFirstChild("Reward") :: TextLabel
		reward.Text = describe(Config.DailyRewards[day], vipMult)
		local isNext = daily.Available and day == daily.NextDay
		if day <= claimedThrough then
			cell.BackgroundColor3 = UIKit.Colors.Success:Lerp(UIKit.Colors.Panel, 0.6)
			if stroke then
				stroke.Color = UIKit.Colors.Success
			end
		elseif isNext then
			cell.BackgroundColor3 = UIKit.Colors.Accent:Lerp(UIKit.Colors.Panel, 0.55)
			if stroke then
				stroke.Color = UIKit.Colors.Accent
			end
		else
			cell.BackgroundColor3 = UIKit.Colors.Panel
			if stroke then
				stroke.Color = UIKit.Colors.Stroke
			end
		end
	end

	if daily.Available then
		UIKit.SetButtonEnabled(dailyButton, true)
		dailyButton.Text = "CLAIM DAY " .. daily.NextDay
		dailyStatus.Text = vipMult > 1 and "<font color='#FF7828'>VIP: rewards doubled!</font>" or "Log in every day to grow your streak!"
	else
		UIKit.SetButtonEnabled(dailyButton, false, "CLAIMED")
		dailyStatus.Text = "Next reward in " .. Util.FormatTime(daily.SecondsUntilReset)
	end
end

local function refreshPlaytime()
	local claimed = State.Get("PlaytimeClaimed", {})
	local elapsed = sessionElapsed()
	for index, entry in ipairs(playtimeCells) do
		local reward = Config.PlaytimeRewards[index]
		entry.Reward.Text = describe(reward) -- coin amounts scale with progress
		local needed = reward.Minutes * 60
		if claimed[tostring(index)] then
			UIKit.SetButtonEnabled(entry.Button, false, "CLAIMED")
			entry.Status.Text = "Done!"
		elseif elapsed >= needed then
			UIKit.SetButtonEnabled(entry.Button, true)
			entry.Button.Text = "CLAIM"
			entry.Status.Text = "Ready!"
		else
			UIKit.SetButtonEnabled(entry.Button, false, Util.FormatTime(needed - elapsed))
			entry.Status.Text = reward.Minutes .. " min"
		end
	end
end

local function refreshGroup()
	if not groupButton then
		return
	end
	if State.Get("GroupClaimed", false) then
		UIKit.SetButtonEnabled(groupButton, false, "CLAIMED")
	else
		UIKit.SetButtonEnabled(groupButton, true)
		groupButton.Text = "CLAIM " .. Config.GroupReward.Gems .. " GEMS"
	end
end

local function refreshAll()
	if not window or not window.IsOpen() then
		return
	end
	refreshDaily()
	refreshPlaytime()
	refreshGroup()
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

local function sectionTitle(parent: Instance, text: string, order: number, color: Color3)
	UIKit.Label({
		Size = UDim2.new(1, 0, 0, 30),
		Text = text,
		Font = UIKit.Fonts.Title,
		TextSize = 22,
		TextColor3 = color,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function buildDaily(list: ScrollingFrame)
	sectionTitle(list, "DAILY REWARDS", 1, UIKit.Colors.Accent)
	local row = UIKit.Frame({
		Size = UDim2.new(1, 0, 0, 104),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = list,
	})
	UIKit.Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	for day = 1, #Config.DailyRewards do
		local cell = UIKit.Frame({
			Size = UDim2.fromOffset(80, 100),
			BackgroundColor3 = UIKit.Colors.Panel,
			LayoutOrder = day,
			Parent = row,
		})
		UIKit.Corner(cell, 10)
		UIKit.Stroke(cell, UIKit.Colors.Stroke, 2)
		UIKit.Label({
			Size = UDim2.new(1, 0, 0, 26),
			Text = "DAY " .. day,
			Font = UIKit.Fonts.Black,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = cell,
		})
		UIKit.Label({
			Name = "Reward",
			Position = UDim2.fromOffset(4, 28),
			Size = UDim2.new(1, -8, 1, -32),
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = cell,
		})
		dailyCells[day] = cell
	end

	local footer = UIKit.Frame({
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = list,
	})
	dailyStatus = UIKit.Label({
		Size = UDim2.new(1, -200, 1, 0),
		TextSize = 15,
		TextColor3 = UIKit.Colors.Muted,
		Parent = footer,
	})
	dailyButton = UIKit.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(180, 42),
		Color = UIKit.Colors.Accent,
		Text = "CLAIM",
	}, function()
		Remotes.Get("ClaimDaily"):FireServer()
	end)
	dailyButton.Parent = footer
end

local function buildPlaytime(list: ScrollingFrame)
	sectionTitle(list, "PLAYTIME GIFTS", 4, UIKit.Colors.Success)
	local row = UIKit.Frame({
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Parent = list,
	})
	UIKit.Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	for index, reward in ipairs(Config.PlaytimeRewards) do
		local cell = UIKit.Frame({
			Size = UDim2.fromOffset(92, 146),
			BackgroundColor3 = UIKit.Colors.Panel,
			LayoutOrder = index,
			Parent = row,
		})
		UIKit.Corner(cell, 10)
		UIKit.Stroke(cell, UIKit.Colors.Success, 1.5, 0.4)
		local status = UIKit.Label({
			Size = UDim2.new(1, 0, 0, 24),
			Font = UIKit.Fonts.Black,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = cell,
		})
		local rewardLabel = UIKit.Label({
			Name = "Reward",
			Position = UDim2.fromOffset(4, 26),
			Size = UDim2.new(1, -8, 0, 68),
			Text = describe(reward),
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = cell,
		})
		local button = UIKit.Button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -12, 0, 34),
			Color = UIKit.Colors.Success,
			TextSize = 14,
			Text = "CLAIM",
		}, function()
			Remotes.Get("ClaimPlaytime"):FireServer(index)
		end)
		button.Parent = cell
		playtimeCells[index] = { Frame = cell, Button = button, Status = status, Reward = rewardLabel }
	end
end

local function buildGroupAndCodes(list: ScrollingFrame)
	sectionTitle(list, "BONUSES", 6, UIKit.Colors.Info)
	local row = UIKit.Frame({
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundTransparency = 1,
		LayoutOrder = 7,
		Parent = list,
	})
	UIKit.Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})

	local hasGroup = Config.GroupId and Config.GroupId > 0
	local codesWidth = hasGroup and 0.5 or 1

	if hasGroup then
		local groupCard = UIKit.Frame({
			Size = UDim2.new(0.5, -5, 1, 0),
			BackgroundColor3 = UIKit.Colors.Panel,
			LayoutOrder = 1,
			Parent = row,
		})
		UIKit.Corner(groupCard, 10)
		UIKit.Padding(groupCard, 10, 8)
		UIKit.Label({
			Size = UDim2.new(1, 0, 0, 36),
			Text = "Join our group for <font color='#6EFAE1'>" .. Config.GroupReward.Gems .. " Gems</font> and <font color='#AF69FF'>+10% coins</font> forever!",
			TextSize = 14,
			TextWrapped = true,
			Parent = groupCard,
		})
		local button = UIKit.Button({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 36),
			Color = UIKit.Colors.Info,
			TextSize = 15,
		}, function()
			Remotes.Get("ClaimGroup"):FireServer()
		end)
		button.Parent = groupCard
		groupButton = button
	end

	local codesCard = UIKit.Frame({
		Size = UDim2.new(codesWidth, hasGroup and -5 or 0, 1, 0),
		BackgroundColor3 = UIKit.Colors.Panel,
		LayoutOrder = 2,
		Parent = row,
	})
	UIKit.Corner(codesCard, 10)
	UIKit.Padding(codesCard, 10, 8)
	UIKit.Label({
		Size = UDim2.new(1, 0, 0, 30),
		Text = "Redeem a <font color='#FFC400'>CODE</font> (find them on our socials!)",
		TextSize = 14,
		TextWrapped = true,
		Parent = codesCard,
	})
	codeBox = UIKit.Create("TextBox", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, -112, 0, 36),
		BackgroundColor3 = UIKit.Colors.PanelDark,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		PlaceholderText = "Enter code...",
		PlaceholderColor3 = UIKit.Colors.Muted,
		Text = "",
		TextColor3 = UIKit.Colors.Text,
		Font = UIKit.Fonts.Bold,
		TextSize = 16,
		Parent = codesCard,
	})
	UIKit.Corner(codeBox, 8)
	local redeem = UIKit.Button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(102, 36),
		Color = UIKit.Colors.Accent,
		Text = "REDEEM",
		TextSize = 15,
	}, function()
		if redeeming then
			return
		end
		local code = codeBox.Text
		if #code == 0 then
			return
		end
		redeeming = true
		local ok, response = pcall(function()
			return Remotes.Get("RedeemCode"):InvokeServer(code)
		end)
		redeeming = false
		if ok and type(response) == "table" then
			UIController.Notify(tostring(response.message), response.ok and "reward" or "error")
			if response.ok then
				codeBox.Text = ""
			end
		else
			UIController.Notify("Couldn't redeem right now, try again.", "error")
		end
	end)
	redeem.Parent = codesCard
end

function RewardsUI.Init()
	window = UIController.CreateWindow("Rewards", "REWARDS", UDim2.fromOffset(680, 500), UIKit.Colors.Accent)
	local holder = UIKit.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIKit.Colors.PanelDark,
		Parent = window.Content,
	})
	UIKit.Corner(holder, 12)
	UIKit.Padding(holder, 12)
	local list = UIKit.ScrollList(holder, nil, 6)
	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end

	buildDaily(list)
	buildPlaytime(list)
	buildGroupAndCodes(list)

	window.OnOpen = refreshAll
	State.Changed:Connect(function(patch)
		if patch.Daily ~= nil or patch.PlaytimeClaimed ~= nil or patch.GroupClaimed ~= nil or patch.Gamepasses ~= nil or patch.ZonesUnlocked ~= nil or patch.Rebirths ~= nil then
			refreshAll()
		end
	end)

	UIController.AddSideButton("Rewards", "REWARDS", UIKit.Colors.Pink, 3, function()
		UIController.Toggle("Rewards")
	end)

	-- 1-second tick: countdowns + side-button badge
	task.spawn(function()
		while true do
			task.wait(1)
			UIController.SetBadge("Rewards", anythingClaimable())
			if window.IsOpen() then
				refreshDaily()
				refreshPlaytime()
			end
		end
	end)
end

return RewardsUI
