--------------------------------------------------------------------------------
-- RewardText - rich-text description of a reward table, matching what the
-- server will grant ({ CoinMinutes?, Gems?, Pet?, Boost? }).
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared.Util)

local State = require(script.Parent.ClientState)

local RewardText = {}

function RewardText.Describe(reward, multiplier: number?, separator: string?): string
	local mult = multiplier or 1
	local parts = {}
	if reward.CoinMinutes then
		local amount = State.CoinsForMinutes(reward.CoinMinutes) * mult
		table.insert(parts, "<font color='#FFC400'>" .. Util.FormatNumber(amount) .. " Coins</font>")
	end
	if reward.Gems then
		table.insert(parts, "<font color='#6EFAE1'>" .. Util.FormatNumber(reward.Gems * mult) .. " Gems</font>")
	end
	if reward.Pet then
		local discovered = State.Get("Discovered", {})
		if reward.PetOnce and discovered[reward.Pet] then
			table.insert(parts, "<font color='#6EFAE1'>+" .. Util.FormatNumber((reward.PetGems or 100) * mult) .. " Gems</font>")
		else
			table.insert(parts, "<font color='#FFAA00'>" .. reward.Pet .. "</font>")
		end
	end
	if reward.Boost then
		table.insert(parts, string.format("<font color='#AF69FF'>x%s %s %s</font>", tostring(reward.Boost.Mult), reward.Boost.Type, Util.FormatTime(reward.Boost.Duration)))
	end
	return table.concat(parts, separator or "\n")
end

return RewardText
