-- MissionService.lua — intro campaign state machine + objective tracker sync
-- Every condition is idempotent and stored in the profile, so rejoining
-- mid-campaign resumes exactly where the player left off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local MissionDefinitions = require(ReplicatedStorage.Shared.Definitions.MissionDefinitions)
local DataService = require(script.Parent.DataService)
local CampaignService = require(script.Parent.CampaignService)
local DialogueService = require(script.Parent.DialogueService)
local ContractService = require(script.Parent.ContractService)
local HomeService = require(script.Parent.HomeService)
local SurvivalService = require(script.Parent.SurvivalService)
local InfectedService = require(script.Parent.InfectedService)
local SettlementService = require(script.Parent.SettlementService)
local ClanService = require(script.Parent.ClanService)

local MissionService = {}

local DELIVERIES_REQUIRED = MissionDefinitions.DELIVERIES_REQUIRED

-- (mission counter field on the profile, step id) pairs that display a counter
local COUNTER_FIELDS = {
	DO_DELIVERIES = "Progress",
	SCAVENGE = "Scavenged",
	FIGHT_INFECTED = "Kills",
	FORTIFY_SAFEHOUSE = "Fortified",
	BUILD_STRUCTURE = "StructuresBuilt",
	COLLECT_YIELD = "Collected",
	JOIN_CLAN = "Joined",
	CLAN_CONTRACT = "GroupDone",
}

local function pushObjective(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local m = data.Missions.INTRO
	local stepIdx = math.floor(m.step or 0) + 1
	local step = MissionDefinitions.STEPS[stepIdx] or MissionDefinitions.STEPS[#MissionDefinitions.STEPS]
	local payload = {
		title = MissionDefinitions.INTRO_TITLE,
		text = step.text,
	}
	local field = COUNTER_FIELDS[step.id]
	if field then
		local need = MissionDefinitions.REQUIREMENTS[step.id] or DELIVERIES_REQUIRED
		payload.progress = math.min(m[field] or 0, need)
		payload.max = need
	end
	Net.fireTo(player, "OBJECTIVE_SYNC", payload)
end

local function recompute(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local m = data.Missions.INTRO
	local furnitureCount = #data.Home.Furniture

	if m.step == 0 and m.Talked then
		m.step = 1
		m.Progress = math.min(data.Stats.Deliveries or 0, DELIVERIES_REQUIRED)
	end
	if m.step == 1 and (m.Progress or 0) >= DELIVERIES_REQUIRED then
		m.step = 2
		m.Progress = 0
		CampaignService.setFlag(player, "first_deliveries")
	end
	if m.step == 2 and m.HomeVisited then
		m.step = 3
	end
	if m.step == 3 and furnitureCount >= 1 then
		m.step = 4
		CampaignService.setFlag(player, "phase1_done")
	end

	-- Chapter 2: surviving the fall ------------------------------------------------
	-- Step 4 (SCAVENGE) also catches legacy saves that already finished Phase 1 --
	-- setFlag is idempotent, so the emergency broadcast fires exactly once.
	if m.step == 4 then
		CampaignService.setFlag(player, "outbreak_started")
	end
	if m.step == 4 and (m.Scavenged or 0) >= (MissionDefinitions.REQUIREMENTS.SCAVENGE or 3) then
		m.step = 5
	end
	if m.step == 5 and (m.Kills or 0) >= (MissionDefinitions.REQUIREMENTS.FIGHT_INFECTED or 1) then
		m.step = 6
	end
	if m.step == 6 and (m.Fortified or 0) >= (MissionDefinitions.REQUIREMENTS.FORTIFY_SAFEHOUSE or 1) then
		m.step = 7
	end

	-- Chapter 3: rebuilding ------------------------------------------------------
	if m.step == 7 then
		CampaignService.setFlag(player, "rebuild_started")
	end
	if m.step == 7 and (m.StructuresBuilt or 0) >= (MissionDefinitions.REQUIREMENTS.BUILD_STRUCTURE or 1) then
		m.step = 8
	end
	if m.step == 8 and (m.Collected or 0) >= (MissionDefinitions.REQUIREMENTS.COLLECT_YIELD or 1) then
		m.step = 9
	end

	-- Chapter 4: clans --------------------------------------------------------------
	if m.step == 9 then
		CampaignService.setFlag(player, "clan_started")
	end
	if m.step == 9 and (m.Joined or 0) >= (MissionDefinitions.REQUIREMENTS.JOIN_CLAN or 1) then
		m.step = 10
	end
	if m.step == 10 and (m.GroupDone or 0) >= (MissionDefinitions.REQUIREMENTS.CLAN_CONTRACT or 1) then
		m.step = 11
	end

	DataService.markDirty(player)
	DataService.sync(player)
	pushObjective(player)
end

local function onDelivered(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if data.Missions.INTRO.step == 1 then
		DataService.update(player, function(d)
			d.Missions.INTRO.Progress = (d.Missions.INTRO.Progress or 0) + 1
		end)
	end
	recompute(player)
end

local function onScavenged(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if data.Missions.INTRO.step == 4 then
		DataService.update(player, function(d)
			d.Missions.INTRO.Scavenged = (d.Missions.INTRO.Scavenged or 0) + 1
		end)
	end
	recompute(player)
end

local function onInfectedDefeated(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if data.Missions.INTRO.step == 5 then
		DataService.update(player, function(d)
			d.Missions.INTRO.Kills = (d.Missions.INTRO.Kills or 0) + 1
		end)
	end
	recompute(player)
end

local function onFortified(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if data.Missions.INTRO.step == 6 then
		DataService.update(player, function(d)
			d.Missions.INTRO.Fortified = (d.Missions.INTRO.Fortified or 0) + 1
		end)
	end
	recompute(player)
end

local function onStructureBuilt(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if data.Missions.INTRO.step == 7 then
		DataService.update(player, function(d)
			d.Missions.INTRO.StructuresBuilt = (d.Missions.INTRO.StructuresBuilt or 0) + 1
		end)
	end
	recompute(player)
end

local function onYieldCollected(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if data.Missions.INTRO.step == 8 then
		DataService.update(player, function(d)
			d.Missions.INTRO.Collected = (d.Missions.INTRO.Collected or 0) + 1
		end)
	end
	recompute(player)
end

local function onClanJoined(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if data.Missions.INTRO.step == 9 then
		DataService.update(player, function(d)
			d.Missions.INTRO.Joined = (d.Missions.INTRO.Joined or 0) + 1
		end)
	end
	recompute(player)
end

local function onClanContractDone(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if data.Missions.INTRO.step == 10 then
		DataService.update(player, function(d)
			d.Missions.INTRO.GroupDone = (d.Missions.INTRO.GroupDone or 0) + 1
		end)
	end
	recompute(player)
end

function MissionService.Init()
	DialogueService.Events.MarcusTalked:Connect(function(player)
		recompute(player)
	end)
	ContractService.Events.Delivered:Connect(onDelivered)
	HomeService.Events.Opened:Connect(function(player)
		DataService.update(player, function(d)
			d.Missions.INTRO.HomeVisited = true
		end)
		recompute(player)
	end)
	HomeService.Events.ItemBought:Connect(function(player)
		recompute(player)
	end)
	SurvivalService.Events.Scavenged:Connect(onScavenged)
	InfectedService.Events.Defeated:Connect(onInfectedDefeated)
	SurvivalService.Events.Fortified:Connect(onFortified)
	SettlementService.Events.StructureBuilt:Connect(onStructureBuilt)
	SettlementService.Events.YieldCollected:Connect(onYieldCollected)
	ClanService.Events.ClanChanged:Connect(onClanJoined)
	ClanService.Events.ClanContractDone:Connect(onClanContractDone)

	-- players already loaded before Init, and every future load
	local function onLoaded(player)
		recompute(player)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if DataService.get(player) then
			onLoaded(player)
		end
	end
	DataService.Events.ProfileLoaded:Connect(onLoaded)
end

return MissionService