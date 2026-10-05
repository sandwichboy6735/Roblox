--------------------------------------------------------------------------------
-- ComplianceService - paid random items policy.
-- Asks Roblox whether each player's region restricts paid random items and
-- exposes the answer to the server (PolicyRestricted) and the client (shop UI).
--------------------------------------------------------------------------------

local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = require(script.Parent.DataService)

local ComplianceService = {}

local ATTEMPTS = 3

local function fetchRestricted(player: Player): boolean
	for attempt = 1, ATTEMPTS do
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if ok and type(info) == "table" then
			return info.ArePaidRandomItemsRestricted == true
		end
		if attempt < ATTEMPTS then
			task.wait(attempt)
		end
	end
	-- Could not confirm the player's policy: be conservative outside Studio.
	return not RunService:IsStudio()
end

-- True when this player must not be sold currency or luck for eggs.
function ComplianceService.IsRestricted(player: Player): boolean
	local profile = DataService:GetProfile(player)
	return profile ~= nil and profile.Runtime.PaidRandomRestricted == true
end

function ComplianceService.IsPurchaseBlocked(player: Player, itemKey: string): boolean
	return Config.RestrictedPurchases[itemKey] == true and ComplianceService.IsRestricted(player)
end

function ComplianceService.Init()
	DataService.ProfileLoaded:Connect(function(player, profile)
		local restricted = fetchRestricted(player)
		if DataService:GetProfile(player) ~= profile then
			return
		end
		profile.Runtime.PaidRandomRestricted = restricted
		DataService:Replicate(player, { PaidRandomRestricted = restricted })
	end)
end

return ComplianceService
