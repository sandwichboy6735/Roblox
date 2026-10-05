--------------------------------------------------------------------------------
-- ChatController - adds a [VIP] tag in chat for VIP gamepass owners.
-- (Social proof: other players see VIP tags and want one too.)
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatController = {}

function ChatController.Init()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if source then
			local sender = Players:GetPlayerByUserId(source.UserId)
			if sender and sender:GetAttribute("VIP") then
				properties.PrefixText = "<font color='#FFAA00'>[VIP]</font> " .. message.PrefixText
			end
		end
		return properties
	end
end

return ChatController
