-- Net.lua — central remote registry (shared, server + client)
-- Server side creates one RemoteEvent per name on first require.
-- Convention: Fire(action, payload) for requests, Fire(payload) for syncs.
-- A client request can ONLY ask; every grant/exploit check lives in a Service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local REMOTES = {
	"PROFILE_SYNC",     -- server -> client: profile snapshot
	"OBJECTIVE_SYNC",   -- server -> client: mission tracker objectives
	"TOAST",            -- server -> client: notification toasts
	"DIALOGUE_OPEN",    -- server -> client: dialogue payload
	"DIALOGUE_RESPOND", -- client -> server: choice id
	"CONTRACT_ACT",     -- client -> server: Accept|Pickup|Deliver
	"SHOP_ACT",         -- client -> server: Open|Buy|Equip
	"HOME_ACT",         -- client -> server: Open|Buy
	"HERO_ACT",         -- client -> server: Recruit|StarUp|Gear|SetSpec|Deploy (Phase 3)
	"HERO_SYNC",        -- server -> client: hero roster snapshot + Heroes Hall open (Phase 3)
}

local folder = nil
local clientFolder = nil

if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	for _, name in ipairs(REMOTES) do
		local ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = folder
	end
end

function Net.event(name: string)
	assert(table.find(REMOTES, name), "Unknown remote: " .. tostring(name))
	if RunService:IsServer() then
		return folder and folder:FindFirstChild(name)
	elseif clientFolder then
		return clientFolder:FindFirstChild(name)
	else
		return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name)
	end
end

function Net.fireTo(player: Player, name: string, payload)
	Net.event(name):FireClient(player, payload)
end

return Net