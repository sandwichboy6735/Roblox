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
GamepassService.Refreshed = Signal.new() -- (player) after the join-time ownership check

local CHECK_ATTEMPTS = 3
local RECHECK_DELAY = 45

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

-- Returns true if the pass was newly granted.
function GamepassService.Grant(player: Player, passKey: string): boolean
	local profile = DataService:GetProfile(player)
	if not profile or profile.Runtime.Gamepasses[passKey] then
		return false
	end
	profile.Runtime.Gamepasses[passKey] = true
	if passKey == "VIP" then
		player:SetAttribute("VIP", true)
	end
	replicate(player)
	GamepassService.Changed:Fire(player, passKey)
	return true
end

-- nil = the lookup failed (try again later), otherwise true/false.
local function checkOwnership(player: Player, passId: number): boolean?
	for attempt = 1, CHECK_ATTEMPTS do
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok then
			return result == true
		end
		if attempt < CHECK_ATTEMPTS then
			task.wait(attempt)
		end
	end
	return nil
end

function GamepassService.Refresh(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end

	local failed = {}
	for key, pass in pairs(Config.Gamepasses) do
		if freeInStudio() then
			GamepassService.Grant(player, key)
		elseif pass.Id and pass.Id > 0 then
			local owns = checkOwnership(player, pass.Id)
			if DataService:GetProfile(player) ~= profile then
				return -- left while we were checking
			end
			if owns then
				-- Merge (never replace) so a pass bought during this check is kept.
				GamepassService.Grant(player, key)
			elseif owns == nil then
				table.insert(failed, key)
			end
		end
	end
	replicate(player)
	GamepassService.Refreshed:Fire(player)

	-- Roblox web lookups fail now and then: re-check failures later instead of
	-- leaving a paying player without their perks for the whole session.
	if #failed > 0 then
		task.delay(RECHECK_DELAY, function()
			if DataService:GetProfile(player) ~= profile then
				return
			end
			for _, key in ipairs(failed) do
				if checkOwnership(player, Config.Gamepasses[key].Id) then
					GamepassService.Grant(player, key)
				end
			end
		end)
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
		if not key or not pass then
			return
		end
		-- Exploiters can fake this event, so confirm the purchase with Roblox.
		-- (Studio test purchases don't create real ownership, so trust them there.)
		if not RunService:IsStudio() and checkOwnership(player, passId) ~= true then
			return
		end
		if GamepassService.Grant(player, key) then
			local profile = DataService:GetProfile(player)
			if profile then
				profile.Data.Stats.RobuxSpent += pass.Price or 0
			end
			Remotes.Get("Notify"):FireClient(player, "Thanks for buying " .. pass.Name .. "!", "success")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("VIP", nil)
	end)
end

return GamepassService
