--------------------------------------------------------------------------------
-- PlayerService - leaderstats, playtime tracking, settings, welcome messages.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local PlayerService = {}

local ALLOWED_SETTINGS = { Music = true, SkipHatchAnimation = true }

local function setupLeaderstats(player: Player, data)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats

	leaderstats.Parent = player
	EconomyService.UpdateLeaderstats(player, data)
end

function PlayerService.Init()
	DataService.ProfileLoaded:Connect(function(player, profile)
		setupLeaderstats(player, profile.Data)

		task.delay(2, function()
			if not player:IsDescendantOf(Players) then
				return
			end
			if profile.Data.Stats.Joins <= 1 then
				Remotes.Get("Notify"):FireClient(player, "Welcome to " .. Config.GameName .. "! Walk into orbs to collect coins.", "info")
			else
				Remotes.Get("Notify"):FireClient(player, "Welcome back, " .. player.DisplayName .. "!", "info")
			end
		end)
	end)

	Remotes.Get("UpdateSetting").OnServerEvent:Connect(function(player, key, value)
		if type(key) ~= "string" or not ALLOWED_SETTINGS[key] or type(value) ~= "boolean" then
			return
		end
		local profile = DataService:GetProfile(player)
		if profile then
			profile.Data.Settings[key] = value
		end
	end)

	-- Playtime tracking (persisted stat; useful for analytics / future rewards)
	task.spawn(function()
		while true do
			task.wait(10)
			for _, profile in pairs(DataService.Profiles) do
				profile.Data.Stats.Playtime += 10
			end
		end
	end)
end

return PlayerService
