--------------------------------------------------------------------------------
-- FloatingText - "+123" style popups that rise and fade at a world position.
--------------------------------------------------------------------------------

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FloatingText = {}

local MAX_POPUPS = 12
local popupCount = 0
local folder: Folder? = nil

-- size: optional pixel size (default 140x40); bigger for big rewards.
function FloatingText.Show(position: Vector3, text: string, color: Color3, size: Vector2?)
	if popupCount >= MAX_POPUPS then
		return
	end
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "FloatingText"
		newFolder.Parent = Workspace
		folder = newFolder
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
	anchor.Parent = folder

	local pixels = size or Vector2.new(140, 40)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(pixels.X, pixels.Y)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(30, 22, 40)
	label.Parent = gui

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.95, function()
		anchor:Destroy()
		popupCount -= 1
	end)
end

return FloatingText
