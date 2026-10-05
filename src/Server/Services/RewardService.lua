--------------------------------------------------------------------------------
-- RewardService - daily streak, playtime chests, group reward.
-- These are the retention hooks that bring players back tomorrow.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local Codes = require(script.Parent.Parent:WaitForChild("Codes"))
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.RateLimiter)
local GamepassService = require(script.Parent.GamepassService)
local EconomyService = require(script.Parent.EconomyService)
local PetService = require(script.Parent.PetService)

local RewardService = {}

local function notify(player: Player, message: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, message, kind or "info")
end

-- Grants a reward table { Coins?, Gems?, Pet? } and returns a description.
local function grant(player: Player, reward, multiplier: number): string
	local parts = {}
	if reward.Coins then
		local amount = EconomyService.AddCoins(player, EconomyService.ScaleCoins(player, reward.Coins) * multiplier, false)
		table.insert(parts, Util.FormatNumber(amount) .. " Coins")
	end
	if reward.Gems then
		local amount = EconomyService.AddGems(player, reward.Gems * multiplier)
		table.insert(parts, amount .. " Gems")
	end
	if reward.Pet then
		local petData = PetService.AddPet(player, reward.Pet)
		if petData then
			table.insert(parts, reward.Pet .. " pet")
		else
			-- Storage full: convert to gems so the player never loses value.
			EconomyService.AddGems(player, 100)
			table.insert(parts, "100 Gems (pet storage full)")
		end
	end
	if reward.Boost then
		EconomyService.ApplyBoost(player, reward.Boost.Type, reward.Boost.Mult, reward.Boost.Duration)
		table.insert(parts, string.format("x%s %s boost (%s)", tostring(reward.Boost.Mult), reward.Boost.Type, Util.FormatTime(reward.Boost.Duration)))
	end
	return table.concat(parts, " + ")
end

--------------------------------------------------------------------------------
-- Daily
--------------------------------------------------------------------------------

function RewardService.ClaimDaily(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local state = Util.ComputeDaily(data.Daily, os.time(), #Config.DailyRewards)
	if not state.Available then
		notify(player, "Come back tomorrow for your next daily reward!", "error")
		return
	end

	data.Daily.Streak = state.NextStreak
	data.Daily.LastClaim = os.time()

	local reward = Config.DailyRewards[state.NextDay]
	local multiplier = GamepassService.Owns(player, "VIP") and Config.Gamepasses.VIP.DailyRewardMultiplier or 1
	local summary = grant(player, reward, multiplier)

	DataService:Replicate(player, { Daily = data.Daily })
	notify(player, string.format("Day %d reward claimed: %s", state.NextDay, summary), "reward")
end

--------------------------------------------------------------------------------
-- Playtime
--------------------------------------------------------------------------------

function RewardService.ClaimPlaytime(player: Player, index: number)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local reward = Config.PlaytimeRewards[index]
	if not reward then
		return
	end
	local runtime = profile.Runtime
	if runtime.PlaytimeClaimed[tostring(index)] then
		return
	end
	local elapsed = os.time() - runtime.SessionStart
	if elapsed < reward.Minutes * 60 then
		notify(player, "Keep playing! " .. Util.FormatTime(reward.Minutes * 60 - elapsed) .. " left", "error")
		return
	end

	runtime.PlaytimeClaimed[tostring(index)] = true
	local summary = grant(player, reward, 1)
	DataService:Replicate(player, { PlaytimeClaimed = runtime.PlaytimeClaimed })
	notify(player, "Playtime reward: " .. summary, "reward")
end

--------------------------------------------------------------------------------
-- Group
--------------------------------------------------------------------------------

local function refreshGroup(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local inGroup = false
	if Config.GroupId and Config.GroupId > 0 then
		local ok, result = pcall(function()
			return (player :: any):IsInGroupAsync(Config.GroupId)
		end)
		if not ok then
			-- Older engine builds: fall back to the legacy API.
			ok, result = pcall(function()
				return (player :: any):IsInGroup(Config.GroupId)
			end)
		end
		inGroup = ok and result == true
	end
	profile.Runtime.InGroup = inGroup
	DataService:Replicate(player, { InGroup = inGroup })
	EconomyService.RefreshMultiplier(player)
end

local claimingGroup: { [Player]: boolean } = {}

function RewardService.ClaimGroup(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile or profile.Data.GroupClaimed or claimingGroup[player] then
		return
	end
	if not RateLimiter.Allow(player, "ClaimGroup", 1, 0.2) then
		return
	end
	-- refreshGroup yields on a web call; the flag stops parallel claims meanwhile.
	claimingGroup[player] = true
	refreshGroup(player)
	claimingGroup[player] = nil
	if DataService:GetProfile(player) ~= profile or profile.Data.GroupClaimed then
		return
	end
	if not profile.Runtime.InGroup then
		notify(player, "Join our Roblox group, then rejoin the game to claim!", "error")
		return
	end
	profile.Data.GroupClaimed = true
	EconomyService.AddGems(player, Config.GroupReward.Gems)
	DataService:Replicate(player, { GroupClaimed = true })
	notify(player, "Thanks for joining the group! +" .. Config.GroupReward.Gems .. " Gems and +10% coins forever", "reward")
end

--------------------------------------------------------------------------------
-- Promo codes
--------------------------------------------------------------------------------

function RewardService.RedeemCode(player: Player, rawCode: string)
	local profile = DataService:GetProfile(player)
	if not profile then
		return { ok = false, message = "Data not loaded yet" }
	end
	if not RateLimiter.Allow(player, "RedeemCode", 3, 0.5) then
		return { ok = false, message = "Slow down!" }
	end

	local code = string.upper((rawCode:gsub("%s+", "")))
	if #code == 0 or #code > 32 then
		return { ok = false, message = "Invalid code" }
	end
	local reward = Codes[code]
	if not reward then
		return { ok = false, message = "Invalid code" }
	end
	if reward.Expires and os.time() > reward.Expires then
		return { ok = false, message = "This code has expired" }
	end
	local redeemed = profile.Data.RedeemedCodes
	if redeemed[code] then
		return { ok = false, message = "You already redeemed this code" }
	end

	redeemed[code] = true
	local summary = grant(player, reward, 1)
	return { ok = true, message = "Code redeemed: " .. summary }
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function RewardService.Init()
	DataService.ProfileLoaded:Connect(function(player)
		refreshGroup(player)
		-- Remind returning players about their daily reward.
		local profile = DataService:GetProfile(player)
		if profile then
			local state = Util.ComputeDaily(profile.Data.Daily, os.time(), #Config.DailyRewards)
			if state.Available then
				task.delay(6, function()
					if player:IsDescendantOf(Players) then
						notify(player, "Your daily reward is ready! Open REWARDS to claim it.", "reward")
					end
				end)
			end
		end
	end)

	Remotes.Get("ClaimDaily").OnServerEvent:Connect(function(player)
		if RateLimiter.Allow(player, "ClaimDaily", 2, 0.5) then
			RewardService.ClaimDaily(player)
		end
	end)
	Remotes.Get("ClaimPlaytime").OnServerEvent:Connect(function(player, index)
		if type(index) == "number" and RateLimiter.Allow(player, "ClaimPlaytime", 6, 2) then
			RewardService.ClaimPlaytime(player, index)
		end
	end)
	Remotes.Get("ClaimGroup").OnServerEvent:Connect(RewardService.ClaimGroup)

	Remotes.Get("RedeemCode").OnServerInvoke = function(player, code)
		if type(code) ~= "string" then
			return { ok = false, message = "Invalid code" }
		end
		return RewardService.RedeemCode(player, code)
	end

	Players.PlayerRemoving:Connect(function(player)
		claimingGroup[player] = nil
	end)
end

return RewardService
