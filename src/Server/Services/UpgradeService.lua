--------------------------------------------------------------------------------
-- UpgradeService - permanent upgrades bought with gems (speed, magnet, coins).
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimiter = require(script.Parent.RateLimiter)

local UpgradeService = {}

local function notify(player: Player, message: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, message, kind or "info")
end

function UpgradeService.GetLevel(player: Player, key: string): number
	local profile = DataService:GetProfile(player)
	if not profile then
		return 0
	end
	return profile.Data.Upgrades[key] or 0
end

-- Bonus value of an upgrade for this player (e.g. +6 speed at level 3).
function UpgradeService.GetBonus(player: Player, key: string): number
	local upgrade = Config.Upgrades[key]
	if not upgrade then
		return 0
	end
	return UpgradeService.GetLevel(player, key) * upgrade.PerLevel
end

local function applySpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.BaseWalkSpeed + UpgradeService.GetBonus(player, "WalkSpeed")
	end
end

function UpgradeService.Buy(player: Player, key: string)
	local profile = DataService:GetProfile(player)
	local upgrade = Config.Upgrades[key]
	if not profile or not upgrade then
		return
	end
	local data = profile.Data
	local level = data.Upgrades[key] or 0
	local cost = upgrade.Costs[level + 1]
	if not cost then
		notify(player, upgrade.Name .. " is already maxed out!", "error")
		return
	end
	if not EconomyService.SpendGems(player, cost) then
		notify(player, "You need " .. (cost - data.Gems) .. " more gems for this upgrade.", "error")
		return
	end
	data.Upgrades[key] = level + 1
	DataService:Replicate(player, { Upgrades = data.Upgrades })
	if key == "WalkSpeed" then
		applySpeed(player)
	elseif key == "CoinBoost" then
		EconomyService.RefreshMultiplier(player)
	end
	notify(player, string.format("%s upgraded to level %d!", upgrade.Name, level + 1), "success")
end

function UpgradeService.Init()
	EconomyService.SetUpgradeMultiplierSource(function(player: Player)
		return 1 + UpgradeService.GetBonus(player, "CoinBoost")
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			applySpeed(player)
		end)
		if player.Character then
			applySpeed(player)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	DataService.ProfileLoaded:Connect(function(player)
		applySpeed(player)
		EconomyService.RefreshMultiplier(player)
	end)

	Remotes.Get("BuyUpgrade").OnServerEvent:Connect(function(player, key)
		if type(key) == "string" and Config.Upgrades[key] and RateLimiter.Allow(player, "BuyUpgrade", 3, 1) then
			UpgradeService.Buy(player, key)
		end
	end)
end

return UpgradeService
