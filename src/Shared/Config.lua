--------------------------------------------------------------------------------
-- BRAINROT OBBY - GAME CONFIG
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

Config.GameName = "Brainrot Obby"
Config.Version = 1

-- Bump the suffix to wipe all player data (e.g. "_v2") - use with care!
Config.DataStoreName = "BrainrotObby_Players_v1"
Config.LeaderboardStorePrefix = "BrainrotObby_LB_v1_"

Config.AutosaveInterval = 60 -- seconds
Config.GroupId = 0 -- <<< YOUR GROUP ID HERE (0 disables the group reward)

Config.Debug = {
	-- When true and running in Studio, every gamepass is treated as owned so you
	-- can test them without buying anything.
	FreeGamepassesInStudio = true,
	-- Prints verbose logs from DataService.
	VerboseData = false,
}

--------------------------------------------------------------------------------
-- MONETIZATION
--------------------------------------------------------------------------------

-- Gamepasses: one-time purchases. Set Id to the gamepass id from Creator Hub.
Config.Gamepasses = {
	VIP = {
		Id = 0,
		Name = "VIP",
		Price = 299,
		Description = "+25% coins forever, a gold [VIP] chat tag, 2x daily rewards and the exclusive VIP brainrot!",
		Color = Color3.fromRGB(255, 196, 0),
		Order = 1,
		CoinMultiplier = 1.25,
		DailyRewardMultiplier = 2,
		Brainrot = "Golden Goatini",
	},
	DoubleCoins = {
		Id = 0,
		Name = "2x Coins",
		Price = 199,
		Description = "Every coin you touch and every stage you beat pays DOUBLE.",
		Color = Color3.fromRGB(255, 150, 40),
		Order = 2,
	},
	DoubleJump = {
		Id = 0,
		Name = "Double Jump",
		Price = 149,
		Description = "Jump again in mid-air with EVERY brainrot. Huge help on the hard stages!",
		Color = Color3.fromRGB(90, 200, 255),
		Order = 3,
	},
	SpeedBoost = {
		Id = 0,
		Name = "Speed Boost",
		Price = 99,
		Description = "+20% walk speed with every brainrot.",
		Color = Color3.fromRGB(120, 255, 120),
		Order = 4,
		SpeedMultiplier = 1.2,
	},
	LegendPack = {
		Id = 0,
		Name = "Legend Pack",
		Price = 449,
		Description = "Instantly unlock 3 Legendary brainrots: Nuke Nonna, Galaxy Gnocchi and Tralala Titan!",
		Color = Color3.fromRGB(255, 120, 60),
		Order = 5,
		Brainrots = { "Nuke Nonna", "Galaxy Gnocchi", "Tralala Titan" },
	},
	RainbowTrail = {
		Id = 0,
		Name = "Rainbow Trail",
		Price = 79,
		Description = "A rainbow trail follows you everywhere. Pure style.",
		Color = Color3.fromRGB(255, 110, 190),
		Order = 6,
	},
}

-- Developer Products: repeatable purchases. Set Id from Creator Hub.
-- Grant keys: Skips (stages), Coins.
Config.Products = {
	Skip_1 = { Id = 0, Name = "Skip Stage", Price = 29, Order = 1, Grant = { Skips = 1 } },
	Skip_5 = { Id = 0, Name = "Skip 5 Stages", Price = 119, Order = 2, Grant = { Skips = 5 } },
	Skip_10 = { Id = 0, Name = "Skip 10 Stages", Price = 199, Order = 3, Grant = { Skips = 10 } },
	Coins_Small = { Id = 0, Name = "1,000 Coins", Price = 49, Order = 4, Grant = { Coins = 1000 } },
	Coins_Medium = { Id = 0, Name = "5,000 Coins", Price = 199, Order = 5, Grant = { Coins = 5000 } },
	Coins_Large = { Id = 0, Name = "25,000 Coins", Price = 699, Order = 6, Grant = { Coins = 25000 } },
}

-- The big green SKIP STAGE button on the HUD prompts this product.
Config.SkipProduct = "Skip_1"

--------------------------------------------------------------------------------
-- RARITIES
--------------------------------------------------------------------------------

Config.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(190, 190, 190) },
	Uncommon = { Order = 2, Color = Color3.fromRGB(90, 220, 90) },
	Rare = { Order = 3, Color = Color3.fromRGB(70, 150, 255) },
	Epic = { Order = 4, Color = Color3.fromRGB(190, 80, 255) },
	Legendary = { Order = 5, Color = Color3.fromRGB(255, 170, 0) },
	Mythic = { Order = 6, Color = Color3.fromRGB(255, 60, 120) },
}

--------------------------------------------------------------------------------
-- BRAINROTS - the characters you play as. Better brainrots run faster, jump
-- higher and have a perk, which is what makes the later stages beatable.
--
--   Speed / Jump: Humanoid WalkSpeed and JumpPower (default Roblox: 16 / 50)
--   Perk: "DoubleJump" | "Dash" | "Glide" | "Magnet" | "CoinBoost" (+ Value)
--   Price: coins. Unlock (instead of or as well as a price):
--     { Stage = n } reach stage n   { Prestige = n }   { Gamepass = key }
--   Looks are in BrainrotStyles.lua.
--------------------------------------------------------------------------------

Config.Brainrots = {
	-- Starter
	["Pasta Panda"] = { Rarity = "Common", Price = 0, Speed = 16, Jump = 50, Order = 1, Tagline = "He just wants carbs." },
	["Bongo Banana"] = { Rarity = "Common", Price = 150, Speed = 17, Jump = 50, Order = 2, Tagline = "Bongo bongo bongo." },
	["Espresso Frog"] = { Rarity = "Common", Price = 300, Speed = 18, Jump = 50, Order = 3, Tagline = "Has had 9 espressos." },
	["Pizza Pigeon"] = { Rarity = "Common", Price = 500, Speed = 17, Jump = 53, Order = 4, Tagline = "Coo. Slice. Coo." },

	["Gelato Goat"] = { Rarity = "Uncommon", Price = 900, Speed = 18, Jump = 54, Perk = "Magnet", Value = 10, Order = 5, Tagline = "Three scoops of chaos." },
	["Mozzarella Moth"] = { Rarity = "Uncommon", Price = 1400, Speed = 19, Jump = 55, Perk = "Glide", Value = 0.55, Order = 6, Tagline = "Drawn to the pizza light." },
	["Spaghetti Squid"] = { Rarity = "Uncommon", Price = 2000, Speed = 19, Jump = 55, Perk = "CoinBoost", Value = 0.15, Order = 7, Tagline = "Al dente tentacles." },
	["Tiramisu Turtle"] = { Rarity = "Uncommon", Price = 2800, Speed = 18, Jump = 57, Perk = "DoubleJump", Value = 0.75, Order = 8, Tagline = "Slow? Try double jumping." },

	["Capybara Cannoli"] = { Rarity = "Rare", Price = 4500, Speed = 20, Jump = 56, Perk = "Magnet", Value = 14, Order = 9, Tagline = "Unbothered. Crunchy." },
	["Sneaker Shark"] = { Rarity = "Rare", Price = 6500, Speed = 22, Jump = 55, Perk = "Dash", Value = 55, Order = 10, Tagline = "Three sneakers, zero chill." },
	["Croco Jet"] = { Rarity = "Rare", Price = 9000, Speed = 21, Jump = 58, Perk = "Glide", Value = 0.4, Order = 11, Tagline = "Cleared for takeoff." },
	["Timber Tapper"] = { Rarity = "Rare", Price = 12000, Speed = 20, Jump = 60, Perk = "DoubleJump", Value = 0.85, Order = 12, Tagline = "Tap tap tap at 3am." },

	["Ballerina Latte"] = { Rarity = "Epic", Price = 18000, Speed = 22, Jump = 60, Perk = "Glide", Value = 0.3, Order = 13, Tagline = "Pirouettes over lava." },
	["Cactus Elephante"] = { Rarity = "Epic", Price = 25000, Speed = 21, Jump = 63, Perk = "DoubleJump", Value = 0.9, Order = 14, Tagline = "Do not hug." },
	["Fridge Giraffe"] = { Rarity = "Epic", Price = 34000, Speed = 23, Jump = 60, Perk = "CoinBoost", Value = 0.35, Order = 15, Tagline = "Keeps snacks at neck height." },
	["Drone Dolphino"] = { Rarity = "Epic", Price = 45000, Speed = 24, Jump = 61, Perk = "Dash", Value = 70, Order = 16, Tagline = "Eee-ee-ee (buzzing)." },

	["Nuke Nonna"] = { Rarity = "Legendary", Price = 70000, Speed = 24, Jump = 65, Perk = "DoubleJump", Value = 1, Order = 17, Tagline = "Eat. Now." },
	["Galaxy Gnocchi"] = { Rarity = "Legendary", Price = 95000, Speed = 25, Jump = 64, Perk = "Glide", Value = 0.22, Order = 18, Tagline = "Potato of the cosmos." },
	["Tralala Titan"] = { Rarity = "Legendary", Price = 130000, Speed = 26, Jump = 65, Perk = "Dash", Value = 85, Order = 19, Tagline = "Tra-la-la-LA." },

	["Omega Brainrot"] = { Rarity = "Mythic", Price = 250000, Speed = 28, Jump = 68, Perk = "DoubleJump", Value = 1, Unlock = { Prestige = 1 }, Order = 20, Tagline = "The final form." },

	-- Unlocked by playing (free!)
	["Sahur Stick"] = { Rarity = "Rare", Price = 0, Speed = 21, Jump = 58, Perk = "Magnet", Value = 12, Unlock = { Stage = 30 }, Order = 21, Tagline = "Reach stage 30. Then run." },
	["Cloud Croissant"] = { Rarity = "Epic", Price = 0, Speed = 22, Jump = 62, Perk = "Glide", Value = 0.32, Unlock = { Stage = 60 }, Order = 22, Tagline = "Flaky and floaty." },
	["Prestige Pastaroni"] = { Rarity = "Legendary", Price = 0, Speed = 25, Jump = 66, Perk = "CoinBoost", Value = 0.5, Unlock = { Prestige = 2 }, Order = 23, Tagline = "Finished the obby twice. Still hungry." },

	-- Secret: collect every Brainrot Fragment hidden on the course
	["Fragment Phantom"] = { Rarity = "Mythic", Price = 0, Speed = 27, Jump = 67, Perk = "Glide", Value = 0.2, Unlock = { Fragments = true }, Order = 25, Tagline = "Pieced together from pure brainrot." },

	-- Gamepass
	["Golden Goatini"] = { Rarity = "Legendary", Price = 0, Speed = 25, Jump = 64, Perk = "CoinBoost", Value = 0.4, Unlock = { Gamepass = "VIP" }, Order = 24, Tagline = "VIP only. Shiny." },
}

Config.StarterBrainrot = "Pasta Panda"

Config.Perks = {
	DoubleJump = { Name = "Double Jump", Describe = function(value) return string.format("Jump again in mid-air (%d%% power)", math.floor(value * 100 + 0.5)) end },
	Dash = { Name = "Dash", Describe = function(value) return string.format("Press Q / tap DASH to burst forward (%d speed)", value) end },
	Glide = { Name = "Glide", Describe = function(value) return string.format("Hold jump while falling to float (%d%% slower fall)", math.floor((1 - value) * 100 + 0.5)) end },
	Magnet = { Name = "Coin Magnet", Describe = function(value) return string.format("Pulls in coins from %d studs away", value) end },
	CoinBoost = { Name = "Coin Boost", Describe = function(value) return string.format("+%d%% coins from everything", math.floor(value * 100 + 0.5)) end },
}

Config.DashCooldown = 2.5 -- seconds

-- Cosmetic trails bought with coins (the Rainbow Trail gamepass is separate).
Config.Trails = {
	None = { Name = "No Trail", Price = 0, Order = 0 },
	Mint = { Name = "Mint", Price = 400, Color = Color3.fromRGB(110, 235, 190), Order = 1 },
	Sky = { Name = "Sky", Price = 800, Color = Color3.fromRGB(90, 180, 255), Order = 2 },
	Lava = { Name = "Lava", Price = 1500, Color = Color3.fromRGB(255, 110, 40), Order = 3 },
	Grape = { Name = "Grape", Price = 2500, Color = Color3.fromRGB(190, 110, 255), Order = 4 },
	Gold = { Name = "Gold", Price = 5000, Color = Color3.fromRGB(255, 210, 60), Order = 5 },
	Void = { Name = "Void", Price = 12000, Color = Color3.fromRGB(40, 20, 60), Order = 6 },
}

-- Hidden Brainrot Fragments: one per world section, off the path. Find them
-- all to unlock the secret brainrot.
Config.Fragments = {
	Count = 12,
	Reward = 150, -- coins per fragment on top of the unlock
}

-- DAILY QUESTS - three are picked per player per UTC day from this pool.
-- Progress = how much a Stat grew since the day started.
Config.Quests = {
	PerDay = 3,
	Pool = {
		{ Id = "Coins", Text = "Collect %d coins", Stat = "CoinsCollected", Goal = 60, Reward = { Coins = 300 } },
		{ Id = "Stages", Text = "Beat %d new stages", Stat = "StagesCleared", Goal = 8, Reward = { Coins = 500 } },
		{ Id = "Play", Text = "Play for %d minutes", Stat = "Playtime", Scale = 60, Goal = 15, Reward = { Coins = 350 } },
		{ Id = "Checkpoints", Text = "Touch %d checkpoints", Stat = "CheckpointsTouched", Goal = 20, Reward = { Coins = 250 } },
		{ Id = "Deaths", Text = "Die %d times (it happens)", Stat = "Deaths", Goal = 25, Reward = { Coins = 200 } },
		{ Id = "BigCoins", Text = "Collect %d coins", Stat = "CoinsCollected", Goal = 200, Reward = { Coins = 900 } },
		{ Id = "BigStages", Text = "Beat %d new stages", Stat = "StagesCleared", Goal = 25, Reward = { Coins = 1500 } },
	},
	BonusReward = { Coins = 1000 }, -- for finishing all of today's quests
}

-- SERVER EVENTS - every Interval seconds a Coin Rush doubles coins for everyone.
Config.Events = {
	Interval = 600,
	Duration = 120,
	List = {
		CoinRush = { Name = "COIN RUSH", Description = "x2 coins for everyone!", CoinMult = 2, Color = Color3.fromRGB(255, 200, 40) },
		LuckyStages = { Name = "LUCKY STAGES", Description = "x3 coins for new stages!", StageMult = 3, Color = Color3.fromRGB(120, 255, 160) },
	},
}

--------------------------------------------------------------------------------
-- WORLDS - the course is 100 stages in a row, split into themed worlds.
-- Difficulty ramps inside each world and resets a little at the next one.
-- CoinValue = value of one floating coin here; StageReward = coins for beating
-- a stage for the first time.
--------------------------------------------------------------------------------

Config.Worlds = {
	{
		Name = "Meme Meadow",
		Stages = 15,
		CoinValue = 5,
		StageReward = 15,
		Difficulty = { 0.05, 0.3 }, -- start / end of the world (0 = tutorial, 1 = extreme)
		Boss = "Sneaker Shark",
		Theme = {
			Platform = Color3.fromRGB(120, 210, 90),
			Trim = Color3.fromRGB(70, 150, 60),
			Accent = Color3.fromRGB(255, 220, 70),
			Hazard = Color3.fromRGB(255, 80, 60),
			Sky = Color3.fromRGB(140, 205, 255),
			Ground = "Grass",
			Decor = "Meadow",
		},
	},
	{
		Name = "Pasta Beach",
		Stages = 15,
		CoinValue = 10,
		StageReward = 30,
		Difficulty = { 0.25, 0.45 },
		Boss = "Croco Jet",
		Theme = {
			Platform = Color3.fromRGB(255, 225, 150),
			Trim = Color3.fromRGB(225, 170, 90),
			Accent = Color3.fromRGB(70, 200, 255),
			Hazard = Color3.fromRGB(40, 150, 255),
			Sky = Color3.fromRGB(120, 215, 255),
			Ground = "Sand",
			Decor = "Beach",
		},
	},
	{
		Name = "Sahur Jungle",
		Stages = 15,
		CoinValue = 20,
		StageReward = 60,
		Difficulty = { 0.4, 0.6 },
		Boss = "Timber Tapper",
		Theme = {
			Platform = Color3.fromRGB(70, 160, 80),
			Trim = Color3.fromRGB(120, 85, 50),
			Accent = Color3.fromRGB(255, 150, 40),
			Hazard = Color3.fromRGB(110, 200, 40),
			Sky = Color3.fromRGB(90, 160, 150),
			Ground = "LeafyGrass",
			Decor = "Jungle",
		},
	},
	{
		Name = "Cappuccino City",
		Stages = 15,
		CoinValue = 40,
		StageReward = 120,
		Difficulty = { 0.55, 0.72 },
		Boss = "Ballerina Latte",
		Theme = {
			Platform = Color3.fromRGB(120, 85, 65),
			Trim = Color3.fromRGB(255, 235, 200),
			Accent = Color3.fromRGB(255, 90, 200),
			Hazard = Color3.fromRGB(255, 160, 40),
			Sky = Color3.fromRGB(255, 170, 120),
			Ground = "Concrete",
			Decor = "City",
		},
	},
	{
		Name = "Crocodilo Skies",
		Stages = 20,
		CoinValue = 80,
		StageReward = 240,
		Difficulty = { 0.68, 0.85 },
		Boss = "Tralala Titan",
		Theme = {
			Platform = Color3.fromRGB(240, 245, 255),
			Trim = Color3.fromRGB(150, 200, 255),
			Accent = Color3.fromRGB(255, 220, 80),
			Hazard = Color3.fromRGB(255, 90, 60),
			Sky = Color3.fromRGB(170, 215, 255),
			Ground = "Snow",
			Decor = "Sky",
		},
	},
	{
		Name = "Brainrot Void",
		Stages = 20,
		CoinValue = 160,
		StageReward = 480,
		Difficulty = { 0.82, 1 },
		Boss = "Omega Brainrot",
		Theme = {
			Platform = Color3.fromRGB(90, 60, 170),
			Trim = Color3.fromRGB(200, 120, 255),
			Accent = Color3.fromRGB(90, 255, 230),
			Hazard = Color3.fromRGB(255, 50, 160),
			Sky = Color3.fromRGB(25, 15, 50),
			Ground = "Basalt",
			Decor = "Void",
		},
	},
}

-- Course layout (CourseBuilder). Stages run along +X and climb slowly.
Config.Course = {
	Seed = 20261023, -- change for a different course (checkpoints are saved by number, not position)
	StageLengthMin = 55,
	StageLengthMax = 85,
	RisePerStage = 1.4, -- studs of height gained per stage
	LobbyLength = 110,
	CoinsPerStage = { 3, 5 },
	FallDepth = 28, -- studs below a stage's floor before a player respawns
}

--------------------------------------------------------------------------------
-- ECONOMY
--------------------------------------------------------------------------------

Config.Coins = {
	RespawnSeconds = 90, -- a coin comes back for a player this long after they took it
	PickupRadius = 5, -- studs, walk-over pickup
	MaxPickupDistance = 22, -- server check (bigger for magnet brainrots)
}

Config.Prestige = {
	FinalStage = 100, -- beating this stage lets you prestige
	CoinMultiplierPerPrestige = 0.5, -- +50% coins per prestige
	Reward = 5000, -- coins for prestiging
}

-- Anti-exploit: checkpoint pads must be touched in order; a stage can't be
-- finished faster than its length / (max speed * this factor).
Config.AntiCheat = {
	MaxSpeedFactor = 2.2,
	CheckpointRadius = 16,
}

--------------------------------------------------------------------------------
-- REWARDS - keys: Coins, Brainrot (given once; coins instead if owned)
--------------------------------------------------------------------------------

Config.DailyRewards = {
	{ Coins = 100 },
	{ Coins = 200 },
	{ Coins = 350 },
	{ Coins = 500 },
	{ Coins = 800 },
	{ Coins = 1200 },
	{ Coins = 1000, Brainrot = "Pizza Pigeon", BrainrotCoins = 1500 },
}

-- Session gifts (reset each visit).
Config.PlaytimeRewards = {
	{ Minutes = 3, Coins = 50 },
	{ Minutes = 10, Coins = 150 },
	{ Minutes = 20, Coins = 300 },
	{ Minutes = 30, Coins = 500 },
	{ Minutes = 45, Coins = 800 },
	{ Minutes = 60, Coins = 1500 },
}

Config.GroupReward = {
	Multiplier = 1.1, -- +10% coins while in the group
	Coins = 500, -- one-time claim
}

-- Promo codes live in src/Server/Codes.lua (server only, so they stay secret).

--------------------------------------------------------------------------------
-- SOUNDS (0 = disabled). Use ids you own or free-to-use Roblox library sounds.
--------------------------------------------------------------------------------

Config.Sounds = {
	Click = 0,
	Coin = 0,
	Checkpoint = 0,
	Death = 0,
	Purchase = 0,
	Error = 0,
	Jump = 0,
	Music = 0,
}

--------------------------------------------------------------------------------
-- PLAYER DATA TEMPLATE
--------------------------------------------------------------------------------

Config.DataTemplate = {
	Version = Config.Version,
	Coins = 0,
	Stage = 1, -- current checkpoint
	Prestige = 0,
	Owned = { ["Pasta Panda"] = true }, -- { [BrainrotName] = true }
	Equipped = "Pasta Panda",
	Trails = { None = true },
	EquippedTrail = "None",
	Fragments = {}, -- { [FragmentId] = true }
	Quests = { Day = 0, Ids = {}, Baseline = {}, Claimed = {}, BonusClaimed = false },
	Stats = {
		TotalCoins = 0,
		BestStage = 1, -- highest stage ever reached (plus 100 per prestige)
		Deaths = 0,
		StagesSkipped = 0,
		StagesCleared = 0,
		CheckpointsTouched = 0,
		CoinsCollected = 0,
		FragmentsFound = 0,
		BestTime = 0, -- fastest full run in seconds (0 = never finished)
		RunStart = 0, -- unix time the current run began
		Playtime = 0,
		RobuxSpent = 0,
		Joins = 0,
	},
	Daily = { LastClaim = 0, Streak = 0 },
	GroupClaimed = false,
	RedeemedCodes = {},
	Purchases = {}, -- processed receipt ids (dedupe)
	Settings = { Music = true, Effects = true, ShowOthers = true },
	FirstJoin = 0,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

function Config.TotalStages(): number
	local total = 0
	for _, world in ipairs(Config.Worlds) do
		total += world.Stages
	end
	return total
end

-- World index and the stage's index inside that world (1-based).
function Config.GetWorldForStage(stage: number): (number, number)
	local remaining = stage
	for index, world in ipairs(Config.Worlds) do
		if remaining <= world.Stages then
			return index, remaining
		end
		remaining -= world.Stages
	end
	local last = #Config.Worlds
	return last, Config.Worlds[last].Stages
end

function Config.GetWorld(stage: number)
	local index = Config.GetWorldForStage(stage)
	return Config.Worlds[index], index
end

-- First stage number of a world.
function Config.GetWorldStart(worldIndex: number): number
	local start = 1
	for index = 1, worldIndex - 1 do
		start += Config.Worlds[index].Stages
	end
	return start
end

-- 0..1 difficulty of a stage (eases inside each world, ramps across worlds).
function Config.GetDifficulty(stage: number): number
	local worldIndex, inWorld = Config.GetWorldForStage(stage)
	local world = Config.Worlds[worldIndex]
	local t = if world.Stages > 1 then (inWorld - 1) / (world.Stages - 1) else 1
	return world.Difficulty[1] + (world.Difficulty[2] - world.Difficulty[1]) * t
end

function Config.GetStageReward(stage: number): number
	local world = Config.GetWorld(stage)
	return world.StageReward
end

-- Coins paid for a coin pickup in this stage (before multipliers).
function Config.GetCoinValue(stage: number): number
	local world = Config.GetWorld(stage)
	return world.CoinValue
end

-- Can this brainrot be used? Returns ok plus a reason to show when not.
function Config.CanUnlock(name: string, data): (boolean, string?)
	local def = Config.Brainrots[name]
	if not def then
		return false, "Unknown brainrot"
	end
	local unlock = def.Unlock
	if unlock then
		if unlock.Stage and (data.Stats.BestStage or 1) < unlock.Stage then
			return false, "Reach stage " .. unlock.Stage
		end
		if unlock.Prestige and (data.Prestige or 0) < unlock.Prestige then
			return false, "Prestige " .. unlock.Prestige .. " needed"
		end
		if unlock.Gamepass then
			return false, "Buy the " .. (Config.Gamepasses[unlock.Gamepass] and Config.Gamepasses[unlock.Gamepass].Name or unlock.Gamepass) .. " gamepass"
		end
		if unlock.Fragments then
			local found = 0
			for _ in pairs(data.Fragments or {}) do
				found += 1
			end
			if found < Config.Fragments.Count then
				return false, string.format("Find all %d hidden fragments (%d/%d)", Config.Fragments.Count, found, Config.Fragments.Count)
			end
		end
	end
	if def.Price > 0 and (data.Coins or 0) < def.Price then
		return false, "Need " .. def.Price .. " coins"
	end
	return true, nil
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

-- Today's quests for a player: a stable pick per (day, userId), one per stat.
function Config.PickQuests(day: number, userId: number): { string }
	local pool = Config.Quests.Pool
	local order = {}
	for index = 1, #pool do
		order[index] = index
	end
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

function Config.SortedTrails(): { { Key: string, Def: any } }
	local list = {}
	for key, def in pairs(Config.Trails) do
		table.insert(list, { Key = key, Def = def })
	end
	table.sort(list, function(a, b)
		return a.Def.Order < b.Def.Order
	end)
	return list
end

-- Brainrots sorted for menus: by rarity, then price.
function Config.SortedBrainrots(): { { Name: string, Def: any } }
	local list = {}
	for name, def in pairs(Config.Brainrots) do
		table.insert(list, { Name = name, Def = def })
	end
	table.sort(list, function(a, b)
		return (a.Def.Order or 0) < (b.Def.Order or 0)
	end)
	return list
end

return Config
