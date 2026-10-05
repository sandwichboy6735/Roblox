--------------------------------------------------------------------------------
-- Hatch Legends - client bootstrap
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Modules = script.Parent:WaitForChild("Modules")
local Controllers = script.Parent:WaitForChild("Controllers")
local State = require(Modules.ClientState)

-- 1) Listen for data BEFORE asking for it.
Remotes.Get("DataLoaded").OnClientEvent:Connect(function(snapshot)
	if type(snapshot) == "table" then
		State.Load(snapshot)
	end
end)
Remotes.Get("DataChanged").OnClientEvent:Connect(function(patch)
	if type(patch) == "table" then
		State.Apply(patch)
	end
end)

-- 2) Start controllers (UIController first: everything else builds on it).
local START_ORDER = {
	"UIController",
	"PetsUI",
	"IndexUI",
	"ShopUI",
	"ZonesUI",
	"RebirthUI",
	"RewardsUI",
	"SettingsUI",
	"HatchUI",
	"OrbController",
	"PetFollowController",
	"WorldController",
	"ChatController",
}

for _, name in ipairs(START_ORDER) do
	local module = Controllers:FindFirstChild(name)
	if not module then
		warn("[Client] Missing controller: " .. name)
		continue
	end
	local ok, err = pcall(function()
		local controller = require(module)
		if type(controller.Init) == "function" then
			controller.Init()
		end
	end)
	if not ok then
		warn("[Client] " .. name .. ".Init failed: " .. tostring(err))
	end
end

-- 3) Ask the server for our data (covers the case where the initial push
--    arrived before our listeners were connected). Retry until loaded.
task.spawn(function()
	local attempts = 0
	while not State.Loaded and attempts < 20 do
		Remotes.Get("RequestData"):FireServer()
		attempts += 1
		task.wait(1.5)
	end
end)
