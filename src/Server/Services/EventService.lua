--------------------------------------------------------------------------------
-- EventService - server-wide events (Coin Rush, Lucky Stages) on a timer.
-- State is published as attributes on ReplicatedStorage so every client can
-- show a banner and countdown:
--   EventName (string, "" when none), EventEndsAt, NextEventAt (unix seconds)
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local EconomyService = require(script.Parent.EconomyService)

local EventService = {}

local active: string? = nil

function EventService.GetActive()
	if not active then
		return nil, nil
	end
	return active, Config.Events.List[active]
end

function EventService.GetCoinMultiplier(): number
	local _, event = EventService.GetActive()
	return if event and event.CoinMult then event.CoinMult else 1
end

function EventService.GetStageMultiplier(): number
	local _, event = EventService.GetActive()
	return if event and event.StageMult then event.StageMult else 1
end

local function refreshAll()
	for _, player in ipairs(Players:GetPlayers()) do
		EconomyService.RefreshMultiplier(player)
	end
end

function EventService.Init()
	EconomyService.SetEventMultiplierSource(EventService.GetCoinMultiplier)
	ReplicatedStorage:SetAttribute("EventName", "")
	local names = {}
	for name in pairs(Config.Events.List) do
		table.insert(names, name)
	end
	table.sort(names)
	task.spawn(function()
		local rng = Random.new()
		while true do
			local wait = Config.Events.Interval - Config.Events.Duration
			ReplicatedStorage:SetAttribute("NextEventAt", os.time() + wait)
			task.wait(wait)
			active = names[rng:NextInteger(1, #names)]
			ReplicatedStorage:SetAttribute("EventName", active)
			ReplicatedStorage:SetAttribute("EventEndsAt", os.time() + Config.Events.Duration)
			refreshAll()
			task.wait(Config.Events.Duration)
			active = nil
			ReplicatedStorage:SetAttribute("EventName", "")
			refreshAll()
		end
	end)
end

return EventService
