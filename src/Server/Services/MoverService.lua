--------------------------------------------------------------------------------
-- MoverService - animates the course's moving parts on the server so every
-- player sees the same thing:
--   MoveKind = "Slide": MoveAxis, MoveDistance, MovePeriod, MovePhase
--   MoveKind = "Spin":  SpinSpeed (degrees per second) around the part's centre
--   MoveKind = "Vanish": VanishPeriod, VanishPhase (platform fades out/in)
--------------------------------------------------------------------------------

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MoverService = {}

type Slide = { Part: BasePart, Base: CFrame, Axis: Vector3, Distance: number, Period: number, Phase: number }
type Spin = { Part: BasePart, Base: CFrame, Speed: number }
type Vanish = { Part: BasePart, Period: number, Phase: number, Visible: boolean }

local slides: { Slide } = {}
local spins: { Spin } = {}
local vanishers: { Vanish } = {}

local function register(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local kind = part:GetAttribute("MoveKind")
	if kind == "Slide" then
		table.insert(slides, {
			Part = part,
			Base = part.CFrame,
			Axis = (part:GetAttribute("MoveAxis") or Vector3.new(1, 0, 0)) :: Vector3,
			Distance = (part:GetAttribute("MoveDistance") or 8) :: number,
			Period = (part:GetAttribute("MovePeriod") or 3) :: number,
			Phase = (part:GetAttribute("MovePhase") or 0) :: number,
		})
	elseif kind == "Spin" then
		table.insert(spins, { Part = part, Base = part.CFrame, Speed = (part:GetAttribute("SpinSpeed") or 90) :: number })
	elseif kind == "Vanish" then
		table.insert(vanishers, { Part = part, Period = (part:GetAttribute("VanishPeriod") or 3) :: number, Phase = (part:GetAttribute("VanishPhase") or 0) :: number, Visible = true })
	end
end

local function step()
	local t = os.clock()
	local parts, cframes = {}, {}
	for _, slide in ipairs(slides) do
		-- smooth back-and-forth: 0..1..0 over one period
		local phase = (t / slide.Period + slide.Phase) % 1
		local k = 0.5 - 0.5 * math.cos(phase * math.pi * 2)
		table.insert(parts, slide.Part)
		table.insert(cframes, slide.Base * CFrame.new(slide.Axis * (slide.Distance * k)))
	end
	for _, spin in ipairs(spins) do
		table.insert(parts, spin.Part)
		table.insert(cframes, spin.Base * CFrame.Angles(0, math.rad(spin.Speed * t), 0))
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for _, vanish in ipairs(vanishers) do
		local phase = (t / vanish.Period + vanish.Phase) % 1
		local visible = phase < 0.55
		if visible ~= vanish.Visible then
			vanish.Visible = visible
			vanish.Part.CanCollide = visible
			vanish.Part.Transparency = if visible then 0 else 0.85
		end
		-- warning flicker just before it vanishes
		if visible and phase > 0.42 then
			vanish.Part.Transparency = if math.floor(phase * 30) % 2 == 0 then 0.4 else 0
		end
	end
end

function MoverService.Init()
	local course = Workspace:WaitForChild("Course")
	for _, descendant in ipairs(course:GetDescendants()) do
		register(descendant)
	end
	RunService.Heartbeat:Connect(step)
end

return MoverService
