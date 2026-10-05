--------------------------------------------------------------------------------
-- WorldController - zone gates (local collision + touch to unlock) and the
-- "next goal" progress bar that always tells players what to do next.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local WorldController = {}

local TOUCH_COOLDOWN = 3

local gates: { [number]: BasePart } = {}
local lastTouch = 0

local goalFill: Frame
local goalLabel: TextLabel

--------------------------------------------------------------------------------
-- Gates
--------------------------------------------------------------------------------

local function refreshGates()
	local unlocked = State.Get("ZonesUnlocked", 1)
	for zone, gate in pairs(gates) do
		local open = zone <= unlocked
		gate.CanCollide = not open
		gate.Transparency = open and 0.85 or 0.2
		local label = gate:FindFirstChild("Label")
		if label and label:IsA("BillboardGui") then
			local subtitle = label:FindFirstChild("Subtitle")
			if subtitle and subtitle:IsA("TextLabel") then
				if open then
					subtitle.Text = "Unlocked!"
				elseif zone == unlocked + 1 then
					subtitle.Text = "Unlock: " .. Util.FormatNumber(Config.Zones[zone].Cost) .. " Coins"
				else
					subtitle.Text = "Locked"
				end
			end
		end
	end
end

local function onGateTouched(zone: number, hit: BasePart)
	local character = player.Character
	if not character or not hit:IsDescendantOf(character) then
		return
	end
	local unlocked = State.Get("ZonesUnlocked", 1)
	if zone ~= unlocked + 1 then
		return
	end
	local now = os.clock()
	if now - lastTouch < TOUCH_COOLDOWN then
		return
	end
	lastTouch = now

	local zoneInfo = Config.Zones[zone]
	local coins = State.Get("Coins", 0)
	if coins < zoneInfo.Cost then
		UIController.Notify(string.format("%s costs %s coins. You need %s more!", zoneInfo.Name, Util.FormatNumber(zoneInfo.Cost), Util.FormatNumber(zoneInfo.Cost - coins)), "error")
		return
	end
	UIController.Confirm("Unlock " .. zoneInfo.Name .. "?", "Spend " .. Util.FormatNumber(zoneInfo.Cost) .. " coins to unlock a new zone with better orbs and a new egg!", function()
		Remotes.Get("UnlockZone"):FireServer(zone)
	end)
end

local function registerGate(gate: Instance)
	if not gate:IsA("BasePart") then
		return
	end
	local zone = gate:GetAttribute("Zone")
	if type(zone) ~= "number" then
		return
	end
	gates[zone] = gate
	gate.Touched:Connect(function(hit)
		onGateTouched(zone, hit)
	end)
end

--------------------------------------------------------------------------------
-- Goal bar
--------------------------------------------------------------------------------

local function refreshGoal()
	if not State.Loaded then
		return
	end
	local coins = State.Get("Coins", 0)
	local unlocked = State.Get("ZonesUnlocked", 1)
	local nextZone = Config.Zones[unlocked + 1]
	local goalText, target
	if nextZone then
		target = nextZone.Cost
		goalText = "Next zone: " .. nextZone.Name
	else
		target = State.GetRebirthCost()
		goalText = "Next: REBIRTH"
	end
	local progress = math.clamp(coins / math.max(target, 1), 0, 1)
	UIKit.Tween(goalFill, { Size = UDim2.fromScale(progress, 1) }, 0.2)
	if progress >= 1 then
		goalLabel.Text = goalText .. "  -  READY!"
	else
		goalLabel.Text = string.format("%s  -  %s / %s", goalText, Util.FormatNumber(coins), Util.FormatNumber(target))
	end
end

local function buildGoalBar()
	local bar = UIKit.Frame({
		Name = "GoalBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(440, 30),
		BackgroundColor3 = UIKit.Colors.Background,
		BackgroundTransparency = 0.15,
		Parent = UIController.Root,
	})
	UIKit.Corner(bar, 15)
	UIKit.Stroke(bar, UIKit.Colors.Accent, 2)

	goalFill = UIKit.Frame({
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UIKit.Colors.Accent,
		Parent = bar,
	})
	UIKit.Corner(goalFill, 15)
	UIKit.Gradient(goalFill, Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 150, 0), 0)

	goalLabel = UIKit.Label({
		Size = UDim2.fromScale(1, 1),
		Font = UIKit.Fonts.Black,
		TextSize = 15,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
		Parent = bar,
	})
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function WorldController.Init()
	buildGoalBar()

	task.spawn(function()
		local map = Workspace:WaitForChild("Map")
		local gateFolder = map:WaitForChild("Gates", 30)
		if gateFolder then
			for _, gate in ipairs(gateFolder:GetChildren()) do
				registerGate(gate)
			end
			gateFolder.ChildAdded:Connect(function(gate)
				registerGate(gate)
				refreshGates()
			end)
		end
		State.OnLoaded(refreshGates)
	end)

	State.OnLoaded(refreshGoal)
	State.Changed:Connect(function(patch)
		if patch.ZonesUnlocked ~= nil then
			refreshGates()
		end
		if patch.Coins ~= nil or patch.ZonesUnlocked ~= nil or patch.Rebirths ~= nil or patch.PurchasedRebirths ~= nil then
			refreshGoal()
		end
	end)
end

return WorldController
