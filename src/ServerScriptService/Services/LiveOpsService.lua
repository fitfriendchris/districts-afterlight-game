--!strict
-- LiveOpsService.lua — Phase 7: daily streak rewards + rotating community goal.
-- SERVER-AUTHORITATIVE: streak validation, goal progress and rewards all live
-- here. Goals persist in a dedicated DataStore keyed by UTC day (cache-first
-- with a graceful fallback so the slice still runs before the place is
-- published). No new remotes — players are reached via toasts, the world sign
-- and the news headline.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Net)
local LiveOpsConfig = require(ReplicatedStorage.Shared.Configs.LiveOpsConfig)
local DataService = require(ServerScriptService.Services.DataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local CampaignService = require(ServerScriptService.Services.CampaignService)
local ContractService = require(ServerScriptService.Services.ContractService)
local InfectedService = require(ServerScriptService.Services.InfectedService)

local cfg = LiveOpsConfig

local LiveOpsService = {}

-- ------------------------------------------------------------------ day ----
local function todayKey(): string
	return os.date("!%Y-%m-%d")
end

local function dayOffsetKey(offset: number): string
	return os.date("!%Y-%m-%d", os.time() + offset * 86400)
end

-- ---------------------------------------------------------------- goal ----
local goal: { Day: string?, Progress: number, Done: boolean, Announced: boolean? } = {
	Day = nil, Progress = 0, Done = false, Announced = nil,
}
local store = nil

local function saveGoal()
	if not store then
		return
	end
	local snap = { Day = goal.Day, Progress = goal.Progress, Done = goal.Done }
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync("GOAL_" .. tostring(goal.Day), snap)
		end)
		if not ok then
			warn("[LiveOpsService] goal save failed: " .. tostring(err))
		end
	end)
end

local function streakDay(day: number): number
	if day > cfg.STREAK.MAX_STREAK then
		return cfg.STREAK.MAX_STREAK
	end
	return day
end

-- world sign (built by build_place.py): part "CommunityBoard" with a "Headline" label
local goalLabel = nil
local function updateSign()
	task.spawn(function()
		if not goalLabel then
			local meridian = workspace:FindFirstChild("Meridian")
			local panel = meridian and meridian:FindFirstChild("CommunityBoardPanel", true)
			if panel and panel:IsA("BasePart") then
				local gui = panel:FindFirstChildOfClass("SurfaceGui")
				goalLabel = gui and gui:FindFirstChild("Headline", true)
			end
		end
		if goalLabel then
			goalLabel.Text = ("COMMUNITY GOAL %d/%d%s"):format(goal.Progress, cfg.GOAL.TARGET, goal.Done and " — MET!" or "")
		end
	end)
end

local function rewardGoalMember(player: Player, why: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	if data.LiveOps.GoalDay == goal.Day then
		return
	end
	DataService.update(player, function(d)
		d.LiveOps.GoalDay = goal.Day
		d.Inventory.Scrap = (d.Inventory.Scrap or 0) + cfg.GOAL.SCRAP_REWARD
	end)
	EconomyService.award(player, cfg.GOAL.CASH_REWARD, 0, "liveops_goal")
	Net.event("TOAST"):FireClient(player, { text = ("MERIDIAN HOLDS THE LINE — %s +%d cash, +%d scrap"):format(why, cfg.GOAL.CASH_REWARD, cfg.GOAL.SCRAP_REWARD), duration = 5 })
end

local function contributeOne(player: Player, why: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	if goal.Done then
		return
	end
	goal.Progress += 1
	if goal.Progress >= cfg.GOAL.TARGET then
		goal.Done = true
		CampaignService.announce("COMMUNITY GOAL MET — MERIDIAN HOLDS THE LINE")
	end
	updateSign()
	saveGoal()
	if goal.Done and not goal.Announced then
		goal.Announced = true
		for _, p in ipairs(Players:GetPlayers()) do
			rewardGoalMember(p, why)
		end
	end
end

-- --------------------------------------------------------------- streak ----
local function grantStreak(player: Player, data)
	local cfgStreak = cfg.STREAK
	local today = todayKey()
	local claim = data.LiveOps.ClaimDay
	if claim == today then
		return -- already collected today
	end
	local day = 1
	if claim == dayOffsetKey(-1) then
		day = (data.LiveOps.Streak or 0) + 1
	end
	local d = streakDay(day)
	local cash = cfgStreak.BASE_CASH + cfgStreak.CASH_STEP * (d - 1)
	local scrap = cfgStreak.SCRAP_BY_DAY[d] or cfgStreak.SCRAP_BY_DAY[cfgStreak.MAX_STREAK]
	local medical = cfgStreak.MEDICAL_BY_DAY[d] or 0
	-- award AFTER the profile is marked (ProfileLoaded fires pre-first-update)
	DataService.update(player, function(dd)
		dd.LiveOps.ClaimDay = today
		dd.LiveOps.Streak = day
		dd.Inventory.Scrap = (dd.Inventory.Scrap or 0) + scrap
		dd.Inventory.Medical = (dd.Inventory.Medical or 0) + medical
	end)
	EconomyService.award(player, cash, 0, "liveops_daily")
	Net.event("TOAST"):FireClient(player, { text = ("DAY %d STREAK — +%d cash, +%d scrap%s"):format(day, cash, scrap, medical > 0 and (", +" .. tostring(medical) .. " medical") or ""), duration = 5 })
end

-- ----------------------------------------------------------------- init ----
function LiveOpsService.Init()
	pcall(function()
		store = DataStoreService:GetDataStore("DistrictsAfterlight_LiveOps_v1")
		local ok, snap = pcall(function()
			return store:GetAsync("GOAL_" .. todayKey())
		end)
		if ok and type(snap) == "table" and snap.Day == todayKey() then
			goal.Day = snap.Day
			goal.Progress = snap.Progress or 0
			goal.Done = snap.Done or false
			goal.Announced = goal.Done and true or nil
		end
	end)
	if not goal.Day then
		goal.Day = todayKey()
		goal.Progress = 0
		goal.Done = false
	end
	updateSign()

	-- contributions: deliveries + infected defeats
	ContractService.Events.Delivered:Connect(function(player)
		contributeOne(player, "deliveries")
	end)
	InfectedService.Events.Defeated:Connect(function(player)
		contributeOne(player, "defenses")
	end)

	-- streaks + late goal rewards on profile load — ONE global handler
	DataService.Events.ProfileLoaded:Connect(function(player, data)
		grantStreak(player, data)
		if goal.Done and data.LiveOps.GoalDay ~= goal.Day then
			rewardGoalMember(player, "goals")
		end
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		local data = DataService.get(p)
		if data then
			grantStreak(p, data)
			if goal.Done and data.LiveOps.GoalDay ~= goal.Day then
				rewardGoalMember(p, "goals")
			end
		end
	end
end

return LiveOpsService