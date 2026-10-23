--------------------------------------------------------------------------------
-- TrailController - coloured trails behind players. The colour shows a
-- player's prestige (player attribute "TrailTier", set by BrainrotService);
-- the Rainbow Trail gamepass gives the galaxy one.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local TrailController = {}

local rgb = Color3.fromRGB
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(120, 70, 255)),
	ColorSequenceKeypoint.new(0.5, rgb(255, 110, 220)),
	ColorSequenceKeypoint.new(1, rgb(80, 220, 255)),
})

local function colorsFor(key: any): ColorSequence?
	if key == "Rainbow" then
		return RAINBOW
	end
	local def = type(key) == "string" and Config.Trails[key]
	if def and def.Color then
		return ColorSequence.new(def.Color, def.Color:Lerp(Color3.new(1, 1, 1), 0.5))
	end
	return nil
end

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
	local colors = colorsFor(player:GetAttribute("Trail"))
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
	player:GetAttributeChangedSignal("Trail"):Connect(function()
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
