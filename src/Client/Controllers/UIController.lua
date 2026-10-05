--------------------------------------------------------------------------------
-- UIController - ScreenGui root, HUD, side buttons, windows, toasts, confirms.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)

local player = Players.LocalPlayer

local UIController = {}
UIController.Windows = {} :: { [string]: any }
UIController.SideButtons = {} :: { [string]: TextButton }

local screenGui: ScreenGui
local root: Frame
local uiScale: UIScale
local toastContainer: Frame
local confirmOverlay: Frame
local coinsLabel: TextLabel
local gemsLabel: TextLabel
local multLabel: TextLabel
local breakdownLabel: TextLabel
local boostsLabel: TextLabel
local sideList: Frame

local KIND_COLORS = {
	info = UIKit.Colors.Info,
	success = UIKit.Colors.Success,
	error = UIKit.Colors.Danger,
	reward = UIKit.Colors.Accent,
}

--------------------------------------------------------------------------------
-- Sounds
--------------------------------------------------------------------------------

local soundCache: { [string]: Sound } = {}

function UIController.PlaySound(key: string, volume: number?)
	local id = Config.Sounds[key]
	if not id or id == 0 then
		return
	end
	local sound = soundCache[key]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = key
		sound.SoundId = "rbxassetid://" .. id
		sound.Volume = volume or 0.5
		sound.Parent = SoundService
		soundCache[key] = sound
	end
	sound:Play()
end

--------------------------------------------------------------------------------
-- Responsive scaling
--------------------------------------------------------------------------------

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local scale = math.min(viewport.X / 1280, viewport.Y / 720)
	uiScale.Scale = math.clamp(scale, 0.55, 1.15)
end

--------------------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------------------

local function currencyPill(parent: Instance, name: string, color: Color3, order: number, iconShape: string)
	local pill = UIKit.Frame({
		Name = name,
		Size = UDim2.fromOffset(230, 46),
		BackgroundColor3 = UIKit.Colors.Background,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Parent = parent,
	})
	UIKit.Corner(pill, 23)
	UIKit.Stroke(pill, color, 2)

	local icon = UIKit.Frame({
		Name = "Icon",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = color,
		Parent = pill,
	})
	if iconShape == "diamond" then
		icon.Rotation = 45
		icon.Size = UDim2.fromOffset(24, 24)
		icon.Position = UDim2.fromOffset(11, 11)
		UIKit.Corner(icon, 4)
	else
		UIKit.Corner(icon, 15)
		UIKit.Stroke(icon, color:Lerp(Color3.new(0, 0, 0), 0.3), 3)
	end

	local label = UIKit.Label({
		Name = "Value",
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -100, 1, 0),
		Font = UIKit.Fonts.Black,
		TextSize = 22,
		Text = "0",
		TextColor3 = Color3.new(1, 1, 1),
		Parent = pill,
	})

	local plus = UIKit.Button({
		Name = "Plus",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		Color = UIKit.Colors.Success,
		Text = "+",
		TextSize = 22,
		Radius = 15,
	}, function()
		UIController.Open("Shop")
	end)
	plus.Parent = pill

	return label
end

local function buildHUD()
	local currency = UIKit.Frame({
		Name = "Currency",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(230, 100),
		BackgroundTransparency = 1,
		Parent = root,
	})
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = currency })
	coinsLabel = currencyPill(currency, "Coins", UIKit.Colors.Accent, 1, "circle")
	gemsLabel = currencyPill(currency, "Gems", UIKit.Colors.Gems, 2, "diamond")

	-- Multiplier (top-right)
	local multPill = UIKit.Frame({
		Name = "Multiplier",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(190, 46),
		BackgroundColor3 = UIKit.Colors.Background,
		BackgroundTransparency = 0.15,
		Parent = root,
	})
	UIKit.Corner(multPill, 23)
	UIKit.Stroke(multPill, UIKit.Colors.Purple, 2)
	multLabel = UIKit.Label({
		Size = UDim2.fromScale(1, 1),
		Font = UIKit.Fonts.Black,
		TextSize = 20,
		Text = "x1.00 Coins",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = UIKit.Colors.Purple,
		Parent = multPill,
	})

	breakdownLabel = UIKit.Label({
		Name = "Breakdown",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 64),
		Size = UDim2.fromOffset(190, 90),
		Font = UIKit.Fonts.Body,
		TextSize = 14,
		TextColor3 = UIKit.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false,
		Parent = root,
	})
	multPill.MouseEnter:Connect(function()
		breakdownLabel.Visible = true
	end)
	multPill.MouseLeave:Connect(function()
		breakdownLabel.Visible = false
	end)

	boostsLabel = UIKit.Label({
		Name = "Boosts",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 64),
		Size = UDim2.fromOffset(190, 50),
		Font = UIKit.Fonts.Bold,
		TextSize = 15,
		TextColor3 = UIKit.Colors.Success,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = root,
	})
end

local lastCoins, lastGems = nil, nil

local function refreshHUD()
	local coins = State.Get("Coins", 0)
	local gems = State.Get("Gems", 0)
	coinsLabel.Text = Util.FormatNumber(coins)
	gemsLabel.Text = Util.FormatNumber(gems)
	if lastCoins and coins > lastCoins then
		UIKit.Pop(coinsLabel.Parent :: GuiObject, 1.06)
	end
	if lastGems and gems > lastGems then
		UIKit.Pop(gemsLabel.Parent :: GuiObject, 1.1)
	end
	lastCoins, lastGems = coins, gems

	local info = State.Get("Multiplier")
	if info then
		multLabel.Text = string.format("x%.2f Coins", info.Total)
		breakdownLabel.Text = string.format(
			"Pets x%.2f\nRebirth x%.2f\nGamepass x%.2f\nGroup x%.2f\nBoost x%.2f",
			info.Pets,
			info.Rebirth,
			info.Gamepass,
			info.Group,
			info.Boost
		)
	end
end

local function refreshBoosts()
	local boosts = State.Get("Boosts", {})
	local now = State.Now()
	local lines = {}
	for boostType, boost in pairs(boosts) do
		local remaining = (boost.ExpiresAt or 0) - now
		if remaining > 0 then
			table.insert(lines, string.format("%s x%s  %s", boostType, tostring(boost.Mult), Util.FormatTime(remaining)))
		end
	end
	boostsLabel.Text = table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Side buttons
--------------------------------------------------------------------------------

function UIController.AddSideButton(name: string, label: string, color: Color3, order: number, onClick: () -> ())
	local button = UIKit.Button({
		Name = name,
		Size = UDim2.fromOffset(120, 48),
		Color = color,
		Text = label,
		TextSize = 20,
		Font = UIKit.Fonts.Title,
		LayoutOrder = order,
		Radius = 14,
	}, function()
		UIController.PlaySound("Click")
		onClick()
	end)
	button.Parent = sideList

	local badge = UIKit.Frame({
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = UIKit.Colors.Danger,
		Visible = false,
		ZIndex = 5,
		Parent = button,
	})
	UIKit.Corner(badge, 10)
	UIKit.Stroke(badge, Color3.new(1, 1, 1), 2)
	UIKit.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "!",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 6,
		Parent = badge,
	})

	UIController.SideButtons[name] = button
	return button
end

function UIController.SetBadge(name: string, visible: boolean)
	local button = UIController.SideButtons[name]
	local badge = button and button:FindFirstChild("Badge")
	if badge then
		badge.Visible = visible
	end
end

--------------------------------------------------------------------------------
-- Windows
--------------------------------------------------------------------------------

function UIController.RegisterWindow(name: string, window)
	UIController.Windows[name] = window
end

function UIController.CloseAll(except: string?)
	for name, window in pairs(UIController.Windows) do
		if name ~= except then
			window.Close()
		end
	end
end

function UIController.Open(name: string)
	local window = UIController.Windows[name]
	if not window then
		return
	end
	UIController.CloseAll(name)
	window.Open()
end

function UIController.Close(name: string)
	local window = UIController.Windows[name]
	if window then
		window.Close()
	end
end

function UIController.Toggle(name: string)
	local window = UIController.Windows[name]
	if not window then
		return
	end
	if window.IsOpen() then
		window.Close()
	else
		UIController.Open(name)
	end
end

function UIController.CreateWindow(name: string, title: string, size: UDim2, accent: Color3?)
	local window = UIKit.Window(root, title, size, accent)
	UIController.RegisterWindow(name, window)
	return window
end

--------------------------------------------------------------------------------
-- Toasts
--------------------------------------------------------------------------------

function UIController.Notify(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or UIKit.Colors.Info
	local toast = UIKit.Frame({
		Size = UDim2.fromOffset(420, 44),
		BackgroundColor3 = UIKit.Colors.Background,
		BackgroundTransparency = 0.1,
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 50,
		Parent = toastContainer,
	})
	UIKit.Corner(toast, 12)
	UIKit.Stroke(toast, color, 2)
	local label = UIKit.Label({
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(12, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 51,
		Parent = toast,
	})
	label.TextColor3 = if kind == "error" then UIKit.Colors.Danger:Lerp(Color3.new(1, 1, 1), 0.5) else Color3.new(1, 1, 1)

	toast.BackgroundTransparency = 1
	label.TextTransparency = 1
	UIKit.Tween(toast, { BackgroundTransparency = 0.1 }, 0.2)
	UIKit.Tween(label, { TextTransparency = 0 }, 0.2)

	if kind == "error" then
		UIController.PlaySound("Error")
	end

	task.delay(4, function()
		UIKit.Tween(toast, { BackgroundTransparency = 1 }, 0.3)
		UIKit.Tween(label, { TextTransparency = 1 }, 0.3)
		task.wait(0.3)
		toast:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Confirm dialog
--------------------------------------------------------------------------------

local confirmCallback: (() -> ())? = nil
local confirmTitle: TextLabel
local confirmBody: TextLabel

function UIController.Confirm(title: string, body: string, onConfirm: () -> ())
	confirmCallback = onConfirm
	confirmTitle.Text = title
	confirmBody.Text = body
	confirmOverlay.Visible = true
end

local function buildConfirm()
	confirmOverlay = UIKit.Frame({
		Name = "ConfirmOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Visible = false,
		ZIndex = 100,
		Parent = root,
	})
	local box = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(400, 220),
		BackgroundColor3 = UIKit.Colors.Background,
		ZIndex = 101,
		Parent = confirmOverlay,
	})
	UIKit.Corner(box, 16)
	UIKit.Stroke(box, UIKit.Colors.Accent, 2)

	confirmTitle = UIKit.Label({
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 36),
		Font = UIKit.Fonts.Title,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 102,
		Parent = box,
	})
	confirmBody = UIKit.Label({
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 0, 80),
		Font = UIKit.Fonts.Body,
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UIKit.Colors.Muted,
		ZIndex = 102,
		Parent = box,
	})

	local yes = UIKit.Button({
		Position = UDim2.new(0.5, -150, 1, -62),
		Size = UDim2.fromOffset(140, 44),
		Color = UIKit.Colors.Success,
		Text = "CONFIRM",
		ZIndex = 102,
	}, function()
		confirmOverlay.Visible = false
		if confirmCallback then
			confirmCallback()
		end
		confirmCallback = nil
	end)
	yes.Parent = box

	local no = UIKit.Button({
		Position = UDim2.new(0.5, 10, 1, -62),
		Size = UDim2.fromOffset(140, 44),
		Color = UIKit.Colors.Danger,
		Text = "CANCEL",
		ZIndex = 102,
	}, function()
		confirmOverlay.Visible = false
		confirmCallback = nil
	end)
	no.Parent = box
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function UIController.Init()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = UIKit.Create("ScreenGui", {
		Name = "HatchLegendsUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
	})

	root = UIKit.Frame({
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = screenGui,
	})
	uiScale = UIKit.Create("UIScale", { Parent = root })

	toastContainer = UIKit.Frame({
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(420, 300),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = root,
	})
	UIKit.Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = toastContainer,
	})

	sideList = UIKit.Frame({
		Name = "SideButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(120, 360),
		BackgroundTransparency = 1,
		Parent = root,
	})
	UIKit.Create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = sideList,
	})

	buildHUD()
	buildConfirm()

	UIController.Root = root
	UIController.ScreenGui = screenGui
	screenGui.Parent = playerGui

	updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local newCamera = workspace.CurrentCamera
		if newCamera then
			newCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
			updateScale()
		end
	end)

	State.OnLoaded(refreshHUD)
	State.Changed:Connect(function(patch)
		if patch.Coins ~= nil or patch.Gems ~= nil or patch.Multiplier ~= nil then
			refreshHUD()
		end
		if patch.Boosts ~= nil then
			refreshBoosts()
		end
	end)

	Remotes.Get("Notify").OnClientEvent:Connect(function(text, kind)
		UIController.Notify(tostring(text), kind)
	end)

	-- Timers (boost countdowns)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 1 then
			accumulator = 0
			refreshBoosts()
		end
	end)

	-- Close windows with Escape-like key (Backspace is unused in Roblox by default)
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Backspace then
			UIController.CloseAll()
		end
	end)
end

return UIController
