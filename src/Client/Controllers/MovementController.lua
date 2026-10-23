--------------------------------------------------------------------------------
-- MovementController - brainrot perks that run on the client (the player owns
-- their own physics): double jump, dash, glide, plus jump pads. The server
-- still validates checkpoint timing against the brainrot's speed.
--------------------------------------------------------------------------------

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Modules = script.Parent.Parent:WaitForChild("Modules")
local State = require(Modules.ClientState)
local UIKit = require(Modules.UIKit)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local MovementController = {}

local humanoid: Humanoid? = nil
local root: BasePart? = nil
local canDoubleJump = false
local jumpHeld = false
local lastDash = -math.huge
local lastPad: { [BasePart]: number } = {}
local dashButton: TextButton
local dashCooldownFill: Frame

local function setCharacter(character: Model)
	humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	canDoubleJump = false
	if humanoid then
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
				canDoubleJump = true
			elseif new == Enum.HumanoidStateType.Jumping then
				-- the first jump is the normal one; a second press in the air double jumps
				task.delay(0.15, function()
					canDoubleJump = true
				end)
			end
		end)
		-- jump pads: launch when touching a pad
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Touched:Connect(function(hit)
					local launch = hit:GetAttribute("Launch")
					if typeof(launch) == "Vector3" and root and os.clock() - (lastPad[hit] or 0) > 0.8 then
						lastPad[hit] = os.clock()
						-- forward is +X along the course; pads always point that way
						root.AssemblyLinearVelocity = Vector3.new(launch.X, launch.Y, launch.Z)
						UIController.PlaySound("Jump", 0.6)
					end
				end)
			end
		end
	end
end

local function tryDoubleJump()
	local power = State.GetPerk("DoubleJump")
	if not power or not humanoid or not root or not canDoubleJump then
		return
	end
	local state = humanoid:GetState()
	if state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.Jumping then
		return
	end
	canDoubleJump = false
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, humanoid.JumpPower * power, velocity.Z)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	UIController.PlaySound("Jump", 0.5)
end

local function tryDash()
	local speed = State.GetPerk("Dash")
	if not speed or not humanoid or not root then
		return
	end
	if os.clock() - lastDash < Config.DashCooldown then
		return
	end
	lastDash = os.clock()
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	direction = direction.Unit
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, math.max(velocity.Y, 8), direction.Z * speed)
	UIController.PlaySound("Jump", 0.5)
end

local function onJumpAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		jumpHeld = true
		tryDoubleJump()
	elseif inputState == Enum.UserInputState.End then
		jumpHeld = false
	end
	return Enum.ContextActionResult.Pass
end

local function onDashAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		tryDash()
	end
	return Enum.ContextActionResult.Pass
end

-- Glide: while holding jump in the air, fall slower.
local function step()
	local glide = State.GetPerk("Glide")
	if glide and jumpHeld and humanoid and root and humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		local velocity = root.AssemblyLinearVelocity
		local maxFall = -Workspace.Gravity * 0.12 * (1 - glide) * 2.5 - 6
		if velocity.Y < maxFall then
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, maxFall, velocity.Z)
		end
	end
	-- dash button cooldown fill
	if dashButton.Visible then
		local k = math.clamp((os.clock() - lastDash) / Config.DashCooldown, 0, 1)
		dashCooldownFill.Size = UDim2.fromScale(k, 1)
	end
end

local function refreshDashButton()
	local hasDash = State.GetPerk("Dash") ~= nil
	dashButton.Visible = hasDash
end

function MovementController.Init()
	dashButton = UIKit.Button({
		Name = "Dash",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -110),
		Size = UDim2.fromOffset(96, 96),
		Color = UIKit.Colors.Pink,
		Text = "DASH\n(Q)",
		Font = UIKit.Fonts.Display,
		TextSize = 22,
		Radius = 48,
		Visible = false,
	}, tryDash)
	dashButton.Parent = UIController.Root
	local cooldownBar = UIKit.Frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(0.7, 0, 0, 8), BackgroundColor3 = UIKit.Colors.Background, Parent = dashButton })
	UIKit.Corner(cooldownBar, 4)
	dashCooldownFill = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = cooldownBar })
	UIKit.Corner(dashCooldownFill, 4)
	if not UserInputService.TouchEnabled then
		dashButton.Text = "DASH\n(Q)"
	else
		dashButton.Text = "DASH"
	end

	ContextActionService:BindAction("BrainrotJump", onJumpAction, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:BindAction("BrainrotDash", onDashAction, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	-- mobile jump button goes through the Humanoid.Jump property
	RunService.RenderStepped:Connect(function()
		if humanoid then
			local jumping = humanoid.Jump
			if jumping and not jumpHeld then
				jumpHeld = true
				tryDoubleJump()
			elseif not jumping and jumpHeld and not UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				jumpHeld = false
			end
		end
		step()
	end)

	if player.Character then
		task.spawn(setCharacter, player.Character)
	end
	player.CharacterAdded:Connect(setCharacter)

	State.OnLoaded(refreshDashButton)
	State.Changed:Connect(function(patch)
		if patch.Equipped ~= nil or patch.Gamepasses ~= nil then
			refreshDashButton()
		end
	end)
end

return MovementController
