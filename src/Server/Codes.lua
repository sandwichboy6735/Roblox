--------------------------------------------------------------------------------
-- PROMO CODES (server only - players can't read this file, so codes for future
-- promotions stay secret until you announce them).
--
-- Codes are case-insensitive. Post them on social media / YouTube descriptions
-- to drive traffic. Optional Expires = unix timestamp (https://www.epochconverter.com).
-- Reward keys: Coins (scaled to the player's progress), Gems, Pet, Boost.
--------------------------------------------------------------------------------

return {
	RELEASE = { Gems = 50 },
	HATCH = { Coins = 2500 },
	LUCKY = { Boost = { Type = "Luck", Mult = 2, Duration = 10 * 60 } },
	-- EXAMPLE = { Gems = 100, Expires = 1767225600 },
}
