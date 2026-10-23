--------------------------------------------------------------------------------
-- RewardText - rich-text description of a reward table, matching what the
-- server will grant ({ Coins?, Brainrot?, BrainrotCoins? }).
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared.Util)

local State = require(script.Parent.ClientState)

local RewardText = {}

function RewardText.Describe(reward, multiplier: number?, separator: string?): string
	local mult = multiplier or 1
	local parts = {}
	if reward.Coins then
		table.insert(parts, "<font color='#FFC400'>" .. Util.FormatNumber(reward.Coins * mult) .. " Coins</font>")
	end
	if reward.Brainrot then
		local owned = State.Get("Owned", {})
		if owned[reward.Brainrot] then
			table.insert(parts, "<font color='#FFC400'>+" .. Util.FormatNumber((reward.BrainrotCoins or 500) * mult) .. " Coins</font>")
		else
			table.insert(parts, "<font color='#FFAA00'>" .. reward.Brainrot .. "</font>")
		end
	end
	return table.concat(parts, separator or "\n")
end

return RewardText
