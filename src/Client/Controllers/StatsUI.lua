--------------------------------------------------------------------------------
-- StatsUI - the player's numbers: stages, deaths, coins, fragments, best run.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)

local StatsUI = {}

local window
local rows: { { Label: TextLabel, Get: () -> string } } = {}

local function fragmentsFound(): number
	local found = 0
	for _ in pairs(State.Get("Fragments", {})) do
		found += 1
	end
	return found
end

local function ownedCount(): number
	local count = 0
	for _ in pairs(State.Get("Owned", {})) do
		count += 1
	end
	return count
end

local STATS = {
	{ Name = "Current stage", Get = function() return tostring(State.Get("Stage", 1)) .. " / " .. Config.TotalStages() end },
	{ Name = "Best stage ever", Get = function()
		local best = State.Get("Stats", {}).BestStage or 1
		local total = Config.TotalStages()
		return if best > total then string.format("%d (prestige %d)", (best - 1) % total + 1, (best - 1) // total) else tostring(best)
	end },
	{ Name = "Prestige", Get = function() return tostring(State.Get("Prestige", 0)) end },
	{ Name = "Fastest full run", Get = function()
		local best = State.Get("Stats", {}).BestTime or 0
		return if best > 0 then Util.FormatTime(best) else "not yet"
	end },
	{ Name = "Deaths", Get = function() return Util.FormatCommas(State.Get("Stats", {}).Deaths or 0) end },
	{ Name = "Coins collected", Get = function() return Util.FormatCommas(State.Get("Stats", {}).CoinsCollected or 0) end },
	{ Name = "Total coins earned", Get = function() return Util.FormatNumber(State.Get("Stats", {}).TotalCoins or 0) end },
	{ Name = "Stages skipped", Get = function() return tostring(State.Get("Stats", {}).StagesSkipped or 0) end },
	{ Name = "Brainrots owned", Get = function() return ownedCount() .. " / " .. #Config.SortedBrainrots() end },
	{ Name = "Fragments found", Get = function() return fragmentsFound() .. " / " .. Config.Fragments.Count end },
	{ Name = "Time played", Get = function() return Util.FormatTime(State.Get("Stats", {}).Playtime or 0) end },
}

local function refresh()
	if not window or not window.IsOpen() then
		return
	end
	for _, row in ipairs(rows) do
		row.Label.Text = row.Get()
	end
end

function StatsUI.Init()
	window = UIController.CreateWindow("Stats", "MY STATS", UDim2.fromOffset(460, 520), UIKit.Colors.Purple)
	local holder = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.Colors.PanelDark, Parent = window.Content })
	UIKit.Corner(holder, 12)
	UIKit.Padding(holder, 10)
	local list = UIKit.ScrollList(holder, nil, 6)
	for order, stat in ipairs(STATS) do
		local row = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = UIKit.Colors.Panel, LayoutOrder = order, Parent = list })
		UIKit.Corner(row, 8)
		UIKit.Label({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.55, 0, 1, 0), Text = stat.Name, TextSize = 16, TextColor3 = UIKit.Colors.Muted, Parent = row })
		local value = UIKit.Label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0.45, 0, 1, 0), Font = UIKit.Fonts.Display, TextSize = 18, TextColor3 = UIKit.Colors.Accent, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		table.insert(rows, { Label = value, Get = stat.Get })
	end
	window.OnOpen = refresh
	State.Changed:Connect(refresh)
	-- opened from the Settings window (keeps the side menu short)
end

return StatsUI
