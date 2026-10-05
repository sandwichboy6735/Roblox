-- General helpers shared by server and client.

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 1500000 -> "1.5M"
function Util.FormatNumber(value: number): string
	value = tonumber(value) or 0
	if value < 0 then
		return "-" .. Util.FormatNumber(-value)
	end
	if value < 1000 then
		return tostring(math.floor(value))
	end

	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end

	local text
	if value >= 100 then
		text = string.format("%.0f", value)
	elseif value >= 10 then
		text = string.format("%.1f", value)
	else
		text = string.format("%.2f", value)
	end

	if text:find("%.") then
		text = text:gsub("0+$", "")
		text = text:gsub("%.$", "")
	end

	return text .. SUFFIXES[index]
end

-- 1234567 -> "1,234,567"
function Util.FormatCommas(value: number): string
	local str = tostring(math.floor(value))
	local formatted = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- 3725 -> "1h 02m", 125 -> "2m 05s", 42 -> "42s"
function Util.FormatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %02ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

function Util.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value :: any) do
		copy[key] = Util.DeepCopy(item)
	end
	return (copy :: any) :: T
end

local function isArray(tbl: { [any]: any }): boolean
	return #tbl > 0 or next(tbl) == nil
end

-- Adds any keys missing from `target` using `template` as the default.
-- Arrays in the template are treated as values (copied only if missing).
function Util.Reconcile(target: { [any]: any }, template: { [any]: any })
	for key, templateValue in pairs(template) do
		local current = target[key]
		if current == nil then
			target[key] = Util.DeepCopy(templateValue)
		elseif type(templateValue) == "table" and type(current) == "table" and not isArray(templateValue) then
			Util.Reconcile(current, templateValue)
		end
	end
end

function Util.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Util.Round(value: number, decimals: number?): number
	local mult = 10 ^ (decimals or 0)
	return math.floor(value * mult + 0.5) / mult
end

-- Picks a random index from a list of weights.
function Util.WeightedIndex(weights: { number }, rng: Random?): number
	local total = 0
	for _, weight in ipairs(weights) do
		total += weight
	end
	local roll = (rng and rng:NextNumber() or math.random()) * total
	for index, weight in ipairs(weights) do
		roll -= weight
		if roll <= 0 then
			return index
		end
	end
	return #weights
end

function Util.Count(tbl: { [any]: any }): number
	local count = 0
	for _ in pairs(tbl) do
		count += 1
	end
	return count
end

-- Current UTC day number (used for daily rewards).
function Util.DayNumber(unixTime: number): number
	return math.floor(unixTime / 86400)
end

-- Converts weights into percentages rounded to `decimals` places that always
-- sum to EXACTLY 100 (largest-remainder method). Required by Roblox's paid
-- random items policy for displayed odds.
function Util.ExactPercentages(weights: { number }, decimals: number): { number }
	local scale = 10 ^ decimals
	local totalUnits = 100 * scale
	local totalWeight = 0
	for _, weight in ipairs(weights) do
		totalWeight += weight
	end
	local result, remainders = {}, {}
	local assigned = 0
	for index, weight in ipairs(weights) do
		local exact = if totalWeight > 0 then weight / totalWeight * totalUnits else 0
		local floored = math.floor(exact)
		result[index] = floored
		remainders[index] = { Index = index, Remainder = exact - floored }
		assigned += floored
	end
	table.sort(remainders, function(a, b)
		return a.Remainder > b.Remainder
	end)
	local leftover = totalUnits - assigned
	local i = 1
	while leftover > 0 and #remainders > 0 do
		local entry = remainders[((i - 1) % #remainders) + 1]
		result[entry.Index] += 1
		leftover -= 1
		i += 1
	end
	for index, units in ipairs(result) do
		result[index] = units / scale
	end
	return result
end

-- Daily reward state shared by server and client.
-- daily = { LastClaim = unix, Streak = n }
function Util.ComputeDaily(daily: { LastClaim: number, Streak: number }, now: number, cycleLength: number)
	local today = Util.DayNumber(now)
	local last = Util.DayNumber(daily.LastClaim or 0)
	local available = last < today
	local nextStreak
	if last == today - 1 then
		nextStreak = (daily.Streak or 0) + 1
	elseif last == today then
		nextStreak = daily.Streak or 1
	else
		nextStreak = 1
	end
	local nextDay = ((nextStreak - 1) % cycleLength) + 1
	local secondsUntilReset = (today + 1) * 86400 - now
	return {
		Available = available,
		NextStreak = nextStreak,
		NextDay = nextDay,
		SecondsUntilReset = secondsUntilReset,
	}
end

return Util
