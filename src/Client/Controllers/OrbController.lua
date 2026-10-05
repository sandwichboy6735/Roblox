--------------------------------------------------------------------------------
-- OrbController - walk-over / magnet orb pickup, orb bobbing, "+coins" popups.
-- The server re-validates every pickup (distance, zone, rate).
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local OrbController = {}

local SEND_INTERVAL = 1 / 6 -- matches the server's sustained pickup rate
local RETRY_AFTER = 2.5 -- un-hide an orb if the server didn't take it after sending
local ANIMATE_DISTANCE = 140
local MAX_POPUPS = 10
local MAX_QUEUE = 6 -- keeps popups within ~1s of the actual pickup

-- Queued: hidden locally and waiting to be sent. SentAt: when the request went out.
type OrbInfo = { Base: CFrame, Phase: number, Queued: boolean, SentAt: number? }

local orbs: { [BasePart]: OrbInfo } = {}
local queue: { BasePart } = {}
local lastSend = 0
local popupCount = 0
local popupFolder: Folder

local function track(orb: Instance)
	if not orb:IsA("BasePart") then
		return
	end
	orbs[orb] = { Base = orb.CFrame, Phase = math.random() * math.pi * 2, Queued = false, SentAt = nil }
end

local function untrack(orb: Instance)
	orbs[orb :: BasePart] = nil
end

local function showPopup(position: Vector3, text: string, color: Color3)
	if popupCount >= MAX_POPUPS then
		return
	end
	popupCount += 1
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = popupFolder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.Parent = gui

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.95, function()
		anchor:Destroy()
		popupCount -= 1
	end)
end

local burstPart: Part
local burst: ParticleEmitter

-- Quick sparkle burst where an orb was picked up.
local function burstAt(position: Vector3, color: Color3, amount: number)
	burstPart.CFrame = CFrame.new(position)
	burst.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	burst:Emit(amount)
end

local function popupFor(orb: BasePart)
	local kind = orb:GetAttribute("Kind")
	burstAt(orb.Position, orb.Color, if kind == "Coin" then 8 else 18)
	local value = orb:GetAttribute("Value") or 0
	if kind == "Gem" then
		showPopup(orb.Position, "+" .. value .. " Gems", Color3.fromRGB(110, 250, 225))
	else
		local amount = math.max(1, math.floor(value * State.GetMultiplier()))
		showPopup(orb.Position, "+" .. Util.FormatNumber(amount), Color3.fromRGB(255, 220, 60))
	end
	UIController.PlaySound("Collect", 0.35)
end

local function hide(orb: BasePart)
	-- Hide locally; the server destroys the real part.
	orb.Transparency = 1
	for _, child in ipairs(orb:GetChildren()) do
		if child:IsA("Light") then
			child.Enabled = false
		elseif child:IsA("Sparkles") then
			child.Enabled = false
		end
	end
end

local function restore(orb: BasePart)
	orb.Transparency = 0
	for _, child in ipairs(orb:GetChildren()) do
		if child:IsA("Light") or child:IsA("Sparkles") then
			child.Enabled = true
		end
	end
end

local function step()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not State.Loaded then
		return
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return
	end

	local unlocked = State.Get("ZonesUnlocked", 1)
	local radius = Config.Orbs.CollectRadius
	if State.Owns("AutoCollect") then
		radius = Config.Gamepasses.AutoCollect.Radius
	end
	local rootPosition = root.Position
	local now = os.clock()

	for orb, info in pairs(orbs) do
		if info.Queued then
			-- Sent but the server never removed it (e.g. rate limited): show it again.
			if info.SentAt and now - info.SentAt > RETRY_AFTER and orb.Parent then
				info.Queued = false
				info.SentAt = nil
				restore(orb)
			end
		elseif #queue < MAX_QUEUE then
			local zone = orb:GetAttribute("Zone") or 1
			if zone <= unlocked and (orb.Position - rootPosition).Magnitude <= radius then
				info.Queued = true
				table.insert(queue, orb)
				hide(orb)
			end
		end
	end

	-- Orbs we've walked too far from for the server to accept reappear at once.
	local serverReach = if State.Owns("AutoCollect") then Config.Gamepasses.AutoCollect.Radius + 16 else Config.Orbs.MaxCollectDistance
	for index = #queue, 1, -1 do
		local orb = queue[index]
		if (orb.Position - rootPosition).Magnitude > serverReach - 6 then
			table.remove(queue, index)
			local info = orbs[orb]
			if info then
				info.Queued = false
				restore(orb)
			end
		end
	end

	-- Drain the queue at a steady rate, nearest orb first.
	if #queue > 1 then
		table.sort(queue, function(a, b)
			return (a.Position - rootPosition).Magnitude < (b.Position - rootPosition).Magnitude
		end)
	end
	while #queue > 0 and now - lastSend >= SEND_INTERVAL do
		local orb = table.remove(queue, 1)
		local info = orb and orbs[orb]
		if info and orb.Parent then
			lastSend = now
			info.SentAt = now
			popupFor(orb)
			Remotes.Get("CollectOrb"):FireServer(orb)
		end
	end
end

local function animate()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local t = os.clock()
	local parts = {}
	local cframes = {}
	for orb, info in pairs(orbs) do
		if not info.Queued and (info.Base.Position - cameraPosition).Magnitude < ANIMATE_DISTANCE then
			local bob = math.sin(t * 2.2 + info.Phase) * 0.4
			table.insert(parts, orb)
			table.insert(cframes, info.Base * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * 1.4 + info.Phase, 0))
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function OrbController.Init()
	burstPart = Instance.new("Part")
	burstPart.Name = "PickupBurst"
	burstPart.Anchored = true
	burstPart.CanCollide = false
	burstPart.CanQuery = false
	burstPart.CanTouch = false
	burstPart.Transparency = 1
	burstPart.Size = Vector3.new(1, 1, 1)
	burstPart.Parent = Workspace
	burst = Instance.new("ParticleEmitter")
	burst.Rate = 0
	burst.LightEmission = 1
	burst.Lifetime = NumberRange.new(0.35, 0.6)
	burst.Speed = NumberRange.new(8, 14)
	burst.Drag = 6
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	burst.Parent = burstPart

	popupFolder = Instance.new("Folder")
	popupFolder.Name = "OrbPopups"
	popupFolder.Parent = Workspace

	task.spawn(function()
		local folder = Workspace:WaitForChild("Orbs")
		for _, orb in ipairs(folder:GetChildren()) do
			track(orb)
		end
		folder.ChildAdded:Connect(track)
		folder.ChildRemoved:Connect(untrack)
	end)

	RunService.Heartbeat:Connect(step)
	RunService.RenderStepped:Connect(animate)
end

return OrbController
