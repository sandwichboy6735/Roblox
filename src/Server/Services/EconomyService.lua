--------------------------------------------------------------------------------
-- EconomyService - coins, gems, multipliers and timed boosts.
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
	local coins = leaderstats:FindFirstChild("Coins")
	if coins then
		coins.Value = Util.FormatNumber(data.Coins)
	end
	local rebirths = leaderstats:FindFirstChild("Rebirths")
	if rebirths then
		rebirths.Value = data.Rebirths
	end
end
EconomyService.UpdateLeaderstats = updateLeaderstats

--------------------------------------------------------------------------------
-- Boosts
--------------------------------------------------------------------------------

function EconomyService.GetBoost(player: Player, boostType: string): number
	local profile = DataService:GetProfile(player)
	if not profile then
		return 1
	end
	local boost = profile.Data.Boosts[boostType]
	if boost and (boost.ExpiresAt or 0) > os.time() then
		return boost.Mult or 1
	end
	return 1
end

function EconomyService.ApplyBoost(player: Player, boostType: string, mult: number, duration: number)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local boosts = profile.Data.Boosts
	local existing = boosts[boostType]
	local base = os.time()
	if existing and (existing.ExpiresAt or 0) > base and (existing.Mult or 1) >= mult then
		base = existing.ExpiresAt -- extend instead of overwrite
	end
	boosts[boostType] = { Mult = mult, ExpiresAt = base + duration }
	DataService:Replicate(player, { Boosts = boosts })
	EconomyService.RefreshMultiplier(player)

	task.delay(boosts[boostType].ExpiresAt - os.time() + 1, function()
		if DataService:GetProfile(player) == profile then
			EconomyService.RefreshMultiplier(player)
			DataService:Replicate(player, { Boosts = profile.Data.Boosts })
		end
	end)
end

--------------------------------------------------------------------------------
-- Multipliers
--------------------------------------------------------------------------------

function EconomyService.GetMultiplierInfo(player: Player)
	local info = { Pets = 1, Rebirth = 1, Gamepass = 1, Group = 1, Boost = 1, Total = 1 }
	local profile = DataService:GetProfile(player)
	if not profile then
		return info
	end
	local data = profile.Data

	-- Only the best `slots` equipped pets count, even if saved data says more.
	local equippedMults = {}
	for _, petData in ipairs(data.Pets) do
		if petData.Equipped then
			local def = Config.Pets[petData.Type]
			if def then
				table.insert(equippedMults, def.Multiplier)
			end
		end
	end
	table.sort(equippedMults, function(a, b)
		return a > b
	end)
	local slots = profile.Runtime.PetSlots or Config.BasePetSlots
	local petMult = 1
	for index = 1, math.min(#equippedMults, slots) do
		petMult += equippedMults[index] - 1
	end
	info.Pets = petMult
	info.Rebirth = 1 + data.Rebirths * Config.Rebirth.MultiplierPerRebirth

	local passMult = 1
	if GamepassService.Owns(player, "DoubleCoins") then
		passMult *= 2
	end
	if GamepassService.Owns(player, "VIP") then
		passMult *= Config.Gamepasses.VIP.CoinMultiplier
	end
	info.Gamepass = passMult
	info.Group = profile.Runtime.InGroup and Config.GroupReward.Multiplier or 1
	info.Boost = EconomyService.GetBoost(player, "Coins")
	info.Total = info.Pets * info.Rebirth * info.Gamepass * info.Group * info.Boost
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

function EconomyService.GetLuckMultiplier(player: Player): number
	local luck = 1
	if GamepassService.Owns(player, "Lucky") then
		luck *= Config.Gamepasses.Lucky.LuckMultiplier
	end
	luck *= EconomyService.GetBoost(player, "Luck")
	return luck
end

-- Scales a base coin amount to the player's progress so rewards and coin packs
-- remain meaningful in late zones.
function EconomyService.ScaleCoins(player: Player, baseAmount: number): number
	local profile = DataService:GetProfile(player)
	if not profile then
		return baseAmount
	end
	return Config.ScaleCoins(baseAmount, profile.Data.ZonesUnlocked, profile.Data.Rebirths)
end

--------------------------------------------------------------------------------
-- Currency
--------------------------------------------------------------------------------

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

function EconomyService.AddGems(player: Player, amount: number): number
	local profile = DataService:GetProfile(player)
	if not profile or amount <= 0 then
		return 0
	end
	amount = math.floor(amount)
	profile.Data.Gems = clampCurrency(profile.Data.Gems + amount)
	DataService:Replicate(player, { Gems = profile.Data.Gems })
	return amount
end

function EconomyService.SpendGems(player: Player, amount: number): boolean
	local profile = DataService:GetProfile(player)
	if not profile or amount < 0 then
		return false
	end
	if profile.Data.Gems < amount then
		return false
	end
	profile.Data.Gems = clampCurrency(profile.Data.Gems - amount)
	DataService:Replicate(player, { Gems = profile.Data.Gems })
	return true
end

function EconomyService.Init()
	DataService.ProfileLoaded:Connect(function(player, profile)
		EconomyService.RefreshMultiplier(player)
		-- Boosts bought in an earlier session: refresh the UI when they run out.
		local now = os.time()
		for _, boost in pairs(profile.Data.Boosts) do
			local remaining = (boost.ExpiresAt or 0) - now
			if remaining > 0 then
				task.delay(remaining + 1, function()
					if DataService:GetProfile(player) == profile then
						EconomyService.RefreshMultiplier(player)
						DataService:Replicate(player, { Boosts = profile.Data.Boosts })
					end
				end)
			end
		end
	end)
	GamepassService.Changed:Connect(function(player)
		EconomyService.RefreshMultiplier(player)
	end)
end

return EconomyService
