--------------------------------------------------------------------------------
-- CoinController - spinning coins, walk-over (or magnet) pickup, local hiding
-- with the same respawn timer as the server, and "+coins" popups.
--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local FloatingText = require(Modules.FloatingText)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local CoinController = {}

local ANIMATE_DISTANCE = 120
local GOLD = Color3.fromRGB(255, 215, 60)

type Info = { Base: CFrame, Phase: number, HiddenUntil: number, Id: string }
local coins: { [BasePart]: Info } = {}
local byId: { [string]: BasePart } = {}
local burstPart: Part
local burst: ParticleEmitter

local function track(coin: Instance)
	if not coin:IsA("BasePart") then
		return
	end
	local id = coin:GetAttribute("CoinId")
	if type(id) ~= "string" then
		return
	end
	coins[coin] = { Base = coin.CFrame, Phase = math.random() * math.pi * 2, HiddenUntil = 0, Id = id }
	byId[id] = coin
end

local function setHidden(coin: BasePart, hidden: boolean)
	coin.Transparency = if hidden then 1 else 0
end

local function step()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not State.Loaded then
		return
	end
	local radius = Config.Coins.PickupRadius + (State.GetPerk("Magnet") or 0)
	local now = os.clock()
	for coin, info in pairs(coins) do
		if info.HiddenUntil > 0 and now >= info.HiddenUntil then
			info.HiddenUntil = 0
			setHidden(coin, false)
		elseif info.HiddenUntil == 0 and (coin.Position - root.Position).Magnitude <= radius then
			info.HiddenUntil = now + Config.Coins.RespawnSeconds
			setHidden(coin, true)
			Remotes.Get("CollectCoin"):FireServer(info.Id)
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
	local parts, cframes = {}, {}
	for coin, info in pairs(coins) do
		if info.HiddenUntil == 0 and (info.Base.Position - cameraPosition).Magnitude < ANIMATE_DISTANCE then
			table.insert(parts, coin)
			table.insert(cframes, info.Base * CFrame.new(0, math.sin(t * 2.5 + info.Phase) * 0.35, 0) * CFrame.Angles(t * 2 + info.Phase, 0, 0))
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function onTaken(coinId: string, amount: number)
	local coin = byId[coinId]
	if not coin then
		return
	end
	burstPart.CFrame = CFrame.new(coin.Position)
	burst:Emit(10)
	FloatingText.Show(coin.Position, "+" .. Util.FormatNumber(amount), GOLD)
	UIController.PlaySound("Coin", 0.4)
end

function CoinController.Init()
	burstPart = Instance.new("Part")
	burstPart.Name = "CoinBurst"
	burstPart.Anchored = true
	burstPart.CanCollide = false
	burstPart.CanQuery = false
	burstPart.CanTouch = false
	burstPart.Transparency = 1
	burstPart.Size = Vector3.new(1, 1, 1)
	burstPart.Parent = Workspace
	burst = Instance.new("ParticleEmitter")
	burst.Rate = 0
	burst.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
	burst.LightEmission = 1
	burst.Lifetime = NumberRange.new(0.3, 0.6)
	burst.Speed = NumberRange.new(8, 14)
	burst.Drag = 6
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	burst.Parent = burstPart

	for _, coin in ipairs(CollectionService:GetTagged("Coin")) do
		track(coin)
	end
	CollectionService:GetInstanceAddedSignal("Coin"):Connect(track)

	Remotes.Get("CoinTaken").OnClientEvent:Connect(onTaken)
	RunService.Heartbeat:Connect(step)
	RunService.RenderStepped:Connect(animate)
end

return CoinController
