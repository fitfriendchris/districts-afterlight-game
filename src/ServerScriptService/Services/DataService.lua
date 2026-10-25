-- DataService.lua — persistent player profiles (Phase 0: the save system)
-- Versioned schema, load retries, autosave, BindToClose, UpdateAsync writes.
-- The completion test: earn cash -> leave -> rejoin -> balance still correct.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ProgressionConfig = require(ReplicatedStorage.Shared.Configs.ProgressionConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Configs.EconomyConfig)

local DataService = {}
DataService.Events = {
	ProfileLoaded = Signal.new(),
	ProfileUpdated = Signal.new(),
}

local STORE_NAME = "DistrictsAfterlight_Profiles_v1"
local AUTOSAVE_INTERVAL = 90

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles = {}
local dirty = {}

local function deepCopy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = (type(v) == "table") and deepCopy(v) or v
	end
	return out
end

local function fillSchema(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = (type(v) == "table") and deepCopy(v) or v
		elseif type(v) == "table" and type(dst[k]) == "table" then
			fillSchema(dst[k], v)
		end
	end
	return dst
end

local function defaultData()
	return {
		Version = 1,
		Cash = EconomyConfig.BASE_STARTING_CASH,
		XP = 0,
		Inventory = { Scrap = 0, Fabric = 0, Medical = 0 },
		Stats = { Deliveries = 0, Pickups = 0, ContractsDone = 0, LastContractAt = 0, Scavenges = 0, InfectedDefeated = 0, Fortified = 0, StructuresBuilt = 0, Collected = 0, ClanCreated = 0 },
		Campaign = { Flags = {} },
		Missions = { INTRO = { Step = 0, Progress = 0 } },
		Contract = { Active = nil },
		Cosmetics = { Owned = {}, Equipped = { JacketColor = "JK_CRIMSON" } },
		Home = { Furniture = {} },
		Settlement = { Structures = {} },
		Clan = { Id = nil, Donated = 0 },
		LiveOps = { ClaimDay = nil, Streak = 0, GoalDay = nil },
		Monetization = { SupporterPass = false, Receipts = {} },
		Settings = {},
		Heroes = { Roster = {}, Active = {} },
	}
end

local function keyFor(userId: number)
	return "PROFILE_" .. tostring(userId)
end

function DataService.get(player: Player)
	return profiles[player]
end

function DataService.markDirty(player: Player)
	dirty[player] = true
end

function DataService.sync(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	Net.event("PROFILE_SYNC"):FireClient(player, {
		Cash = data.Cash,
		XP = data.XP,
		Level = ProgressionConfig.levelFromXP(data.XP),
		MissionStep = data.Missions.INTRO.step or 0,
		Deliveries = data.Stats.Deliveries or 0,
		Contract = data.Contract.Active and {
			Target = data.Contract.Active.Target,
			HasPackage = data.Contract.Active.HasPackage,
		} or nil,
		Cosmetics = data.Cosmetics,
		Inventory = data.Inventory,
		Heroes = data.Heroes,
		Home = { Furniture = data.Home.Furniture },
		Settlement = data.Settlement,
		Clan = { Id = data.Clan.Id, Donated = data.Clan.Donated },
		Flags = data.Campaign.Flags,
	})
end

-- Single mutation path: fn mutates the profile, then dirty + updated signal + sync.
function DataService.update(player: Player, fn: (data: any) -> ())
	local data = profiles[player]
	if not data then
		return nil
	end
	fn(data)
	dirty[player] = true
	DataService.Events.ProfileUpdated:Fire(player, data)
	DataService.sync(player)
	return data
end

local function saveProfile(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player.UserId), function()
			return data -- server-authoritative full write; no client writes exist
		end)
	end)
	if ok then
		dirty[player] = nil
	else
		warn("[DataService] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function loadProfile(player: Player)
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player.UserId))
		end)
		if ok then
			return result
		end
		warn("[DataService] load attempt " .. attempt .. " failed: " .. tostring(result))
		task.wait(2)
	end
	return nil
end

local function onPlayerAdded(player: Player)
	local raw = loadProfile(player) -- nil = brand-new player
	local data = raw or defaultData()
	if type(data) ~= "table" then
		data = defaultData()
	end
	fillSchema(data, defaultData())
	data.Version = 1
	local level = ProgressionConfig.levelFromXP(data.XP or 0)
	profiles[player] = data
	DataService.sync(player)
	DataService.Events.ProfileLoaded:Fire(player, data)
	print(("[DataService] %s loaded (level %d, cash %d)"):format(player.Name, level, data.Cash))
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		saveProfile(player)
		profiles[player] = nil
		dirty[player] = nil
	end
end

function DataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	game:BindToClose(function()
		for player in pairs(profiles) do
			saveProfile(player)
		end
		task.wait(2)
	end)

	-- autosave loop
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in pairs(dirty) do
				local savePlayer = player
				task.spawn(saveProfile, savePlayer)
			end
		end
	end)
end

return DataService