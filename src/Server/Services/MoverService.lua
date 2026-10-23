--------------------------------------------------------------------------------
-- MoverService - animates the course's moving parts on the server so every
-- player sees the same thing.
--
-- Walkable movers ("Carry" = true) are driven with physics constraints so
-- players standing on them are carried along. Hazards are moved by CFrame.
--   MoveKind = "Slide":     MoveAxis, MoveDistance, MovePeriod, MovePhase (Roll = spin while sliding)
--   MoveKind = "Spin":      SpinSpeed (deg/s) around the part's centre (SpinAxis = "X" for fans,
--                           SpinRadius to orbit around the original centre)
--   MoveKind = "Turntable": SpinSpeed, a walkable disc that turns (physics)
--   MoveKind = "Pendulum":  PendulumPivot, PendulumAmp, PendulumPeriod, PendulumPhase, PendulumAxis
--   MoveKind = "Vanish":    VanishPeriod, VanishPhase (platform fades out/in)
--   MoveKind = "Blink":     BlinkPeriod, BlinkPhase (hazard turns off/on)
--------------------------------------------------------------------------------

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MoverService = {}

type Slide = { Part: BasePart, Base: CFrame, Axis: Vector3, Distance: number, Period: number, Phase: number, Roll: boolean, Align: AlignPosition? }
type Spin = { Part: BasePart, Base: CFrame, Speed: number, Axis: string, Radius: number, Orient: AlignOrientation?, Followers: { { Part: BasePart, Offset: CFrame } } }
type Pendulum = { Part: BasePart, Pivot: CFrame, Offset: CFrame, Amp: number, Period: number, Phase: number }
type Toggle = { Part: BasePart, Period: number, Phase: number, On: boolean, Hazard: boolean }

local slides: { Slide } = {}
local spins: { Spin } = {}
local pendulums: { Pendulum } = {}
local toggles: { Toggle } = {}
local turntableFollowers: { BasePart } = {}

-- Turns an anchored part into a physics-driven one that follows a target.
local function makeCarried(part: BasePart): (AlignPosition, AlignOrientation)
	local attachment = Instance.new("Attachment")
	attachment.Name = "MoverAttachment"
	attachment.Parent = part
	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.RigidityEnabled = true
	alignPosition.MaxForce = math.huge
	alignPosition.Responsiveness = 200
	alignPosition.Position = part.Position
	alignPosition.Parent = part
	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.RigidityEnabled = true
	alignOrientation.MaxTorque = math.huge
	alignOrientation.Responsiveness = 200
	alignOrientation.CFrame = part.CFrame.Rotation
	alignOrientation.Parent = part
	-- the platform's look (child parts) rides along
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = child
			weld.Parent = child
			child.Anchored = false
			child.Massless = true
			child.CanCollide = false
		end
	end
	part.Anchored = false
	part.Massless = false
	part.CustomPhysicalProperties = part.CustomPhysicalProperties or PhysicalProperties.new(1, 0.5, 0)
	part:SetNetworkOwner(nil)
	return alignPosition, alignOrientation
end

local function register(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	if part:GetAttribute("FollowTurntable") then
		table.insert(turntableFollowers, part)
		return
	end
	local kind = part:GetAttribute("MoveKind")
	if kind == "Slide" then
		local slide: Slide = {
			Part = part,
			Base = part.CFrame,
			Axis = (part:GetAttribute("MoveAxis") or Vector3.new(1, 0, 0)) :: Vector3,
			Distance = (part:GetAttribute("MoveDistance") or 8) :: number,
			Period = (part:GetAttribute("MovePeriod") or 3) :: number,
			Phase = (part:GetAttribute("MovePhase") or 0) :: number,
			Roll = part:GetAttribute("Roll") == true,
			Align = nil,
		}
		if part:GetAttribute("Carry") then
			slide.Align = makeCarried(part)
		end
		table.insert(slides, slide)
	elseif kind == "Spin" or kind == "Turntable" then
		local spin: Spin = {
			Part = part,
			Base = part.CFrame,
			Speed = (part:GetAttribute("SpinSpeed") or 90) :: number,
			Axis = (part:GetAttribute("SpinAxis") or "Y") :: string,
			Radius = (part:GetAttribute("SpinRadius") or 0) :: number,
			Orient = nil,
			Followers = {},
		}
		if part:GetAttribute("Carry") then
			local _, orient = makeCarried(part)
			spin.Orient = orient
		end
		table.insert(spins, spin)
	elseif kind == "Pendulum" then
		local pivot = part:GetAttribute("PendulumPivot")
		if typeof(pivot) == "Vector3" then
			local pivotCF = CFrame.new(pivot)
			table.insert(pendulums, {
				Part = part,
				Pivot = pivotCF,
				Offset = pivotCF:ToObjectSpace(part.CFrame),
				Amp = (part:GetAttribute("PendulumAmp") or 1) :: number,
				Period = (part:GetAttribute("PendulumPeriod") or 3) :: number,
				Phase = (part:GetAttribute("PendulumPhase") or 0) :: number,
			})
			if part:GetAttribute("PendulumAxis") == "X" then
				part:SetAttribute("PendulumAxisX", true)
			end
		end
	elseif kind == "Vanish" then
		table.insert(toggles, { Part = part, Period = (part:GetAttribute("VanishPeriod") or 3) :: number, Phase = (part:GetAttribute("VanishPhase") or 0) :: number, On = true, Hazard = false })
	elseif kind == "Blink" then
		table.insert(toggles, { Part = part, Period = (part:GetAttribute("BlinkPeriod") or 2) :: number, Phase = (part:GetAttribute("BlinkPhase") or 0) :: number, On = true, Hazard = true })
	end
end

-- Attach the turntable stripes to the nearest turntable disc.
local function linkFollowers()
	for _, follower in ipairs(turntableFollowers) do
		local best, bestDistance = nil, math.huge
		for _, spin in ipairs(spins) do
			if spin.Orient then
				local distance = (spin.Base.Position - follower.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = spin, distance
				end
			end
		end
		if best then
			table.insert(best.Followers, { Part = follower, Offset = best.Base:ToObjectSpace(follower.CFrame) })
		end
	end
end

local function step()
	local t = os.clock()
	local parts, cframes = {}, {}
	for _, slide in ipairs(slides) do
		local phase = (t / slide.Period + slide.Phase) % 1
		local k = 0.5 - 0.5 * math.cos(phase * math.pi * 2)
		local target = slide.Base * CFrame.new(slide.Axis * (slide.Distance * k))
		if slide.Align then
			slide.Align.Position = target.Position
		else
			if slide.Roll then
				target = target * CFrame.Angles(slide.Distance * k * 0.6, 0, 0)
			end
			table.insert(parts, slide.Part)
			table.insert(cframes, target)
		end
	end
	for _, spin in ipairs(spins) do
		local angle = math.rad(spin.Speed * t)
		local rotation = if spin.Axis == "X" then CFrame.Angles(angle, 0, 0) else CFrame.Angles(0, angle, 0)
		if spin.Orient then
			-- discs lie on their side (cylinder axis up), so spin about world Y
			local target = CFrame.Angles(0, angle, 0) * spin.Base.Rotation
			spin.Orient.CFrame = target
			for _, follower in ipairs(spin.Followers) do
				table.insert(parts, follower.Part)
				table.insert(cframes, CFrame.new(spin.Base.Position) * CFrame.Angles(0, angle, 0) * CFrame.new(-spin.Base.Position) * spin.Base * follower.Offset)
			end
		elseif spin.Radius > 0 then
			local orbit = CFrame.new(spin.Base.Position) * CFrame.Angles(0, angle, 0) * CFrame.new(spin.Radius, 0, 0)
			table.insert(parts, spin.Part)
			table.insert(cframes, orbit)
		else
			table.insert(parts, spin.Part)
			table.insert(cframes, spin.Base * rotation)
		end
	end
	for _, pendulum in ipairs(pendulums) do
		local swing = math.sin((t / pendulum.Period + pendulum.Phase) * math.pi * 2) * pendulum.Amp
		local rotation = if pendulum.Part:GetAttribute("PendulumAxisX") then CFrame.Angles(0, 0, swing) else CFrame.Angles(swing, 0, 0)
		table.insert(parts, pendulum.Part)
		table.insert(cframes, pendulum.Pivot * rotation * pendulum.Offset)
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for _, toggle in ipairs(toggles) do
		local phase = (t / toggle.Period + toggle.Phase) % 1
		local on = phase < 0.55
		if on ~= toggle.On then
			toggle.On = on
			if toggle.Hazard then
				toggle.Part.CanTouch = on
				toggle.Part.CanCollide = false
				toggle.Part.Transparency = if on then 0 else 0.9
			else
				toggle.Part.CanCollide = on
				for _, child in ipairs(toggle.Part:GetChildren()) do
					if child:IsA("BasePart") then
						child.Transparency = if on then (if child.Name == "Glow" then 0.2 else 0) else 0.85
					end
				end
			end
		end
		-- warning flicker just before a platform vanishes
		if not toggle.Hazard and on and phase > 0.42 then
			local plate = toggle.Part:FindFirstChild("Plate")
			if plate and plate:IsA("BasePart") then
				plate.Transparency = if math.floor(phase * 30) % 2 == 0 then 0.4 else 0
			end
		end
	end
end

function MoverService.Init()
	local course = Workspace:WaitForChild("Course")
	for _, descendant in ipairs(course:GetDescendants()) do
		register(descendant)
	end
	linkFollowers()
	RunService.Heartbeat:Connect(step)
end

return MoverService
