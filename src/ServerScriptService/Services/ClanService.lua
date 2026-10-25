--!strict
-- ClanService.lua — Phase 5: persistent clans + shared group contracts.
-- SERVER-AUTHORITATIVE: creation/joins/donations/contract progress are validated
-- and mutated here. Clan state lives in a dedicated DataStore (cache-first with
-- graceful fallback so the slice still runs before the place is published).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local Net = require(ReplicatedStorage.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ClanConfig = require(ReplicatedStorage.Shared.Configs.ClanConfig)
local DataService = require(ServerScriptService.Services.DataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local ContractService = require(ServerScriptService.Services.ContractService)

local cfg = ClanConfig

local ClanService = {}
ClanService.Events = {
	ClanChanged = Signal.new(),     -- (player, memberOf: number?)
	ClanContractDone = Signal.new(), -- (player)  — delivering member's mission credit
	ClanDissolved = Signal.new(),   -- (clanId)  — freed ids, orphaned territory, broken allies
	AllianceFormed = Signal.new(),  -- (player)  — accepting leader's mission credit
	BoardOpened = Signal.new(),     -- (player)  — clan hall board open: territory syncs its snapshot
}

local clans: { [number]: any } = {}     -- id -> clan record (numbers only)
local allyOffers: { [number]: any } = {} -- targetClanId -> { From = clanId }
local nameToId: { [string]: number } = {}
local dirtyClans: { [number]: boolean } = {}
local lastChange: { [Player]: number } = {}
local store = nil                       -- DataStore, when available
local nextId = 1

-- ------------------------------------------------------------------ store ----
local function normalizeName(s: any): string
	if typeof(s) ~= "string" then
		return ""
	end
	return s:gsub("%s+", " "):gsub("^%s", ""):gsub("%s$", "")
end

local function saveClan(id: number)
	local clan = clans[id]
	if not clan or not store then
		return
	end
	dirtyClans[id] = nil
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync("CLAN_" .. tostring(id), clan)
		end)
		if not ok then
			warn("[ClanService] clan save failed: " .. tostring(err))
			dirtyClans[id] = true
		end
	end)
end

-- ---------------------------------------------------------------- helpers ----
local function clanOf(player: Player)
	local data = DataService.get(player)
	local cid = data and data.Clan and data.Clan.Id
	return cid and clans[cid] or nil
end

local function memberCount(clan): number
	local n = 0
	for _ in pairs(clan.Members) do
		n += 1
	end
	return n
end

local function snapshot(): { any }
	local out = {}
	for id, clan in pairs(clans) do
		table.insert(out, {
			Id = id, Name = clan.Name, Tag = clan.Tag,
			Members = memberCount(clan), Bank = clan.Bank,
			Allied = table.concat(allyTags(clan), " "),
			Contract = clan.Contract and {
				Progress = clan.Contract.Progress,
				Required = clan.Contract.Required,
				Target = clan.Contract.Target,
			} or nil,
		})
	end
	table.sort(out, function(a, b)
		return a.Members > b.Members
	end)
	return out
end

local function cooldownOk(player: Player): boolean
	local now = os.clock()
	if (lastChange[player] or 0) + cfg.LEAVE_COOLDOWN > now then
		Net.event("TOAST"):FireClient(player, { text = "Clan cooldown — try again shortly", duration = 3 })
		return false
	end
	lastChange[player] = now
	return true
end

-- Phase 6: cross-service helpers (TerritoryService consumes these)
local function allyList(clan): { [number]: boolean }
	if type(clan.Allies) ~= "table" then
		clan.Allies = {}
	end
	return clan.Allies
end

function ClanService.allyIdsOf(clanId: number?): { number }
	local clan = clanId and clans[clanId] or nil
	if not clan then
		return {}
	end
	local out = {}
	for id in pairs(allyList(clan)) do
		table.insert(out, id)
	end
	return out
end

function ClanService.tagOf(clanId: number?): string?
	local clan = clanId and clans[clanId] or nil
	return clan and clan.Tag or nil
end

function ClanService.memberUserIdsOf(clanId: number?): { number }
	local clan = clanId and clans[clanId] or nil
	if not clan then
		return {}
	end
	local out = {}
	for userId in pairs(clan.Members) do
		table.insert(out, userId)
	end
	return out
end

local function leaderOf(clan): Player?
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == clan.OwnerUserId then
			return p
		end
	end
	return nil
end

local function isLeader(player: Player, clan): boolean
	return clan.OwnerUserId == player.UserId
end

local function allyTags(clan): { string }
	local tags = {}
	for id in pairs(allyList(clan)) do
		local other = clans[id]
		if other then
			table.insert(tags, ("[%s]"):format(other.Tag))
		end
	end
	table.sort(tags)
	return tags
end

-- ---------------------------------------------------------------- actions ----
function ClanService.create(player: Player, name: any, tag: any)
	local data = DataService.get(player)
	if not data then
		return false
	end
	if data.Clan.Id then
		Net.event("TOAST"):FireClient(player, { text = "Leave your clan first", duration = 3 })
		return false
	end
	if not cooldownOk(player) then
		return false
	end
	local cleanName = normalizeName(name)
	local cleanTag = normalizeName(tag):upper()
	if #cleanName < cfg.NAME_MIN or #cleanName > cfg.NAME_MAX then
		Net.event("TOAST"):FireClient(player, { text = ("Clan name is %d–%d characters"):format(cfg.NAME_MIN, cfg.NAME_MAX), duration = 3 })
		return false
	end
	if #cleanTag < cfg.TAG_MIN or #cleanTag > cfg.TAG_MAX then
		Net.event("TOAST"):FireClient(player, { text = ("Tag is %d–%d characters"):format(cfg.TAG_MIN, cfg.TAG_MAX), duration = 3 })
		return false
	end
	if nameToId[cleanName:lower()] then
		Net.event("TOAST"):FireClient(player, { text = "That clan name is taken", duration = 3 })
		return false
	end
	-- founding costs
	if not EconomyService.spend(player, cfg.CREATE_CASH, "clan_create") then
		Net.event("TOAST"):FireClient(player, { text = ("Founding costs $%d"):format(cfg.CREATE_CASH), duration = 3 })
		return false
	end
	local scrapOK = false
	DataService.update(player, function(d)
		if (d.Inventory.Scrap or 0) >= cfg.CREATE_SCRAP then
			d.Inventory.Scrap -= cfg.CREATE_SCRAP
			scrapOK = true
		end
	end)
	if not scrapOK then
		EconomyService.award(player, cfg.CREATE_CASH, 0, "clan_create_refund")
		Net.event("TOAST"):FireClient(player, { text = ("Founding also needs %d scrap"):format(cfg.CREATE_SCRAP), duration = 3 })
		return false
	end

	local id = nextId
	nextId += 1
	clans[id] = {
		Id = id, Name = cleanName, Tag = cleanTag,
		OwnerUserId = player.UserId, Bank = 0,
		Members = { [player.UserId] = true },
		Contract = nil, LastContractAt = 0,
		Allies = {},
	}
	nameToId[cleanName:lower()] = id
	DataService.update(player, function(d)
		d.Clan.Id = id
		d.Stats.ClanCreated = (d.Stats.ClanCreated or 0) + 1
	end)
	ClanService.persistAll() -- new clan dirty
	ClanService.Events.ClanChanged:Fire(player, id)
	Net.event("TOAST"):FireClient(player, { text = ("Clan [%s] %s founded!"):format(cleanTag, cleanName), duration = 4 })
	ClanService.sync(player)
	return true
end

function ClanService.join(player: Player, id: number)
	local clan = clans[id]
	local data = DataService.get(player)
	if not clan or not data then
		Net.event("TOAST"):FireClient(player, { text = "That clan no longer exists", duration = 3 })
		return false
	end
	if data.Clan.Id then
		Net.event("TOAST"):FireClient(player, { text = "Leave your clan first", duration = 3 })
		return false
	end
	if not cooldownOk(player) then
		return false
	end
	if memberCount(clan) >= cfg.MEMBER_CAP then
		Net.event("TOAST"):FireClient(player, { text = "That clan is full", duration = 3 })
		return false
	end
	clan.Members[player.UserId] = true
	DataService.update(player, function(d)
		d.Clan.Id = id
	end)
	ClanService.Events.ClanChanged:Fire(player, id)
	Net.event("TOAST"):FireClient(player, { text = ("Joined [%s] %s"):format(clan.Tag, clan.Name), duration = 3 })
	ClanService.sync(player)
	return true
end

function ClanService.leave(player: Player)
	local clan = clanOf(player)
	if not clan then
		return false
	end
	if not cooldownOk(player) then
		return false
	end
	clan.Members[player.UserId] = nil
	DataService.update(player, function(d)
		d.Clan.Id = nil
	end)
	-- dissolve if the owner leaves, or the last member leaves
	if memberCount(clan) == 0 or clan.OwnerUserId == player.UserId then
		for userId in pairs(clan.Members) do
			for _, p in ipairs(Players:GetPlayers()) do
				if p.UserId == userId then
					DataService.update(p, function(d)
						d.Clan.Id = nil
					end)
					Net.event("TOAST"):FireClient(p, { text = ("[%s] dissolved — the founder left"):format(clan.Tag), duration = 4 })
				end
			end
		end
		clans[clan.Id] = nil
		dirtyClans[clan.Id] = nil
		nameToId[clan.Name:lower()] = nil
		allyOffers[clan.Id] = nil
		-- allies: cut the dead clan out of every friendly list
		for _, other in pairs(clans) do
			if other.Allies and other.Allies[clan.Id] then
				other.Allies[clan.Id] = nil
				dirtyClans[other.Id] = true
			end
		end
		ClanService.Events.ClanDissolved:Fire(clan.Id)
	else
		ClanService.persistAll()
	end
	ClanService.Events.ClanChanged:Fire(player, nil)
	ClanService.sync(player)
	return true
end

function ClanService.donate(player: Player, amount: number)
	local clan = clanOf(player)
	if not clan then
		return false
	end
	amount = math.floor(tonumber(amount) or 0)
	if amount < cfg.DONATE_MIN or amount > cfg.DONATE_MAX then
		Net.event("TOAST"):FireClient(player, { text = ("Donate between $%d and $%d"):format(cfg.DONATE_MIN, cfg.DONATE_MAX), duration = 3 })
		return false
	end
	if not EconomyService.spend(player, amount, "clan_donate") then
		Net.event("TOAST"):FireClient(player, { text = "Not enough cash", duration = 3 })
		return false
	end
	clan.Bank += amount
	DataService.update(player, function(d)
		d.Clan.Donated = (d.Clan.Donated or 0) + amount
	end)
	ClanService.persistAll()
	Net.event("TOAST"):FireClient(player, { text = ("Donated $%d to the clan bank"):format(amount), duration = 3 })
	ClanService.sync(player)
	return true
end

function ClanService.startContract(player: Player)
	local clan = clanOf(player)
	if not clan then
		return false
	end
	if clan.Contract then
		Net.event("TOAST"):FireClient(player, { text = "A clan contract is already running", duration = 3 })
		return false
	end
	if os.clock() - (clan.LastContractAt or 0) < cfg.CONTRACT.COOLDOWN then
		Net.event("TOAST"):FireClient(player, { text = "The board needs a moment before the next contract", duration = 3 })
		return false
	end
	local targets = require(ReplicatedStorage.Shared.WorldLayout).DELIVERY_TARGETS
	local target = math.random(#targets)
	clan.Contract = {
		Target = target,
		Progress = 0,
		Required = cfg.CONTRACT.REQUIRED_DELIVERIES,
	}
	ClanService.persistAll()
	ClanService.sync(player)
	for userId in pairs(clan.Members) do
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == userId then
				Net.event("TOAST"):FireClient(p, { text = "GROUP CONTRACT: deliveries for house " .. tostring(target), duration = 4 })
			end
		end
	end
	return true
end

-- called by ContractService when any clan member delivers
function ClanService.onContractDelivered(player: Player)
	local clan = clanOf(player)
	if not clan or not clan.Contract then
		return
	end
	local contract = clan.Contract
	contract.Progress += 1
	clan.LastContractAt = os.clock()
	Net.event("TOAST"):FireClient(player, { text = ("Group progress %d/%d"):format(contract.Progress, contract.Required), duration = 3 })
	if contract.Progress >= contract.Required then
		clan.Bank += cfg.CONTRACT.CASH_REWARD
		EconomyService.award(player, cfg.CONTRACT.CASH_SHARE, cfg.CONTRACT.XP_SHARE, "clan_contract")
		clan.Contract = nil
		clan.LastContractAt = os.clock()
		ClanService.Events.ClanContractDone:Fire(player)
		for userId in pairs(clan.Members) do
			for _, p in ipairs(Players:GetPlayers()) do
				if p.UserId == userId then
					Net.event("TOAST"):FireClient(p, { text = ("GROUP CONTRACT COMPLETE — bank +%d"):format(cfg.CONTRACT.CASH_REWARD), duration = 4 })
				end
			end
		end
	end
	ClanService.persistAll()
	ClanService.sync(player)
end

-- ---------------------------------------------------------------- allies ----
local function toastClan(clanId: number, text: string)
	for _, p in ipairs(Players:GetPlayers()) do
		local data = DataService.get(p)
		if data and data.Clan and data.Clan.Id == clanId then
			Net.event("TOAST"):FireClient(p, { text = text, duration = 4 })
		end
	end
end

function ClanService.allyOffer(player: Player, targetId: number)
	local clan = clanOf(player)
	if not clan then
		return false
	end
	if not isLeader(player, clan) then
		Net.event("TOAST"):FireClient(player, { text = "Only the founder can raise alliances", duration = 3 })
		return false
	end
	local target = clans[targetId]
	if not target or target.Id == clan.Id then
		Net.event("TOAST"):FireClient(player, { text = "No such rival clan", duration = 3 })
		return false
	end
	local mine, theirs = allyList(clan), allyList(target)
	if mine[targetId] then
		Net.event("TOAST"):FireClient(player, { text = "Already allies", duration = 3 })
		return false
	end
	local count = 0
	for _ in pairs(mine) do
		count += 1
	end
	if count >= cfg.ALLY_MAX then
		Net.event("TOAST"):FireClient(player, { text = ("Alliance slots full (%d)"):format(cfg.ALLY_MAX), duration = 3 })
		return false
	end
	local tcount = 0
	for _ in pairs(theirs) do
		tcount += 1
	end
	if tcount >= cfg.ALLY_MAX then
		Net.event("TOAST"):FireClient(player, { text = "Their alliance slots are full", duration = 3 })
		return false
	end
	-- mutual offers seal instantly
	local pending = allyOffers[targetId]
	if pending and pending.From == clan.Id then
		-- this IS our own offer echoing back (shouldn't happen); ignore
		return false
	end
	local mutual = allyOffers[clan.Id]
	if mutual and mutual.From == targetId then
		return ClanService.allyAccept(player, targetId)
	end
	allyOffers[targetId] = { From = clan.Id }
	local leader = leaderOf(target)
	if leader then
		Net.event("TOAST"):FireClient(leader, { text = ("[%s] %s proposes an alliance — open the Clan Hall to accept"):format(clan.Tag, clan.Name), duration = 6 })
	end
	Net.event("TOAST"):FireClient(player, { text = ("Alliance offered to [%s]"):format(target.Tag), duration = 3 })
	ClanService.sync(player)
	return true
end

function ClanService.allyAccept(player: Player, fromId: number)
	local clan = clanOf(player)
	if not clan then
		return false
	end
	if not isLeader(player, clan) then
		Net.event("TOAST"):FireClient(player, { text = "Only the founder can accept alliances", duration = 3 })
		return false
	end
	local from = clans[fromId]
	if not from then
		Net.event("TOAST"):FireClient(player, { text = "That clan has dissolved", duration = 3 })
		return false
	end
	local offer = allyOffers[clan.Id]
	if (not offer or offer.From ~= fromId) and not allyList(clan)[fromId] then
		Net.event("TOAST"):FireClient(player, { text = "No standing alliance offer from them", duration = 3 })
		return false
	end
	allyOffers[clan.Id] = nil
	allyOffers[fromId] = nil
	if allyList(clan)[fromId] then
		Net.event("TOAST"):FireClient(player, { text = "Already allies", duration = 3 })
		return false -- stale offer on an existing pact: clear it, credit nothing
	end
	allyList(clan)[fromId] = true
	allyList(from)[clan.Id] = true
	ClanService.persistAll()
	ClanService.Events.AllianceFormed:Fire(player)
	toastClan(clan.Id, ("ALLIANCE SEALED — [%s] + [%s] stand together"):format(clan.Tag, from.Tag))
	toastClan(fromId, ("ALLIANCE SEALED — [%s] + [%s] stand together"):format(from.Tag, clan.Tag))
	ClanService.sync(player)
	for _, p in ipairs(Players:GetPlayers()) do
		local data = DataService.get(p)
		if data and data.Clan and data.Clan.Id == fromId then
			ClanService.sync(p)
		end
	end
	return true
end

function ClanService.allyBreak(player: Player, targetId: number)
	local clan = clanOf(player)
	if not clan then
		return false
	end
	if not isLeader(player, clan) then
		Net.event("TOAST"):FireClient(player, { text = "Only the founder can break alliances", duration = 3 })
		return false
	end
	if not allyList(clan)[targetId] then
		return false
	end
	local other = clans[targetId]
	allyList(clan)[targetId] = nil
	if other then
		allyList(other)[clan.Id] = nil
		toastClan(targetId, ("[%s] broke the alliance"):format(clan.Tag))
	end
	ClanService.persistAll()
	Net.event("TOAST"):FireClient(player, { text = "Alliance broken", duration = 3 })
	ClanService.sync(player)
	return true
end

-- ------------------------------------------------------------------- sync ----
function ClanService.sync(player: Player, open: boolean?)
	local mine = nil
	local data = DataService.get(player)
	if data and data.Clan and data.Clan.Id then
		mine = clans[data.Clan.Id]
	end
		local offer = mine and allyOffers[mine.Id] or nil
		local offerFrom = offer and clans[offer.From] or nil
		Net.event("CLAN_SYNC"):FireClient(player, {
			Open = open or nil,
			Clans = snapshot(),
			Offer = offerFrom and { Id = offerFrom.Id, Tag = offerFrom.Tag, Name = offerFrom.Name } or nil,
			MemberOf = data and data.Clan and data.Clan.Id or nil,
			Donated = data and data.Clan and data.Clan.Donated or 0,
		Mine = mine and { Id = mine.Id, Name = mine.Name, Tag = mine.Tag, Bank = mine.Bank, Members = memberCount(mine), Leader = mine.OwnerUserId == player.UserId, Allies = table.concat(allyTags(mine), " "), AllyIds = ClanService.allyIdsOf(mine.Id), Contract = mine.Contract and { Progress = mine.Contract.Progress, Required = mine.Contract.Required } or nil } or nil,
	})
end

function ClanService.persistAll()
	for id in pairs(clans) do
		dirtyClans[id] = true
	end
end

-- board open: ONE payload carries the snapshot + Open flag (no ordering hazard)
function ClanService.openBoard(player: Player)
	ClanService.sync(player, true)
	ClanService.Events.BoardOpened:Fire(player)
end

function ClanService.Init()
	-- clan hall board prompt (world part built by build_place.py)
	task.spawn(function()
		local meridian = workspace:WaitForChild("Meridian", 20)
		local hall = meridian and meridian:WaitForChild("ClanHall", 20)
		if hall then
			local boardPart = hall:FindFirstChild("ClanBoard", true) or hall:FindFirstChildOfClass("Part")
			if boardPart then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Open Clan Hall"
				prompt.ObjectText = "Clan Hall"
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.HoldDuration = 0.1
				prompt.RequiresLineOfSight = false
				prompt.MaxActivationDistance = 10
				prompt.Parent = boardPart
				prompt.Triggered:Connect(function(player)
					ClanService.openBoard(player)
				end)
			end
		end
	end)

	-- load the clan store (graceful when unpublished — DataStore API off)
	pcall(function()
		store = DataStoreService:GetDataStore("DistrictsAfterlight_Clan_v1")
		local ok, data = pcall(function()
			return store:GetAsync("CLAN_INDEX")
		end)
		if type(data) == "table" then
			for id, clan in pairs(data) do
				clans[tonumber(id) or 0] = clan
				nameToId[clan.Name:lower()] = tonumber(id) or 0
			end
			for id in pairs(clans) do
				if id >= nextId then
					nextId = id + 1
				end
			end
		end
	end)

	-- membership restores when the profile loads (Data side owns data.Clan.Id);
	-- ONE global handler — no per-player nested connects
	local function onProfileLoaded(who: Player, data)
		if data.Clan and data.Clan.Id then
			ClanService.sync(who)
		end
	end
	DataService.Events.ProfileLoaded:Connect(onProfileLoaded)
	for _, p in ipairs(Players:GetPlayers()) do
		local d = DataService.get(p)
		if d then
			onProfileLoaded(p, d)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)

	-- periodic flush
	task.spawn(function()
		while true do
			task.wait(cfg.SAVE_INTERVAL)
			for id, _ in pairs(dirtyClans) do
				saveClan(id)
			end
		end
	end)

	game:BindToClose(function()
		for id in pairs(dirtyClans) do
			saveClan(id)
		end
		task.wait(2)
	end)

	-- hook regular contract deliveries into group progress
	ContractService.Events.Delivered:Connect(function(player)
		ClanService.onContractDelivered(player)
	end)

	Net.event("CLAN_ACT").OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then
			return
		end
		local action = payload.action
		if action == "Create" and typeof(payload.name) == "string" and typeof(payload.tag) == "string" then
			ClanService.create(player, payload.name, payload.tag)
		elseif action == "Join" then
			ClanService.join(player, math.floor(tonumber(payload.id) or -1))
		elseif action == "Leave" then
			ClanService.leave(player)
		elseif action == "Donate" then
			ClanService.donate(player, payload.amount)
		elseif action == "Contract" then
			ClanService.startContract(player)
		elseif action == "AllyOffer" then
			ClanService.allyOffer(player, math.floor(tonumber(payload.id) or -1))
		elseif action == "AllyAccept" then
			ClanService.allyAccept(player, math.floor(tonumber(payload.id) or -1))
		elseif action == "AllyBreak" then
			ClanService.allyBreak(player, math.floor(tonumber(payload.id) or -1))
		elseif action == "Resync" then
			ClanService.sync(player)
		end
	end)
end

return ClanService