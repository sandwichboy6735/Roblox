--------------------------------------------------------------------------------
-- TrailController - coloured speed trails behind players. The colour shows
-- how far a player has upgraded their speed (player attribute "TrailTier",
-- set by the server's UpgradeService), so progress is visible to everyone.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")

local TrailController = {}

local rgb = Color3.fromRGB
local TIERS = {
	ColorSequence.new(rgb(230, 230, 240)), -- grey
	ColorSequence.new(rgb(110, 235, 120)), -- green
	ColorSequence.new(rgb(90, 180, 255)), -- blue
	ColorSequence.new(rgb(185, 110, 255)), -- purple
	ColorSequence.new(rgb(255, 215, 70), rgb(255, 160, 30)), -- golden
	ColorSequence.new({ -- galaxy (max speed + a rebirth)
		ColorSequenceKeypoint.new(0, rgb(120, 70, 255)),
		ColorSequenceKeypoint.new(0.5, rgb(255, 110, 220)),
		ColorSequenceKeypoint.new(1, rgb(80, 220, 255)),
	}),
}

local function apply(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") then
		return
	end
	local trail = root:FindFirstChild("SpeedTrail") :: Trail?
	if not trail then
		local top = Instance.new("Attachment")
		top.Name = "TrailTop"
		top.Position = Vector3.new(0, 1, 0.3)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "TrailBottom"
		bottom.Position = Vector3.new(0, -1.2, 0.3)
		bottom.Parent = root
		local newTrail = Instance.new("Trail")
		newTrail.Name = "SpeedTrail"
		newTrail.Attachment0 = top
		newTrail.Attachment1 = bottom
		newTrail.Lifetime = 0.45
		newTrail.MinLength = 0.1
		newTrail.FaceCamera = true
		newTrail.LightEmission = 0.6
		newTrail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		newTrail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
		newTrail.Parent = root
		trail = newTrail
	end
	local tier = player:GetAttribute("TrailTier")
	local colors = if type(tier) == "number" then TIERS[math.clamp(tier, 0, #TIERS)] else nil
	local t = trail :: Trail
	t.Enabled = colors ~= nil
	if colors then
		t.Color = colors
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		apply(player, character)
	end)
	player:GetAttributeChangedSignal("TrailTier"):Connect(function()
		if player.Character then
			task.spawn(apply, player, player.Character)
		end
	end)
	if player.Character then
		task.spawn(apply, player, player.Character)
	end
end

function TrailController.Init()
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return TrailController
