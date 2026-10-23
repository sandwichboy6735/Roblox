--------------------------------------------------------------------------------
-- BrainrotsUI - the brainrot collection: 3D cards for every character, a
-- detail panel with speed / jump bars and the perk, and EQUIP / BUY buttons.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local BrainrotBuilder = require(Shared.BrainrotBuilder)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)

local BrainrotsUI = {}

local MAX_SPEED, MAX_JUMP = 28, 70

type Card = { Button: TextButton, Stroke: UIStroke, View: ViewportFrame, Tag: Frame, TagLabel: TextLabel, Owned: boolean?, Equipped: boolean? }

local window
local grid: ScrollingFrame
local detail: Frame
local detailViewport: ViewportFrame?
local detailModel: Model?
local detailName: TextLabel
local detailRarity: TextLabel
local detailTagline: TextLabel
local speedFill: Frame
local jumpFill: Frame
local speedText: TextLabel
local jumpText: TextLabel
local perkLabel: TextLabel
local actionButton: TextButton
local hintLabel: TextLabel
local countLabel: TextLabel
local cards: { [string]: Card } = {}
local selected: string? = nil

local function isOwned(name: string): boolean
	local owned = State.Get("Owned", {})
	return owned[name] == true
end

local function unlockText(name: string): (boolean, string)
	local def = Config.Brainrots[name]
	local data = { Stats = State.Get("Stats", {}), Prestige = State.Get("Prestige", 0), Coins = State.Get("Coins", 0) }
	local ok, reason = Config.CanUnlock(name, data)
	if ok then
		return true, if def.Price > 0 then "BUY  " .. Util.FormatNumber(def.Price) else "UNLOCK FREE"
	end
	return false, reason or "Locked"
end

local function refreshDetail()
	if not selected then
		detail.Visible = false
		return
	end
	local name = selected
	local def = Config.Brainrots[name]
	if not def then
		detail.Visible = false
		return
	end
	detail.Visible = true
	local rarityColor = Config.Rarities[def.Rarity].Color
	if not detailViewport or detailViewport:GetAttribute("Key") ~= name then
		if detailViewport then
			detailViewport:Destroy()
		end
		local viewport, model = BrainrotBuilder.CreateViewport(name, { Size = UDim2.new(1, 0, 0, 170), Zoom = 0.95, Parent = detail })
		viewport:SetAttribute("Key", name)
		detailViewport = viewport
		detailModel = model
	end
	detailName.Text = name
	local oldShine = detailName:FindFirstChildOfClass("UIGradient")
	if oldShine then
		oldShine:Destroy()
	end
	local shine = UIKit.ShineFor(def.Rarity, 0)
	detailName.TextColor3 = if shine then Color3.new(1, 1, 1) else rarityColor
	if shine then
		UIKit.Shine(detailName, shine)
	end
	detailRarity.Text = string.upper(def.Rarity)
	detailRarity.TextColor3 = rarityColor
	detailTagline.Text = def.Tagline or ""
	speedFill.Size = UDim2.fromScale(math.clamp(def.Speed / MAX_SPEED, 0.05, 1), 1)
	jumpFill.Size = UDim2.fromScale(math.clamp(def.Jump / MAX_JUMP, 0.05, 1), 1)
	speedText.Text = tostring(def.Speed)
	jumpText.Text = tostring(def.Jump)
	if def.Perk then
		local perk = Config.Perks[def.Perk]
		perkLabel.Text = string.format("<font color='#FFC400'>%s</font>: %s", perk.Name, perk.Describe(def.Value))
	else
		perkLabel.Text = "<font color='#A5AAC8'>No perk. Reliable. Humble.</font>"
	end

	local owned = isOwned(name)
	local equipped = State.Get("Equipped") == name
	if owned then
		actionButton.Text = if equipped then "EQUIPPED" else "EQUIP"
		UIKit.SetButtonColor(actionButton, if equipped then UIKit.Colors.Info else UIKit.Colors.Success)
		UIKit.SetButtonEnabled(actionButton, not equipped, "EQUIPPED")
		hintLabel.Text = ""
	else
		local can, text = unlockText(name)
		actionButton.Text = if can then text else "LOCKED"
		UIKit.SetButtonColor(actionButton, if can then UIKit.Colors.Accent else UIKit.Colors.PanelLight)
		UIKit.SetButtonEnabled(actionButton, can, "LOCKED")
		hintLabel.Text = if can then "" else text
	end
end

local function select(name: string)
	selected = name
	for cardName, card in pairs(cards) do
		card.Stroke.Thickness = if cardName == name then 4 else 1.5
	end
	refreshDetail()
end

local function createCard(name: string, order: number): Card
	local def = Config.Brainrots[name]
	local rarityColor = Config.Rarities[def.Rarity].Color
	local button = UIKit.Create("TextButton", {
		Name = name,
		BackgroundColor3 = UIKit.Colors.Panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		Parent = grid,
	}) :: TextButton
	UIKit.Corner(button, 12)
	local stroke = UIKit.Stroke(button, rarityColor, 1.5)
	local backdrop = UIKit.Frame({ Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 86), BackgroundColor3 = rarityColor, Parent = button })
	UIKit.Corner(backdrop, 10)
	UIKit.Gradient(backdrop, rarityColor:Lerp(Color3.new(0, 0, 0), 0.4), rarityColor:Lerp(Color3.new(0, 0, 0), 0.8), 90)
	local view = BrainrotBuilder.CreateViewport(name, { Size = UDim2.fromScale(1, 1), Parent = backdrop })
	UIKit.Label({ Position = UDim2.fromOffset(4, 96), Size = UDim2.new(1, -8, 0, 18), Text = name, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Center, Parent = button })
	UIKit.Label({ Position = UDim2.fromOffset(4, 114), Size = UDim2.new(1, -8, 0, 16), Text = def.Rarity, TextSize = 12, TextColor3 = rarityColor, TextXAlignment = Enum.TextXAlignment.Center, Parent = button })
	local tag = UIKit.Frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.fromOffset(84, 18), BackgroundColor3 = UIKit.Colors.Success, ZIndex = 3, Visible = false, Parent = button })
	UIKit.Corner(tag, 9)
	local tagLabel = UIKit.Label({ Size = UDim2.fromScale(1, 1), Text = "EQUIPPED", TextSize = 11, Font = UIKit.Fonts.Black, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = tag })
	button.Activated:Connect(function()
		UIController.PlaySound("Click")
		select(name)
	end)
	return { Button = button, Stroke = stroke, View = view, Tag = tag, TagLabel = tagLabel }
end

local function refreshCards()
	local equipped = State.Get("Equipped")
	local ownedCount, total = 0, 0
	for _, entry in ipairs(Config.SortedBrainrots()) do
		local name = entry.Name
		total += 1
		local card = cards[name]
		if not card then
			card = createCard(name, total)
			cards[name] = card
		end
		local owned = isOwned(name)
		if owned then
			ownedCount += 1
		end
		local isEquipped = equipped == name
		if card.Owned ~= owned or card.Equipped ~= isEquipped then
			card.Owned = owned
			card.Equipped = isEquipped
			BrainrotBuilder.SetSilhouette(card.View, not owned)
			card.Button.BackgroundColor3 = if owned then UIKit.Colors.Panel else UIKit.Colors.PanelDark
			card.Tag.Visible = isEquipped or not owned
			if isEquipped then
				card.TagLabel.Text = "EQUIPPED"
				card.Tag.BackgroundColor3 = UIKit.Colors.Success
			elseif not owned then
				local def = Config.Brainrots[name]
				card.TagLabel.Text = if def.Unlock then "LOCKED" elseif def.Price > 0 then Util.FormatNumber(def.Price) else "FREE"
				card.Tag.BackgroundColor3 = if def.Unlock then UIKit.Colors.Danger else UIKit.Colors.Accent
			end
		end
	end
	countLabel.Text = string.format("Collected <font color='#FFC400'>%d / %d</font> brainrots", ownedCount, total)
	if not selected then
		select(equipped or Config.StarterBrainrot)
	else
		refreshDetail()
	end
end

local function buildDetail(parent: Instance)
	detail = UIKit.Frame({
		Name = "Detail",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 250, 1, 0),
		BackgroundColor3 = UIKit.Colors.PanelDark,
		Visible = false,
		Parent = parent,
	})
	UIKit.Corner(detail, 12)
	UIKit.Padding(detail, 10)
	detailName = UIKit.Label({ Position = UDim2.fromOffset(0, 172), Size = UDim2.new(1, 0, 0, 28), Font = UIKit.Fonts.Display, TextSize = 22, TextStrokeColor3 = UIKit.Ink, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, Parent = detail })
	detailRarity = UIKit.Label({ Position = UDim2.fromOffset(0, 200), Size = UDim2.new(1, 0, 0, 18), Font = UIKit.Fonts.Black, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Parent = detail })
	detailTagline = UIKit.Label({ Position = UDim2.fromOffset(0, 218), Size = UDim2.new(1, 0, 0, 20), Font = UIKit.Fonts.Body, TextSize = 13, TextColor3 = UIKit.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = detail })

	local function statRow(y: number, label: string, color: Color3): (Frame, TextLabel)
		UIKit.Label({ Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(60, 18), Text = label, TextSize = 13, Font = UIKit.Fonts.Black, Parent = detail })
		local bar = UIKit.Frame({ Position = UDim2.fromOffset(62, y + 3), Size = UDim2.new(1, -100, 0, 12), BackgroundColor3 = UIKit.Colors.Panel, Parent = detail })
		UIKit.Corner(bar, 6)
		local fill = UIKit.Frame({ Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = color, Parent = bar })
		UIKit.Corner(fill, 6)
		local value = UIKit.Label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, y), Size = UDim2.fromOffset(34, 18), TextSize = 13, Font = UIKit.Fonts.Black, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Right, Parent = detail })
		return fill, value
	end
	speedFill, speedText = statRow(246, "SPEED", UIKit.Colors.Info)
	jumpFill, jumpText = statRow(270, "JUMP", UIKit.Colors.Success)
	perkLabel = UIKit.Label({ Position = UDim2.fromOffset(0, 296), Size = UDim2.new(1, 0, 0, 54), TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = detail })

	actionButton = UIKit.Button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 44), Color = UIKit.Colors.Success, TextSize = 18, Font = UIKit.Fonts.Display }, function()
		if not selected then
			return
		end
		if isOwned(selected) then
			Remotes.Get("EquipBrainrot"):FireServer(selected)
		else
			Remotes.Get("BuyBrainrot"):FireServer(selected)
		end
		UIController.PlaySound("Click")
	end)
	actionButton.Parent = detail
	hintLabel = UIKit.Label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 22), TextSize = 13, TextColor3 = UIKit.Colors.Danger, TextXAlignment = Enum.TextXAlignment.Center, Parent = detail })
end

function BrainrotsUI.Init()
	window = UIController.CreateWindow("Brainrots", "BRAINROTS", UDim2.fromOffset(820, 520), UIKit.Colors.Success)
	local content = window.Content

	countLabel = UIKit.Label({ Size = UDim2.new(1, -260, 0, 24), TextSize = 17, Parent = content })
	local gridHolder = UIKit.Frame({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, -262, 1, -30), BackgroundColor3 = UIKit.Colors.PanelDark, Parent = content })
	UIKit.Corner(gridHolder, 12)
	UIKit.Padding(gridHolder, 10)
	grid = UIKit.ScrollGrid(gridHolder, UDim2.fromOffset(116, 136), 10)
	buildDetail(content)

	window.OnOpen = refreshCards
	State.Changed:Connect(function(patch)
		if patch.Owned ~= nil or patch.Equipped ~= nil or patch.Coins ~= nil or patch.Stats ~= nil or patch.Prestige ~= nil then
			if window.IsOpen() then
				refreshCards()
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		if detailModel and window.IsOpen() and detail.Visible then
			detailModel:PivotTo(CFrame.Angles(0, os.clock() * 0.8, 0))
		end
	end)

	UIController.AddSideButton("Brainrots", "BRAINROTS", UIKit.Colors.Success, 1, function()
		UIController.Toggle("Brainrots")
	end)
end

return BrainrotsUI
