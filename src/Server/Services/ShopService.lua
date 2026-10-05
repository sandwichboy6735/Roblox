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
local RebirthService = require(script.Parent.RebirthService)
local ComplianceService = require(script.Parent.ComplianceService)

local ShopService = {}

local MAX_RECEIPT_HISTORY = 60

local function notify(player: Player, message: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, message, kind or "info")
end

local function grantProduct(player: Player, productKey: string, product)
	local grantInfo = product.Grant
	local summary = {}

	if grantInfo.CoinMinutes then
		local amount = EconomyService.AddCoins(player, EconomyService.CoinsForMinutes(player, grantInfo.CoinMinutes), false)
		table.insert(summary, Util.FormatNumber(amount) .. " Coins")
	end
	if grantInfo.Gems then
		EconomyService.AddGems(player, grantInfo.Gems)
		table.insert(summary, grantInfo.Gems .. " Gems")
	end
	if grantInfo.Boost then
		EconomyService.ApplyBoost(player, grantInfo.Boost.Type, grantInfo.Boost.Mult, grantInfo.Boost.Duration)
		table.insert(summary, product.Name)
	end
	if grantInfo.Rebirths then
		RebirthService.GrantRebirths(player, grantInfo.Rebirths)
		table.insert(summary, "+" .. grantInfo.Rebirths .. " Rebirth")
	end

	notify(player, "Purchased " .. product.Name .. ": " .. table.concat(summary, ", "), "success")
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if DataService.UsingMock and not RunService:IsStudio() then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- never confirm into a fake store
	end
	-- Receipts are often redelivered right as the player joins, while their data
	-- is still loading, so wait for it rather than bouncing the receipt.
	local profile = DataService:WaitForProfile(player, 60)
	if not profile or not profile.Loaded then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchases = profile.Data.Purchases
	for _, id in ipairs(purchases) do
		if id == receiptInfo.PurchaseId then
			if profile.UnsavedReceipts[receiptInfo.PurchaseId] then
				-- Granted earlier but the save failed: only confirm once it's saved.
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
	if ComplianceService.IsPurchaseBlocked(player, productKey) then
		-- The shop hides these for restricted regions. Robux were already charged,
		-- so still deliver, but log it so other prompt paths can be found.
		warn("[ShopService] Restricted product " .. productKey .. " purchased by " .. player.Name .. " outside the shop")
	end

	local ok, err = pcall(grantProduct, player, productKey, product)
	if not ok then
		warn("[ShopService] Failed to grant " .. productKey .. ": " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(purchases, receiptInfo.PurchaseId)
	while #purchases > MAX_RECEIPT_HISTORY do
		table.remove(purchases, 1)
	end
	profile.Data.Stats.RobuxSpent += receiptInfo.CurrencySpent or 0

	-- Persist before confirming so the receipt is never granted twice.
	profile.UnsavedReceipts[receiptInfo.PurchaseId] = true
	local saved = DataService:Save(player)
	if not saved then
		-- Grant is in memory; a retry hits the dedupe list above and re-saves.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.Init()
	MarketplaceService.ProcessReceipt = processReceipt
end

return ShopService
