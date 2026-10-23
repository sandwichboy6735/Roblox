--------------------------------------------------------------------------------
-- IntroController - a short camera sweep over the lobby with the game's title
-- when you join, so the first thing new players see is the whole course.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local IntroController = {}

local DURATION = 3

local function play()
	local camera = Workspace.CurrentCamera
	local course = Workspace:WaitForChild("Course", 20)
	if not camera or not course then
		return
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	-- sweep from high above the lobby down toward the player
	local lobbyX = -Config.Course.LobbyLength / 2
	local startCF = CFrame.lookAt(Vector3.new(lobbyX - 120, 110, -160), Vector3.new(200, 20, 0))
	local endCF = CFrame.lookAt(root.Position + Vector3.new(-14, 8, -14), root.Position + Vector3.new(6, 2, 0))
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = startCF
	local tween = TweenService:Create(camera, TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = endCF })
	tween:Play()

	-- title splash
	local holder = UIKit.Frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(900, 220), BackgroundTransparency = 1, ZIndex = 160, Parent = UIController.Root })
	local title = UIKit.Label({ Size = UDim2.new(1, 0, 0, 130), Text = string.upper(Config.GameName), Font = UIKit.Fonts.Display, TextSize = 110, TextColor3 = Color3.fromRGB(255, 215, 60), TextStrokeColor3 = UIKit.Ink, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 161, Parent = holder })
	UIKit.Shine(title, "Gold")
	local sub = UIKit.Label({ Position = UDim2.fromOffset(0, 135), Size = UDim2.new(1, 0, 0, 50), Text = string.format("%d stages  -  %d worlds  -  collect every brainrot", Config.TotalStages(), #Config.Worlds), Font = UIKit.Fonts.Title, TextSize = 30, TextStrokeColor3 = UIKit.Ink, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 161, Parent = holder })
	local scale = UIKit.Create("UIScale", { Scale = 0.3, Parent = holder })
	TweenService:Create(scale, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local skip = UIKit.Button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(120, 40), Color = UIKit.Colors.PanelLight, Text = "SKIP", TextSize = 16, ZIndex = 161 }, function()
		tween:Cancel()
	end)
	skip.Parent = UIController.Root

	tween.Completed:Wait()
	camera.CameraType = Enum.CameraType.Custom
	skip:Destroy()
	UIKit.Tween(title, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.5)
	UIKit.Tween(sub, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.5)
	task.delay(0.55, function()
		holder:Destroy()
	end)
end

function IntroController.Init()
	task.spawn(function()
		local ok, err = pcall(play)
		if not ok then
			warn("[Intro] " .. tostring(err))
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CameraType = Enum.CameraType.Custom
			end
		end
	end)
end

return IntroController
