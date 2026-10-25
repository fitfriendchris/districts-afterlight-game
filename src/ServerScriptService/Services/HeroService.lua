-- HeroService.lua — Phase 3: hero roster, star evolution, gear, deployed ally squads
-- Server-authoritative: recruit/evolve/gear costs validated here; clients only ask.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local HeroConfig = require(ReplicatedStorage.Shared.Configs.HeroConfig)
local HeroDefinitions = require(ReplicatedStorage.Shared.Definitions.HeroDefinitions)

local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)
local InfectedService = require(script.Parent.InfectedService)

local HeroService = {}
HeroService.Events = {
	Recruited = Signal.new(), -- (player, heroId)
	Evolved = Signal.new(),   -- (player, heroId, newStar)
}

local cfg = HeroConfig
local alliesByPlayer: { [Player]: { Model } } = {}

-- ---------------------------------------------------------------- helpers ----
local function canPayMaterials(player: Player, costs: { [string]: number }): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	for mat, amount in pairs(costs) do
		if (data.Inventory[mat] or 0) < amount then
			return false
		end
	end
	return true
end

local function payMaterials(player: Player, costs: { [string]: number })
	DataService.update(player, function(d)
		for mat, amount in pairs(costs) do
			d.Inventory[mat] = math.max(0, (d.Inventory[mat] or 0) - amount)
		end
	end)
end

local function materialShortage(costs: { [string]: number }): string
	local parts = {}
	for mat, amount in pairs(costs) do
		table.insert(parts, ("+%d %s"):format(amount, mat))
	end
	return table.concat(parts, ", ")
end

local function squadOf(player: Player): { string }
	local data = DataService.get(player)
	return (data and data.Heroes and data.Heroes.Active) or {}
end

local function heroMultiplier(entry, key: string): number
	-- combines star scaling + gear + specialization for one stat axis
	local mult = 1.0
	if key == "damage" then
		mult += (entry.Star - 1) * 0.35
		if entry.Weapon then
			mult += cfg.GEAR.WEAPON.DAMAGE_MULT
		end
		local spec = cfg.SPECIALIZATIONS[entry.Spec or ""]
		if spec and spec.DAMAGE_MULT then
			mult += spec.DAMAGE_MULT
		end
	else -- health
		mult += (entry.Star - 1) * 0.25
		if entry.Armor then
			mult += cfg.GEAR.ARMOR.HEALTH_MULT
		end
		local spec = cfg.SPECIALIZATIONS[entry.Spec or ""]
		if spec and spec.HEALTH_MULT then
			mult += spec.HEALTH_MULT
		end
	end
	return mult
end

function HeroService.medicalDropBonus(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local bonus = 0
	for _, id in ipairs(squadOf(player)) do
		local entry = data.Heroes.Roster[id]
		local spec = entry and cfg.SPECIALIZATIONS[entry.Spec or ""]
		if spec and spec.MEDICAL_BONUS then
			bonus += spec.MEDICAL_BONUS
		end
	end
	return math.min(bonus, 0.6)
end

-- ---------------------------------------------------------------- ally rig ----
local ALLY_SKIN = Color3.fromRGB(96, 148, 210)
local ALLY_CLOTH = Color3.fromRGB(38, 52, 78)

local function newPart(name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	return p
end

local function buildAllyRig(spawnCF: CFrame, heroDef, star: number, health: number): (Model?, Humanoid?)
	local model = Instance.new("Model")
	model.Name = "Ally_" .. heroDef.id

	local hrp = newPart("HumanoidRootPart", Vector3.new(2, 2, 1), spawnCF, ALLY_SKIN)
	hrp.Massless = false
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.Parent = model

	local torso = newPart("Torso", Vector3.new(2, 2, 1), spawnCF, ALLY_CLOTH)
	local head = newPart("Head", Vector3.new(1.2, 1.2, 1.2), spawnCF * CFrame.new(0, 1.6, 0), ALLY_SKIN)
	local la = newPart("Left Arm", Vector3.new(1, 2, 1), spawnCF * CFrame.new(-1.5, 0, 0), ALLY_SKIN)
	local ra = newPart("Right Arm", Vector3.new(1, 2, 1), spawnCF * CFrame.new(1.5, 0, 0), ALLY_SKIN)
	local ll = newPart("Left Leg", Vector3.new(1, 2, 1), spawnCF * CFrame.new(-0.5, -2, 0), ALLY_CLOTH)
	local rl = newPart("Right Leg", Vector3.new(1, 2, 1), spawnCF * CFrame.new(0.5, -2, 0), ALLY_CLOTH)
	for _, p in ipairs({ torso, head, la, ra, ll, rl }) do
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = p
		w.Parent = p
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = cfg.ALLY.WALK_SPEED
	humanoid.JumpPower = 0
	humanoid.Parent = model

	model.PrimaryPart = hrp
	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.fromOffset(150, 22)
	plate.StudsOffset = Vector3.new(0, 2.2, 0)
	plate.AlwaysOnTop = true
	plate.Adornee = head
	plate.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.4
	label.BackgroundColor3 = Color3.fromRGB(12, 20, 34)
	label.TextColor3 = Color3.fromRGB(150, 200, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.Text = ("%s %s"):format(heroDef.name, string.rep("★", star))
	label.Parent = plate

	pcall(function()
		hrp:SetNetworkOwner(nil)
	end)
	return model, humanoid
end

-- ---------------------------------------------------------------- ally AI ----
local function runAllyAI(player: Player, model: Model, humanoid: Humanoid, heroDef, damage: number, index: number)
	task.spawn(function()
		while model.Parent and humanoid.Health > 0 and player.Parent do
			task.wait(cfg.ALLY.TICK)
			local char = player.Character
			local proot = char and char:FindFirstChild("HumanoidRootPart")
			if not proot then
				continue
			end

			-- engage nearest registered hostile within range of the ally
			local target = nil
			local bestDist = cfg.ALLY.ATTACK_RANGE
			for _, zombie in ipairs(InfectedService.listHostiles()) do
				local zroot = zombie:FindFirstChild("HumanoidRootPart")
				if zroot then
					local d = (zroot.Position - model.PrimaryPart.Position).Magnitude
					if d < bestDist then
						target = zroot
						bestDist = d
					end
				end
			end

			if target then
				local zhum = target.Parent and target.Parent:FindFirstChildOfClass("Humanoid")
				if zhum and zhum.Health > 0 then
					humanoid:MoveTo(target.Position)
					local now = os.clock()
					if bestDist <= 4.5 and now - (model:GetAttribute("lastHit") or 0) >= cfg.ALLY.ATTACK_COOLDOWN then
						model:SetAttribute("lastHit", now)
						InfectedService.hurt(target.Parent, damage, player)
					end
				end
			else
				local offset = Vector3.new((index - 1) * cfg.ALLY.FOLLOW_OFFSET * 2 - 2, 0, cfg.ALLY.FOLLOW_OFFSET)
				humanoid:MoveTo(proot.Position + proot.CFrame.LookVector * -cfg.ALLY.FOLLOW_OFFSET + offset)
			end
		end
	end)
end

local function deployAlly(player: Player, heroId: string, index: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	local entry = data.Heroes.Roster[heroId]
	local heroDef = HeroDefinitions.byId(heroId)
	if not entry or not heroDef then
		return
	end
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local health = cfg.ALLY.BASE_HEALTH * heroMultiplier(entry, "health")
	local damage = cfg.ALLY.BASE_DAMAGE * heroMultiplier(entry, "damage")
	local spawnCF = player.Character.HumanoidRootPart.CFrame
		* CFrame.new(cfg.ALLY.FOLLOW_OFFSET * (index % 2 == 0 and 1.4 or -1.4), 0, 2.2)
	local model, humanoid = buildAllyRig(spawnCF, heroDef, entry.Star, health)
	if not model or not humanoid then
		return
	end
	local meridian = workspace:FindFirstChild("Meridian")
	if not meridian then
		model:Destroy()
		return
	end
	model.Parent = meridian:WaitForChild("Infected") -- reuses the hostile registry folder
	InfectedService.registerAlly(model, humanoid, player)

	humanoid.Died:Connect(function()
		InfectedService.unregisterAlly(model)
		local list = alliesByPlayer[player]
		if list then
			for i, m in ipairs(list) do
				if m == model then
					table.remove(list, i)
					break
				end
			end
		end
		Net.event("TOAST"):FireClient(player, {
			text = ("%s fell in defense — redeploy them from the Heroes Hall"):format(heroDef.name),
			duration = 5,
		})
		task.delay(2.5, function()
			model:Destroy()
		end)
	end)

	alliesByPlayer[player] = alliesByPlayer[player] or {}
	table.insert(alliesByPlayer[player], model)
	runAllyAI(player, model, humanoid, heroDef, damage, #alliesByPlayer[player])
end

local function clearAllies(player: Player)
	local list = alliesByPlayer[player]
	if not list then
		return
	end
	for _, model in ipairs(list) do
		InfectedService.unregisterAlly(model)
		if model.Parent then
			model:Destroy()
		end
	end
	alliesByPlayer[player] = nil
end

local function redeploySquad(player: Player)
	clearAllies(player)
	task.wait(1.2)
	local active = squadOf(player)
	for i, heroId in ipairs(active) do
		if i <= cfg.SQUAD_SIZE then
			deployAlly(player, heroId, i)
		end
	end
end

-- ---------------------------------------------------------------- actions ----
local function onHeroAct(player: Player, payload)
	local action = payload and payload.action
	local data = DataService.get(player)
	if not data then
		return
	end

	if action == "Recruit" then
		local heroDef = HeroDefinitions.byId(payload.id or "")
		if not heroDef or data.Heroes.Roster[heroDef.id] then
			return
		end
		local cash = cfg.RECRUIT_CASH[heroDef.rarity] or 999999
		local mats = cfg.RECRUIT_MATERIALS[heroDef.rarity] or { Scrap = 99 }
		if (data.Cash or 0) < cash then
			Net.event("TOAST"):FireClient(player, { text = ("Not enough cash ($%d needed)"):format(cash), duration = 3 })
			return
		end
		if not canPayMaterials(player, mats) then
			Net.event("TOAST"):FireClient(player, { text = ("Missing materials: %s — scavenge for them"):format(materialShortage(mats)), duration = 4 })
			return
		end
		EconomyService.spend(player, cash, "hero_recruit")
		payMaterials(player, mats)
		DataService.update(player, function(d)
			d.Heroes.Roster[heroDef.id] = { Star = 1, Spec = "", Weapon = false, Armor = false }
		end)
		EconomyService.award(player, 0, cfg.XP_RECRUIT, "hero_recruit")
		HeroService.Events.Recruited:Fire(player, heroDef.id)
		Net.event("TOAST"):FireClient(player, {
			text = ("%s joined your cause!"):format(heroDef.name),
			duration = 4,
		})

	elseif action == "StarUp" then
		local id = payload.id or ""
		local entry = data.Heroes.Roster[id]
		if not entry then
			return
		end
		if entry.Star >= cfg.MAX_STAR then
			return
		end
		local medCost = cfg.STAR_MEDICAL[entry.Star] or 99
		local cashCost = cfg.STAR_CASH[entry.Star] or 999999
		if (data.Inventory.Medical or 0) < medCost then
			Net.event("TOAST"):FireClient(player, { text = ("Evolution needs %d medical supplies"):format(medCost), duration = 3 })
			return
		end
		if (data.Cash or 0) < cashCost then
			Net.event("TOAST"):FireClient(player, { text = ("Evolution needs $%d"):format(cashCost), duration = 3 })
			return
		end
		DataService.update(player, function(d)
			local e = d.Heroes.Roster[id]
			e.Star = e.Star + 1
			d.Inventory.Medical = math.max(0, (d.Inventory.Medical or 0) - medCost)
		end)
		EconomyService.spend(player, cashCost, "hero_star")
		EconomyService.award(player, 0, cfg.XP_EVOLVE, "hero_star")
		local newStar = data.Heroes.Roster[id].Star -- profile is live: already incremented above
		HeroService.Events.Evolved:Fire(player, id, newStar)
		Net.event("TOAST"):FireClient(player, {
			text = ("%s evolved to %s"):format(HeroDefinitions.byId(id).name, string.rep("★", newStar)),
			duration = 4,
		})
		-- redeploy if active so rig stats refresh
		if table.find(squadOf(player), id) then
			task.spawn(redeploySquad, player)
		end

	elseif action == "Gear" then
		local id = payload.id or ""
		local slot = payload.slot or ""
		local entry = data.Heroes.Roster[id]
		if not entry or (slot ~= "Weapon" and slot ~= "Armor") then
			return
		end
		if entry[slot] then
			return
		end
		local costs = slot == "Weapon"
			and { Scrap = cfg.GEAR.WEAPON.COST_SCRAP }
			or { Scrap = cfg.GEAR.ARMOR.COST_SCRAP, Fabric = cfg.GEAR.ARMOR.COST_FABRIC }
		if not canPayMaterials(player, costs) then
			Net.event("TOAST"):FireClient(player, { text = ("Missing materials: %s"):format(materialShortage(costs)), duration = 4 })
			return
		end
		payMaterials(player, costs)
		DataService.update(player, function(d)
			d.Heroes.Roster[id][slot] = true
		end)
		Net.event("TOAST"):FireClient(player, {
			text = ("%s geared up (%s)"):format(HeroDefinitions.byId(id).name, slot),
			duration = 3,
		})
		if table.find(squadOf(player), id) then
			task.spawn(redeploySquad, player)
		end

	elseif action == "SetSpec" then
		local id = payload.id or ""
		local spec = payload.spec or ""
		local entry = data.Heroes.Roster[id]
		if not entry or (spec ~= "" and not cfg.SPECIALIZATIONS[spec]) then
			return
		end
		if spec ~= "" and entry.Star < cfg.SPECIALIZATION_UNLOCK_STAR then
			Net.event("TOAST"):FireClient(player, { text = "Specializations unlock at ★2", duration = 3 })
			return
		end
		DataService.update(player, function(d)
			d.Heroes.Roster[id].Spec = spec
		end)
		Net.event("TOAST"):FireClient(player, {
			text = spec == "" and ("Specialization cleared") or ("%s path locked in"):format(spec),
			duration = 3,
		})
		if table.find(squadOf(player), id) then
			task.spawn(redeploySquad, player)
		end

	elseif action == "Deploy" then
		local id = payload.id or ""
		local entry = data.Heroes.Roster[id]
		if not entry then
			return
		end
		DataService.update(player, function(d)
			local active = d.Heroes.Active
			local at = table.find(active, id)
			if payload.on and not at then
				if #active >= cfg.SQUAD_SIZE then
					return
				end
				table.insert(active, id)
			elseif not payload.on and at then
				table.remove(active, at)
			end
		end)
		task.spawn(redeploySquad, player)
		Net.event("TOAST"):FireClient(player, { text = payload.on and "Hero deployed — they fight beside you" or "Hero recalled to the hall", duration = 3 })
	end

	DataService.markDirty(player)
	DataService.sync(player)
end

-- ----------------------------------------------------------------- kiosk ----
local function setupKiosk()
	task.spawn(function()
		local meridian = workspace:WaitForChild("Meridian", 30)
		local kiosk = meridian and meridian:WaitForChild("HeroKiosk", 20)
		if not kiosk or not kiosk:IsA("BasePart") then
			warn("[HeroService] HeroKiosk missing")
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open Heroes Hall"
		prompt.ObjectText = "Heroes Hall"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = kiosk
		prompt.Triggered:Connect(function(player)
			local data = DataService.get(player)
			Net.event("HERO_SYNC"):FireClient(player, { Open = true, Heroes = data and data.Heroes or nil })
		end)
	end)
end

function HeroService.Init()
	InfectedService.MedicalDropBonus = HeroService.medicalDropBonus
	Net.event("HERO_ACT").OnServerEvent:Connect(onHeroAct)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.delay(1.5, function()
				redeploySquad(player)
			end)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		clearAllies(player)
		alliesByPlayer[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.delay(2, function()
			redeploySquad(player)
		end)
	end

	setupKiosk()
	print("[HeroService] heroes hall online")
end

return HeroService