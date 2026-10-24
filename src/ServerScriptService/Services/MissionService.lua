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

local MissionService = {}

local DELIVERIES_REQUIRED = MissionDefinitions.DELIVERIES_REQUIRED

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
	if step.id == "DO_DELIVERIES" then
		payload.progress = math.min(m.Progress or 0, DELIVERIES_REQUIRED)
		payload.max = DELIVERIES_REQUIRED
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