-- CampaignService.lua — campaign flags (Phase 0/2 groundwork) + world reactions
-- Flags live in the profile so rejoining never re-wards or re-triggers state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local DataService = require(script.Parent.DataService)

local CampaignService = {}
CampaignService.Events = {
	FlagSet = Signal.new(), -- (player, flag)
}

-- Server-global one-time world reactions (shared server flavor only)
local reacted: { [string]: boolean } = {}

local function setNewsHeadline(text: string)
	task.spawn(function()
		local meridian = workspace:WaitForChild("Meridian", 10)
		local screen = meridian and meridian:WaitForChild("NewsScreen", 5)
		if not screen then
			return
		end
		local gui = screen:FindFirstChildOfClass("SurfaceGui")
		local headline = gui and gui:FindFirstChild("Headline", true)
		if headline then
			headline.Text = text
		end
	end)
end

-- public hook for other services (territory captures, alliance headlines)
function CampaignService.announce(text: string)
	setNewsHeadline(text)
end

local WORLD_REACTIONS = {
	phase1_done = function()
		if reacted.phase1_done then
			return
		end
		reacted.phase1_done = true
		setNewsHeadline("GRID FLICKERS ACROSS MERIDIAN — OFFICIALS URGE CALM")
		local lighting = game:GetService("Lighting")
		lighting.ClockTime = 19.4
		lighting.Brightness = 2.4
	end,

	-- Chapter 2 begins: the emergency broadcast + the fall of evening light
	outbreak_started = function()
		if reacted.outbreak_started then
			return
		end
		reacted.outbreak_started = true
		setNewsHeadline("EMERGENCY BROADCAST: HARBOR FACILITY OUTAGE — STAY INDOORS")
		local lighting = game:GetService("Lighting")
		lighting.ClockTime = 19.8
		lighting.Brightness = 1.7
		lighting.FogEnd = 520
		lighting.FogColor = Color3.fromRGB(24, 26, 34)
	end,

	-- Chapter 3 begins: the rebuild — dawn breaks over the settlement
	rebuild_started = function()
		if reacted.rebuild_started then
			return
		end
		reacted.rebuild_started = true
		setNewsHeadline("SETTLEMENT CHARTER SIGNED — MERIDIAN BEGINS TO REBUILD")
		local lighting = game:GetService("Lighting")
		lighting.ClockTime = 14.2
		lighting.Brightness = 2.6
		lighting.FogEnd = 1400
		lighting.FogColor = Color3.fromRGB(200, 208, 222)
	end,

	-- Territory flips hands: the war for Meridian is on
	territory_claimed = function()
		if reacted.territory_claimed then
			return
		end
		reacted.territory_claimed = true
		setNewsHeadline("TERRITORY FLIPS HANDS — THE WAR FOR MERIDIAN IS ON")
		local lighting = game:GetService("Lighting")
		lighting.ClockTime = 16.0
		lighting.Brightness = 2.0
	end,

	-- Chapter 4 begins: the clans era — banners are rising in Meridian
	clan_started = function()
		if reacted.clan_started then
			return
		end
		reacted.clan_started = true
		setNewsHeadline("CLAN CHARTERS PILE UP — DISTRICTS FORMING ALLIANCES")
		local lighting = game:GetService("Lighting")
		lighting.ClockTime = 15.4
		lighting.Brightness = 2.2
	end,

	-- A pact sealed: the districts watch who stands with whom
	alliance_formed = function()
		if reacted.alliance_formed then
			return
		end
		reacted.alliance_formed = true
		setNewsHeadline("PACT SEALED — WHICH DISTRICTS STAND TOGETHER?")
	end,
}

function CampaignService.hasFlag(player: Player, flag: string): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	return table.find(data.Campaign.Flags or {}, flag) ~= nil
end

function CampaignService.setFlag(player: Player, flag: string)
	if CampaignService.hasFlag(player, flag) then
		return
	end
	DataService.update(player, function(data)
		table.insert(data.Campaign.Flags, flag)
	end)
	print(("[CampaignService] %s flag: %s"):format(player.Name, flag))
	CampaignService.Events.FlagSet:Fire(player, flag)
	local react = WORLD_REACTIONS[flag]
	if react then
		react()
	end
end

function CampaignService.Init() end

return CampaignService