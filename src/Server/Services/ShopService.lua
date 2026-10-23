--------------------------------------------------------------------------------
-- ShopService - Developer Product purchases (ProcessReceipt).
-- Idempotent: each PurchaseId is granted at most once, even across retries.
--------------------------------------------------------------------------------

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StageService = require(script.Parent.StageService)

local ShopService = {}

local MAX_RECEIPT_HISTORY = 60

local function notify(player: Player, message: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, message, kind or "info")
end

local function grantProduct(player: Player, product)
	local grantInfo = product.Grant
	if grantInfo.Coins then
		local amount = EconomyService.AddCoins(player, grantInfo.Coins, false)
		notify(player, "Purchased " .. product.Name .. ": +" .. Util.FormatNumber(amount) .. " Coins", "success")
	end
	if grantInfo.Skips then
		StageService.Skip(player, grantInfo.Skips)
	end
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if DataService.UsingMock and not RunService:IsStudio() then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- never confirm into a fake store
	end
	local profile = DataService:WaitForProfile(player, 60)
	if not profile or not profile.Loaded then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchases = profile.Data.Purchases
	for _, id in ipairs(purchases) do
		if id == receiptInfo.PurchaseId then
			if profile.UnsavedReceipts[receiptInfo.PurchaseId] then
				if DataService:Save(player) then
					return Enum.ProductPurchaseDecision.PurchaseGranted
				end
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	local productKey, product = Config.GetProductById(receiptInfo.ProductId)
	if not productKey or not product then
		warn("[ShopService] Receipt for unknown ProductId " .. tostring(receiptInfo.ProductId) .. " - add it to Config.Products")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(grantProduct, player, product)
	if not ok then
		warn("[ShopService] Failed to grant " .. productKey .. ": " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(purchases, receiptInfo.PurchaseId)
	while #purchases > MAX_RECEIPT_HISTORY do
		table.remove(purchases, 1)
	end
	profile.Data.Stats.RobuxSpent += receiptInfo.CurrencySpent or 0

	profile.UnsavedReceipts[receiptInfo.PurchaseId] = true
	local saved = DataService:Save(player)
	if not saved then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.Init()
	MarketplaceService.ProcessReceipt = processReceipt
end

return ShopService
