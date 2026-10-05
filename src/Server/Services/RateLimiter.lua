--------------------------------------------------------------------------------
-- RateLimiter - per-player token buckets for remote handlers.
--   if not RateLimiter.Allow(player, "EquipPet", 10, 10) then return end
-- capacity = burst size, refillPerSecond = sustained rate.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")

local RateLimiter = {}

type Bucket = { Tokens: number, Updated: number }
local buckets: { [Player]: { [string]: Bucket } } = {}

function RateLimiter.Allow(player: Player, key: string, capacity: number, refillPerSecond: number): boolean
	local now = os.clock()
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { Tokens = capacity, Updated = now }
		playerBuckets[key] = bucket
	end
	bucket.Tokens = math.min(capacity, bucket.Tokens + (now - bucket.Updated) * refillPerSecond)
	bucket.Updated = now
	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return RateLimiter
