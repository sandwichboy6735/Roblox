--------------------------------------------------------------------------------
-- GamepassService - caches gamepass ownership and reacts to new purchases.
--------------------------------------------------------------------------------

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local GamepassService = {}
GamepassService.Changed = Signal.new() -- (player, passKey)

local function freeInStudio()
	return RunService:IsStudio() and Config.Debug.FreeGamepassesInStudio
end

function GamepassService.Owns(player: Player, passKey: string): boolean
	local profile = DataService:GetProfile(player)
	if not profile then
		return false
	end
	return profile.Runtime.Gamepasses[passKey] == true
end

local function replicate(player)
	local profile = DataService:GetProfile(player)
	if profile then
		DataService:Replicate(player, { Gamepasses = profile.Runtime.Gamepasses })
	end
end

function GamepassService.Grant(player: Player, passKey: string)
	local profile = DataService:GetProfile(player)
	if not profile or profile.Runtime.Gamepasses[passKey] then
		return
	end
	profile.Runtime.Gamepasses[passKey] = true
	replicate(player)
	GamepassService.Changed:Fire(player, passKey)
end

function GamepassService.Refresh(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end

	local owned = {}
	for key, pass in pairs(Config.Gamepasses) do
		if freeInStudio() then
			owned[key] = true
		elseif pass.Id and pass.Id > 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and result then
				owned[key] = true
			end
		end
	end

	profile.Runtime.Gamepasses = owned
	if owned.VIP then
		player:SetAttribute("VIP", true)
	end
	replicate(player)
	for key in pairs(owned) do
		GamepassService.Changed:Fire(player, key)
	end
end

function GamepassService.Init()
	DataService.ProfileLoaded:Connect(function(player)
		GamepassService.Refresh(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		local key, pass = Config.GetGamepassByProductId(passId)
		if not key then
			return
		end
		GamepassService.Grant(player, key)
		if key == "VIP" then
			player:SetAttribute("VIP", true)
		end
		local profile = DataService:GetProfile(player)
		if profile then
			profile.Data.Stats.RobuxSpent += pass.Price or 0
		end
		Remotes.Get("Notify"):FireClient(player, "Thanks for buying " .. pass.Name .. "!", "success")
	end)

	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("VIP", nil)
	end)
end

return GamepassService
