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
		Description = "Doubles the weight of Legendary & Mythic pets in every egg. Exact odds are shown on each egg.",
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
-- CoinMinutes = coins worth that many minutes of the player's current income
-- (best zone x permanent multiplier), so packs are equally valuable at every
-- stage of the game. See Config.CoinsForMinutes.
Config.Products = {
	Coins_Small = { Id = 0, Name = "Coin Pouch", Price = 49, Order = 1, Grant = { CoinMinutes = 10 } },
	Coins_Medium = { Id = 0, Name = "Coin Bag", Price = 129, Order = 2, Grant = { CoinMinutes = 40 } },
	Coins_Large = { Id = 0, Name = "Coin Chest", Price = 349, Order = 3, Grant = { CoinMinutes = 120 } },
	Coins_Mega = { Id = 0, Name = "Coin Vault", Price = 999, Order = 4, Grant = { CoinMinutes = 480 } },

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
	-- Strong early boosts, but below the zone 4-5 egg pets so zone eggs stay the goal.
	["Golden Dog"] = pet("Golden Dog", "Rare", 3, Color3.fromRGB(255, 215, 0), "Block"),
	["Diamond Cat"] = pet("Diamond Cat", "Epic", 6, Color3.fromRGB(180, 240, 255), "Block"),
	["Crystal Dragon"] = pet("Crystal Dragon", "Legendary", 15, Color3.fromRGB(200, 255, 250)),
	["Celestial Capybara"] = pet("Celestial Capybara", "Mythic", 50, Color3.fromRGB(255, 255, 200), "Block"),

	-- Exclusive rewards (not in any egg)
	-- First 7-day streak reward (one time only; later cycles give gems instead).
	["Golden Capybara"] = pet("Golden Capybara", "Legendary", 60, Color3.fromRGB(255, 200, 40), "Block"),
}

-- Golden / Rainbow crafting: combine `Needed` copies of a pet at the tier below.
-- A tier multiplies the pet's bonus: Dog x1.25 -> Golden 1 + 0.25 * 2.5 = x1.63.
Config.PetTiers = {
	{ Name = "Golden", Needed = 5, Bonus = 2.5 },
	{ Name = "Rainbow", Needed = 5, Bonus = 6 },
}

-- Effective coin multiplier of one pet, including its Golden/Rainbow tier.
function Config.GetPetMultiplier(petType: string, tier: number?): number
	local def = Config.Pets[petType]
	if not def then
		return 1
	end
	local tierInfo = Config.PetTiers[tier or 0]
	local bonus = if tierInfo then tierInfo.Bonus else 1
	return 1 + (def.Multiplier - 1) * bonus
end

Config.PetStorageLimit = 150 -- total pets a player can hold
Config.BasePetSlots = 3 -- equipped at once (before gamepasses)

--------------------------------------------------------------------------------
-- EGGS  (Chance values are percentages and should sum to 100 per egg)
--------------------------------------------------------------------------------

Config.Eggs = {
	Basic = {
		Name = "Basic Egg",
		Zone = 1,
		Cost = 250,
		Currency = "Coins",
		Color = Color3.fromRGB(250, 242, 215),
		Pattern = "Spots", -- egg look: Spots / Stripes / Diamonds (see EggLooks)
		PatternColor = Color3.fromRGB(110, 200, 90),
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
		Cost = 8000,
		Currency = "Coins",
		Color = Color3.fromRGB(255, 150, 200),
		Pattern = "Stripes",
		PatternColor = Color3.fromRGB(255, 255, 255),
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
		Cost = 320000,
		Currency = "Coins",
		Color = Color3.fromRGB(170, 220, 255),
		Pattern = "Diamonds",
		PatternColor = Color3.fromRGB(245, 252, 255),
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
		Cost = 9000000,
		Currency = "Coins",
		Color = Color3.fromRGB(255, 90, 40),
		Pattern = "Spots",
		PatternColor = Color3.fromRGB(255, 220, 60),
		PatternNeon = true,
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
		Cost = 250000000,
		Currency = "Coins",
		Color = Color3.fromRGB(90, 60, 160),
		Pattern = "Spots",
		PatternColor = Color3.fromRGB(255, 120, 235),
		PatternNeon = true,
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
		Pattern = "Diamonds",
		PatternColor = Color3.fromRGB(255, 220, 80),
		PatternNeon = true,
		Glass = true,
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
--
-- Pacing (simulated solo player collecting ~0.85 orbs/s while their pets break
-- coin piles and chests, hatching when a pet pays for itself, no gifts):
-- first egg ~40 s, zone 2 ~8 min, zone 3 ~18 min, zone 4 ~35 min,
-- zone 5 ~80 min, first rebirth ~2.5 h. Later rebirths take longer.
--------------------------------------------------------------------------------

Config.Zones = {
	{
		Name = "Grassy Meadow",
		Cost = 0,
		OrbValue = 5,
		OrbCount = 50,
		BreakableHP = 1, -- multiplies breakable HP here (see Config.Breakables)
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
		Cost = 10000,
		OrbValue = 40,
		OrbCount = 50,
		BreakableHP = 2.2,
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
		Cost = 700000,
		OrbValue = 400,
		OrbCount = 50,
		BreakableHP = 4,
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
		Cost = 35000000,
		OrbValue = 5000,
		OrbCount = 50,
		BreakableHP = 7,
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
		Cost = 1300000000,
		OrbValue = 75000,
		OrbCount = 50,
		BreakableHP = 12,
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

-- World layout (MapBuilder builds zones in a row along +X).
Config.Map = {
	ZoneSize = 180,
	ZoneSpacing = 200,
}

Config.Orbs = {
	RespawnMin = 2, -- seconds
	RespawnMax = 4,
	BigOrbChance = 0.06, -- 6% of orbs are "big" (5x value)
	BigOrbMultiplier = 5,
	-- Orbs are shared, so each zone adds orbs for every extra player standing in
	-- it. Without this, a full server would earn far less per player than solo.
	ExtraPerPlayer = 12,
	MaxPerZone = 140,
	GemOrbChance = 0.02, -- 2% of orbs are gem orbs (1-3 gems)
	CollectRadius = 7, -- studs, walk-over pickup
	MaxCollectDistance = 24, -- server validation (pickup rate limits: CollectibleService)
}

--------------------------------------------------------------------------------
-- BREAKABLES - coin piles, crates and chests in every zone. Click one and your
-- equipped pets run over and break it. HP grows zone by zone (Zone.BreakableHP),
-- so rarer, Golden and Rainbow pets matter: they break things much faster.
-- Reward is counted in orbs: Reward 3 = worth three of the zone's coin orbs
-- (before the player's coin multiplier).
--------------------------------------------------------------------------------

Config.Breakables = {
	PerZone = 10, -- small breakables alive per zone with one player in it
	ExtraPerPlayer = 3, -- more for each extra player in the zone
	MaxPerZone = 22,
	RespawnMin = 5, -- seconds
	RespawnMax = 10,
	PlayerDamage = 2, -- damage per second from the player alone (no pets yet)
	PetDamage = 2, -- per equipped pet: PetDamage * sqrt(pet multiplier) per second
	MaxDistance = 70, -- studs: pets give up if their owner walks further away
	AutoTargetRange = 40, -- after a break, pets move on to the nearest one this close
	Kinds = {
		Pile = { Name = "Coin Pile", Weight = 68, HP = 25, Reward = 3, GemChance = 0.04, Gems = { 1, 1 } },
		Crate = { Name = "Crate", Weight = 26, HP = 80, Reward = 11, GemChance = 0.1, Gems = { 1, 2 } },
		Chest = { Name = "Treasure Chest", Weight = 6, HP = 300, Reward = 48, GemChance = 0.5, Gems = { 2, 4 } },
	},
	-- One per zone: a huge chest that takes teamwork (or a great team of pets).
	-- Everyone who helps gets a share; anyone who did 3%+ also gets gems.
	Giant = { Name = "Giant Chest", HP = 6000, Reward = 1100, Gems = { 15, 30 }, Respawn = 180, MinShare = 0.03 },
}

-- Damage per second one pet deals to breakables (Golden/Rainbow included).
function Config.GetPetDamage(petType: string, tier: number?): number
	return Config.Breakables.PetDamage * math.sqrt(Config.GetPetMultiplier(petType, tier))
end

-- Total damage per second of a team: the player plus their best `slots` pets.
function Config.GetTeamDamage(pets: { { Type: string, Tier: number? } }, slots: number): number
	local damages = {}
	for _, pet in ipairs(pets) do
		if Config.Pets[pet.Type] then
			table.insert(damages, Config.GetPetDamage(pet.Type, pet.Tier))
		end
	end
	table.sort(damages, function(a, b)
		return a > b
	end)
	local total = Config.Breakables.PlayerDamage
	for index = 1, math.min(#damages, slots) do
		total += damages[index]
	end
	return total
end

function Config.GetBreakableHP(kind: string, zoneIndex: number): number
	local spec = Config.Breakables.Kinds[kind] or (kind == "Giant" and Config.Breakables.Giant)
	local zone = Config.Zones[zoneIndex]
	if not spec or not zone then
		return 1
	end
	return math.floor(spec.HP * (zone.BreakableHP or 1))
end

--------------------------------------------------------------------------------
-- REBIRTH
--------------------------------------------------------------------------------

Config.Rebirth = {
	BaseCost = 32000000000, -- 32B: reached in the last zone
	CostGrowth = 1.8, -- cost = BaseCost * CostGrowth ^ (rebirths earned by playing)
	MaxCost = 1e15, -- keeps costs below the 2^53 coin cap
	MultiplierPerRebirth = 0.5, -- +50% coins per rebirth (permanent)
	GemsReward = 25,
	RequireAllZones = true, -- must have unlocked the last zone to rebirth
}

--------------------------------------------------------------------------------
-- REWARDS (coins are scaled to the player's current zone/rebirths)
--------------------------------------------------------------------------------

-- CoinMinutes = minutes of the player's current income (see Config.CoinsForMinutes).
Config.DailyRewards = {
	{ CoinMinutes = 5 },
	{ Gems = 5 },
	{ CoinMinutes = 10 },
	{ Gems = 10 },
	{ CoinMinutes = 20 },
	{ Gems = 20 },
	-- The pet is given once; if the player already has it, they get PetGems instead.
	{ Gems = 50, Pet = "Golden Capybara", PetOnce = true, PetGems = 100 },
}

-- Session gifts (reset each visit). Kept small so gameplay, not timers, drives
-- progress: about +30% coins over a full hour.
Config.PlaytimeRewards = {
	{ Minutes = 3, CoinMinutes = 1 },
	{ Minutes = 10, Gems = 5 },
	{ Minutes = 20, CoinMinutes = 3 },
	{ Minutes = 30, Gems = 10 },
	{ Minutes = 45, CoinMinutes = 6 },
	{ Minutes = 60, Gems = 25, CoinMinutes = 8 },
}

Config.GroupReward = {
	Multiplier = 1.1, -- +10% coins while in the group
	Gems = 50, -- one-time claim
}

-- Promo codes live in src/Server/Codes.lua (server only, so they stay secret).

--------------------------------------------------------------------------------
-- DAILY QUESTS - three are picked per player per UTC day from this pool.
-- Progress = how much a Stat grew since the day started (Scale converts units,
-- e.g. Playtime seconds -> minutes). Rewards use the same keys as other rewards.
--------------------------------------------------------------------------------

Config.Quests = {
	PerDay = 3,
	Pool = {
		{ Id = "Orbs", Text = "Collect %d orbs", Stat = "OrbsCollected", Goal = 250, Reward = { Gems = 10 } },
		{ Id = "Hatch", Text = "Hatch %d eggs", Stat = "PetsHatched", Goal = 20, Reward = { CoinMinutes = 6 } },
		{ Id = "GemOrbs", Text = "Find %d gem orbs", Stat = "GemOrbs", Goal = 6, Reward = { CoinMinutes = 8 } },
		{ Id = "Play", Text = "Play for %d minutes", Stat = "Playtime", Scale = 60, Goal = 20, Reward = { Gems = 15 } },
		{ Id = "Craft", Text = "Craft %d Golden or Rainbow pet", Stat = "PetsCrafted", Goal = 1, Reward = { Gems = 25 } },
		{ Id = "BigHatch", Text = "Hatch %d eggs", Stat = "PetsHatched", Goal = 60, Reward = { Gems = 30 } },
		{ Id = "BigOrbs", Text = "Collect %d orbs", Stat = "OrbsCollected", Goal = 800, Reward = { CoinMinutes = 12 } },
		{ Id = "Break", Text = "Break %d coin piles or chests", Stat = "BreakablesBroken", Goal = 40, Reward = { Gems = 12 } },
		{ Id = "BigBreak", Text = "Break %d coin piles or chests", Stat = "BreakablesBroken", Goal = 150, Reward = { CoinMinutes = 12 } },
	},
	BonusReward = { Gems = 40 }, -- for finishing all of today's quests
}

--------------------------------------------------------------------------------
-- SERVER EVENTS - a random event starts every Interval seconds.
--------------------------------------------------------------------------------

Config.Events = {
	Interval = 600, -- seconds between event starts
	Duration = 120,
	List = {
		CoinFrenzy = { Name = "COIN FRENZY", Description = "x2 coins from every orb!", CoinMult = 2, ExtraOrbs = 0.5, Color = Color3.fromRGB(255, 200, 40) },
		GemRush = { Name = "GEM RUSH", Description = "Gem orbs are everywhere!", GemChance = 0.12, Color = Color3.fromRGB(255, 90, 210) },
	},
}

--------------------------------------------------------------------------------
-- UPGRADES - permanent boosts bought with gems.
--------------------------------------------------------------------------------

Config.Upgrades = {
	WalkSpeed = { Name = "Speed", Description = "+2 walk speed per level", PerLevel = 2, Costs = { 20, 45, 90, 160, 260 }, Order = 1 },
	Magnet = { Name = "Magnet", Description = "+1.5 stud pickup range per level", PerLevel = 1.5, Costs = { 25, 55, 110, 190, 300 }, Order = 2 },
	CoinBoost = { Name = "Coin Boost", Description = "+10% coins per level", PerLevel = 0.1, Costs = { 30, 70, 140, 240, 380 }, Order = 3 },
}
Config.BaseWalkSpeed = 20 -- keep equal to StarterPlayer.CharacterWalkSpeed

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
	PurchasedRebirths = 0, -- from the Instant Rebirth product (don't raise the cost)
	ZonesUnlocked = 1,
	Pets = {}, -- { {Id, Type, Tier, Equipped, Hatched} }  Tier: 0 normal, 1 Golden, 2 Rainbow
	Discovered = {}, -- { [PetName] = true } for the pet Index
	Stats = {
		TotalCoins = 0,
		PetsHatched = 0,
		PetsCrafted = 0,
		OrbsCollected = 0,
		GemOrbs = 0,
		BreakablesBroken = 0,
		Playtime = 0, -- seconds
		RobuxSpent = 0,
		Joins = 0,
	},
	Daily = { LastClaim = 0, Streak = 0 },
	GroupClaimed = false,
	RedeemedCodes = {}, -- { [CODE] = true }
	Quests = { Day = 0, Ids = {}, Baseline = {}, Claimed = {}, BonusClaimed = false },
	Upgrades = { WalkSpeed = 0, Magnet = 0, CoinBoost = 0 },
	Purchases = {}, -- processed receipt ids (dedupe)
	Boosts = {}, -- { Luck = {Mult, ExpiresAt}, Coins = {...} }
	Settings = { Music = true, SkipHatchAnimation = false, ShowGuide = true },
	FirstJoin = 0,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Orbs a player is assumed to collect per second when pricing coin rewards.
Config.Economy = {
	-- About 0.85 orbs/s walking plus what pets earn from breakables.
	ReferenceOrbsPerSecond = 1.5,
}

-- Average coins per orb relative to a zone's OrbValue (normal, big, gem orbs).
function Config.ExpectedOrbFactor(): number
	local orbs = Config.Orbs
	local normal = 1 - orbs.BigOrbChance - orbs.GemOrbChance
	return normal * 1.025 + orbs.BigOrbChance * orbs.BigOrbMultiplier
end

-- Coins worth `minutes` of a player's income in their best zone, using their
-- permanent multiplier (pets x rebirth x gamepasses x group; not timed boosts).
-- Shared so the client can preview exact amounts.
function Config.CoinsForMinutes(minutes: number, zonesUnlocked: number, permanentMultiplier: number): number
	local zone = Config.Zones[math.clamp(zonesUnlocked or 1, 1, #Config.Zones)]
	local perSecond = Config.Economy.ReferenceOrbsPerSecond * zone.OrbValue * Config.ExpectedOrbFactor() * math.max(permanentMultiplier or 1, 1)
	return math.max(1, math.floor(minutes * 60 * perSecond))
end

-- `naturalRebirths` = rebirths earned by playing (Rebirths - PurchasedRebirths).
function Config.GetRebirthCost(naturalRebirths: number): number
	local cost = Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ math.max(naturalRebirths, 0)
	return math.floor(math.min(cost, Config.Rebirth.MaxCost))
end

-- Today's quests for a player: a stable pick per (day, userId), one per stat.
function Config.PickQuests(day: number, userId: number): { string }
	local pool = Config.Quests.Pool
	local order = {}
	for index = 1, #pool do
		order[index] = index
	end
	-- deterministic shuffle (LCG) so client and server agree without syncing
	local seed = (day * 7919 + userId * 104729) % 2147483647
	for i = #order, 2, -1 do
		seed = (seed * 16807) % 2147483647
		local j = (seed % i) + 1
		order[i], order[j] = order[j], order[i]
	end
	local picked, usedStats = {}, {}
	for _, index in ipairs(order) do
		local quest = pool[index]
		if not usedStats[quest.Stat] then
			usedStats[quest.Stat] = true
			table.insert(picked, quest.Id)
			if #picked >= Config.Quests.PerDay then
				break
			end
		end
	end
	return picked
end

function Config.GetQuest(id: string)
	for _, quest in ipairs(Config.Quests.Pool) do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

-- Zone index containing a world position, or nil (bridges / outside).
function Config.GetZoneAtPosition(position: Vector3): number?
	local spacing = Config.Map.ZoneSpacing
	local half = Config.Map.ZoneSize / 2
	local index = math.floor(position.X / spacing + 0.5) + 1
	if index < 1 or index > #Config.Zones then
		return nil
	end
	local centerX = (index - 1) * spacing
	if math.abs(position.X - centerX) > half or math.abs(position.Z) > half then
		return nil
	end
	return index
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
		if a.Egg.Zone ~= b.Egg.Zone then
			return a.Egg.Zone < b.Egg.Zone
		end
		if a.Egg.Currency ~= b.Egg.Currency then
			return a.Egg.Currency == "Coins" -- coin eggs first (nearest to spawn)
		end
		return a.Egg.Cost < b.Egg.Cost
	end)
	return list
end

return Config
