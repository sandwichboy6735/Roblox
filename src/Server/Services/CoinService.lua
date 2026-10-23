--------------------------------------------------------------------------------
-- CoinService - floating coins on the stages. Each coin can be taken once per
-- player every Config.Coins.RespawnSeconds; the client hides it locally and
-- the server validates distance and timing.
--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimiter = require(script.Parent.RateLimiter)

local CoinService = {}

local coins: { [string]: BasePart } = {}
local taken: { [Player]: { [string]: number } } = {} -- coinId -> os.clock() when taken

local function magnetRange(player: Player): number
	local profile = DataService:GetProfile(player)
	local def = profile and Config.Brainrots[profile.Data.Equipped]
	if def and def.Perk == "Magnet" then
		return def.Value
	end
	return 0
end

local function onCollect(player: Player, coinId: any)
	if type(coinId) ~= "string" then
		return
	end
	local coin = coins[coinId]
	local profile = DataService:GetProfile(player)
	if not coin or not profile then
		return
	end
	local record = taken[player]
	if not record then
		record = {}
		taken[player] = record
	end
	local now = os.clock()
	if record[coinId] and now - record[coinId] < Config.Coins.RespawnSeconds then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	if (root.Position - coin.Position).Magnitude > Config.Coins.MaxPickupDistance + magnetRange(player) then
		return
	end
	if not RateLimiter.Allow(player, "Coin", 10, 5) then
		return
	end
	record[coinId] = now
	local stage = coin:GetAttribute("Stage")
	local value = Config.GetCoinValue(if type(stage) == "number" then stage else 1)
	local amount = EconomyService.AddCoins(player, value, true)
	profile.Data.Stats.CoinsCollected += 1
	Remotes.Get("CoinTaken"):FireClient(player, coinId, amount)
end

function CoinService.Init()
	for _, coin in ipairs(CollectionService:GetTagged("Coin")) do
		local id = coin:GetAttribute("CoinId")
		if type(id) == "string" and coin:IsA("BasePart") then
			coins[id] = coin
		end
	end
	Remotes.Get("CollectCoin").OnServerEvent:Connect(onCollect)
	Players.PlayerRemoving:Connect(function(player)
		taken[player] = nil
	end)
end

return CoinService
