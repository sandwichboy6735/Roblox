-- Central registry of RemoteEvents / RemoteFunctions.
-- Server calls Remotes.Init() once; both sides use Remotes.Get(name).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFINITIONS: { [string]: string } = {
	-- Server -> Client
	DataLoaded = "RemoteEvent",
	DataChanged = "RemoteEvent",
	Notify = "RemoteEvent",

	-- Client -> Server
	RequestData = "RemoteEvent",
	CollectOrb = "RemoteEvent",
	HatchEgg = "RemoteFunction",
	EquipPet = "RemoteEvent",
	UnequipPet = "RemoteEvent",
	EquipBest = "RemoteEvent",
	UnequipAll = "RemoteEvent",
	DeletePet = "RemoteEvent",
	CraftPet = "RemoteEvent",
	UnlockZone = "RemoteEvent",
	TeleportZone = "RemoteEvent",
	Rebirth = "RemoteEvent",
	ClaimDaily = "RemoteEvent",
	ClaimPlaytime = "RemoteEvent",
	ClaimGroup = "RemoteEvent",
	UpdateSetting = "RemoteEvent",
	RedeemCode = "RemoteFunction",
	ClaimQuest = "RemoteEvent",
	BuyUpgrade = "RemoteEvent",
}

local Remotes = {}
local folder: Folder? = nil

function Remotes.Init()
	assert(RunService:IsServer(), "Remotes.Init must be called on the server")
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		existing:Destroy()
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = "Remotes"
	for name, className in pairs(DEFINITIONS) do
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = newFolder
	end
	newFolder.Parent = ReplicatedStorage
	folder = newFolder
end

function Remotes.Get(name: string): any
	assert(DEFINITIONS[name], "Unknown remote: " .. tostring(name))
	if not folder then
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return (folder :: Folder):WaitForChild(name)
end

return Remotes
