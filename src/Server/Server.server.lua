--------------------------------------------------------------------------------
-- Brainrot Obby - server bootstrap
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Services = script.Parent:WaitForChild("Services")

Remotes.Init()

-- Build the course first so services can reference checkpoints.
local CourseBuilder = require(Services.CourseBuilder)
CourseBuilder.Build()

local START_ORDER = {
	"DataService",
	"GamepassService",
	"EconomyService",
	"EventService",
	"MoverService",
	"StageService",
	"CoinService",
	"BrainrotService",
	"FragmentService",
	"RewardService",
	"QuestService",
	"ShopService",
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

local brainrots = 0
for _ in pairs(Config.Brainrots) do
	brainrots += 1
end
print(string.format("[%s] Server ready (v%d). %d stages, %d worlds, %d brainrots.", Config.GameName, Config.Version, Config.TotalStages(), #Config.Worlds, brainrots))
