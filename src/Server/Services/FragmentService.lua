--------------------------------------------------------------------------------
-- FragmentService - the hidden Brainrot Fragments. Each is collected once per
-- player forever; finding all of them unlocks the secret brainrot.
--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local BrainrotService = require(script.Parent.BrainrotService)
local RateLimiter = require(script.Parent.RateLimiter)

local FragmentService = {}

local fragments: { [string]: BasePart } = {}

local function notify(player: Player, message: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, message, kind or "info")
end

local function count(data): number
	local found = 0
	for _ in pairs(data.Fragments) do
		found += 1
	end
	return found
end

local function onCollect(player: Player, id: any)
	if type(id) ~= "string" then
		return
	end
	local shard = fragments[id]
	local profile = DataService:GetProfile(player)
	if not shard or not profile or profile.Data.Fragments[id] then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - shard.Position).Magnitude > Config.Coins.MaxPickupDistance then
		return
	end
	if not RateLimiter.Allow(player, "Fragment", 3, 1) then
		return
	end
	local data = profile.Data
	data.Fragments[id] = true
	data.Stats.FragmentsFound += 1
	local reward = EconomyService.AddCoins(player, Config.Fragments.Reward, true)
	DataService:Replicate(player, { Fragments = data.Fragments, Stats = data.Stats })
	Remotes.Get("FragmentTaken"):FireClient(player, id, reward)
	local found = count(data)
	if found >= Config.Fragments.Count then
		for name, def in pairs(Config.Brainrots) do
			if def.Unlock and def.Unlock.Fragments then
				BrainrotService.Give(player, name)
			end
		end
		notify(player, "You found EVERY fragment! The secret brainrot is yours.", "reward")
	else
		notify(player, string.format("Brainrot Fragment found! (%d/%d) +%d coins", found, Config.Fragments.Count, reward), "reward")
	end
end

function FragmentService.Init()
	for _, shard in ipairs(CollectionService:GetTagged("Fragment")) do
		local id = shard:GetAttribute("FragmentId")
		if type(id) == "string" and shard:IsA("BasePart") then
			fragments[id] = shard
		end
	end
	Remotes.Get("CollectFragment").OnServerEvent:Connect(onCollect)
end

return FragmentService
