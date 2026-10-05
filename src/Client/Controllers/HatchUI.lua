--------------------------------------------------------------------------------
-- HatchUI - egg panel (odds + buy buttons), auto hatch and the reveal animation.
--------------------------------------------------------------------------------

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local EggLooks = require(Shared.EggLooks)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local PetBuilder = require(Modules.PetBuilder)
local UIController = require(script.Parent.UIController)
local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer

local HatchUI = {}

local CLOSE_DISTANCE = 22
local MIN_AUTO_INTERVAL = 0.45
local AUTO_WAIT_FOR_FUNDS = 0.5

local window
local oddsGrid: ScrollingFrame
local costLabel: TextLabel
local luckLabel: TextLabel
local hatchOneButton: TextButton
local hatchThreeButton: TextButton
local autoButton: TextButton

local oddsEgg: string? = nil -- egg whose cells are in the odds grid
local chanceLabels: { TextLabel } = {}

local currentEgg: string? = nil
local currentStand: BasePart? = nil
local busy = false
local autoHatching = false
local autoRun = 0 -- id of the active auto-hatch loop (stale loops exit)

local overlay: Frame
local stage: Frame
local autoChip: Frame
local autoChipLabel: TextLabel

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function currencyAmount(egg): number
	if egg.Currency == "Gems" then
		return State.Get("Gems", 0)
	end
	return State.Get("Coins", 0)
end

-- Returns { {Pet, Chance(0-100 after luck)} } mirroring the server roll.
-- Displayed chances always sum to exactly 100% (paid random items policy).
local function adjustedOdds(egg)
	local luck = State.GetLuck()
	local weights = {}
	for index, entry in ipairs(egg.Pets) do
		local def = Config.Pets[entry.Pet]
		local weight = entry.Chance
		if def and Config.Rarities[def.Rarity] and Config.Rarities[def.Rarity].LuckAffected then
			weight *= luck
		end
		weights[index] = weight
	end
	local percentages = Util.ExactPercentages(weights, 2)
	local result = {}
	for index, entry in ipairs(egg.Pets) do
		table.insert(result, { Pet = entry.Pet, Chance = percentages[index] })
	end
	return result
end

local function formatChance(chance: number): string
	return string.format("%.2f%%", chance)
end

local function promptPass(key: string)
	local pass = Config.Gamepasses[key]
	if pass and pass.Id and pass.Id > 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	else
		UIController.Notify("Set Config.Gamepasses." .. key .. ".Id to enable this purchase.", "error")
	end
end

--------------------------------------------------------------------------------
-- Egg panel
--------------------------------------------------------------------------------

local function refreshButtons()
	if not currentEgg then
		return
	end
	local egg = Config.Eggs[currentEgg]
	local currencyName = egg.Currency == "Gems" and "Gems" or "Coins"
	local have = currencyAmount(egg)

	costLabel.Text = string.format("Cost: <font color='#FFC400'>%s %s</font>   You have %s", Util.FormatNumber(egg.Cost), currencyName, Util.FormatNumber(have))
	local luck = State.GetLuck()
	if luck > 1 then
		luckLabel.Text = string.format("<font color='#50DC78'>LUCK x%s ACTIVE: odds below include your boost</font>", tostring(luck))
	elseif State.Get("PaidRandomRestricted", true) then
		luckLabel.Text = "Odds for each pet are shown below."
	else
		luckLabel.Text = "Odds shown below. The Lucky pass doubles Legendary & Mythic weights."
	end

	hatchOneButton.Text = "HATCH x1"
	UIKit.SetButtonEnabled(hatchOneButton, not busy)

	if State.Owns("TripleHatch") then
		hatchThreeButton.Text = "HATCH x3"
		UIKit.SetButtonColor(hatchThreeButton, UIKit.Colors.Pink)
	else
		hatchThreeButton.Text = "x3  R$" .. Config.Gamepasses.TripleHatch.Price
		UIKit.SetButtonColor(hatchThreeButton, UIKit.Colors.PanelLight)
	end
	UIKit.SetButtonEnabled(hatchThreeButton, not busy or not State.Owns("TripleHatch"))

	if State.Owns("AutoHatch") then
		autoButton.Text = autoHatching and "AUTO: ON" or "AUTO: OFF"
		UIKit.SetButtonColor(autoButton, autoHatching and UIKit.Colors.Success or UIKit.Colors.Danger)
	else
		autoButton.Text = "AUTO  R$" .. Config.Gamepasses.AutoHatch.Price
		UIKit.SetButtonColor(autoButton, UIKit.Colors.PanelLight)
	end
end

-- Builds the 3D odds cells once per egg; later calls only refresh the chances
-- (they change with luck boosts).
local function rebuildOdds()
	if not currentEgg then
		return
	end
	local egg = Config.Eggs[currentEgg]
	local odds = adjustedOdds(egg)
	if oddsEgg ~= currentEgg then
		oddsEgg = currentEgg
		UIKit.ClearChildren(oddsGrid)
		table.clear(chanceLabels)
		for order, entry in ipairs(odds) do
			local def = Config.Pets[entry.Pet]
			local rarityColor = Config.Rarities[def.Rarity].Color
			local cell = UIKit.Frame({
				BackgroundColor3 = UIKit.Colors.Panel,
				LayoutOrder = order,
				Parent = oddsGrid,
			})
			UIKit.Corner(cell, 10)
			UIKit.Stroke(cell, rarityColor, 1.5)

			local backdrop = UIKit.Frame({ Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = rarityColor, Parent = cell })
			UIKit.Corner(backdrop, 8)
			UIKit.Gradient(backdrop, rarityColor:Lerp(Color3.new(0, 0, 0), 0.45), rarityColor:Lerp(Color3.new(0, 0, 0), 0.8), 90)
			PetBuilder.CreateViewport(entry.Pet, 0, { Size = UDim2.fromScale(1, 1), Parent = backdrop })
			UIKit.Label({
				Position = UDim2.fromOffset(4, 60),
				Size = UDim2.new(1, -8, 0, 16),
				Text = def.Name,
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = cell,
			})
			UIKit.Label({
				Position = UDim2.fromOffset(4, 75),
				Size = UDim2.new(1, -8, 0, 16),
				Text = string.format("x%s", tostring(def.Multiplier)),
				TextSize = 12,
				TextColor3 = UIKit.Colors.Accent,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = cell,
			})
			chanceLabels[order] = UIKit.Label({
				Position = UDim2.fromOffset(4, 91),
				Size = UDim2.new(1, -8, 0, 20),
				TextSize = 16,
				Font = UIKit.Fonts.Black,
				TextColor3 = rarityColor,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = cell,
			})
		end
	end
	for order, entry in ipairs(odds) do
		local label = chanceLabels[order]
		if label then
			label.Text = formatChance(entry.Chance)
		end
	end
end

local function openEgg(eggKey: string, stand: BasePart?)
	local egg = Config.Eggs[eggKey]
	if not egg then
		return
	end
	if egg.Zone > State.Get("ZonesUnlocked", 1) then
		UIController.Notify("Unlock " .. Config.Zones[egg.Zone].Name .. " to open this egg!", "error")
		return
	end
	if currentEgg ~= eggKey then
		autoHatching = false
	end
	currentEgg = eggKey
	currentStand = stand
	window.Title.Text = string.upper(egg.Name)
	rebuildOdds()
	refreshButtons()
	UIController.Open("Egg")
end

--------------------------------------------------------------------------------
-- Reveal animation
--------------------------------------------------------------------------------

-- A 3D egg in a viewport, built exactly like the ones on the egg stands.
local function eggShape(parent: Instance, egg, xScale: number): ViewportFrame
	local viewport = UIKit.Create("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(xScale, 0.5),
		Size = UDim2.fromOffset(190, 230),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, -0.7),
		ZIndex = 202,
		Parent = parent,
	}) :: ViewportFrame
	local model = EggLooks.Build(egg)
	model.Parent = viewport
	PetBuilder.FrameCamera(viewport, model, 1.1)
	return viewport
end

-- Rotating light rays behind a revealed pet (each ray spins about the centre).
local function addRays(parent: GuiObject, color: Color3, count: number): { Frame }
	local rays = {}
	for i = 1, count do
		local ray = UIKit.Frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(22, 340),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.35,
			Rotation = (i - 1) * 180 / count,
			ZIndex = 202,
			Parent = parent,
		})
		UIKit.Create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = ray,
		})
		rays[i] = ray
	end
	return rays
end

local function petCard(parent: Instance, result, xScale: number): (Frame, Model, { Frame })
	local def = Config.Pets[result.Type]
	local rarityColor = Config.Rarities[def.Rarity].Color
	local holder = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(xScale, 0.5),
		Size = UDim2.fromOffset(210, 280),
		BackgroundTransparency = 1,
		ZIndex = 202,
		Parent = parent,
	})
	-- Rare and better pets get spinning light rays behind the card.
	local order = Config.Rarities[def.Rarity].Order
	local rays = if order >= Config.Rarities.Rare.Order then addRays(holder, rarityColor, 4 + order) else {}

	local card = UIKit.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIKit.Colors.Background,
		ZIndex = 203,
		Parent = holder,
	})
	UIKit.Corner(card, 18)
	UIKit.Stroke(card, rarityColor, 4)

	local glow = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(176, 160),
		BackgroundColor3 = rarityColor,
		ZIndex = 204,
		Parent = card,
	})
	UIKit.Corner(glow, 16)
	UIKit.Gradient(glow, rarityColor:Lerp(Color3.new(1, 1, 1), 0.15), rarityColor:Lerp(Color3.new(0, 0, 0), 0.65), 90)
	local viewport, model = PetBuilder.CreateViewport(result.Type, 0, {
		Size = UDim2.fromScale(1, 1),
		Zoom = 0.95,
		ZIndex = 205,
		Parent = glow,
	})
	viewport.Name = "PetView"

	UIKit.Label({
		Position = UDim2.fromOffset(8, 176),
		Size = UDim2.new(1, -16, 0, 30),
		Text = def.Name,
		Font = UIKit.Fonts.Title,
		TextSize = 24,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 204,
		Parent = card,
	})
	local shine = UIKit.ShineFor(def.Rarity, 0)
	local rarityLabel = UIKit.Label({
		Position = UDim2.fromOffset(8, 204),
		Size = UDim2.new(1, -16, 0, 30),
		Text = string.upper(def.Rarity),
		Font = UIKit.Fonts.Display,
		TextSize = 26,
		TextColor3 = if shine then Color3.new(1, 1, 1) else rarityColor,
		TextStrokeColor3 = UIKit.Ink,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 204,
		Parent = card,
	})
	if shine then
		UIKit.Shine(rarityLabel, shine)
	end
	if result.New then
		local badge = UIKit.Frame({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 10, 0, -10),
			Size = UDim2.fromOffset(70, 30),
			BackgroundColor3 = UIKit.Colors.Danger,
			Rotation = 12,
			ZIndex = 206,
			Parent = card,
		})
		UIKit.Corner(badge, 8)
		UIKit.Stroke(badge, Color3.new(1, 1, 1), 2)
		UIKit.Label({
			Size = UDim2.fromScale(1, 1),
			Text = "NEW!",
			Font = UIKit.Fonts.Title,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 207,
			Parent = badge,
		})
	end
	UIKit.Label({
		Position = UDim2.fromOffset(8, 236),
		Size = UDim2.new(1, -16, 0, 22),
		Text = string.format("x%s coins", tostring(def.Multiplier)) .. (result.Equipped and "  <font color='#50DC78'>EQUIPPED</font>" or ""),
		TextSize = 16,
		TextColor3 = UIKit.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 204,
		Parent = card,
	})
	return holder, model, rays
end

local function bestRarityOrder(results): number
	local best = 0
	for _, result in ipairs(results) do
		local def = Config.Pets[result.Type]
		local order = def and Config.Rarities[def.Rarity].Order or 0
		best = math.max(best, order)
	end
	return best
end

local function playReveal(eggKey: string, results)
	local egg = Config.Eggs[eggKey]
	UIKit.ClearChildren(stage)
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	UIKit.Tween(overlay, { BackgroundTransparency = 0.35 }, 0.2)

	local count = #results
	local positions = {}
	for i = 1, count do
		positions[i] = if count == 1 then 0.5 else 0.2 + (i - 1) * 0.3
	end

	-- 1) Eggs pop in and shake with rising intensity
	local eggs = {}
	for i = 1, count do
		local eggFrame = eggShape(stage, egg, positions[i])
		local scale = UIKit.Create("UIScale", { Scale = 0, Parent = eggFrame })
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		eggs[i] = eggFrame
	end
	task.wait(0.35)

	local shakes = 8
	for s = 1, shakes do
		local angle = 6 + s * 2.5
		for _, eggFrame in ipairs(eggs) do
			UIKit.Tween(eggFrame, { Rotation = if s % 2 == 0 then angle else -angle }, 0.08)
		end
		task.wait(0.11 - s * 0.006)
	end
	for _, eggFrame in ipairs(eggs) do
		UIKit.Tween(eggFrame, { Rotation = 0 }, 0.05)
	end

	-- 2) Flash
	local flash = UIKit.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		ZIndex = 210,
		Parent = stage,
	})
	for _, eggFrame in ipairs(eggs) do
		eggFrame:Destroy()
	end
	UIKit.Tween(flash, { BackgroundTransparency = 1 }, 0.45)

	-- 3) Reveal cards
	local best = bestRarityOrder(results)
	if best >= Config.Rarities.Legendary.Order then
		UIController.PlaySound("Rare")
	else
		UIController.PlaySound("Hatch")
	end

	local models: { Model } = {}
	local allRays: { Frame } = {}
	for i, result in ipairs(results) do
		local card, model, rays = petCard(stage, result, positions[i])
		local scale = UIKit.Create("UIScale", { Scale = 0.3, Parent = card })
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		table.insert(models, model)
		for _, ray in ipairs(rays) do
			table.insert(allRays, ray)
		end
	end
	-- Pets turn to show themselves off; the rays slowly spin.
	local started = os.clock()
	local spin = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		for index, model in ipairs(models) do
			model:PivotTo(CFrame.Angles(0, math.sin(t * 1.6 + index) * 0.9 + t * 0.6, 0))
		end
		for _, ray in ipairs(allRays) do
			ray.Rotation += 0.6
		end
	end)

	if best >= Config.Rarities.Legendary.Order then
		local isMythic = best >= Config.Rarities.Mythic.Order
		local banner = UIKit.Label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.08),
			Size = UDim2.fromOffset(700, 80),
			Text = isMythic and "MYTHIC HATCH!!!" or "LEGENDARY HATCH!",
			Font = UIKit.Fonts.Title,
			TextSize = 64,
			TextColor3 = isMythic and Config.Rarities.Mythic.Color or Config.Rarities.Legendary.Color,
			TextStrokeTransparency = 0,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 211,
			Parent = stage,
		})
		local scale = UIKit.Create("UIScale", { Scale = 0.2, Parent = banner })
		TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		EffectsController.Confetti(isMythic and 160 or 100)
	end

	task.wait(best >= Config.Rarities.Legendary.Order and 2.2 or 1.4)

	UIKit.Tween(overlay, { BackgroundTransparency = 1 }, 0.25)
	for _, child in ipairs(stage:GetDescendants()) do
		if child:IsA("GuiObject") then
			UIKit.Tween(child, { BackgroundTransparency = 1 }, 0.25)
			if child:IsA("TextLabel") then
				UIKit.Tween(child, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.25)
			elseif child:IsA("ViewportFrame") then
				UIKit.Tween(child, { ImageTransparency = 1 }, 0.25)
			end
		elseif child:IsA("UIStroke") then
			UIKit.Tween(child, { Transparency = 1 }, 0.25)
		end
	end
	task.wait(0.27)
	spin:Disconnect()
	UIKit.ClearChildren(stage)
	overlay.Visible = false
end

local function summarize(results)
	local parts = {}
	for _, result in ipairs(results) do
		table.insert(parts, string.format("%s (%s)%s", result.Type, result.Rarity, result.New and " NEW!" or ""))
	end
	return "Hatched " .. table.concat(parts, ", ")
end

--------------------------------------------------------------------------------
-- Hatching
--------------------------------------------------------------------------------

-- Returns "ok", "funds" (can't afford yet), "busy" (a hatch is in progress)
-- or "failed".
local function hatch(count: number): string
	if busy then
		return "busy"
	end
	if not currentEgg then
		return "failed"
	end
	local eggKey = currentEgg
	local egg = Config.Eggs[eggKey]
	if currencyAmount(egg) < egg.Cost * count then
		if not autoHatching then
			UIController.Notify("Not enough " .. egg.Currency .. "! Collect orbs or visit the shop.", "error")
		end
		return "funds"
	end

	busy = true
	refreshButtons()
	local ok, response = pcall(function()
		return Remotes.Get("HatchEgg"):InvokeServer(eggKey, count)
	end)

	local success = false
	if not ok or type(response) ~= "table" then
		UIController.Notify("Hatch failed, please try again.", "error")
	elseif not response.ok then
		UIController.Notify(tostring(response.reason), "error")
	else
		success = true
		local settings = State.Get("Settings", {})
		if settings.SkipHatchAnimation then
			UIController.PlaySound("Hatch")
			-- During auto hatch only announce exciting results, so toasts don't
			-- bury the egg panel.
			local exciting = bestRarityOrder(response.results) >= Config.Rarities.Legendary.Order
			for _, result in ipairs(response.results) do
				if result.New then
					exciting = true
				end
			end
			if exciting or not autoHatching then
				UIController.Notify(summarize(response.results), "reward")
			end
		else
			local wasOpen = window.IsOpen()
			window.Close()
			playReveal(eggKey, response.results)
			if wasOpen and currentEgg == eggKey then
				window.Open()
			end
		end
	end

	busy = false
	refreshButtons()
	return if success then "ok" else "failed"
end

local function refreshAutoChip()
	if not autoChip then
		return
	end
	local showChip = autoHatching and not window.IsOpen()
	autoChip.Visible = showChip
	if showChip and currentEgg then
		autoChipLabel.Text = "AUTO HATCHING: " .. string.upper(Config.Eggs[currentEgg].Name)
	end
end

local function autoLoop(runId: number)
	refreshAutoChip()
	-- A newer loop (AUTO toggled off and on quickly) replaces this one.
	while autoHatching and autoRun == runId do
		local started = os.clock()
		local count = State.Owns("TripleHatch") and 3 or 1
		local egg = currentEgg and Config.Eggs[currentEgg]
		if egg and count == 3 and currencyAmount(egg) < egg.Cost * 3 then
			count = 1
		end
		local result = hatch(count)
		if result == "funds" or result == "busy" then
			-- Keep running: hatch again once there are enough coins / it's free.
			task.wait(AUTO_WAIT_FOR_FUNDS)
		elseif result == "failed" then
			if autoRun == runId then
				autoHatching = false
				refreshButtons()
			end
			break
		end
		local elapsed = os.clock() - started
		if elapsed < MIN_AUTO_INTERVAL then
			task.wait(MIN_AUTO_INTERVAL - elapsed)
		end
	end
	if autoRun == runId then
		refreshAutoChip()
	end
end

local function stopAuto()
	if autoHatching then
		autoHatching = false
		refreshButtons()
		refreshAutoChip()
	end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function HatchUI.Init()
	window = UIController.CreateWindow("Egg", "EGG", UDim2.fromOffset(620, 430), UIKit.Colors.Pink)
	local content = window.Content

	luckLabel = UIKit.Label({
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		TextColor3 = UIKit.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content,
	})

	local gridHolder = UIKit.Frame({
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 236),
		BackgroundColor3 = UIKit.Colors.PanelDark,
		Parent = content,
	})
	UIKit.Corner(gridHolder, 12)
	UIKit.Padding(gridHolder, 10)
	oddsGrid = UIKit.ScrollGrid(gridHolder, UDim2.fromOffset(84, 114), 8)
	local layout = oddsGrid:FindFirstChildOfClass("UIGridLayout")
	if layout then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end

	costLabel = UIKit.Label({
		Position = UDim2.fromOffset(0, 270),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content,
	})

	local buttonRow = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Parent = content,
	})
	UIKit.Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = buttonRow,
	})

	hatchOneButton = UIKit.Button({ Size = UDim2.fromOffset(170, 48), Color = UIKit.Colors.Success, TextSize = 18, LayoutOrder = 1 }, function()
		stopAuto()
		hatch(1)
	end)
	hatchOneButton.Parent = buttonRow

	hatchThreeButton = UIKit.Button({ Size = UDim2.fromOffset(170, 48), Color = UIKit.Colors.Pink, TextSize = 18, LayoutOrder = 2 }, function()
		if not State.Owns("TripleHatch") then
			promptPass("TripleHatch")
			return
		end
		stopAuto()
		hatch(3)
	end)
	hatchThreeButton.Parent = buttonRow

	autoButton = UIKit.Button({ Size = UDim2.fromOffset(170, 48), Color = UIKit.Colors.Danger, TextSize = 18, LayoutOrder = 3 }, function()
		if not State.Owns("AutoHatch") then
			promptPass("AutoHatch")
			return
		end
		autoHatching = not autoHatching
		refreshButtons()
		if autoHatching then
			autoRun += 1
			task.spawn(autoLoop, autoRun)
		else
			refreshAutoChip()
		end
	end)
	autoButton.Parent = buttonRow

	window.OnClose = function()
		-- Auto Hatch keeps running in the background (with a STOP chip on screen).
		refreshAutoChip()
	end
	window.OnOpen = refreshAutoChip

	-- "Auto hatching" chip, shown while auto hatch runs with the panel closed.
	autoChip = UIKit.Frame({
		Name = "AutoHatchChip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.fromOffset(330, 40),
		BackgroundColor3 = UIKit.Colors.Background,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = UIController.Root,
	})
	UIKit.Corner(autoChip, 20)
	UIKit.Stroke(autoChip, UIKit.Colors.Pink, 2)
	autoChipLabel = UIKit.Label({
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -110, 1, 0),
		Font = UIKit.Fonts.Black,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = autoChip,
	})
	local stopButton = UIKit.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(84, 30),
		Color = UIKit.Colors.Danger,
		Text = "STOP",
		TextSize = 15,
		Radius = 15,
	}, stopAuto)
	stopButton.Parent = autoChip

	-- Reveal overlay (above windows)
	overlay = UIKit.Frame({
		Name = "HatchOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 200,
		Parent = UIController.Root,
	})
	stage = UIKit.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 201,
		Parent = overlay,
	})

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
		if triggeringPlayer ~= player then
			return
		end
		if prompt.Name == "HatchPrompt" then
			local eggPart = prompt.Parent
			local eggKey = eggPart and eggPart:GetAttribute("EggId")
			if type(eggKey) == "string" then
				openEgg(eggKey, if eggPart and eggPart:IsA("BasePart") then eggPart else nil)
			end
		elseif prompt.Name == "RebirthPrompt" then
			UIController.Open("Rebirth")
		end
	end)

	State.Changed:Connect(function(patch)
		if not window.IsOpen() then
			return
		end
		if patch.Coins ~= nil or patch.Gems ~= nil or patch.Gamepasses ~= nil then
			refreshButtons()
		end
		if patch.Gamepasses ~= nil or patch.Boosts ~= nil then
			rebuildOdds()
		end
	end)

	-- Walking away closes the panel. Auto Hatch keeps going anywhere in the
	-- egg's zone (the server allows that for pass owners) and stops on leaving it.
	RunService.Heartbeat:Connect(function()
		if not currentStand or (not window.IsOpen() and not autoHatching) then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		if (root.Position - currentStand.Position).Magnitude > CLOSE_DISTANCE then
			if not busy and window.IsOpen() then
				window.Close()
			end
			local egg = currentEgg and Config.Eggs[currentEgg]
			local inEggZone = egg ~= nil and State.Owns("AutoHatch") and Config.GetZoneAtPosition(root.Position) == egg.Zone
			if autoHatching and not inEggZone then
				stopAuto()
				UIController.Notify("Auto Hatch stopped: you left the egg's zone.", "info")
			end
		end
	end)
end

return HatchUI
