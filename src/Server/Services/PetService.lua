--------------------------------------------------------------------------------
-- PetService - hatching, inventory, equipping. All validation is server-side.
--------------------------------------------------------------------------------

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local GamepassService = require(script.Parent.GamepassService)
local EconomyService = require(script.Parent.EconomyService)
local MapBuilder = require(script.Parent.MapBuilder)
local RateLimiter = require(script.Parent.RateLimiter)

local PetService = {}

local MAX_HATCH_DISTANCE = 40
local HATCH_COOLDOWN = 0.25
local lastHatch: { [Player]: number } = {}

local function notify(player: Player, message: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, message, kind or "info")
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

function PetService.GetSlotCount(player: Player): number
	local slots = Config.BasePetSlots
	if GamepassService.Owns(player, "ExtraPetSlots") then
		slots += Config.Gamepasses.ExtraPetSlots.Slots
	end
	if GamepassService.Owns(player, "VIP") then
		slots += Config.Gamepasses.VIP.ExtraPetSlots
	end
	return slots
end

local function countEquipped(data): number
	local count = 0
	for _, petData in ipairs(data.Pets) do
		if petData.Equipped then
			count += 1
		end
	end
	return count
end

local function findPet(data, petId: string)
	for index, petData in ipairs(data.Pets) do
		if petData.Id == petId then
			return petData, index
		end
	end
	return nil, nil
end

local function sync(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	-- Compact list of {n = name, t = tier} that every client renders.
	local equipped = {}
	for _, petData in ipairs(profile.Data.Pets) do
		if petData.Equipped then
			table.insert(equipped, { n = petData.Type, t = petData.Tier or 0 })
		end
	end
	local encoded = HttpService:JSONEncode(equipped)
	if player:GetAttribute("EquippedPets") ~= encoded then
		-- Replicates to every client, which rebuilds this player's pet models.
		player:SetAttribute("EquippedPets", encoded)
	end
	local slots = PetService.GetSlotCount(player)
	profile.Runtime.PetSlots = slots
	DataService:Replicate(player, { Pets = profile.Data.Pets, PetSlots = slots, Discovered = profile.Data.Discovered })
	EconomyService.RefreshMultiplier(player)
end
PetService.Sync = sync

local function rollPet(player: Player, egg)
	local luck = EconomyService.GetLuckMultiplier(player)
	local weights = {}
	local total = 0
	for index, entry in ipairs(egg.Pets) do
		local def = Config.Pets[entry.Pet]
		local weight = entry.Chance
		if def and Config.Rarities[def.Rarity] and Config.Rarities[def.Rarity].LuckAffected then
			weight *= luck
		end
		weights[index] = weight
		total += weight
	end
	local roll = math.random() * total
	for index, entry in ipairs(egg.Pets) do
		roll -= weights[index]
		if roll <= 0 then
			return entry.Pet
		end
	end
	return egg.Pets[#egg.Pets].Pet
end

--------------------------------------------------------------------------------
-- Inventory
--------------------------------------------------------------------------------

local function petMultiplier(petData): number
	return Config.GetPetMultiplier(petData.Type, petData.Tier)
end

-- Adds a pet to the player's inventory (auto-equips if a slot is free).
function PetService.AddPet(player: Player, petType: string, skipSync: boolean?, tier: number?)
	local profile = DataService:GetProfile(player)
	local def = Config.Pets[petType]
	if not profile or not def then
		return nil
	end
	local data = profile.Data
	if #data.Pets >= Config.PetStorageLimit then
		return nil
	end

	local petData = {
		Id = HttpService:GenerateGUID(false),
		Type = petType,
		Tier = tier or 0,
		Equipped = countEquipped(data) < PetService.GetSlotCount(player),
		Hatched = os.time(),
	}
	table.insert(data.Pets, petData)
	data.Discovered[petType] = true
	if not skipSync then
		sync(player)
	end
	return petData
end

-- Unequips the weakest pets if more are equipped than the player has slots
-- for (e.g. a pass that granted slots is no longer owned).
function PetService.EnforceSlots(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local slots = PetService.GetSlotCount(player)
	local equipped = {}
	for _, petData in ipairs(profile.Data.Pets) do
		if petData.Equipped then
			table.insert(equipped, petData)
		end
	end
	if #equipped <= slots then
		sync(player)
		return
	end
	table.sort(equipped, function(a, b)
		return petMultiplier(a) > petMultiplier(b)
	end)
	for index = slots + 1, #equipped do
		equipped[index].Equipped = false
	end
	sync(player)
end

function PetService.Equip(player: Player, petId: string)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local petData = findPet(profile.Data, petId)
	if not petData or petData.Equipped then
		return
	end
	if countEquipped(profile.Data) >= PetService.GetSlotCount(player) then
		notify(player, "All pet slots are full! Unequip a pet or buy more slots.", "error")
		return
	end
	petData.Equipped = true
	sync(player)
end

function PetService.Unequip(player: Player, petId: string)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local petData = findPet(profile.Data, petId)
	if not petData or not petData.Equipped then
		return
	end
	petData.Equipped = false
	sync(player)
end

function PetService.UnequipAll(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	for _, petData in ipairs(profile.Data.Pets) do
		petData.Equipped = false
	end
	sync(player)
end

function PetService.EquipBest(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local pets = profile.Data.Pets
	local sorted = table.clone(pets)
	table.sort(sorted, function(a, b)
		return petMultiplier(a) > petMultiplier(b)
	end)
	local slots = PetService.GetSlotCount(player)
	for index, petData in ipairs(sorted) do
		petData.Equipped = index <= slots
	end
	sync(player)
end

-- Combines `Needed` pets of one type and tier into one pet of the next tier.
function PetService.Craft(player: Player, petType: string, fromTier: number)
	local profile = DataService:GetProfile(player)
	local recipe = Config.PetTiers[fromTier + 1]
	if not profile or not recipe or not Config.Pets[petType] then
		return
	end
	local data = profile.Data
	local candidates = {}
	for index, petData in ipairs(data.Pets) do
		if petData.Type == petType and (petData.Tier or 0) == fromTier then
			table.insert(candidates, { Index = index, Pet = petData })
		end
	end
	if #candidates < recipe.Needed then
		notify(player, string.format("You need %d %s to craft a %s one (you have %d).", recipe.Needed, petType, recipe.Name, #candidates), "error")
		return
	end

	-- Use unequipped copies first so the player's team changes as little as possible.
	table.sort(candidates, function(a, b)
		if a.Pet.Equipped ~= b.Pet.Equipped then
			return not a.Pet.Equipped
		end
		return a.Index > b.Index
	end)
	local consumed = {}
	local anyEquipped = false
	for i = 1, recipe.Needed do
		local entry = candidates[i]
		consumed[entry.Pet.Id] = true
		anyEquipped = anyEquipped or entry.Pet.Equipped == true
	end
	for index = #data.Pets, 1, -1 do
		if consumed[data.Pets[index].Id] then
			table.remove(data.Pets, index)
		end
	end

	local crafted = PetService.AddPet(player, petType, true, fromTier + 1)
	if crafted and anyEquipped then
		crafted.Equipped = true
	end
	data.Stats.PetsCrafted += 1
	DataService:Replicate(player, { Stats = data.Stats })
	sync(player)
	Remotes.Get("Notify"):FireClient(player, string.format("Crafted a %s %s! (x%.2f)", recipe.Name, petType, Config.GetPetMultiplier(petType, fromTier + 1)), "reward")
end

function PetService.Delete(player: Player, petId: string)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local petData, index = findPet(profile.Data, petId)
	if not petData or not index then
		return
	end
	table.remove(profile.Data.Pets, index)
	sync(player)
end

--------------------------------------------------------------------------------
-- Hatching
--------------------------------------------------------------------------------

function PetService.Hatch(player: Player, eggKey: string, count: number)
	local profile = DataService:GetProfile(player)
	if not profile then
		return { ok = false, reason = "Data not loaded" }
	end
	local egg = Config.Eggs[eggKey]
	if not egg then
		return { ok = false, reason = "Unknown egg" }
	end
	if count ~= 1 and count ~= 3 then
		return { ok = false, reason = "Invalid amount" }
	end
	if count == 3 and not GamepassService.Owns(player, "TripleHatch") then
		return { ok = false, reason = "Triple Hatch gamepass required" }
	end

	local now = os.clock()
	if (lastHatch[player] or 0) + HATCH_COOLDOWN > now then
		return { ok = false, reason = "Too fast" }
	end
	lastHatch[player] = now

	local data = profile.Data
	if egg.Zone > data.ZonesUnlocked then
		return { ok = false, reason = "Unlock " .. Config.Zones[egg.Zone].Name .. " first" }
	end

	-- Must be standing near the egg stand (Auto Hatch owners: anywhere in its zone)
	local standPosition = MapBuilder.GetEggStandPosition(eggKey)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return { ok = false, reason = "No character" }
	end
	local nearStand = standPosition ~= nil and (root.Position - standPosition).Magnitude <= MAX_HATCH_DISTANCE
	local inEggZone = GamepassService.Owns(player, "AutoHatch") and MapBuilder.GetZoneAt(root.Position) == egg.Zone
	if standPosition and not nearStand and not inEggZone then
		return { ok = false, reason = "Walk closer to the egg" }
	end

	if #data.Pets + count > Config.PetStorageLimit then
		return { ok = false, reason = "Pet storage full! Delete some pets." }
	end

	local totalCost = egg.Cost * count
	local paid
	if egg.Currency == "Gems" then
		paid = EconomyService.SpendGems(player, totalCost)
	else
		paid = EconomyService.SpendCoins(player, totalCost)
	end
	if not paid then
		return { ok = false, reason = "Not enough " .. egg.Currency .. "!" }
	end

	local results = {}
	for _ = 1, count do
		local petType = rollPet(player, egg)
		local isNew = not data.Discovered[petType]
		local petData = PetService.AddPet(player, petType, true)
		if petData then
			local def = Config.Pets[petType]
			table.insert(results, {
				Id = petData.Id,
				Type = petType,
				Rarity = def.Rarity,
				Multiplier = def.Multiplier,
				Equipped = petData.Equipped,
				New = isNew,
			})
		end
	end
	data.Stats.PetsHatched += #results
	DataService:Replicate(player, { Stats = data.Stats })
	sync(player)

	return { ok = true, results = results }
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function PetService.Init()
	DataService.ProfileLoaded:Connect(function(player, profile)
		-- Heal any invalid saved pets (e.g. a pet removed from Config).
		local pets = profile.Data.Pets
		for index = #pets, 1, -1 do
			if not Config.Pets[pets[index].Type] then
				table.remove(pets, index)
			else
				profile.Data.Discovered[pets[index].Type] = true
			end
		end
		sync(player)
	end)

	GamepassService.Changed:Connect(function(player, key)
		if key == "ExtraPetSlots" or key == "VIP" then
			sync(player)
		end
	end)
	GamepassService.Refreshed:Connect(function(player, failedKeys)
		-- If a slot pass couldn't be checked, don't unequip a paying player's
		-- pets; the multiplier is already capped to their known slots.
		for _, key in ipairs(failedKeys or {}) do
			if key == "ExtraPetSlots" or key == "VIP" then
				sync(player)
				return
			end
		end
		PetService.EnforceSlots(player)
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastHatch[player] = nil
	end)

	Remotes.Get("HatchEgg").OnServerInvoke = function(player, eggKey, count)
		if type(eggKey) ~= "string" or type(count) ~= "number" then
			return { ok = false, reason = "Bad request" }
		end
		return PetService.Hatch(player, eggKey, count)
	end

	local function petAction(player: Player): boolean
		return RateLimiter.Allow(player, "PetAction", 10, 8)
	end
	Remotes.Get("EquipPet").OnServerEvent:Connect(function(player, petId)
		if type(petId) == "string" and petAction(player) then
			PetService.Equip(player, petId)
		end
	end)
	Remotes.Get("UnequipPet").OnServerEvent:Connect(function(player, petId)
		if type(petId) == "string" and petAction(player) then
			PetService.Unequip(player, petId)
		end
	end)
	Remotes.Get("DeletePet").OnServerEvent:Connect(function(player, petId)
		if type(petId) == "string" and petAction(player) then
			PetService.Delete(player, petId)
		end
	end)
	Remotes.Get("CraftPet").OnServerEvent:Connect(function(player, petType, fromTier)
		if type(petType) == "string" and type(fromTier) == "number" and fromTier == math.floor(fromTier) and fromTier >= 0 and petAction(player) then
			PetService.Craft(player, petType, fromTier)
		end
	end)
	Remotes.Get("EquipBest").OnServerEvent:Connect(function(player)
		if petAction(player) then
			PetService.EquipBest(player)
		end
	end)
	Remotes.Get("UnequipAll").OnServerEvent:Connect(function(player)
		if petAction(player) then
			PetService.UnequipAll(player)
		end
	end)
end

return PetService
