--------------------------------------------------------------------------------
-- RebirthService - prestige loop: reset coins + zones for a permanent multiplier.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local ZoneService = require(script.Parent.ZoneService)

local RebirthService = {}

local function notify(player: Player, message: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, message, kind or "info")
end

function RebirthService.GetCost(rebirths: number): number
	return Config.GetRebirthCost(rebirths)
end

function RebirthService.Rebirth(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local cost = RebirthService.GetCost(data.Rebirths)

	if Config.Rebirth.RequireAllZones and data.ZonesUnlocked < #Config.Zones then
		notify(player, "Unlock every zone before rebirthing!", "error")
		return
	end
	if data.Coins < cost then
		notify(player, "You need " .. Util.FormatNumber(cost - data.Coins) .. " more coins to rebirth", "error")
		return
	end

	data.Coins = 0
	data.ZonesUnlocked = 1
	data.Rebirths += 1
	data.Gems += Config.Rebirth.GemsReward

	DataService:Replicate(player, {
		Coins = data.Coins,
		ZonesUnlocked = data.ZonesUnlocked,
		Rebirths = data.Rebirths,
		Gems = data.Gems,
	})
	EconomyService.UpdateLeaderstats(player, data)
	EconomyService.RefreshMultiplier(player)
	ZoneService.Teleport(player, 1)
	notify(
		player,
		string.format("REBIRTH %d! Permanent x%.2f coins. +%d Gems", data.Rebirths, 1 + data.Rebirths * Config.Rebirth.MultiplierPerRebirth, Config.Rebirth.GemsReward),
		"reward"
	)
end

-- Used by the "Instant Rebirth" developer product: +rebirths with NO reset.
function RebirthService.GrantRebirths(player: Player, amount: number)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	profile.Data.Rebirths += amount
	DataService:Replicate(player, { Rebirths = profile.Data.Rebirths })
	EconomyService.UpdateLeaderstats(player, profile.Data)
	EconomyService.RefreshMultiplier(player)
end

function RebirthService.Init()
	Remotes.Get("Rebirth").OnServerEvent:Connect(function(player)
		RebirthService.Rebirth(player)
	end)
end

return RebirthService
