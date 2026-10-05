--------------------------------------------------------------------------------
-- HATCH LEGENDS - GAME CONFIG
--
-- Every number that affects gameplay or money lives in this file.
-- Server and client both read it (never put secrets here).
--
-- BEFORE PUBLISHING:
--   1. Create your Gamepasses + Developer Products on the Roblox Creator Hub
--      and paste their Ids into Config.Gamepasses / Config.Products below.
--   2. Set Config.GroupId to your group's id (for the "join group" reward).
--   3. Optionally set Config.Sounds ids to sounds you own / have rights to.
--------------------------------------------------------------------------------

local Config = {}

Config.GameName = "Hatch Legends"
Config.Version = 1

-- Bump the suffix to wipe all player data (e.g. "_v2") - use with care!
Config.DataStoreName = "HatchLegends_Players_v1"
Config.LeaderboardStorePrefix = "HatchLegends_LB_v1_"

Config.AutosaveInterval = 60 -- seconds
Config.GroupId = 0 -- <<< YOUR GROUP ID HERE (0 disables the group reward)

Config.Debug = {
	-- When true and running in Studio, every gamepass is treated as owned so you
	-- can test VIP / Auto Collect / Triple Hatch without buying anything.
	FreeGamepassesInStudio = true,
	-- Prints verbose logs from DataService.
	VerboseData = false,
}

--------------------------------------------------------------------------------
-- MONETIZATION
--------------------------------------------------------------------------------

-- Gamepasses: one-time purchases. Set Id to the gamepass id from Creator Hub.
Config.Gamepasses = {
	DoubleCoins = {
		Id = 0,
		Name = "2x Coins",
		Price = 249,
		Description = "Permanently earn DOUBLE coins from every orb!",
		Color = Color3.fromRGB(255, 196, 0),
		Order = 1,
	},
	VIP = {
		Id = 0,
		Name = "VIP",
		Price = 399,
		Description = "+25% coins, VIP chat tag, +1 pet slot and 2x daily rewards!",
		Color = Color3.fromRGB(255, 120, 40),
		Order = 2,
		CoinMultiplier = 1.25,
		ExtraPetSlots = 1,
		DailyRewardMultiplier = 2,
	},
	AutoCollect = {
		Id = 0,
		Name = "Auto Collect",
		Price = 199,
		Description = "Magnet that pulls in every orb near you automatically!",
		Color = Color3.fromRGB(80, 200, 255),
		Order = 3,
		Radius = 32,
	},
	Lucky = {
		Id = 0,
		Name = "Lucky",
		Price = 299,
		Description = "2x chance to hatch LEGENDARY and MYTHIC pets!",
		Color = Color3.fromRGB(120, 255, 120),
		Order = 4,
		LuckMultiplier = 2,
	},
	ExtraPetSlots = {
		Id = 0,
		Name = "+3 Pet Slots",
		Price = 199,
		Description = "Equip 3 more pets at once for a huge multiplier boost!",
		Color = Color3.fromRGB(200, 120, 255),
		Order = 5,
		Slots = 3,
	},
	TripleHatch = {
		Id = 0,
		Name = "Triple Hatch",
		Price = 249,
		Description = "Hatch 3 eggs at the same time!",
		Color = Color3.fromRGB(255, 100, 180),
		Order = 6,
	},
	AutoHatch = {
		Id = 0,
		Name = "Auto Hatch",
		Price = 349,
		Description = "Hatch eggs automatically while you sit back and relax!",
		Color = Color3.fromRGB(255, 80, 80),
		Order = 7,
	},
}

-- Developer Products: repeatable purchases. Set Id from Creator Hub.
-- Coin packs scale with the player's progress (see EconomyService.ScaleCoins)
-- so they stay valuable in late zones.
Config.Products = {
	Coins_Small = { Id = 0, Name = "Coin Pouch", Price = 49, Order = 1, Grant = { Coins = 2000 } },
	Coins_Medium = { Id = 0, Name = "Coin Bag", Price = 129, Order = 2, Grant = { Coins = 7500 } },
	Coins_Large = { Id = 0, Name = "Coin Chest", Price = 349, Order = 3, Grant = { Coins = 25000 } },
	Coins_Mega = { Id = 0, Name = "Coin Vault", Price = 999, Order = 4, Grant = { Coins = 100000 } },

	Gems_Small = { Id = 0, Name = "100 Gems", Price = 99, Order = 5, Grant = { Gems = 100 } },
	Gems_Medium = { Id = 0, Name = "350 Gems", Price = 299, Order = 6, Grant = { Gems = 350 } },
	Gems_Large = { Id = 0, Name = "1,200 Gems", Price = 899, Order = 7, Grant = { Gems = 1200 } },

	LuckPotion = {
		Id = 0,
		Name = "Lucky Potion (15m)",
		Price = 79,
		Order = 8,
		Grant = { Boost = { Type = "Luck", Mult = 2, Duration = 15 * 60 } },
	},
	CoinPotion = {
		Id = 0,
		Name = "2x Coins Potion (15m)",
		Price = 79,
		Order = 9,
		Grant = { Boost = { Type = "Coins", Mult = 2, Duration = 15 * 60 } },
	},
	RebirthToken = {
		Id = 0,
		Name = "Instant Rebirth",
		Price = 199,
		Order = 10,
		Grant = { Rebirths = 1 },
	},
}

-- Paid random items compliance:
-- Players whose region restricts paid random items (PolicyService
-- ArePaidRandomItemsRestricted) cannot buy anything that feeds eggs (currency)
-- or changes egg odds (luck). Their eggs are paid for only with earned currency.
-- Keys are Config.Gamepasses / Config.Products keys.
Config.RestrictedPurchases = {
	Coins_Small = true,
	Coins_Medium = true,
	Coins_Large = true,
	Coins_Mega = true,
	Gems_Small = true,
	Gems_Medium = true,
	Gems_Large = true,
	LuckPotion = true,
	Lucky = true,
}

--------------------------------------------------------------------------------
-- PETS
--------------------------------------------------------------------------------

Config.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(190, 190, 190), LuckAffected = false },
	Uncommon = { Order = 2, Color = Color3.fromRGB(90, 220, 90), LuckAffected = false },
	Rare = { Order = 3, Color = Color3.fromRGB(70, 150, 255), LuckAffected = false },
	Epic = { Order = 4, Color = Color3.fromRGB(190, 80, 255), LuckAffected = false },
	Legendary = { Order = 5, Color = Color3.fromRGB(255, 170, 0), LuckAffected = true },
	Mythic = { Order = 6, Color = Color3.fromRGB(255, 60, 120), LuckAffected = true },
}

-- Pet multipliers are ADDITIVE: total = 1 + sum(Multiplier - 1) of equipped pets.
-- Shape: "Ball" | "Block" | "Cylinder" (used when no model exists in
-- ReplicatedStorage.PetModels[<name>]). Drop a Model named exactly like the
-- pet into that folder to replace the placeholder shape with real art.
local function pet(name, rarity, multiplier, color, shape)
	return { Name = name, Rarity = rarity, Multiplier = multiplier, Color = color, Shape = shape or "Ball" }
end

Config.Pets = {
	-- Zone 1: Grassy Meadow
	["Dog"] = pet("Dog", "Common", 1.25, Color3.fromRGB(200, 150, 90), "Block"),
	["Cat"] = pet("Cat", "Common", 1.3, Color3.fromRGB(120, 120, 130), "Block"),
	["Bunny"] = pet("Bunny", "Uncommon", 1.6, Color3.fromRGB(240, 240, 240)),
	["Fox"] = pet("Fox", "Rare", 2.2, Color3.fromRGB(230, 110, 40), "Block"),
	["Deer"] = pet("Deer", "Epic", 4, Color3.fromRGB(150, 100, 60), "Block"),
	["Unicorn"] = pet("Unicorn", "Legendary", 10, Color3.fromRGB(255, 200, 240)),

	-- Zone 2: Candy Land
	["Gummy Bear"] = pet("Gummy Bear", "Common", 1.6, Color3.fromRGB(255, 90, 90), "Block"),
	["Lollipop Lamb"] = pet("Lollipop Lamb", "Uncommon", 2.2, Color3.fromRGB(255, 180, 220)),
	["Choco Puppy"] = pet("Choco Puppy", "Rare", 3.5, Color3.fromRGB(100, 60, 30), "Block"),
	["Candy Cane Cat"] = pet("Candy Cane Cat", "Epic", 6, Color3.fromRGB(255, 255, 255), "Block"),
	["Cotton Candy Dragon"] = pet("Cotton Candy Dragon", "Legendary", 15, Color3.fromRGB(170, 200, 255)),
	["Sugar Phoenix"] = pet("Sugar Phoenix", "Mythic", 40, Color3.fromRGB(255, 120, 200)),

	-- Zone 3: Frozen Peaks
	["Penguin"] = pet("Penguin", "Common", 2.5, Color3.fromRGB(40, 40, 50), "Block"),
	["Seal"] = pet("Seal", "Uncommon", 3.5, Color3.fromRGB(170, 180, 200)),
	["Snow Owl"] = pet("Snow Owl", "Rare", 6, Color3.fromRGB(245, 245, 255)),
	["Ice Wolf"] = pet("Ice Wolf", "Epic", 10, Color3.fromRGB(150, 220, 255), "Block"),
	["Frost Dragon"] = pet("Frost Dragon", "Legendary", 25, Color3.fromRGB(80, 180, 255)),
	["Aurora Yeti"] = pet("Aurora Yeti", "Mythic", 70, Color3.fromRGB(120, 255, 220), "Block"),

	-- Zone 4: Volcano
	["Magma Crab"] = pet("Magma Crab", "Common", 4, Color3.fromRGB(200, 60, 30), "Block"),
	["Ember Lizard"] = pet("Ember Lizard", "Uncommon", 6, Color3.fromRGB(255, 120, 40), "Block"),
	["Lava Hound"] = pet("Lava Hound", "Rare", 10, Color3.fromRGB(120, 40, 40), "Block"),
	["Fire Fox"] = pet("Fire Fox", "Epic", 18, Color3.fromRGB(255, 80, 0), "Block"),
	["Inferno Dragon"] = pet("Inferno Dragon", "Legendary", 45, Color3.fromRGB(255, 40, 0)),
	["Phoenix King"] = pet("Phoenix King", "Mythic", 120, Color3.fromRGB(255, 200, 50)),

	-- Zone 5: Space Station
	["Moon Bunny"] = pet("Moon Bunny", "Common", 7, Color3.fromRGB(220, 220, 240)),
	["Star Pup"] = pet("Star Pup", "Uncommon", 10, Color3.fromRGB(255, 240, 120), "Block"),
	["Nebula Cat"] = pet("Nebula Cat", "Rare", 18, Color3.fromRGB(140, 80, 220), "Block"),
	["Galaxy Wolf"] = pet("Galaxy Wolf", "Epic", 32, Color3.fromRGB(60, 40, 140), "Block"),
	["Void Dragon"] = pet("Void Dragon", "Legendary", 80, Color3.fromRGB(30, 10, 60)),
	["Supernova Capybara"] = pet("Supernova Capybara", "Mythic", 250, Color3.fromRGB(255, 150, 60), "Block"),

	-- Premium (Gem egg)
	["Golden Dog"] = pet("Golden Dog", "Rare", 5, Color3.fromRGB(255, 215, 0), "Block"),
	["Diamond Cat"] = pet("Diamond Cat", "Epic", 12, Color3.fromRGB(180, 240, 255), "Block"),
	["Crystal Dragon"] = pet("Crystal Dragon", "Legendary", 35, Color3.fromRGB(200, 255, 250)),
	["Celestial Capybara"] = pet("Celestial Capybara", "Mythic", 150, Color3.fromRGB(255, 255, 200), "Block"),

	-- Exclusive rewards (not in any egg)
	["Golden Capybara"] = pet("Golden Capybara", "Legendary", 20, Color3.fromRGB(255, 200, 40), "Block"),
}

Config.PetStorageLimit = 150 -- total pets a player can hold
Config.BasePetSlots = 3 -- equipped at once (before gamepasses)

--------------------------------------------------------------------------------
-- EGGS  (Chance values are percentages and should sum to 100 per egg)
--------------------------------------------------------------------------------

Config.Eggs = {
	Basic = {
		Name = "Basic Egg",
		Zone = 1,
		Cost = 100,
		Currency = "Coins",
		Color = Color3.fromRGB(230, 230, 210),
		Pets = {
			{ Pet = "Dog", Chance = 40 },
			{ Pet = "Cat", Chance = 30 },
			{ Pet = "Bunny", Chance = 18 },
			{ Pet = "Fox", Chance = 9 },
			{ Pet = "Deer", Chance = 2.5 },
			{ Pet = "Unicorn", Chance = 0.5 },
		},
	},
	Candy = {
		Name = "Candy Egg",
		Zone = 2,
		Cost = 2500,
		Currency = "Coins",
		Color = Color3.fromRGB(255, 150, 200),
		Pets = {
			{ Pet = "Gummy Bear", Chance = 40 },
			{ Pet = "Lollipop Lamb", Chance = 30 },
			{ Pet = "Choco Puppy", Chance = 18 },
			{ Pet = "Candy Cane Cat", Chance = 9 },
			{ Pet = "Cotton Candy Dragon", Chance = 2.5 },
			{ Pet = "Sugar Phoenix", Chance = 0.5 },
		},
	},
	Frost = {
		Name = "Frost Egg",
		Zone = 3,
		Cost = 50000,
		Currency = "Coins",
		Color = Color3.fromRGB(170, 220, 255),
		Pets = {
			{ Pet = "Penguin", Chance = 40 },
			{ Pet = "Seal", Chance = 30 },
			{ Pet = "Snow Owl", Chance = 18 },
			{ Pet = "Ice Wolf", Chance = 9 },
			{ Pet = "Frost Dragon", Chance = 2.5 },
			{ Pet = "Aurora Yeti", Chance = 0.5 },
		},
	},
	Lava = {
		Name = "Lava Egg",
		Zone = 4,
		Cost = 1000000,
		Currency = "Coins",
		Color = Color3.fromRGB(255, 90, 40),
		Pets = {
			{ Pet = "Magma Crab", Chance = 40 },
			{ Pet = "Ember Lizard", Chance = 30 },
			{ Pet = "Lava Hound", Chance = 18 },
			{ Pet = "Fire Fox", Chance = 9 },
			{ Pet = "Inferno Dragon", Chance = 2.5 },
			{ Pet = "Phoenix King", Chance = 0.5 },
		},
	},
	Cosmic = {
		Name = "Cosmic Egg",
		Zone = 5,
		Cost = 25000000,
		Currency = "Coins",
		Color = Color3.fromRGB(90, 60, 160),
		Pets = {
			{ Pet = "Moon Bunny", Chance = 40 },
			{ Pet = "Star Pup", Chance = 30 },
			{ Pet = "Nebula Cat", Chance = 18 },
			{ Pet = "Galaxy Wolf", Chance = 9 },
			{ Pet = "Void Dragon", Chance = 2.5 },
			{ Pet = "Supernova Capybara", Chance = 0.5 },
		},
	},
	Premium = {
		Name = "Gem Egg",
		Zone = 1, -- stand lives in the spawn zone
		Cost = 50,
		Currency = "Gems",
		Color = Color3.fromRGB(120, 255, 230),
		Pets = {
			{ Pet = "Golden Dog", Chance = 50 },
			{ Pet = "Diamond Cat", Chance = 30 },
			{ Pet = "Crystal Dragon", Chance = 15 },
			{ Pet = "Celestial Capybara", Chance = 5 },
		},
	},
}

--------------------------------------------------------------------------------
-- ZONES (in order). Zone 1 is the spawn. Cost = coins to unlock.
--------------------------------------------------------------------------------

Config.Zones = {
	{
		Name = "Grassy Meadow",
		Cost = 0,
		OrbValue = 5,
		OrbCount = 28,
		Eggs = { "Basic" },
		Theme = {
			Ground = Color3.fromRGB(96, 170, 70),
			Accent = Color3.fromRGB(60, 120, 50),
			Trim = Color3.fromRGB(140, 100, 60),
			Orb = Color3.fromRGB(255, 220, 60),
			Material = "Grass",
			Decor = "Trees",
		},
	},
	{
		Name = "Candy Land",
		Cost = 2500,
		OrbValue = 40,
		OrbCount = 26,
		Eggs = { "Candy" },
		Theme = {
			Ground = Color3.fromRGB(255, 170, 210),
			Accent = Color3.fromRGB(255, 255, 255),
			Trim = Color3.fromRGB(255, 90, 140),
			Orb = Color3.fromRGB(255, 120, 190),
			Material = "SmoothPlastic",
			Decor = "Candy",
		},
	},
	{
		Name = "Frozen Peaks",
		Cost = 50000,
		OrbValue = 400,
		OrbCount = 26,
		Eggs = { "Frost" },
		Theme = {
			Ground = Color3.fromRGB(225, 240, 255),
			Accent = Color3.fromRGB(150, 210, 255),
			Trim = Color3.fromRGB(90, 150, 220),
			Orb = Color3.fromRGB(120, 220, 255),
			Material = "Snow",
			Decor = "Ice",
		},
	},
	{
		Name = "Volcano",
		Cost = 1000000,
		OrbValue = 5000,
		OrbCount = 24,
		Eggs = { "Lava" },
		Theme = {
			Ground = Color3.fromRGB(60, 50, 50),
			Accent = Color3.fromRGB(255, 110, 30),
			Trim = Color3.fromRGB(120, 40, 30),
			Orb = Color3.fromRGB(255, 140, 40),
			Material = "Slate",
			Decor = "Rock",
		},
	},
	{
		Name = "Space Station",
		Cost = 25000000,
		OrbValue = 75000,
		OrbCount = 24,
		Eggs = { "Cosmic" },
		Theme = {
			Ground = Color3.fromRGB(45, 40, 70),
			Accent = Color3.fromRGB(160, 90, 255),
			Trim = Color3.fromRGB(90, 220, 255),
			Orb = Color3.fromRGB(190, 120, 255),
			Material = "Metal",
			Decor = "Crystal",
		},
	},
}

Config.Orbs = {
	RespawnMin = 2, -- seconds
	RespawnMax = 4,
	BigOrbChance = 0.06, -- 6% of orbs are "big" (5x value)
	BigOrbMultiplier = 5,
	GemOrbChance = 0.02, -- 2% of orbs are gem orbs (1-3 gems)
	CollectRadius = 7, -- studs, walk-over pickup
	MaxCollectDistance = 24, -- server validation (pickup rate limits: CollectibleService)
}

--------------------------------------------------------------------------------
-- REBIRTH
--------------------------------------------------------------------------------

Config.Rebirth = {
	BaseCost = 250000,
	CostGrowth = 2.2, -- cost = BaseCost * CostGrowth ^ rebirths
	MultiplierPerRebirth = 0.5, -- +50% coins per rebirth (permanent)
	GemsReward = 25,
	RequireAllZones = false,
}

--------------------------------------------------------------------------------
-- REWARDS (coins are scaled to the player's current zone/rebirths)
--------------------------------------------------------------------------------

Config.DailyRewards = {
	{ Coins = 1000 },
	{ Gems = 5 },
	{ Coins = 2500 },
	{ Gems = 10 },
	{ Coins = 5000 },
	{ Gems = 20 },
	{ Gems = 50, Pet = "Golden Capybara" },
}

Config.PlaytimeRewards = {
	{ Minutes = 3, Coins = 500 },
	{ Minutes = 10, Gems = 5 },
	{ Minutes = 20, Coins = 2500 },
	{ Minutes = 30, Gems = 10 },
	{ Minutes = 45, Coins = 10000 },
	{ Minutes = 60, Gems = 25, Coins = 15000 },
}

Config.GroupReward = {
	Multiplier = 1.1, -- +10% coins while in the group
	Gems = 50, -- one-time claim
}

-- Promo codes live in src/Server/Codes.lua (server only, so they stay secret).

--------------------------------------------------------------------------------
-- SOUNDS (0 = disabled). Use ids you own or free-to-use Roblox library sounds.
--------------------------------------------------------------------------------

Config.Sounds = {
	Click = 0,
	Collect = 0,
	Hatch = 0,
	Rare = 0,
	Purchase = 0,
	Error = 0,
	Music = 0,
}

--------------------------------------------------------------------------------
-- PLAYER DATA TEMPLATE
--------------------------------------------------------------------------------

Config.DataTemplate = {
	Version = Config.Version,
	Coins = 0,
	Gems = 0,
	Rebirths = 0,
	ZonesUnlocked = 1,
	Pets = {}, -- { {Id, Type, Equipped, Hatched} }
	Discovered = {}, -- { [PetName] = true } for the pet Index
	Stats = {
		TotalCoins = 0,
		PetsHatched = 0,
		OrbsCollected = 0,
		Playtime = 0, -- seconds
		RobuxSpent = 0,
		Joins = 0,
	},
	Daily = { LastClaim = 0, Streak = 0 },
	GroupClaimed = false,
	RedeemedCodes = {}, -- { [CODE] = true }
	Purchases = {}, -- processed receipt ids (dedupe)
	Boosts = {}, -- { Luck = {Mult, ExpiresAt}, Coins = {...} }
	Settings = { Music = true, SkipHatchAnimation = false },
	FirstJoin = 0,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Scales a base coin amount to the player's progress so rewards and coin packs
-- stay meaningful in late zones. Shared so the client can preview amounts.
function Config.ScaleCoins(baseAmount: number, zonesUnlocked: number, rebirths: number): number
	local zone = Config.Zones[math.clamp(zonesUnlocked or 1, 1, #Config.Zones)]
	local zoneScale = zone.OrbValue / Config.Zones[1].OrbValue
	local rebirthScale = 1 + (rebirths or 0) * Config.Rebirth.MultiplierPerRebirth
	return math.floor(baseAmount * zoneScale * rebirthScale)
end

function Config.GetRebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
end

function Config.GetGamepassByProductId(id: number)
	for key, pass in pairs(Config.Gamepasses) do
		if pass.Id == id and id ~= 0 then
			return key, pass
		end
	end
	return nil, nil
end

function Config.GetProductById(id: number)
	for key, product in pairs(Config.Products) do
		if product.Id == id and id ~= 0 then
			return key, product
		end
	end
	return nil, nil
end

function Config.GetEggsSortedByZone()
	local list = {}
	for key, egg in pairs(Config.Eggs) do
		table.insert(list, { Key = key, Egg = egg })
	end
	table.sort(list, function(a, b)
		if a.Egg.Zone == b.Egg.Zone then
			return a.Egg.Cost < b.Egg.Cost
		end
		return a.Egg.Zone < b.Egg.Zone
	end)
	return list
end

return Config
