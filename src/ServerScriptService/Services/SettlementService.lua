--!strict
-- SettlementService.lua — Phase 4: settlement building + production economy.
-- SERVER-AUTHORITATIVE: placement, costs, production math and upgrades live here.
-- Clients only send SETTLEMENT_ACT requests; every check happens in this service.
-- Profiles store plain numbers only (no instance refs) via DataService.save.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local SettlementConfig = require(ReplicatedStorage.Shared.Configs.SettlementConfig)
local DataService = require(ServerScriptService.Services.DataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)

local cfg = SettlementConfig

type Struct = { Type: string, Pad: number, Level: number, Bank: number, LastTick: number }

local SettlementService = {}
SettlementService.Events = {
	StructureBuilt = Signal.new(), -- (player, structureType)
	YieldCollected = Signal.new(), -- (player, structureType, amount)
}

-- runtime-only rig registry: player -> pad -> { model: Model, text: TextLabel, upgrade: ProximityPrompt }
local rigsByPlayer: { [Player]: { [number]: any } } = {}

-- declared before definitions (analyzer: early capture must not bind nil globals)
local structsByPad
local onCollect
local onUpgrade
local setRigText
type Rig = { model: Model, text: TextLabel, upgrade: ProximityPrompt }
local structsByPad: (Player, number, any?) -> (Struct?)

function structsByPad(player: Player, padIndex: number, data: any?)
	local list = (data and data.Settlement) and data.Settlement.Structures or nil
	if not list then
		local d = DataService.get(player)
		if not d or not d.Settlement then
			return nil
		end
		list = d.Settlement.Structures
	end
	for _, s in ipairs(list) do
		if s.Pad == padIndex then
			return s
		end
	end
	return nil
end

-- ------------------------------------------------------------- validation ----
local function trySpend(player: Player, costs: { [string]: number }): boolean
	local ok = false
	DataService.update(player, function(d)
		for item, amount in pairs(costs) do
			if (d.Inventory[item] or 0) < amount then
				return
			end
		end
		for item, amount in pairs(costs) do
			d.Inventory[item] -= amount
		end
		ok = true
	end)
	return ok
end

local function structuresList(player: Player)
	local d = DataService.get(player)
	return d and d.Settlement and d.Settlement.Structures or nil
end

local function padPos(padIndex: number): Vector3
	local pad = WorldLayout.BUILD_PADS[padIndex]
	assert(pad, "bad pad index " .. tostring(padIndex))
	return Vector3.new(pad.x, pad.y, pad.z)
end

-- ------------------------------------------------------------------- rigs ----
local function buildRig(player: Player, padIndex: number, typeName: string): Rig?
	local def = cfg.STRUCTURES[typeName] :: any
	if not def then
		return nil
	end
	local base = padPos(padIndex)

	local model = Instance.new("Model")
	model.Name = ("Structure_Pad%d"):format(padIndex)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.Size = Vector3.new(def.Radius * 2, def.Height, def.Radius * 2)
	body.CFrame = CFrame.new(base + Vector3.new(0, def.Height / 2 + 0.3, 0)) * CFrame.Angles(0, 0.6, 0)
	body.Color = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
	body.Material = Enum.Material.Metal
	body.Parent = model
	model.PrimaryPart = body

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 26)
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body
	local text = Instance.new("TextLabel")
	text.Name = "Info"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 15
	text.TextStrokeTransparency = 0.4
	text.TextColor3 = Color3.fromRGB(255, 232, 180)
	text.Parent = gui

	if def.Produces then
		local collect = Instance.new("ProximityPrompt")
		collect.ActionText = "Collect Yield"
		collect.ObjectText = def.Name
		collect.KeyboardKeyCode = Enum.KeyCode.E
		collect.HoldDuration = 0.1
		collect.RequiresLineOfSight = false
		collect.MaxActivationDistance = 9
		collect.Parent = body
		collect.Triggered:Connect(function(who)
			if who == player then
				onCollect(player, padIndex)
			end
		end)
	end

	local upgrade = Instance.new("ProximityPrompt")
	upgrade.Name = "UpgradePrompt"
	upgrade.ActionText = "Upgrade"
	upgrade.ObjectText = def.Name
	upgrade.KeyboardKeyCode = Enum.KeyCode.F
	upgrade.HoldDuration = 0.1
	upgrade.RequiresLineOfSight = false
	upgrade.MaxActivationDistance = 9
	upgrade.Parent = body
	upgrade.Triggered:Connect(function(who)
		if who == player then
			onUpgrade(player, padIndex)
		end
	end)

	return { model = model, text = text, upgrade = upgrade }
end

function setRigText(player: Player, padIndex: number, struct)
	local rig = rigsByPlayer[player] and rigsByPlayer[player][padIndex]
	if not rig then
		return
	end
	local def = cfg.STRUCTURES[struct.Type]
	local ready = ""
	if def.Produces and struct.Bank >= 1 then
		local unit = def.Produces.kind == "Cash" and "cash" or def.Produces.item
		ready = ("  —  %d %s ready"):format(math.floor(struct.Bank), unit)
	end
	rig.text.Text = ("%s Lv%d%s"):format(def.Name, struct.Level, ready)
	if rig.upgrade and def then
		rig.upgrade.Enabled = struct.Level < cfg.MAX_LEVEL
		rig.upgrade.ActionText = struct.Level < cfg.MAX_LEVEL and ("Upgrade → Lv%d"):format(struct.Level + 1) or "Maxed"
	end
end

-- ---------------------------------------------------------------- actions ----
function SettlementService.buildStructure(player: Player, padIndex: number, typeName: string)
	local def = cfg.STRUCTURES[typeName]
	if not def then
		return false
	end
	local list = structuresList(player)
	if not list then
		return false
	end
	if not WorldLayout.BUILD_PADS[padIndex] then
		return false
	end
	if #list >= cfg.BUILD_PADS then
		return false
	end
	if structsByPad(player, padIndex) then
		Net.event("TOAST"):FireClient(player, "That pad is occupied")
		return false
	end
	if not trySpend(player, def.Cost) then
		Net.event("TOAST"):FireClient(player, "Not enough materials for " .. def.Name)
		return false
	end
	rigsByPlayer[player] = rigsByPlayer[player] or {}

	local struct = { Type = typeName, Pad = padIndex, Level = 1, Bank = 0, LastTick = os.clock() }
	table.insert(list, struct)
	DataService.update(player, function(d)
		d.Stats.StructuresBuilt = (d.Stats.StructuresBuilt or 0) + 1
	end)
	local rig = buildRig(player, padIndex, typeName)
	if rig then
		rig.model.Parent = workspace
		rigsByPlayer[player][padIndex] = rig
		setRigText(player, padIndex, struct)
		EconomyService.award(player, 0, cfg.BUILD_XP, "settlement_build")
		SettlementService.Events.StructureBuilt:Fire(player, typeName)
	else
		DataService.update(player, function(d)
			for item, amount in pairs(def.Cost) do
				d.Inventory[item] += amount
			end
		end)
		return false
	end
	SettlementService.sync(player)
	return true
end

onCollect = function(player: Player, padIndex: number)
	local struct = structsByPad(player, padIndex)
	if not struct then
		return
	end
	local def = cfg.STRUCTURES[struct.Type]
	if not def.Produces then
		return
	end
	local whole = math.floor(struct.Bank)
	if whole < 1 then
		return
	end
	local amount = def.Produces.amount * whole
	DataService.update(player, function(d)
		if def.Produces.kind == "Cash" then
			d.Cash += amount
		else
			d.Inventory[def.Produces.item] = (d.Inventory[def.Produces.item] or 0) + amount
		end
		d.Stats.Collected = (d.Stats.Collected or 0) + 1
		local s = structsByPad(player, padIndex, d)
		if s then
			s.Bank -= whole
			s.LastTick = os.clock()
		end
	end)
	local gain = def.Produces.kind == "Cash" and ("$%d collected"):format(amount) or ("+%d %s"):format(amount, def.Produces.item)
	Net.event("TOAST"):FireClient(player, gain)
	local updated = structsByPad(player, padIndex)
	if updated then
		setRigText(player, padIndex, updated)
	end
	SettlementService.Events.YieldCollected:Fire(player, struct.Type, amount)
	SettlementService.sync(player)
end

onUpgrade = function(player: Player, padIndex: number)
	local struct = structsByPad(player, padIndex)
	if not struct then
		return
	end
	if struct.Level >= cfg.MAX_LEVEL then
		Net.event("TOAST"):FireClient(player, "Already max level")
		return
	end
	local def = cfg.STRUCTURES[struct.Type]
	local mult = cfg.UPGRADE_MULT[struct.Level + 1]
	local costs: { [string]: number } = {}
	for item, amount in pairs(def.Cost) do
		costs[item] = math.floor(amount * mult)
	end
	if not trySpend(player, costs) then
		Net.event("TOAST"):FireClient(player, "Not enough materials to upgrade")
		return
	end
	DataService.update(player, function(d)
		local s = structsByPad(player, padIndex, d)
		if s then
			s.Level += 1
		end
	end)
	local updated = structsByPad(player, padIndex)
	if updated then
		setRigText(player, padIndex, updated)
	end
	EconomyService.award(player, 0, cfg.UPGRADE_XP, "settlement_upgrade")
	SettlementService.sync(player)
end

function SettlementService.demolish(player: Player, padIndex: number)
	local def = cfg.STRUCTURES[structsByPad(player, padIndex) and structsByPad(player, padIndex).Type or ""]
	if not def then
		return false
	end
	DataService.update(player, function(d)
		for item, amount in pairs(def.Cost) do
			d.Inventory[item] += math.floor(amount * cfg.REFUND_RATE)
		end
		local list = d.Settlement.Structures
		for i = #list, 1, -1 do
			if list[i].Pad == padIndex then
				table.remove(list, i)
			end
		end
	end)
	local rigs = rigsByPlayer[player]
	if rigs and rigs[padIndex] then
		rigs[padIndex].model:Destroy()
		rigs[padIndex] = nil
	end
	SettlementService.sync(player)
	return true
end

-- ------------------------------------------------------------- production ----
local function accrue(player: Player)
	DataService.update(player, function(d)
		local now = os.clock()
		local storageBonus = 0
		for _, s in ipairs(d.Settlement.Structures) do
			if s.Type == "STORAGE" then
				storageBonus += 1
			end
		end
		for _, s in ipairs(d.Settlement.Structures) do
			local def = cfg.STRUCTURES[s.Type]
			if def and def.Produces and def.Interval > 0 then
				local elapsed = now - (s.LastTick or now)
				s.LastTick = now
				local cap = def.Interval * (cfg.CAP_MULT + storageBonus)
				s.Bank = math.min(s.Bank + def.Produces.amount * (elapsed / def.Interval) * cfg.LEVEL_MULT[s.Level], cap)
			end
		end
	end)
end

function SettlementService.sync(player: Player)
	local list = structuresList(player)
	if not list then
		return
	end
	Net.event("SETTLEMENT_SYNC"):FireClient(player, { Structures = list })
end

local function rebuildFor(player: Player)
	rigsByPlayer[player] = rigsByPlayer[player] or {}
	accrue(player)
	local list = structuresList(player)
	if not list then
		return
	end
	for _, s in ipairs(list) do
		if not rigsByPlayer[player][s.Pad] then
			local rig = buildRig(player, s.Pad, s.Type)
			if rig then
				rig.model.Parent = workspace
				rigsByPlayer[player][s.Pad] = rig
			end
		end
		setRigText(player, s.Pad, s)
	end
end

function SettlementService.Init()
	-- settlement board prompt (world part built by build_place.py)
	task.spawn(function()
		local meridian = workspace:WaitForChild("Meridian", 20)
		local board = meridian and meridian:WaitForChild("SettlementBoard", 20)
		if board then
			local part = board:FindFirstChild("Board", true) or board:FindFirstChildOfClass("Part")
			if part then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Open Settlement"
				prompt.ObjectText = "Settlement Board"
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.HoldDuration = 0.1
				prompt.RequiresLineOfSight = false
				prompt.MaxActivationDistance = 10
				prompt.Parent = part
				prompt.Triggered:Connect(function(player)
					local list = structuresList(player)
					Net.event("SETTLEMENT_SYNC"):FireClient(player, { Open = true, Structures = list })
				end)
			end
		end
	end)

	-- rebuild rigs + catch-up accrual whenever any profile finishes loading
	DataService.Events.ProfileLoaded:Connect(function(player, data)
		if data.Settlement then
			rebuildFor(player)
			SettlementService.sync(player)
		end
	end)
	-- players who loaded BEFORE SettlementService.Init ran (fast joins / server boot)
	for _, player in ipairs(Players:GetPlayers()) do
		if DataService.get(player) then
			rebuildFor(player)
			SettlementService.sync(player)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		local rigs = rigsByPlayer[player]
		if rigs then
			for _, rig in pairs(rigs) do
				rig.model:Destroy()
			end
			rigsByPlayer[player] = nil
		end
	end)

	-- production heartbeat: accrue into banks + refresh billboard text
	task.spawn(function()
		while true do
			task.wait(10)
			for _, player in ipairs(Players:GetPlayers()) do
				if structuresList(player) then
					accrue(player)
					local list = structuresList(player)
					if list then
						for _, s in ipairs(list) do
							setRigText(player, s.Pad, s)
						end
					end
				end
			end
		end
	end)

	Net.event("SETTLEMENT_ACT").OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then
			return
		end
		local pad = math.floor(tonumber(payload.pad) or -1)
		if pad < 1 then
			return
		end
		if payload.action == "Build" and typeof(payload.type) == "string" then
			SettlementService.buildStructure(player, pad, payload.type)
		elseif payload.action == "Collect" then
			onCollect(player, pad)
		elseif payload.action == "Upgrade" then
			onUpgrade(player, pad)
		elseif payload.action == "Demolish" then
			SettlementService.demolish(player, pad)
		end
	end)
end

return SettlementService