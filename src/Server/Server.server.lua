--------------------------------------------------------------------------------
-- Hatch Legends - server bootstrap
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Services = script.Parent:WaitForChild("Services")

Remotes.Init()

-- Build the world first so services can reference zone positions.
local MapBuilder = require(Services.MapBuilder)
MapBuilder.Build()

local START_ORDER = {
	"DataService",
	"GamepassService",
	"ComplianceService",
	"EconomyService",
	"PetService",
	"ZoneService",
	"RebirthService",
	"RewardService",
	"QuestService",
	"EventService",
	"UpgradeService",
	"ShopService",
	"CollectibleService",
	"BreakableService",
	"LeaderboardService",
	"PlayerService",
}

for _, serviceName in ipairs(START_ORDER) do
	local module = Services:FindFirstChild(serviceName)
	if not module then
		warn("[Server] Missing service module: " .. serviceName)
		continue
	end
	local service = require(module)
	if type(service.Init) == "function" then
		local ok, err = pcall(service.Init)
		if not ok then
			warn("[Server] " .. serviceName .. ".Init failed: " .. tostring(err))
		end
	end
end

print(string.format("[%s] Server ready (v%d). %d zones, %d pets, %d eggs.", Config.GameName, Config.Version, #Config.Zones, (function()
	local count = 0
	for _ in pairs(Config.Pets) do
		count += 1
	end
	return count
end)(), (function()
	local count = 0
	for _ in pairs(Config.Eggs) do
		count += 1
	end
	return count
end)()))
