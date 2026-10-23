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

local ALLOWED_SETTINGS = { Music = true, Effects = true, ShowOthers = true }

local function setupLeaderstats(player: Player, data)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Parent = leaderstats

	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats

	local prestige = Instance.new("IntValue")
	prestige.Name = "Prestige"
	prestige.Parent = leaderstats

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
				Remotes.Get("Notify"):FireClient(player, "Welcome to " .. Config.GameName .. "! Reach the glowing pad ahead.", "info")
			else
				Remotes.Get("Notify"):FireClient(player, "Welcome back, " .. player.DisplayName .. "! You're on stage " .. profile.Data.Stage .. ".", "info")
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

	task.spawn(function()
		while true do
			task.wait(10)
			for player, profile in pairs(DataService.Profiles) do
				profile.Data.Stats.Playtime += 10
				DataService:Replicate(player, { Stats = profile.Data.Stats })
			end
		end
	end)
end

return PlayerService
