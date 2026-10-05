--------------------------------------------------------------------------------
-- LeaderboardService - global OrderedDataStore leaderboards on physical boards.
--------------------------------------------------------------------------------

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.MapBuilder)

local LeaderboardService = {}

local PUSH_INTERVAL = 60
local REFRESH_INTERVAL = 90
local TOP_COUNT = 25
local MAX_ORDERED_VALUE = 9007199254740991

local BOARDS = {
	{ Key = "TotalCoins", Get = function(data) return data.Stats.TotalCoins end },
	{ Key = "Rebirths", Get = function(data) return data.Rebirths end },
	{ Key = "PetsHatched", Get = function(data) return data.Stats.PetsHatched end },
}

local stores = {}
local nameCache: { [number]: string } = {}

--------------------------------------------------------------------------------
-- Mock ordered store for Studio
--------------------------------------------------------------------------------

local MockOrdered = {}
MockOrdered.__index = MockOrdered

function MockOrdered.new()
	return setmetatable({ data = {} }, MockOrdered)
end

function MockOrdered:SetAsync(key, value)
	self.data[key] = value
end

function MockOrdered:GetSortedAsync(ascending, pageSize)
	local list = {}
	for key, value in pairs(self.data) do
		table.insert(list, { key = key, value = value })
	end
	table.sort(list, function(a, b)
		if ascending then
			return a.value < b.value
		end
		return a.value > b.value
	end)
	while #list > pageSize do
		table.remove(list)
	end
	return {
		GetCurrentPage = function()
			return list
		end,
	}
end

--------------------------------------------------------------------------------

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = ok and name or ("User " .. userId)
	nameCache[userId] = result
	return result
end

local function pushScores()
	for player, profile in pairs(DataService.Profiles) do
		for _, board in ipairs(BOARDS) do
			local value = math.clamp(math.floor(board.Get(profile.Data)), 0, MAX_ORDERED_VALUE)
			if value > 0 then
				pcall(function()
					stores[board.Key]:SetAsync(tostring(player.UserId), value)
				end)
			end
		end
	end
end

local function renderBoard(boardPart: Part, entries)
	local gui = boardPart:FindFirstChild("Board")
	local rows = gui and gui:FindFirstChild("Rows")
	if not rows then
		return
	end
	for _, child in ipairs(rows:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	if #entries == 0 then
		local status = Instance.new("TextLabel")
		status.BackgroundTransparency = 1
		status.Size = UDim2.new(1, 0, 0, 40)
		status.Font = Enum.Font.Gotham
		status.Text = "Be the first on the board!"
		status.TextColor3 = Color3.fromRGB(200, 200, 210)
		status.TextScaled = true
		status.Parent = rows
		return
	end

	for rank, entry in ipairs(entries) do
		local row = Instance.new("Frame")
		row.Name = "Row" .. rank
		row.LayoutOrder = rank
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundColor3 = rank % 2 == 0 and Color3.fromRGB(40, 42, 58) or Color3.fromRGB(48, 50, 68)
		row.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = row

		local rankColor = Color3.fromRGB(230, 230, 240)
		if rank == 1 then
			rankColor = Color3.fromRGB(255, 215, 0)
		elseif rank == 2 then
			rankColor = Color3.fromRGB(200, 200, 210)
		elseif rank == 3 then
			rankColor = Color3.fromRGB(205, 127, 50)
		end

		local rankLabel = Instance.new("TextLabel")
		rankLabel.BackgroundTransparency = 1
		rankLabel.Size = UDim2.new(0, 60, 1, 0)
		rankLabel.Font = Enum.Font.GothamBlack
		rankLabel.Text = "#" .. rank
		rankLabel.TextColor3 = rankColor
		rankLabel.TextScaled = true
		rankLabel.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.new(0, 66, 0, 0)
		nameLabel.Size = UDim2.new(1, -300, 1, 0)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = entry.Name
		nameLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local valueLabel = Instance.new("TextLabel")
		valueLabel.BackgroundTransparency = 1
		valueLabel.Position = UDim2.new(1, -230, 0, 0)
		valueLabel.Size = UDim2.new(0, 220, 1, 0)
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.Text = Util.FormatNumber(entry.Value)
		valueLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
		valueLabel.TextScaled = true
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Parent = row

		row.Parent = rows
	end
end

local function refreshBoards()
	local boards = MapBuilder.GetLeaderboardBoards()
	for _, board in ipairs(BOARDS) do
		local boardPart = boards[board.Key]
		if boardPart then
			local ok, page = pcall(function()
				return stores[board.Key]:GetSortedAsync(false, TOP_COUNT):GetCurrentPage()
			end)
			if ok and page then
				local entries = {}
				for _, item in ipairs(page) do
					local userId = tonumber(item.key)
					if userId then
						table.insert(entries, { Name = getName(userId), Value = item.value })
					end
				end
				renderBoard(boardPart, entries)
			end
		end
	end
end

function LeaderboardService.Init()
	for _, board in ipairs(BOARDS) do
		if DataService.UsingMock then
			stores[board.Key] = MockOrdered.new()
		else
			local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.LeaderboardStorePrefix .. board.Key)
			stores[board.Key] = ok and store or MockOrdered.new()
		end
	end

	task.spawn(function()
		task.wait(5)
		pushScores()
		refreshBoards()
		local lastPush = os.clock()
		local lastRefresh = os.clock()
		while true do
			task.wait(5)
			local now = os.clock()
			if now - lastPush >= PUSH_INTERVAL then
				lastPush = now
				pushScores()
			end
			if now - lastRefresh >= REFRESH_INTERVAL then
				lastRefresh = now
				refreshBoards()
			end
		end
	end)

	-- Push a player's final score when they leave.
	DataService.ProfileReleasing:Connect(function(player, profile)
		for _, board in ipairs(BOARDS) do
			local value = math.clamp(math.floor(board.Get(profile.Data)), 0, MAX_ORDERED_VALUE)
			if value > 0 then
				task.spawn(pcall, function()
					stores[board.Key]:SetAsync(tostring(player.UserId), value)
				end)
			end
		end
	end)
end

return LeaderboardService
