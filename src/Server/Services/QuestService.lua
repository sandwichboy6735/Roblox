--------------------------------------------------------------------------------
-- QuestService - three daily quests per player plus a bonus for all three.
-- Progress is measured from Stats, so no gameplay code needs quest hooks.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.RateLimiter)
local RewardService = require(script.Parent.RewardService)

local QuestService = {}

local function notify(player: Player, message: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, message, kind or "info")
end

-- Starts a fresh set of quests when the UTC day changes.
local function ensureToday(player: Player, profile)
	local data = profile.Data
	local quests = data.Quests
	local today = Util.DayNumber(os.time())
	if quests.Day == today and #quests.Ids > 0 then
		return
	end
	quests.Day = today
	quests.Ids = Config.PickQuests(today, player.UserId)
	quests.Baseline = {}
	for _, id in ipairs(quests.Ids) do
		local quest = Config.GetQuest(id)
		if quest then
			quests.Baseline[quest.Stat] = data.Stats[quest.Stat] or 0
		end
	end
	quests.Claimed = {}
	quests.BonusClaimed = false
	DataService:Replicate(player, { Quests = quests })
end

function QuestService.GetProgress(profile, quest): number
	local data = profile.Data
	local raw = (data.Stats[quest.Stat] or 0) - (data.Quests.Baseline[quest.Stat] or 0)
	return math.floor(raw / (quest.Scale or 1))
end

function QuestService.Claim(player: Player, slot: number)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	ensureToday(player, profile)
	local quests = profile.Data.Quests
	local id = quests.Ids[slot]
	local quest = id and Config.GetQuest(id)
	if not quest then
		return
	end
	if quests.Claimed[id] then
		return
	end
	if QuestService.GetProgress(profile, quest) < quest.Goal then
		notify(player, "That quest isn't finished yet!", "error")
		return
	end
	quests.Claimed[id] = true
	local summary = RewardService.Grant(player, quest.Reward, 1)
	notify(player, "Quest complete! " .. summary, "reward")

	local all = true
	for _, questId in ipairs(quests.Ids) do
		if not quests.Claimed[questId] then
			all = false
		end
	end
	if all and not quests.BonusClaimed then
		quests.BonusClaimed = true
		local bonus = RewardService.Grant(player, Config.Quests.BonusReward, 1)
		notify(player, "All daily quests done! Bonus: " .. bonus, "reward")
	end
	DataService:Replicate(player, { Quests = quests })
end

function QuestService.Init()
	DataService.ProfileLoaded:Connect(function(player, profile)
		ensureToday(player, profile)
	end)

	Remotes.Get("ClaimQuest").OnServerEvent:Connect(function(player, slot)
		if type(slot) == "number" and slot == math.floor(slot) and RateLimiter.Allow(player, "ClaimQuest", 4, 1) then
			QuestService.Claim(player, slot)
		end
	end)

	-- Roll quests over at midnight UTC for players who stay online.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService:GetProfile(player)
				if profile then
					ensureToday(player, profile)
				end
			end
		end
	end)
end

return QuestService
