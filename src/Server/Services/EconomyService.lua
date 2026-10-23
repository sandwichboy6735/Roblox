--------------------------------------------------------------------------------
-- EconomyService - coins and the coin multiplier.
-- Multiplier = prestige x gamepasses x group x equipped brainrot's Coin Boost.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local DataService = require(script.Parent.DataService)
local GamepassService = require(script.Parent.GamepassService)

local EconomyService = {}

local MAX_SAFE = 2 ^ 53

local function clampCurrency(value: number): number
	return math.clamp(math.floor(value), 0, MAX_SAFE)
end

local function updateLeaderstats(player: Player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local stage = leaderstats:FindFirstChild("Stage")
	if stage then
		stage.Value = data.Stage
	end
	local coins = leaderstats:FindFirstChild("Coins")
	if coins then
		coins.Value = Util.FormatNumber(data.Coins)
	end
	local prestige = leaderstats:FindFirstChild("Prestige")
	if prestige then
		prestige.Value = data.Prestige
	end
end
EconomyService.UpdateLeaderstats = updateLeaderstats

-- Injected by EventService (it requires this module, so requiring it here
-- would create a cycle).
local eventMultiplier: () -> number = function()
	return 1
end

function EconomyService.SetEventMultiplierSource(source: () -> number)
	eventMultiplier = source
end

function EconomyService.GetMultiplierInfo(player: Player)
	local info = { Prestige = 1, Gamepass = 1, Group = 1, Brainrot = 1, Event = 1, Total = 1 }
	local profile = DataService:GetProfile(player)
	if not profile then
		return info
	end
	local data = profile.Data
	info.Prestige = 1 + data.Prestige * Config.Prestige.CoinMultiplierPerPrestige
	local passMult = 1
	if GamepassService.Owns(player, "DoubleCoins") then
		passMult *= 2
	end
	if GamepassService.Owns(player, "VIP") then
		passMult *= Config.Gamepasses.VIP.CoinMultiplier
	end
	info.Gamepass = passMult
	info.Group = profile.Runtime.InGroup and Config.GroupReward.Multiplier or 1
	local brainrot = Config.Brainrots[data.Equipped]
	if brainrot and brainrot.Perk == "CoinBoost" then
		info.Brainrot = 1 + brainrot.Value
	end
	info.Event = eventMultiplier()
	info.Total = info.Prestige * info.Gamepass * info.Group * info.Brainrot * info.Event
	return info
end

function EconomyService.GetMultiplier(player: Player): number
	return EconomyService.GetMultiplierInfo(player).Total
end

function EconomyService.RefreshMultiplier(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local info = EconomyService.GetMultiplierInfo(player)
	profile.Runtime.Multiplier = info
	DataService:Replicate(player, { Multiplier = info })
end

-- Adds coins; with applyMultiplier the amount is scaled by the player's multiplier.
function EconomyService.AddCoins(player: Player, amount: number, applyMultiplier: boolean?): number
	local profile = DataService:GetProfile(player)
	if not profile or amount <= 0 then
		return 0
	end
	if applyMultiplier then
		amount *= EconomyService.GetMultiplier(player)
	end
	amount = math.max(1, math.floor(amount))
	local data = profile.Data
	data.Coins = clampCurrency(data.Coins + amount)
	data.Stats.TotalCoins = clampCurrency(data.Stats.TotalCoins + amount)
	DataService:Replicate(player, { Coins = data.Coins, Stats = data.Stats })
	updateLeaderstats(player, data)
	return amount
end

function EconomyService.SpendCoins(player: Player, amount: number): boolean
	local profile = DataService:GetProfile(player)
	if not profile or amount < 0 then
		return false
	end
	local data = profile.Data
	if data.Coins < amount then
		return false
	end
	data.Coins = clampCurrency(data.Coins - amount)
	DataService:Replicate(player, { Coins = data.Coins })
	updateLeaderstats(player, data)
	return true
end

function EconomyService.Init()
	DataService.ProfileLoaded:Connect(function(player)
		EconomyService.RefreshMultiplier(player)
	end)
	GamepassService.Changed:Connect(function(player)
		EconomyService.RefreshMultiplier(player)
	end)
end

return EconomyService
