--------------------------------------------------------------------------------
-- Offline tests for shared game logic and Config data.
-- Run with:   ./scripts/test.sh
-- The script bundles tests/stubs.luau + Config + Util + BrainrotStyles + Codes
-- and this file, so those are already defined here.
--------------------------------------------------------------------------------

local passed, failed = 0, 0
local function check(condition: boolean, message: string)
	if condition then
		passed += 1
	else
		failed += 1
		print("FAIL: " .. message)
	end
end

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-9)
end

--------------------------------------------------------------------------------
-- Util
--------------------------------------------------------------------------------

check(Util.FormatNumber(0) == "0", "FormatNumber 0")
check(Util.FormatNumber(1234) == "1.23K", "FormatNumber 1234 -> " .. Util.FormatNumber(1234))
check(Util.FormatNumber(1500000) == "1.5M", "FormatNumber 1.5M")
check(Util.FormatTime(42) == "42s", "FormatTime seconds")
check(Util.FormatTime(125) == "2m 05s", "FormatTime minutes")
local target = { Coins = 5, Stats = { TotalCoins = 9 } }
Util.Reconcile(target, { Coins = 0, Stage = 1, Stats = { TotalCoins = 0, Deaths = 0 }, Owned = {} })
check(target.Coins == 5 and target.Stage == 1, "Reconcile keeps values / adds missing")
check(target.Stats.TotalCoins == 9 and target.Stats.Deaths == 0, "Reconcile nested")

local DAY = 86400
local now = 100 * DAY + 3600
local cycle = #Config.DailyRewards
local s = Util.ComputeDaily({ LastClaim = 0, Streak = 0 }, now, cycle)
check(s.Available and s.NextStreak == 1 and s.NextDay == 1, "Daily: first ever claim")
s = Util.ComputeDaily({ LastClaim = now - DAY, Streak = 3 }, now, cycle)
check(s.Available and s.NextStreak == 4 and s.NextDay == 4, "Daily: next day continues streak")
s = Util.ComputeDaily({ LastClaim = now - 3 * DAY, Streak = 3 }, now, cycle)
check(s.Available and s.NextStreak == 1, "Daily: a missed day resets")

--------------------------------------------------------------------------------
-- Worlds and stages
--------------------------------------------------------------------------------

local total = Config.TotalStages()
check(total == 100, "100 stages total (got " .. total .. ")")
check(Config.Prestige.FinalStage == total, "Prestige needs the final stage")
check(#Config.Worlds >= 4, "At least four worlds")
for index, world in ipairs(Config.Worlds) do
	check(world.Stages >= 5, world.Name .. " has stages")
	check(world.Difficulty[1] < world.Difficulty[2] and world.Difficulty[2] <= 1 and world.Difficulty[1] >= 0, world.Name .. " difficulty range valid")
	check(world.CoinValue > 0 and world.StageReward > 0, world.Name .. " pays coins")
	check(type(world.Theme.Decor) == "string" and type(world.Theme.Ground) == "string", world.Name .. " has a theme")
	if index > 1 then
		local previous = Config.Worlds[index - 1]
		check(world.CoinValue > previous.CoinValue and world.StageReward > previous.StageReward, world.Name .. " pays more than the world before")
		check(world.Difficulty[2] > previous.Difficulty[2], world.Name .. " ends harder than the world before")
	end
	local start = Config.GetWorldStart(index)
	local w, inWorld = Config.GetWorldForStage(start)
	check(w == index and inWorld == 1, world.Name .. " starts at stage " .. start)
	local w2, inWorld2 = Config.GetWorldForStage(start + world.Stages - 1)
	check(w2 == index and inWorld2 == world.Stages, world.Name .. " last stage maps back")
end
check(Config.GetWorldStart(1) == 1, "World 1 starts at stage 1")
local lastDifficulty = -1
for stage = 1, total do
	local d = Config.GetDifficulty(stage)
	check(d >= 0 and d <= 1, "Difficulty in range for stage " .. stage)
	local _, inWorld = Config.GetWorldForStage(stage)
	if inWorld > 1 then
		check(d >= lastDifficulty, "Difficulty never drops inside a world (stage " .. stage .. ")")
	end
	lastDifficulty = d
end
check(Config.GetDifficulty(1) < 0.1, "Stage 1 is a tutorial")
check(Config.GetDifficulty(total) == 1, "Last stage is max difficulty")
check(Config.GetStageReward(1) == Config.Worlds[1].StageReward and Config.GetCoinValue(total) == Config.Worlds[#Config.Worlds].CoinValue, "Reward lookups")
check(Config.Course.StageLengthMin < Config.Course.StageLengthMax and Config.Course.RisePerStage > 0, "Course layout settings sane")
check(Config.Course.CoinsPerStage[1] <= Config.Course.CoinsPerStage[2], "Coins per stage range")

-- A full run earns enough for the mid-tier brainrots but not everything.
local runCoins = 0
for stage = 1, total do
	runCoins += Config.GetStageReward(stage) + Config.GetCoinValue(stage) * (Config.Course.CoinsPerStage[1] + Config.Course.CoinsPerStage[2]) / 2
end
local priceSum = 0
for _, def in pairs(Config.Brainrots) do
	priceSum += def.Price
end
check(runCoins > 15000, "One run earns a meaningful amount (" .. math.floor(runCoins) .. ")")
check(priceSum > runCoins * 5, "Buying every brainrot takes many runs")

--------------------------------------------------------------------------------
-- Brainrots
--------------------------------------------------------------------------------

local orders = {}
local count = 0
for name, def in pairs(Config.Brainrots) do
	count += 1
	check(Config.Rarities[def.Rarity] ~= nil, name .. " has a valid rarity")
	check(def.Speed >= 16 and def.Speed <= 30 and def.Jump >= 50 and def.Jump <= 70, name .. " stats in range")
	check(def.Price >= 0, name .. " price non-negative")
	check(orders[def.Order] == nil, name .. " has a unique order")
	orders[def.Order] = true
	check(type(def.Tagline) == "string", name .. " has a tagline")
	if def.Perk then
		check(Config.Perks[def.Perk] ~= nil and type(def.Value) == "number", name .. " perk valid")
		check(type(Config.Perks[def.Perk].Describe(def.Value)) == "string", name .. " perk describes itself")
	end
	if def.Unlock then
		check(def.Unlock.Stage == nil or (def.Unlock.Stage > 1 and def.Unlock.Stage <= total), name .. " stage unlock in range")
		check(def.Unlock.Gamepass == nil or Config.Gamepasses[def.Unlock.Gamepass] ~= nil, name .. " gamepass unlock exists")
	end
	local style = BrainrotStyles.Characters[name]
	check(style ~= nil, name .. " has a look")
	if style then
		check(BrainrotStyles.Archetypes[style.Archetype] == true, name .. " uses a known body plan")
		check(style.Primary ~= nil and style.Secondary ~= nil and style.Accent ~= nil, name .. " has all three colours")
		for _, extra in ipairs(style.Extras or {}) do
			check(BrainrotStyles.Extras[extra] == true, name .. " uses a known extra (" .. tostring(extra) .. ")")
		end
	end
end
check(count >= 20, "At least 20 brainrots (" .. count .. ")")
for name in pairs(BrainrotStyles.Characters) do
	check(Config.Brainrots[name] ~= nil, "Style " .. name .. " matches a brainrot")
end
check(Config.Brainrots[Config.StarterBrainrot] ~= nil and Config.Brainrots[Config.StarterBrainrot].Price == 0, "Starter brainrot is free")
check(Config.DataTemplate.Owned[Config.StarterBrainrot] == true and Config.DataTemplate.Equipped == Config.StarterBrainrot, "New players own and wear the starter")

-- Better rarity = better stats on average, and the price climbs with Order.
local sorted = Config.SortedBrainrots()
for index = 2, #sorted do
	local a, b = sorted[index - 1], sorted[index]
	if a.Def.Price > 0 and b.Def.Price > 0 then
		check(b.Def.Price >= a.Def.Price, b.Name .. " costs at least as much as " .. a.Name)
	end
end
local function avgStat(rarity)
	local sum, n = 0, 0
	for _, def in pairs(Config.Brainrots) do
		if def.Rarity == rarity then
			sum += def.Speed + def.Jump
			n += 1
		end
	end
	return if n > 0 then sum / n else 0
end
check(avgStat("Common") < avgStat("Rare") and avgStat("Rare") < avgStat("Legendary") and avgStat("Legendary") < avgStat("Mythic"), "Rarer brainrots are stronger")

-- CanUnlock
local fresh = { Stats = { BestStage = 1 }, Prestige = 0, Coins = 0 }
check(select(1, Config.CanUnlock("Pasta Panda", fresh)) == true, "Starter can always be unlocked")
check(select(1, Config.CanUnlock("Bongo Banana", fresh)) == false, "Can't afford with 0 coins")
check(select(1, Config.CanUnlock("Bongo Banana", { Stats = { BestStage = 1 }, Prestige = 0, Coins = 150 })) == true, "Can afford exactly")
check(select(1, Config.CanUnlock("Sahur Stick", { Stats = { BestStage = 29 }, Prestige = 0, Coins = 0 })) == false, "Stage unlock blocks early")
check(select(1, Config.CanUnlock("Sahur Stick", { Stats = { BestStage = 30 }, Prestige = 0, Coins = 0 })) == true, "Stage unlock opens at the stage")
check(select(1, Config.CanUnlock("Omega Brainrot", { Stats = { BestStage = 100 }, Prestige = 0, Coins = 1e9 })) == false, "Prestige unlock blocks before prestige")
check(select(1, Config.CanUnlock("Golden Goatini", { Stats = { BestStage = 100 }, Prestige = 9, Coins = 1e9 })) == false, "Gamepass unlock is never buyable")
check(select(1, Config.CanUnlock("Nope", fresh)) == false, "Unknown brainrot")

--------------------------------------------------------------------------------
-- Monetization and rewards
--------------------------------------------------------------------------------

check(Config.Products[Config.SkipProduct] ~= nil and Config.Products[Config.SkipProduct].Grant.Skips == 1, "Skip product exists")
for key, product in pairs(Config.Products) do
	check(product.Price > 0 and type(product.Name) == "string", "Product " .. key .. " priced and named")
	check((product.Grant.Skips or 0) > 0 or (product.Grant.Coins or 0) > 0, "Product " .. key .. " grants something")
end
for key, pass in pairs(Config.Gamepasses) do
	check(pass.Price > 0 and type(pass.Description) == "string" and pass.Color ~= nil, "Gamepass " .. key .. " complete")
end
check(Config.Brainrots[Config.Gamepasses.VIP.Brainrot] ~= nil, "VIP brainrot exists")
for _, name in ipairs(Config.Gamepasses.LegendPack.Brainrots) do
	check(Config.Brainrots[name] ~= nil and Config.Brainrots[name].Rarity == "Legendary", "Legend Pack brainrot " .. name .. " is legendary")
end
check(Config.Gamepasses.SpeedBoost.SpeedMultiplier > 1 and Config.Gamepasses.VIP.CoinMultiplier > 1, "Gamepass numbers sane")

for code, reward in pairs(Codes) do
	check(code == string.upper(code), "Code is uppercase: " .. code)
	check((reward.Coins or 0) > 0 or reward.Brainrot ~= nil, "Code gives something: " .. code)
	if reward.Brainrot then
		check(Config.Brainrots[reward.Brainrot] ~= nil, "Code brainrot exists: " .. code)
	end
end
for day, reward in ipairs(Config.DailyRewards) do
	check((reward.Coins or 0) > 0 or reward.Brainrot ~= nil, "Daily reward " .. day .. " gives something")
	if reward.Brainrot then
		check(Config.Brainrots[reward.Brainrot] ~= nil, "Daily brainrot exists: day " .. day)
	end
end
for index, reward in ipairs(Config.PlaytimeRewards) do
	check(reward.Minutes > 0 and (reward.Coins or 0) > 0, "Playtime reward " .. index .. " valid")
	if index > 1 then
		check(reward.Minutes > Config.PlaytimeRewards[index - 1].Minutes, "Playtime rewards in order")
	end
end
check(Config.GroupReward.Coins > 0 and Config.GroupReward.Multiplier > 1, "Group reward")

-- DataStore-safe template: no mixed array/dictionary tables.
local function checkSerializable(value: any, path: string)
	if type(value) ~= "table" then
		check(type(value) ~= "function" and type(value) ~= "userdata", "Serializable value at " .. path)
		return
	end
	local hasString, hasNumber = false, false
	for k, v in pairs(value) do
		if type(k) == "string" then
			hasString = true
		elseif type(k) == "number" then
			hasNumber = true
		end
		checkSerializable(v, path .. "." .. tostring(k))
	end
	check(not (hasString and hasNumber), "No mixed keys at " .. path)
end
checkSerializable(Config.DataTemplate, "DataTemplate")
check(Config.DataTemplate.Settings.Music == true and Config.DataTemplate.Settings.Effects == true, "Settings defaults")
check(near(Config.Prestige.CoinMultiplierPerPrestige, 0.5) and Config.Prestige.Reward > 0, "Prestige settings")
check(Config.AntiCheat.MaxSpeedFactor > 1 and Config.AntiCheat.CheckpointRadius > 5, "Anti-cheat tolerances sane")
check(Config.Coins.RespawnSeconds > 10 and Config.Coins.PickupRadius < Config.Coins.MaxPickupDistance, "Coin settings sane")

--------------------------------------------------------------------------------
-- Bosses, trails, fragments, quests, events
--------------------------------------------------------------------------------

for _, world in ipairs(Config.Worlds) do
	check(Config.Brainrots[world.Boss] ~= nil, world.Name .. " boss brainrot exists")
end
check(Config.Trails.None ~= nil and Config.Trails.None.Price == 0, "Free 'no trail' option")
local trailOrders = {}
for key, trail in pairs(Config.Trails) do
	check(type(trail.Name) == "string" and trail.Price >= 0, "Trail " .. key .. " valid")
	check(key == "None" or trail.Color ~= nil, "Trail " .. key .. " has a colour")
	check(trailOrders[trail.Order] == nil, "Trail " .. key .. " order unique")
	trailOrders[trail.Order] = true
end
check(Config.DataTemplate.Trails.None == true and Config.DataTemplate.EquippedTrail == "None", "Trail data template")
check(Config.Fragments.Count >= 6 and Config.Fragments.Reward > 0, "Fragment settings")
local secret = 0
for name, def in pairs(Config.Brainrots) do
	if def.Unlock and def.Unlock.Fragments then
		secret += 1
		check(def.Price == 0, name .. " is free once the fragments are found")
	end
end
check(secret == 1, "Exactly one fragment brainrot")
local allFound = {}
for i = 1, Config.Fragments.Count do
	allFound["F" .. i] = true
end
check(select(1, Config.CanUnlock("Fragment Phantom", { Stats = { BestStage = 1 }, Prestige = 0, Coins = 0, Fragments = {} })) == false, "Secret locked without fragments")
check(select(1, Config.CanUnlock("Fragment Phantom", { Stats = { BestStage = 1 }, Prestige = 0, Coins = 0, Fragments = allFound })) == true, "Secret unlocks with every fragment")

local questIds, statCount, distinct = {}, 0, {}
for _, quest in ipairs(Config.Quests.Pool) do
	check(questIds[quest.Id] == nil, "Quest id unique: " .. quest.Id)
	questIds[quest.Id] = true
	check(Config.DataTemplate.Stats[quest.Stat] ~= nil, quest.Id .. " tracks a saved stat")
	check(quest.Goal > 0 and (quest.Reward.Coins or 0) > 0, quest.Id .. " has a goal and reward")
	check(string.find(quest.Text, "%d", 1, true) ~= nil, quest.Id .. " text shows the goal")
	if not distinct[quest.Stat] then
		distinct[quest.Stat] = true
		statCount += 1
	end
end
check(statCount >= Config.Quests.PerDay, "Enough quest stats for a full day")
for _, userId in ipairs({ 1, 42, 123456789 }) do
	for day = 20000, 20010 do
		local ids = Config.PickQuests(day, userId)
		check(#ids == Config.Quests.PerDay, "PickQuests count")
		local stats, ok = {}, true
		for _, id in ipairs(ids) do
			local quest = Config.GetQuest(id)
			if not quest or stats[quest.Stat] then
				ok = false
			else
				stats[quest.Stat] = true
			end
		end
		check(ok, "PickQuests one per stat")
		check(table.concat(Config.PickQuests(day, userId), ",") == table.concat(ids, ","), "PickQuests deterministic")
	end
end
check(Config.Events.Duration < Config.Events.Interval, "Events shorter than their interval")
for key, event in pairs(Config.Events.List) do
	check(type(event.Name) == "string" and (event.CoinMult or event.StageMult), "Event " .. key .. " does something")
end
check(Config.DataTemplate.Stats.StagesCleared == 0 and Config.DataTemplate.Stats.CheckpointsTouched == 0 and Config.DataTemplate.Stats.FragmentsFound == 0, "New stats in template")

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
