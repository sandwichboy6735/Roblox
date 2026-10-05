--------------------------------------------------------------------------------
-- Offline tests for shared game logic and Config data.
-- Run with:   ./scripts/test.sh
-- The script bundles tests/stubs.luau + Config + Util + this file and runs it
-- with the Luau CLI, so `Config`, `Util` and `Color3` are already defined here.
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
check(Util.FormatNumber(999) == "999", "FormatNumber 999")
check(Util.FormatNumber(1000) == "1K", "FormatNumber 1000 -> " .. Util.FormatNumber(1000))
check(Util.FormatNumber(1234) == "1.23K", "FormatNumber 1234 -> " .. Util.FormatNumber(1234))
check(Util.FormatNumber(1500000) == "1.5M", "FormatNumber 1.5M -> " .. Util.FormatNumber(1500000))
check(Util.FormatNumber(25000000) == "25M", "FormatNumber 25M -> " .. Util.FormatNumber(25000000))
check(Util.FormatNumber(-2500) == "-2.5K", "FormatNumber negative")
check(Util.FormatCommas(1234567) == "1,234,567", "FormatCommas")
check(Util.FormatTime(42) == "42s", "FormatTime seconds")
check(Util.FormatTime(125) == "2m 05s", "FormatTime minutes")
check(Util.FormatTime(3725) == "1h 02m", "FormatTime hours")

-- Reconcile fills missing keys without overwriting
local target = { Coins = 5, Stats = { TotalCoins = 9 } }
Util.Reconcile(target, { Coins = 0, Gems = 0, Stats = { TotalCoins = 0, PetsHatched = 0 }, Pets = {} })
check(target.Coins == 5 and target.Gems == 0, "Reconcile keeps values / adds missing")
check(target.Stats.TotalCoins == 9 and target.Stats.PetsHatched == 0, "Reconcile nested")
check(type(target.Pets) == "table", "Reconcile copies arrays")

-- ExactPercentages always sums to exactly 100
for _, weights in ipairs({ { 40, 30, 18, 9, 2.5, 0.5 }, { 40, 30, 18, 9, 5, 1 }, { 1, 1, 1 }, { 50, 30, 30, 10 }, { 1 } }) do
	local pct = Util.ExactPercentages(weights, 2)
	local units = 0
	for _, p in ipairs(pct) do
		units += math.floor(p * 100 + 0.5)
	end
	check(units == 10000, "ExactPercentages sums to 100 for " .. table.concat(weights, ","))
end

-- Daily streak logic
local DAY = 86400
local now = 100 * DAY + 3600
local cycle = #Config.DailyRewards
local s = Util.ComputeDaily({ LastClaim = 0, Streak = 0 }, now, cycle)
check(s.Available and s.NextStreak == 1 and s.NextDay == 1, "Daily: first ever claim")
s = Util.ComputeDaily({ LastClaim = now - DAY, Streak = 3 }, now, cycle)
check(s.Available and s.NextStreak == 4 and s.NextDay == 4, "Daily: streak continues")
s = Util.ComputeDaily({ LastClaim = now - 3 * DAY, Streak = 5 }, now, cycle)
check(s.Available and s.NextStreak == 1, "Daily: streak resets after a missed day")
s = Util.ComputeDaily({ LastClaim = now - 60, Streak = 2 }, now, cycle)
check(not s.Available and s.NextDay == 2, "Daily: already claimed today")
s = Util.ComputeDaily({ LastClaim = now - DAY, Streak = cycle }, now, cycle)
check(s.Available and s.NextDay == 1, "Daily: cycle wraps after the last day")
check(s.SecondsUntilReset > 0 and s.SecondsUntilReset <= DAY, "Daily: reset countdown in range")

-- WeightedIndex respects weights
local rng = Random and Random.new(1) or nil
local counts = { 0, 0 }
for _ = 1, 20000 do
	local i = Util.WeightedIndex({ 3, 1 }, rng)
	counts[i] += 1
end
check(counts[1] > counts[2] * 2.5 and counts[1] < counts[2] * 3.5, "WeightedIndex ~3:1")

--------------------------------------------------------------------------------
-- Config data integrity
--------------------------------------------------------------------------------

for name, pet in pairs(Config.Pets) do
	check(pet.Name == name, "Pet name matches key: " .. name)
	check(Config.Rarities[pet.Rarity] ~= nil, "Pet rarity exists: " .. name)
	check(type(pet.Multiplier) == "number" and pet.Multiplier >= 1, "Pet multiplier >= 1: " .. name)
	check(pet.Shape == "Ball" or pet.Shape == "Block" or pet.Shape == "Cylinder", "Pet shape valid: " .. name)
end

local eggsInZones = {}
for index, zone in ipairs(Config.Zones) do
	if index > 1 then
		check(zone.Cost > Config.Zones[index - 1].Cost, "Zone costs increase: " .. zone.Name)
		check(zone.OrbValue > Config.Zones[index - 1].OrbValue, "Orb values increase: " .. zone.Name)
	end
	for _, eggKey in ipairs(zone.Eggs) do
		eggsInZones[eggKey] = true
		check(Config.Eggs[eggKey] ~= nil, "Zone egg exists: " .. eggKey)
	end
end

for key, egg in pairs(Config.Eggs) do
	local sum = 0
	for _, entry in ipairs(egg.Pets) do
		sum += entry.Chance
		check(Config.Pets[entry.Pet] ~= nil, "Egg " .. key .. " pet exists: " .. entry.Pet)
		check(entry.Chance > 0, "Egg " .. key .. " chance > 0 for " .. entry.Pet)
	end
	check(near(sum, 100, 1e-6), "Egg " .. key .. " chances sum to 100 (got " .. sum .. ")")
	check(egg.Zone >= 1 and egg.Zone <= #Config.Zones, "Egg zone valid: " .. key)
	check(egg.Currency == "Coins" or egg.Currency == "Gems", "Egg currency valid: " .. key)
end

for key in pairs(Config.RestrictedPurchases) do
	check(Config.Products[key] ~= nil or Config.Gamepasses[key] ~= nil, "Restricted purchase key exists: " .. key)
end
-- Everything that sells currency or luck must be restricted for paid-random-item regions.
for key, product in pairs(Config.Products) do
	local grant = product.Grant
	local feedsEggs = grant.CoinMinutes or grant.Coins or grant.Gems or (grant.Boost and grant.Boost.Type == "Luck")
	if feedsEggs then
		check(Config.RestrictedPurchases[key] == true, "Currency/luck product is restricted: " .. key)
	end
end
check(Config.RestrictedPurchases.Lucky == true, "Lucky pass is restricted")

for code, reward in pairs(Codes) do
	check(code == string.upper(code), "Code is uppercase: " .. code)
	if reward.Pet then
		check(Config.Pets[reward.Pet] ~= nil, "Code pet exists: " .. code)
	end
end
for day, reward in ipairs(Config.DailyRewards) do
	if reward.Pet then
		check(Config.Pets[reward.Pet] ~= nil, "Daily pet exists: day " .. day)
	end
end

-- DataStore-safe template: no mixed array/dictionary tables, no numeric dict keys.
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

-- Income-based coin rewards
local factor = Config.ExpectedOrbFactor()
check(factor > 1 and factor < 2, "Expected orb factor sane: " .. factor)
local tenMin = Config.CoinsForMinutes(10, 1, 1)
local expected = 10 * 60 * Config.Economy.ReferenceOrbsPerSecond * Config.Zones[1].OrbValue * factor
check(math.abs(tenMin - expected) <= 1, "CoinsForMinutes formula (" .. tenMin .. " vs " .. expected .. ")")
check(Config.CoinsForMinutes(10, 2, 1) > tenMin, "CoinsForMinutes grows with zone")
check(math.abs(Config.CoinsForMinutes(10, 1, 3) - tenMin * 3) <= 3, "CoinsForMinutes scales with multiplier")
check(Config.CoinsForMinutes(20, 1, 1) > Config.CoinsForMinutes(10, 1, 1), "CoinsForMinutes grows with minutes")
check(Config.CoinsForMinutes(10, 99, 1) == Config.CoinsForMinutes(10, #Config.Zones, 1), "CoinsForMinutes clamps zone")
check(Config.CoinsForMinutes(10, 1, 0) == tenMin, "CoinsForMinutes floors multiplier at 1")

-- Rebirth cost uses natural rebirths and is capped
check(Config.GetRebirthCost(0) == Config.Rebirth.BaseCost, "Rebirth base cost")
check(Config.GetRebirthCost(1) > Config.GetRebirthCost(0), "Rebirth cost grows")
check(Config.GetRebirthCost(500) == Config.Rebirth.MaxCost, "Rebirth cost capped")
check(Config.Rebirth.MaxCost < 2 ^ 53, "Rebirth cap below the coin cap")
check(Config.GetRebirthCost(-3) == Config.Rebirth.BaseCost, "Rebirth cost never below base")

-- Zone lookup by world position
local function v3(x, y, z)
	return { X = x, Y = y, Z = z }
end
local spacing = Config.Map.ZoneSpacing
check(Config.GetZoneAtPosition(v3(0, 3, 0) :: any) == 1, "Zone at origin is 1")
check(Config.GetZoneAtPosition(v3(spacing, 3, 40) :: any) == 2, "Zone 2 centre")
check(Config.GetZoneAtPosition(v3(spacing / 2, 3, 0) :: any) == nil, "Bridge is in no zone")
check(Config.GetZoneAtPosition(v3((#Config.Zones - 1) * spacing, 3, 0) :: any) == #Config.Zones, "Last zone")
check(Config.GetZoneAtPosition(v3(#Config.Zones * spacing, 3, 0) :: any) == nil, "Past last zone")
check(Config.GetZoneAtPosition(v3(0, 3, Config.Map.ZoneSize) :: any) == nil, "Outside zone on Z")

-- Pacing guard rails: costs rise faster than orb values; first egg is quick.
check(Config.Eggs.Basic.Cost <= Config.Zones[1].OrbValue * 40, "First egg affordable within ~40 orbs")
-- Each coin egg costs far less than the next goal, so players hatch many eggs.
for _, egg in pairs(Config.Eggs) do
	if egg.Currency == "Coins" then
		local nextZone = Config.Zones[egg.Zone + 1]
		local nextGoal = if nextZone then nextZone.Cost else Config.GetRebirthCost(0)
		check(egg.Cost * 20 <= nextGoal, egg.Name .. " costs at most 1/20 of the next goal")
	end
end

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
