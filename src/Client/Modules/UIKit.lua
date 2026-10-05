--------------------------------------------------------------------------------
-- UIKit - tiny helper library for building consistent, animated UI in code.
--------------------------------------------------------------------------------

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Colors = {
	Background = Color3.fromRGB(20, 22, 34),
	Panel = Color3.fromRGB(32, 35, 52),
	PanelLight = Color3.fromRGB(46, 50, 74),
	PanelDark = Color3.fromRGB(26, 28, 42),
	Stroke = Color3.fromRGB(78, 84, 120),
	Text = Color3.fromRGB(245, 246, 255),
	Muted = Color3.fromRGB(165, 170, 200),
	Accent = Color3.fromRGB(255, 196, 0),
	Gems = Color3.fromRGB(110, 250, 225),
	Success = Color3.fromRGB(80, 220, 120),
	Danger = Color3.fromRGB(240, 85, 95),
	Info = Color3.fromRGB(95, 165, 255),
	Purple = Color3.fromRGB(175, 105, 255),
	Pink = Color3.fromRGB(255, 110, 190),
}

UIKit.Fonts = {
	Display = Enum.Font.LuckiestGuy, -- big buttons, banners, numbers
	Title = Enum.Font.FredokaOne,
	Bold = Enum.Font.GothamBold,
	Black = Enum.Font.GothamBlack,
	Body = Enum.Font.Gotham,
}

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local INK = Color3.fromRGB(28, 22, 40) -- outline colour for the cartoon look
UIKit.Ink = INK

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function UIKit.Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function UIKit.Tween(instance: Instance, props: { [string]: any }, duration: number?, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local info = TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

function UIKit.Corner(parent: Instance, radius: number?)
	return UIKit.Create("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function UIKit.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	return UIKit.Create("UIStroke", {
		Color = color or UIKit.Colors.Stroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIKit.Padding(parent: Instance, all: number, vertical: number?)
	local v = vertical or all
	return UIKit.Create("UIPadding", {
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, v),
		PaddingBottom = UDim.new(0, v),
		Parent = parent,
	})
end

function UIKit.Gradient(parent: Instance, colorA: Color3, colorB: Color3, rotation: number?)
	return UIKit.Create("UIGradient", {
		Color = ColorSequence.new(colorA, colorB),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function UIKit.Frame(props: { [string]: any }?): Frame
	local defaults = {
		BackgroundColor3 = UIKit.Colors.Panel,
		BorderSizePixel = 0,
	}
	for key, value in pairs(props or {}) do
		defaults[key] = value
	end
	return UIKit.Create("Frame", defaults)
end

function UIKit.Label(props: { [string]: any }?): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = UIKit.Fonts.Bold,
		TextColor3 = UIKit.Colors.Text,
		TextSize = 18,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
	}
	for key, value in pairs(props or {}) do
		defaults[key] = value
	end
	return UIKit.Create("TextLabel", defaults)
end

-- Solid "3D lip" under a button or panel (UIShadow with no blur).
function UIKit.Lip(parent: GuiObject, color: Color3, depth: number?)
	pcall(function()
		local shadow = Instance.new("UIShadow" :: any)
		shadow.Name = "Lip"
		shadow.BlurRadius = UDim.new(0, 0)
		shadow.Offset = UDim2.fromOffset(0, depth or 4)
		shadow.Color = color
		shadow.Transparency = 0
		shadow.Parent = parent
	end)
end

-- Colours the outline and lip to match a button's base colour.
local function paintButton(button: GuiButton, color: Color3)
	button.BackgroundColor3 = color
	local stroke = button:FindFirstChild("Outline")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = darker(color, 0.6)
	end
	local lip = button:FindFirstChild("Lip") :: any
	if lip then
		lip.Color = darker(color, 0.45)
	end
end

-- A chunky, glossy cartoon button. `props.Color` sets the base color.
function UIKit.Button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local color = props.Color or UIKit.Colors.Accent
	local defaults = {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = UIKit.Fonts.Title,
		TextColor3 = props.TextColor3 or Color3.new(1, 1, 1),
		TextStrokeColor3 = INK,
		TextStrokeTransparency = 0.25,
		TextSize = 18,
		Text = "",
		Size = UDim2.fromOffset(140, 42),
	}
	for key, value in pairs(props) do
		if key ~= "Color" and key ~= "Radius" then
			defaults[key] = value
		end
	end
	local button = UIKit.Create("TextButton", defaults) :: TextButton
	UIKit.Corner(button, props.Radius or 12)
	local outline = UIKit.Stroke(button, darker(color, 0.6), 2.5)
	outline.Name = "Outline"
	-- Glossy: bright on top, a little darker at the bottom.
	UIKit.Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 240, 240)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
		}),
		Rotation = 90,
		Parent = button,
	})
	UIKit.Lip(button, darker(color, 0.45), 4)

	local scale = UIKit.Create("UIScale", { Scale = 1, Parent = button })
	button:SetAttribute("BaseColor", color)

	button.MouseEnter:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		TweenService:Create(scale, FAST, { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, FAST, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		TweenService:Create(scale, FAST, { Scale = 0.95 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, FAST, { Scale = 1.05 }):Play()
	end)

	if onClick then
		button.Activated:Connect(function()
			if button:GetAttribute("Disabled") then
				return
			end
			onClick()
		end)
	end
	return button
end

function UIKit.SetButtonEnabled(button: TextButton, enabled: boolean, disabledText: string?)
	button:SetAttribute("Disabled", not enabled)
	local baseColor = button:GetAttribute("BaseColor") :: Color3?
	if enabled then
		paintButton(button, baseColor or UIKit.Colors.Accent)
		button.TextColor3 = Color3.new(1, 1, 1)
	else
		paintButton(button, UIKit.Colors.PanelLight)
		button.TextColor3 = UIKit.Colors.Muted
		if disabledText then
			button.Text = disabledText
		end
	end
end

function UIKit.SetButtonColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	if not button:GetAttribute("Disabled") then
		paintButton(button, color)
	end
end

-- Scrolling list with a vertical UIListLayout. Returns the ScrollingFrame.
function UIKit.ScrollList(parent: Instance, props: { [string]: any }?, padding: number?): ScrollingFrame
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UIKit.Colors.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	}
	for key, value in pairs(props or {}) do
		defaults[key] = value
	end
	local scroll = UIKit.Create("ScrollingFrame", defaults) :: ScrollingFrame
	UIKit.Create("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = scroll,
	})
	return scroll
end

-- Scrolling grid. Returns the ScrollingFrame.
function UIKit.ScrollGrid(parent: Instance, cellSize: UDim2, padding: number?, props: { [string]: any }?): ScrollingFrame
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UIKit.Colors.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	}
	for key, value in pairs(props or {}) do
		defaults[key] = value
	end
	local scroll = UIKit.Create("ScrollingFrame", defaults) :: ScrollingFrame
	UIKit.Create("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.fromOffset(padding or 10, padding or 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Parent = scroll,
	})
	return scroll
end

-- Removes all GuiObjects (keeps layouts/paddings).
function UIKit.ClearChildren(parent: Instance)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Window with header + close button. Returns a table:
--   { Frame, Content, Title, Open(), Close(), IsOpen(), OnOpen, OnClose }
function UIKit.Window(parent: Instance, title: string, size: UDim2, accent: Color3?)
	local frame = UIKit.Frame({
		Name = title .. "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = UIKit.Colors.Background,
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	})
	UIKit.Corner(frame, 18)
	UIKit.Stroke(frame, INK, 4)
	UIKit.Lip(frame, darker(accent or UIKit.Colors.Stroke, 0.5), 6)
	UIKit.Gradient(frame, Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 215), 90)

	local scale = UIKit.Create("UIScale", { Scale = 1, Parent = frame })

	local header = UIKit.Frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = accent or UIKit.Colors.Panel,
		ZIndex = 11,
		Parent = frame,
	})
	UIKit.Corner(header, 16)
	UIKit.Gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190), 90)
	-- square off the bottom corners of the header (and continue its gloss,
	-- since this strip covers the bottom 30% of it)
	local strip = UIKit.Frame({
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 1, -16),
		BackgroundColor3 = header.BackgroundColor3,
		ZIndex = 11,
		Parent = header,
	})
	UIKit.Gradient(strip, Color3.fromRGB(210, 210, 210), Color3.fromRGB(190, 190, 190), 90)

	local titleLabel = UIKit.Label({
		Name = "Title",
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.fromOffset(20, 2),
		Font = UIKit.Fonts.Display,
		TextSize = 32,
		Text = title,
		TextStrokeColor3 = INK,
		TextStrokeTransparency = 0,
		ZIndex = 12,
		Parent = header,
	})

	local closeButton = UIKit.Button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(38, 38),
		Color = UIKit.Colors.Danger,
		Text = "X",
		TextSize = 20,
		ZIndex = 12,
	})
	closeButton.Parent = header

	local content = UIKit.Frame({
		Name = "Content",
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = frame,
	})
	UIKit.Padding(content, 16, 12)

	local window = {}
	window.Frame = frame
	window.Content = content
	window.Title = titleLabel
	window.OnOpen = nil :: (() -> ())?
	window.OnClose = nil :: (() -> ())?

	function window.IsOpen(): boolean
		return frame.Visible
	end

	function window.Open()
		if frame.Visible then
			return
		end
		frame.Visible = true
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if window.OnOpen then
			window.OnOpen()
		end
	end

	function window.Close()
		if not frame.Visible then
			return
		end
		frame.Visible = false
		if window.OnClose then
			window.OnClose()
		end
	end

	closeButton.Activated:Connect(window.Close)

	return window
end

-- Pops an element (scale bounce) - great feedback for currency changes.
function UIKit.Pop(instance: GuiObject, amount: number?)
	local scale = instance:FindFirstChildOfClass("UIScale") or UIKit.Create("UIScale", { Parent = instance })
	scale.Scale = amount or 1.15
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

--------------------------------------------------------------------------------
-- Animated shine for the best stuff: a gold sweep (Legendary, Golden) and a
-- rolling rainbow (Mythic, Rainbow). Put it on white text or frames.
--------------------------------------------------------------------------------

local GOLD_SHINE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 30)),
	ColorSequenceKeypoint.new(0.42, Color3.fromRGB(255, 225, 90)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 235)),
	ColorSequenceKeypoint.new(0.58, Color3.fromRGB(255, 225, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 30)),
})

local shines: { [UIGradient]: string } = setmetatable({}, { __mode = "k" }) :: any
local shineLoop: RBXScriptConnection? = nil

local function rainbowAt(t: number): ColorSequence
	local keys = {}
	for i = 0, 6 do
		keys[i + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((t * 0.25 + i / 6) % 1, 0.65, 1))
	end
	return ColorSequence.new(keys)
end

local function animateShines()
	local t = os.clock()
	local rainbow = rainbowAt(t)
	local sweep = Vector2.new(((t * 0.6) % 2.4) - 1.2, 0)
	for gradient, style in pairs(shines) do
		if gradient.Parent then
			if style == "Rainbow" then
				gradient.Color = rainbow
			else
				gradient.Offset = sweep
			end
		end
	end
end

-- style: "Gold" | "Rainbow". Returns the UIGradient.
function UIKit.Shine(target: GuiObject, style: string): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = if style == "Rainbow" then rainbowAt(0) else GOLD_SHINE
	gradient.Rotation = if style == "Rainbow" then 0 else 15
	gradient.Parent = target
	shines[gradient] = style
	if not shineLoop then
		shineLoop = RunService.Heartbeat:Connect(animateShines)
	end
	return gradient
end

-- Which shine (if any) a pet deserves: tier 2 / Mythic rainbow, tier 1 / Legendary gold.
function UIKit.ShineFor(rarity: string?, tier: number?): string?
	if (tier or 0) >= 2 or rarity == "Mythic" then
		return "Rainbow"
	elseif (tier or 0) == 1 or rarity == "Legendary" then
		return "Gold"
	end
	return nil
end

function UIKit.RarityGradient(parent: Instance, color: Color3)
	return UIKit.Gradient(parent, color, color:Lerp(Color3.new(0, 0, 0), 0.45), 90)
end

return UIKit
