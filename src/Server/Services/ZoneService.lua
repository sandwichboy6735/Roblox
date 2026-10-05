--------------------------------------------------------------------------------
-- ZoneService - unlocking and teleporting between zones.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MapBuilder = require(script.Parent.MapBuilder)

local ZoneService = {}

local lastNotify: { [Player]: number } = {}

local function notify(player: Player, message: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, message, kind or "info")
end

function ZoneService.Teleport(player: Player, index: number)
	local character = player.Character
	if not character then
		return
	end
	local cframe = MapBuilder.GetZoneSpawn(index)
	if cframe then
		character:PivotTo(cframe + Vector3.new(0, 2, 0))
	end
end

function ZoneService.Unlock(player: Player, index: number)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local zone = Config.Zones[index]
	if not zone or index ~= data.ZonesUnlocked + 1 then
		return
	end

	if data.Coins < zone.Cost then
		local now = os.clock()
		if (lastNotify[player] or 0) + 2 < now then
			lastNotify[player] = now
			notify(player, "You need " .. Util.FormatNumber(zone.Cost - data.Coins) .. " more coins to unlock " .. zone.Name, "error")
		end
		return
	end

	if not EconomyService.SpendCoins(player, zone.Cost) then
		return
	end
	data.ZonesUnlocked = index
	DataService:Replicate(player, { ZonesUnlocked = index })
	notify(player, "Unlocked " .. zone.Name .. "!", "success")
	ZoneService.Teleport(player, index)
end

function ZoneService.Init()
	Remotes.Get("UnlockZone").OnServerEvent:Connect(function(player, index)
		if type(index) == "number" and index == math.floor(index) then
			ZoneService.Unlock(player, index)
		end
	end)

	Remotes.Get("TeleportZone").OnServerEvent:Connect(function(player, index)
		if type(index) ~= "number" then
			return
		end
		local profile = DataService:GetProfile(player)
		if profile and index >= 1 and index <= profile.Data.ZonesUnlocked then
			ZoneService.Teleport(player, index)
		end
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastNotify[player] = nil
	end)
end

return ZoneService
