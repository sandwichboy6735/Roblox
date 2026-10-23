--------------------------------------------------------------------------------
-- PlayerVisualsController - what makes characters feel alive:
--   name tags over every player (brainrot, rarity colour, stage),
--   a cartoon outline on your own costume,
--   landing dust, and a death explosion that flings costume pieces around.
--------------------------------------------------------------------------------

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)

local player = Players.LocalPlayer

local PlayerVisualsController = {}

local INK = Color3.fromRGB(28, 22, 40)
local tags: { [Player]: { Name: TextLabel, Stage: TextLabel } } = {}
local dustPart: Part
local dust: ParticleEmitter

local function effectsOn(): boolean
	local settings = State.Get("Settings", {})
	return settings.Effects ~= false
end

--------------------------------------------------------------------------------
-- Name tags
--------------------------------------------------------------------------------

local function refreshTag(target: Player)
	local tag = tags[target]
	if not tag then
		return
	end
	local brainrot = target:GetAttribute("Brainrot")
	local def = type(brainrot) == "string" and Config.Brainrots[brainrot] or nil
	local color = if def then Config.Rarities[def.Rarity].Color:Lerp(Color3.new(1, 1, 1), 0.3) else Color3.new(1, 1, 1)
	tag.Name.Text = target.DisplayName .. (if def then "  -  " .. brainrot else "")
	tag.Name.TextColor3 = color
	local oldShine = tag.Name:FindFirstChildOfClass("UIGradient")
	if oldShine then
		oldShine:Destroy()
	end
	local shine = def and UIKit.ShineFor(def.Rarity, 0) or nil
	if shine then
		tag.Name.TextColor3 = Color3.new(1, 1, 1)
		UIKit.Shine(tag.Name, shine)
	end
	local leaderstats = target:FindFirstChild("leaderstats")
	local stage = leaderstats and leaderstats:FindFirstChild("Stage")
	local prestige = leaderstats and leaderstats:FindFirstChild("Prestige")
	local stageText = if stage and stage:IsA("IntValue") then "Stage " .. stage.Value else ""
	if prestige and prestige:IsA("IntValue") and prestige.Value > 0 then
		stageText ..= "  -  Prestige " .. prestige.Value
	end
	tag.Stage.Text = stageText
end

local function addTag(target: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.new(6, 0, 1.6, 0)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.MaxDistance = if target == player then 0 else 70
	gui.LightInfluence = 0
	gui.Adornee = head
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.6)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextStrokeTransparency = 0
	name.TextStrokeColor3 = INK
	name.Parent = gui
	local stage = Instance.new("TextLabel")
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromScale(0, 0.6)
	stage.Size = UDim2.fromScale(1, 0.4)
	stage.Font = Enum.Font.LuckiestGuy
	stage.TextScaled = true
	stage.TextColor3 = Color3.fromRGB(255, 225, 90)
	stage.TextStrokeTransparency = 0
	stage.TextStrokeColor3 = INK
	stage.Parent = gui
	gui.Parent = head
	tags[target] = { Name = name, Stage = stage }
	refreshTag(target)
	-- hide the default Roblox name (we draw our own)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

--------------------------------------------------------------------------------
-- Outline on my own costume
--------------------------------------------------------------------------------

local outline: Highlight

local function attachOutline(character: Model)
	local costume = character:WaitForChild("Costume", 10)
	if costume then
		outline.Adornee = costume
		outline.Enabled = true
	end
	character.ChildAdded:Connect(function(child)
		if child.Name == "Costume" then
			outline.Adornee = child
			outline.Enabled = true
		end
	end)
end

--------------------------------------------------------------------------------
-- Dust and death explosion
--------------------------------------------------------------------------------

local function puff(position: Vector3, amount: number)
	if not effectsOn() then
		return
	end
	dustPart.CFrame = CFrame.new(position)
	dust:Emit(amount)
end

local function explode(character: Model)
	if not effectsOn() then
		return
	end
	local costume = character:FindFirstChild("Costume")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not costume or not root or not root:IsA("BasePart") then
		return
	end
	local rng = Random.new()
	local count = 0
	for _, part in ipairs(costume:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 and count < 24 then
			count += 1
			local chunk = part:Clone()
			for _, child in ipairs(chunk:GetChildren()) do
				if not child:IsA("SpecialMesh") then
					child:Destroy()
				end
			end
			chunk.Anchored = false
			chunk.CanCollide = true
			chunk.CanQuery = false
			chunk.CanTouch = false
			chunk.Massless = false
			chunk.Parent = Workspace
			chunk.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(20, 45), rng:NextNumber(-25, 25))
			chunk.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
			Debris:AddItem(chunk, 2.5)
		end
	end
	puff(root.Position, 20)
end

local function watchCharacter(target: Player, character: Model)
	addTag(target, character)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		explode(character)
	end)
	if target == player then
		attachOutline(character)
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					puff(root.Position - Vector3.new(0, 2.6, 0), 8)
				end
			end
		end)
	end
end

local function watch(target: Player)
	target.CharacterAdded:Connect(function(character)
		watchCharacter(target, character)
	end)
	if target.Character then
		task.spawn(watchCharacter, target, target.Character)
	end
	target:GetAttributeChangedSignal("Brainrot"):Connect(function()
		refreshTag(target)
	end)
end

function PlayerVisualsController.Init()
	dustPart = Instance.new("Part")
	dustPart.Name = "DustFx"
	dustPart.Anchored = true
	dustPart.CanCollide = false
	dustPart.CanQuery = false
	dustPart.CanTouch = false
	dustPart.Transparency = 1
	dustPart.Size = Vector3.new(1, 1, 1)
	dustPart.Parent = Workspace
	dust = Instance.new("ParticleEmitter")
	dust.Rate = 0
	dust.Color = ColorSequence.new(Color3.fromRGB(240, 235, 225))
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(4, 9)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1.6) })
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Parent = dustPart

	outline = Instance.new("Highlight")
	outline.Name = "CostumeOutline"
	outline.FillTransparency = 1
	outline.OutlineColor = INK
	outline.OutlineTransparency = 0.1
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Enabled = false
	outline.Parent = dustPart

	for _, target in ipairs(Players:GetPlayers()) do
		watch(target)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(target)
		tags[target] = nil
	end)

	-- stage numbers on tags change often; refresh them a few times a second
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.5 then
			accumulator = 0
			for target in pairs(tags) do
				refreshTag(target)
			end
		end
	end)
end

return PlayerVisualsController
