--------------------------------------------------------------------------------
-- BrainrotService - buying, unlocking and wearing brainrots.
-- The equipped brainrot is welded onto the character as a costume (built with
-- BrainrotBuilder) and sets the humanoid's speed and jump. Perks that run on
-- the client (double jump, dash, glide) read the "Brainrot" player attribute.
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local BrainrotBuilder = require(Shared.BrainrotBuilder)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GamepassService = require(script.Parent.GamepassService)
local RateLimiter = require(script.Parent.RateLimiter)

local BrainrotService = {}

local COSTUME_SCALE = 1.55
-- R15 parts hidden under the costume (legs stay visible so walking still reads).
local HIDDEN_PARTS = { Head = true, UpperTorso = true, LowerTorso = true, LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true, Torso = true, ["Left Arm"] = true, ["Right Arm"] = true }

local function notify(player: Player, message: string, kind: string?)
	Remotes.Get("Notify"):FireClient(player, message, kind or "info")
end

--------------------------------------------------------------------------------
-- Costume
--------------------------------------------------------------------------------

local function hideBody(character: Model, hidden: boolean)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and HIDDEN_PARTS[child.Name] then
			child.Transparency = if hidden then 1 else 0
			for _, decal in ipairs(child:GetChildren()) do
				if decal:IsA("Decal") then
					decal.Transparency = if hidden then 1 else 0
				end
			end
		elseif child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Transparency = if hidden then 1 else 0
			end
		end
	end
end

function BrainrotService.ApplyCostume(player: Player)
	local profile = DataService:GetProfile(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return
	end
	local name = profile.Data.Equipped
	local def = Config.Brainrots[name]
	if not def then
		return
	end

	local old = character:FindFirstChild("Costume")
	if old then
		old:Destroy()
	end

	local ok, built = pcall(BrainrotBuilder.Build, name, { Effects = true, Weld = true, Scale = COSTUME_SCALE })
	if ok and built then
		local model = built.Model
		model.Name = "Costume"
		-- Feet of the costume just above the knees; it faces where the player faces.
		local bottom = root.CFrame * CFrame.new(0, -1.4, 0)
		model:PivotTo(bottom)
		built.Root.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = built.Root
		weld.Parent = built.Root
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Massless = true
			end
		end
		model.Parent = character
		hideBody(character, true)
	end

	humanoid.UseJumpPower = true
	local speed = def.Speed
	if GamepassService.Owns(player, "SpeedBoost") then
		speed *= Config.Gamepasses.SpeedBoost.SpeedMultiplier
	end
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = def.Jump
	player:SetAttribute("Brainrot", name)
	-- trail: the Rainbow Trail gamepass beats everything, else the equipped one
	if GamepassService.Owns(player, "RainbowTrail") then
		player:SetAttribute("Trail", "Rainbow")
	else
		player:SetAttribute("Trail", profile.Data.EquippedTrail or "None")
	end
end

--------------------------------------------------------------------------------
-- Owning and equipping
--------------------------------------------------------------------------------

function BrainrotService.Owns(player: Player, name: string): boolean
	local profile = DataService:GetProfile(player)
	return profile ~= nil and profile.Data.Owned[name] == true
end

-- Gives a brainrot (rewards, gamepasses, unlocks). Returns true if it was new.
function BrainrotService.Give(player: Player, name: string, quiet: boolean?): boolean
	local profile = DataService:GetProfile(player)
	if not profile or not Config.Brainrots[name] or profile.Data.Owned[name] then
		return false
	end
	profile.Data.Owned[name] = true
	DataService:Replicate(player, { Owned = profile.Data.Owned })
	if not quiet then
		notify(player, "New brainrot unlocked: " .. name .. "! Equip it in the BRAINROTS menu.", "reward")
	end
	return true
end

function BrainrotService.Equip(player: Player, name: string)
	local profile = DataService:GetProfile(player)
	if not profile or not profile.Data.Owned[name] then
		return
	end
	profile.Data.Equipped = name
	DataService:Replicate(player, { Equipped = name })
	EconomyService.RefreshMultiplier(player)
	BrainrotService.ApplyCostume(player)
end

function BrainrotService.Buy(player: Player, name: string)
	local profile = DataService:GetProfile(player)
	local def = Config.Brainrots[name]
	if not profile or not def then
		return
	end
	if profile.Data.Owned[name] then
		BrainrotService.Equip(player, name)
		return
	end
	local ok, reason = Config.CanUnlock(name, profile.Data)
	if not ok then
		notify(player, reason or "You can't unlock that yet.", "error")
		return
	end
	if def.Price > 0 and not EconomyService.SpendCoins(player, def.Price) then
		notify(player, "You need " .. Util.FormatNumber(def.Price - profile.Data.Coins) .. " more coins.", "error")
		return
	end
	BrainrotService.Give(player, name, true)
	notify(player, "You unlocked " .. name .. "!", "reward")
	BrainrotService.Equip(player, name)
end

-- Free unlocks earned by playing (stage / prestige / gamepass).
local function grantEarned(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	for name, def in pairs(Config.Brainrots) do
		local unlock = def.Unlock
		if unlock and not data.Owned[name] then
			local earned = false
			if unlock.Stage and (data.Stats.BestStage or 1) >= unlock.Stage then
				earned = true
			elseif unlock.Prestige and data.Prestige >= unlock.Prestige then
				earned = true
			elseif unlock.Gamepass and GamepassService.Owns(player, unlock.Gamepass) then
				earned = true
			end
			if earned and def.Price == 0 then
				BrainrotService.Give(player, name)
			end
		end
	end
	-- the Legend Pack gamepass
	if GamepassService.Owns(player, "LegendPack") then
		for _, name in ipairs(Config.Gamepasses.LegendPack.Brainrots) do
			BrainrotService.Give(player, name)
		end
	end
end
BrainrotService.GrantEarned = grantEarned

--------------------------------------------------------------------------------
-- Trails (coin cosmetics)
--------------------------------------------------------------------------------

function BrainrotService.BuyTrail(player: Player, key: string)
	local profile = DataService:GetProfile(player)
	local def = Config.Trails[key]
	if not profile or not def then
		return
	end
	local data = profile.Data
	if not data.Trails[key] then
		if def.Price > 0 and not EconomyService.SpendCoins(player, def.Price) then
			notify(player, "You need " .. Util.FormatNumber(def.Price - data.Coins) .. " more coins for that trail.", "error")
			return
		end
		data.Trails[key] = true
		notify(player, "Unlocked the " .. def.Name .. " trail!", "reward")
	end
	data.EquippedTrail = key
	DataService:Replicate(player, { Trails = data.Trails, EquippedTrail = key })
	BrainrotService.ApplyCostume(player)
end

function BrainrotService.Init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Humanoid", 10)
			if DataService:GetProfile(player) then
				BrainrotService.ApplyCostume(player)
			end
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)

	DataService.ProfileLoaded:Connect(function(player, profile)
		-- Heal bad saves (a brainrot removed from Config, nothing equipped).
		if not Config.Brainrots[profile.Data.Equipped] or not profile.Data.Owned[profile.Data.Equipped] then
			profile.Data.Owned[Config.StarterBrainrot] = true
			profile.Data.Equipped = Config.StarterBrainrot
		end
		grantEarned(player)
		if player.Character then
			BrainrotService.ApplyCostume(player)
		end
	end)
	GamepassService.Changed:Connect(function(player, passKey)
		grantEarned(player)
		if passKey == "SpeedBoost" or passKey == "RainbowTrail" then
			BrainrotService.ApplyCostume(player)
		end
	end)

	Remotes.Get("EquipBrainrot").OnServerEvent:Connect(function(player, name)
		if type(name) == "string" and RateLimiter.Allow(player, "Equip", 4, 1) then
			BrainrotService.Equip(player, name)
		end
	end)
	Remotes.Get("BuyBrainrot").OnServerEvent:Connect(function(player, name)
		if type(name) == "string" and RateLimiter.Allow(player, "Buy", 3, 1) then
			BrainrotService.Buy(player, name)
		end
	end)
	local function trailRequest(player, key)
		if type(key) == "string" and RateLimiter.Allow(player, "Trail", 3, 1) then
			BrainrotService.BuyTrail(player, key)
		end
	end
	Remotes.Get("BuyTrail").OnServerEvent:Connect(trailRequest)
	Remotes.Get("EquipTrail").OnServerEvent:Connect(trailRequest)
end

return BrainrotService
