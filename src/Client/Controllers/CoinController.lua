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

local fragments: { [BasePart]: { Id: string, Base: CFrame, Phase: number } } = {}

local function trackFragment(shard: Instance)
	if shard:IsA("BasePart") then
		local id = shard:GetAttribute("FragmentId")
		if type(id) == "string" then
			fragments[shard] = { Id = id, Base = shard.CFrame, Phase = math.random() * 6 }
		end
	end
end

local function stepFragments(root: BasePart)
	local found = State.Get("Fragments", {})
	for shard, info in pairs(fragments) do
		local taken = found[info.Id] == true
		shard.Transparency = if taken then 1 else 0
		if not taken and (shard.Position - root.Position).Magnitude <= Config.Coins.PickupRadius + 1 then
			Remotes.Get("CollectFragment"):FireServer(info.Id)
		end
	end
end

local function step()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not State.Loaded then
		return
	end
	local radius = Config.Coins.PickupRadius + (State.GetPerk("Magnet") or 0)
	local now = os.clock()
	stepFragments(root)
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
	for shard, info in pairs(fragments) do
		if shard.Transparency < 1 and (info.Base.Position - cameraPosition).Magnitude < ANIMATE_DISTANCE then
			table.insert(parts, shard)
			table.insert(cframes, info.Base * CFrame.new(0, math.sin(t * 2 + info.Phase) * 0.5, 0) * CFrame.Angles(0, t * 1.5, 0))
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function onFragmentTaken(id: string, reward: number)
	for shard, info in pairs(fragments) do
		if info.Id == id then
			burstPart.CFrame = CFrame.new(shard.Position)
			burst.Color = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.new(1, 1, 1))
			burst:Emit(40)
			burst.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
			FloatingText.Show(shard.Position, "FRAGMENT! +" .. Util.FormatNumber(reward), Color3.fromRGB(220, 150, 255), Vector2.new(220, 56))
			UIController.PlaySound("Checkpoint", 0.6)
		end
	end
end

local function onTaken(coinId: string, amount: number)
	local coin = byId[coinId]
	if not coin then
		return
	end
	burstPart.CFrame = CFrame.new(coin.Position)
	local lucky = coin:GetAttribute("Lucky") == true
	burst:Emit(if lucky then 40 else 10)
	FloatingText.Show(coin.Position, (if lucky then "LUCKY! +" else "+") .. Util.FormatNumber(amount), GOLD, if lucky then Vector2.new(220, 56) else nil)
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

	for _, shard in ipairs(CollectionService:GetTagged("Fragment")) do
		trackFragment(shard)
	end
	Remotes.Get("CoinTaken").OnClientEvent:Connect(onTaken)
	Remotes.Get("FragmentTaken").OnClientEvent:Connect(onFragmentTaken)
	RunService.Heartbeat:Connect(step)
	RunService.RenderStepped:Connect(animate)
end

return CoinController
