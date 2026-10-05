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
	local equipped = {}
	for _, petData in ipairs(profile.Data.Pets) do
		if petData.Equipped then
			table.insert(equipped, petData.Type)
		end
	end
	player:SetAttribute("EquippedPets", HttpService:JSONEncode(equipped))
	DataService:Replicate(player, { Pets = profile.Data.Pets, PetSlots = PetService.GetSlotCount(player) })
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

-- Adds a pet to the player's inventory (auto-equips if a slot is free).
function PetService.AddPet(player: Player, petType: string, skipSync: boolean?)
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
		Equipped = countEquipped(data) < PetService.GetSlotCount(player),
		Hatched = os.time(),
	}
	table.insert(data.Pets, petData)
	if not skipSync then
		sync(player)
	end
	return petData
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
		local defA = Config.Pets[a.Type]
		local defB = Config.Pets[b.Type]
		local multA = defA and defA.Multiplier or 0
		local multB = defB and defB.Multiplier or 0
		return multA > multB
	end)
	local slots = PetService.GetSlotCount(player)
	for index, petData in ipairs(sorted) do
		petData.Equipped = index <= slots
	end
	sync(player)
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

	-- Must be standing near the egg stand
	local standPosition = MapBuilder.GetEggStandPosition(eggKey)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if standPosition and root then
		if (root.Position - standPosition).Magnitude > MAX_HATCH_DISTANCE then
			return { ok = false, reason = "Walk closer to the egg" }
		end
	elseif not root then
		return { ok = false, reason = "No character" }
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
		local petData = PetService.AddPet(player, petType, true)
		if petData then
			local def = Config.Pets[petType]
			table.insert(results, {
				Id = petData.Id,
				Type = petType,
				Rarity = def.Rarity,
				Multiplier = def.Multiplier,
				Equipped = petData.Equipped,
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
			end
		end
		sync(player)
	end)

	GamepassService.Changed:Connect(function(player, key)
		if key == "ExtraPetSlots" or key == "VIP" then
			sync(player)
		end
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

	Remotes.Get("EquipPet").OnServerEvent:Connect(function(player, petId)
		if type(petId) == "string" then
			PetService.Equip(player, petId)
		end
	end)
	Remotes.Get("UnequipPet").OnServerEvent:Connect(function(player, petId)
		if type(petId) == "string" then
			PetService.Unequip(player, petId)
		end
	end)
	Remotes.Get("DeletePet").OnServerEvent:Connect(function(player, petId)
		if type(petId) == "string" then
			PetService.Delete(player, petId)
		end
	end)
	Remotes.Get("EquipBest").OnServerEvent:Connect(function(player)
		PetService.EquipBest(player)
	end)
	Remotes.Get("UnequipAll").OnServerEvent:Connect(function(player)
		PetService.UnequipAll(player)
	end)
end

return PetService
