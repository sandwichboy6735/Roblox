--------------------------------------------------------------------------------
-- UIController - ScreenGui root, HUD (coins, stage, timer, skip/reset), side buttons, windows, toasts, confirms.
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
local multLabel: TextLabel
local stageLabel: TextLabel
local worldLabel: TextLabel
local timerLabel: TextLabel
local prestigeLabel: TextLabel
local progressFill: Frame
local fragmentLabel: TextLabel
local sideList: Frame

local MAX_TOASTS = 4
local toastCounter = 0

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
	local scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.55, 1.15)
	uiScale.Scale = scale
	-- UIScale also scales Root itself, so size Root at 1/scale (centred) to keep
	-- it exactly covering the screen after scaling.
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
end

--------------------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------------------

local function pill(parent: Instance, name: string, color: Color3, width: number, order: number): Frame
	local frame = UIKit.Frame({
		Name = name,
		Size = UDim2.fromOffset(width, 46),
		BackgroundColor3 = UIKit.Colors.Background,
		BackgroundTransparency = 0.1,
		LayoutOrder = order,
		Parent = parent,
	})
	UIKit.Corner(frame, 23)
	UIKit.Stroke(frame, UIKit.Ink, 3)
	UIKit.Lip(frame, color:Lerp(Color3.new(0, 0, 0), 0.4), 3)
	return frame
end

local function bigText(parent: Instance, props: { [string]: any }): TextLabel
	local defaults = {
		Size = UDim2.fromScale(1, 1),
		Font = UIKit.Fonts.Display,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = UIKit.Ink,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = parent,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return UIKit.Label(defaults)
end

local function buildHUD()
	-- Top-left: coins
	local column = UIKit.Frame({
		Name = "TopLeft",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(240, 110),
		BackgroundTransparency = 1,
		Parent = root,
	})
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = column })

	local coinPill = pill(column, "Coins", UIKit.Colors.Accent, 230, 1)
	local icon = UIKit.Frame({ Name = "Icon", Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(7, 7), BackgroundColor3 = UIKit.Colors.Accent, Parent = coinPill })
	UIKit.Corner(icon, 16)
	UIKit.Stroke(icon, UIKit.Ink, 2.5)
	UIKit.Gradient(icon, Color3.new(1, 1, 1), Color3.fromRGB(215, 175, 120), 90)
	bigText(icon, { Text = "$", TextSize = 18, TextColor3 = Color3.fromRGB(120, 80, 20), TextStrokeTransparency = 1 })
	coinsLabel = bigText(coinPill, { Name = "Value", Position = UDim2.fromOffset(48, 2), Size = UDim2.new(1, -100, 1, 0), TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Text = "0" })
	local plus = UIKit.Button({ Name = "Plus", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(30, 30), Color = UIKit.Colors.Success, Text = "+", TextSize = 22, Radius = 15 }, function()
		UIController.Open("Shop")
	end)
	plus.Parent = coinPill

	local multPill = pill(column, "Multiplier", UIKit.Colors.Purple, 230, 2)
	multLabel = bigText(multPill, { TextSize = 20, TextColor3 = UIKit.Colors.Purple:Lerp(Color3.new(1, 1, 1), 0.3), Text = "x1.00 Coins" })

	-- Top-centre: stage + world + timer
	local stagePill = UIKit.Frame({
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(300, 76),
		BackgroundColor3 = UIKit.Colors.Background,
		BackgroundTransparency = 0.1,
		Parent = root,
	})
	UIKit.Corner(stagePill, 20)
	UIKit.Stroke(stagePill, UIKit.Ink, 3)
	UIKit.Lip(stagePill, UIKit.Colors.Info:Lerp(Color3.new(0, 0, 0), 0.4), 4)
	stageLabel = bigText(stagePill, { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 40), TextSize = 34, TextColor3 = Color3.fromRGB(255, 230, 90), Text = "STAGE 1" })
	worldLabel = bigText(stagePill, { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 22), Font = UIKit.Fonts.Title, TextSize = 16, TextColor3 = UIKit.Colors.Muted, TextStrokeTransparency = 0.5, Text = "" })
	local progressBar = UIKit.Frame({ Position = UDim2.new(0, 14, 1, -11), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = UIKit.Colors.PanelLight, Parent = stagePill })
	UIKit.Corner(progressBar, 3)
	progressFill = UIKit.Frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 230, 90), Parent = progressBar })
	UIKit.Corner(progressFill, 3)

	local fragmentPill = pill(root, "Fragments", UIKit.Colors.Purple, 170, 1)
	fragmentPill.AnchorPoint = Vector2.new(1, 0)
	fragmentPill.Position = UDim2.new(1, -16, 0, 12 + 54)
	fragmentPill.Size = UDim2.fromOffset(170, 36)
	fragmentLabel = bigText(fragmentPill, { TextSize = 16, Font = UIKit.Fonts.Title, TextColor3 = Color3.fromRGB(220, 150, 255), Text = "FRAGMENTS 0/12" })

	local timerPill = pill(root, "Timer", UIKit.Colors.Info, 190, 1)
	timerPill.AnchorPoint = Vector2.new(0.5, 0)
	timerPill.Position = UDim2.new(0.5, 0, 0, 96)
	timerPill.Size = UDim2.fromOffset(190, 36)
	timerLabel = bigText(timerPill, { TextSize = 18, Font = UIKit.Fonts.Title, Text = "RUN 0:00" })

	-- Top-right: prestige
	local prestigePill = pill(root, "Prestige", UIKit.Colors.Pink, 170, 1)
	prestigePill.AnchorPoint = Vector2.new(1, 0)
	prestigePill.Position = UDim2.new(1, -16, 0, 12)
	prestigeLabel = bigText(prestigePill, { TextSize = 20, TextColor3 = UIKit.Colors.Pink:Lerp(Color3.new(1, 1, 1), 0.3), Text = "PRESTIGE 0" })

	-- Bottom-centre: SKIP STAGE (Robux) and RESET
	local bottom = UIKit.Frame({
		Name = "BottomButtons",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(420, 58),
		BackgroundTransparency = 1,
		Parent = root,
	})
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = bottom })
	local skipProduct = Config.Products[Config.SkipProduct]
	local skip = UIKit.Button({
		Name = "Skip",
		Size = UDim2.fromOffset(250, 54),
		Color = UIKit.Colors.Success,
		Text = "SKIP STAGE  \u{E002}" .. tostring(skipProduct and skipProduct.Price or 0),
		Font = UIKit.Fonts.Display,
		TextSize = 24,
		Radius = 18,
		LayoutOrder = 1,
	}, function()
		UIController.PlaySound("Click")
		UIController.PromptSkip()
	end)
	skip.Parent = bottom
	local reset = UIKit.Button({
		Name = "Reset",
		Size = UDim2.fromOffset(130, 54),
		Color = UIKit.Colors.Danger,
		Text = "RESET",
		Font = UIKit.Fonts.Display,
		TextSize = 22,
		Radius = 18,
		LayoutOrder = 2,
	}, function()
		UIController.PlaySound("Click")
		Remotes.Get("ResetCharacter"):FireServer()
	end)
	reset.Parent = bottom
end

local lastCoins = nil

local function refreshHUD()
	local coins = State.Get("Coins", 0)
	coinsLabel.Text = Util.FormatNumber(coins)
	if lastCoins and coins > lastCoins then
		UIKit.Pop(coinsLabel.Parent :: GuiObject, 1.06)
	end
	lastCoins = coins
	local info = State.Get("Multiplier")
	if info then
		multLabel.Text = string.format("x%.2f Coins", info.Total)
	end
	local stage = State.Get("Stage", 1)
	local total = Config.TotalStages()
	stageLabel.Text = string.format("STAGE %d / %d", stage, total)
	local world, worldIndex = Config.GetWorld(stage)
	worldLabel.Text = string.format("World %d: %s", worldIndex, world.Name)
	prestigeLabel.Text = "PRESTIGE " .. tostring(State.Get("Prestige", 0))
	local _, inWorld = Config.GetWorldForStage(stage)
	UIKit.Tween(progressFill, { Size = UDim2.fromScale(math.clamp((inWorld - 1) / math.max(world.Stages - 1, 1), 0, 1), 1) }, 0.3)
	local found = 0
	for _ in pairs(State.Get("Fragments", {})) do
		found += 1
	end
	fragmentLabel.Text = string.format("FRAGMENTS %d/%d", found, Config.Fragments.Count)
end

local function refreshTimer()
	local stats = State.Get("Stats", {})
	local start = stats.RunStart or 0
	local elapsed = if start > 0 then math.max(0, State.Now() - start) else 0
	timerLabel.Text = string.format("RUN %d:%02d", elapsed // 60, elapsed % 60)
end

-- The SKIP STAGE button: prompts the skip product, or explains when it's unset.
function UIController.PromptSkip()
	local product = Config.Products[Config.SkipProduct]
	if not product then
		return
	end
	if State.Get("Stage", 1) >= Config.TotalStages() then
		UIController.Notify("You're on the last stage! Walk into the finish portal.", "info")
		return
	end
	if not product.Id or product.Id == 0 then
		UIController.Notify("Set Config.Products." .. Config.SkipProduct .. ".Id to enable stage skips.", "error")
		return
	end
	game:GetService("MarketplaceService"):PromptProductPurchase(player, product.Id)
end

--------------------------------------------------------------------------------
-- Side buttons
--------------------------------------------------------------------------------

-- Emoji icons render on every platform without uploading images.
local SIDE_ICONS = {
	Brainrots = "🧠",
	Shop = "🛒",
	Stages = "🚩",
	Rewards = "🎁",
	Settings = "⚙️",
	Quests = "📜",
	Stats = "📊",
}

function UIController.AddSideButton(name: string, label: string, color: Color3, order: number, onClick: () -> ())
	local button = UIKit.Button({
		Name = name,
		Size = UDim2.fromOffset(104, 64),
		Color = color,
		Text = "",
		LayoutOrder = order,
		Radius = 16,
	}, function()
		UIController.PlaySound("Click")
		onClick()
	end)
	UIKit.Label({
		Name = "Icon",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 32),
		Text = SIDE_ICONS[name] or "",
		TextSize = 28,
		RichText = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = button,
	})
	UIKit.Label({
		Name = "Caption",
		Position = UDim2.new(0, 0, 1, -26),
		Size = UDim2.new(1, 0, 0, 22),
		Text = label,
		Font = UIKit.Fonts.Title,
		TextSize = 15,
		TextStrokeColor3 = UIKit.Ink,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = button,
	})
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
	-- Keep at most MAX_TOASTS on screen: drop the oldest first.
	local existing = {}
	for _, child in ipairs(toastContainer:GetChildren()) do
		if child:IsA("GuiObject") then
			table.insert(existing, child)
		end
	end
	table.sort(existing, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #existing - MAX_TOASTS + 1 do
		existing[index]:Destroy()
	end
	toastCounter += 1

	local color = KIND_COLORS[kind or "info"] or UIKit.Colors.Info
	local toast = UIKit.Frame({
		Size = UDim2.fromOffset(420, 44),
		BackgroundColor3 = UIKit.Colors.Background,
		BackgroundTransparency = 0.1,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = toastCounter,
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
		if not toast.Parent then
			return -- already pushed out by newer toasts
		end
		UIKit.Tween(toast, { BackgroundTransparency = 1 }, 0.3)
		UIKit.Tween(label, { TextTransparency = 1 }, 0.3)
		task.wait(0.3)
		toast:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Big centre-screen banner (zone unlocked, rebirth, legendary hatch, events)
--------------------------------------------------------------------------------

function UIController.Banner(title: string, subtitle: string?, color: Color3?)
	local holder = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(760, 140),
		BackgroundTransparency = 1,
		ZIndex = 150,
		Parent = root,
	})
	local titleLabel = UIKit.Label({
		Size = UDim2.new(1, 0, 0, 84),
		Text = title,
		Font = UIKit.Fonts.Title,
		TextSize = 72,
		TextColor3 = color or UIKit.Colors.Accent,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 151,
		Parent = holder,
	})
	local subLabel = UIKit.Label({
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 40),
		Text = subtitle or "",
		TextSize = 28,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 151,
		Parent = holder,
	})
	local scale = UIKit.Create("UIScale", { Scale = 0.2, Parent = holder })
	TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.4, function()
		UIKit.Tween(titleLabel, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.4)
		UIKit.Tween(subLabel, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.4)
		task.wait(0.45)
		holder:Destroy()
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
		Name = "BrainrotObbyUI",
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

	-- Two-column grid of menu buttons on the left edge.
	sideList = UIKit.Frame({
		Name = "SideButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.55, 0),
		Size = UDim2.fromOffset(216, 310),
		BackgroundTransparency = 1,
		Parent = root,
	})
	UIKit.Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(104, 64),
		CellPadding = UDim2.fromOffset(8, 10),
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
	State.OnLoaded(refreshTimer)
	State.Changed:Connect(function(patch)
		if patch.Coins ~= nil or patch.Multiplier ~= nil or patch.Stage ~= nil or patch.Prestige ~= nil or patch.Fragments ~= nil then
			refreshHUD()
		end
	end)

	Remotes.Get("Notify").OnClientEvent:Connect(function(text, kind)
		UIController.Notify(tostring(text), kind)
	end)

	-- Run timer
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 1 then
			accumulator = 0
			if State.Loaded then
				refreshTimer()
			end
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
