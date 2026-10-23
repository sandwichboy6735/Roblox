--------------------------------------------------------------------------------
-- ClientState - local replica of the player's profile (read-only mirror).
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local State = {}
State.Data = {} :: { [string]: any }
State.Loaded = false
State.Changed = Signal.new() -- (patch)
State.LoadedSignal = Signal.new()
State.ServerTimeOffset = 0

function State.Load(snapshot: { [string]: any })
	State.Data = snapshot
	if snapshot.ServerTime then
		State.ServerTimeOffset = snapshot.ServerTime - os.time()
	end
	local firstLoad = not State.Loaded
	State.Loaded = true
	if firstLoad then
		State.LoadedSignal:Fire()
	end
	State.Changed:Fire(snapshot)
end

function State.Apply(patch: { [string]: any })
	for key, value in pairs(patch) do
		State.Data[key] = value
	end
	State.Changed:Fire(patch)
end

function State.OnLoaded(fn: () -> ())
	if State.Loaded then
		task.spawn(fn)
	else
		State.LoadedSignal:Connect(fn)
	end
end

function State.Get(key: string, default: any?): any
	local value = State.Data[key]
	if value == nil then
		return default
	end
	return value
end

function State.Now(): number
	return os.time() + State.ServerTimeOffset
end

function State.Owns(passKey: string): boolean
	local passes = State.Data.Gamepasses
	return passes ~= nil and passes[passKey] == true
end

function State.GetMultiplier(): number
	local info = State.Data.Multiplier
	return info and info.Total or 1
end

-- The brainrot the player is wearing (definition from Config).
function State.GetBrainrot()
	return Config.Brainrots[State.Get("Equipped", Config.StarterBrainrot)]
end

-- Does the equipped brainrot (or a gamepass) give this perk? Returns the value.
function State.GetPerk(perk: string): number?
	local def = State.GetBrainrot()
	if def and def.Perk == perk then
		return def.Value
	end
	if perk == "DoubleJump" and State.Owns("DoubleJump") then
		return 0.8
	end
	return nil
end

function State.TotalStages(): number
	return Config.TotalStages()
end

return State
