-- InfectedService.lua — Phase 2 hostile NPCs: rigs, chase AI, melee combat
-- Zombies are server-built R6-style rigs with a Humanoid (welded assembly,
-- massless limbs, server network ownership). All damage/awards run on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local SurvivalConfig = require(ReplicatedStorage.Shared.Configs.SurvivalConfig)

local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)

local InfectedService = {}
InfectedService.Events = {
	Defeated = Signal.new(), -- (player, zombieModel)
}

local cfg = SurvivalConfig.INFECTED

local folder: Folder? = nil
local alive: { [Model]: Humanoid } = {}
local lastHitBy: { [Model]: Player } = {}
local attackClock: { [Model]: number } = {}

-- forward declaration: defeat() schedules respawns through this hook
local spawnAt

local SKIN = Color3.fromRGB(84, 138, 74)
local CLOTH = Color3.fromRGB(52, 58, 54)
local EYES = Color3.fromRGB(255, 66, 46)

local function newPart(name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true -- only the root carries mass, keeps the walk stable
	return p
end

local function weldTo(root: Part, other: Part)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = other
	w.Parent = other
end

local function buildNameplate(head: Part)
	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.fromOffset(104, 24)
	plate.StudsOffset = Vector3.new(0, 2.3, 0)
	plate.AlwaysOnTop = true
	plate.Adornee = head
	plate.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(30, 12, 12)
	label.TextColor3 = Color3.fromRGB(255, 120, 106)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Text = "INFECTED"
	label.Parent = plate
end

local function spawnRig(homeCF: CFrame): Model?
	if not folder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Infected"

	local hrp = newPart("HumanoidRootPart", Vector3.new(2, 2, 1), homeCF, SKIN)
	hrp.Massless = false
	hrp.Transparency = 1
	hrp.CanCollide = false

	local torso = newPart("Torso", Vector3.new(2, 2, 1), homeCF, CLOTH)
	local head = newPart("Head", Vector3.new(1.2, 1.2, 1.2), homeCF * CFrame.new(0, 1.6, 0), SKIN)
	local eyes = newPart("Eyes", Vector3.new(0.92, 0.18, 0.12), homeCF * CFrame.new(0, 1.72, -0.55), EYES)
	eyes.Material = Enum.Material.Neon
	local la = newPart("Left Arm", Vector3.new(1, 2, 1), homeCF * CFrame.new(-1.5, 0, 0), SKIN)
	local ra = newPart("Right Arm", Vector3.new(1, 2, 1), homeCF * CFrame.new(1.5, 0, 0), SKIN)
	local ll = newPart("Left Leg", Vector3.new(1, 2, 1), homeCF * CFrame.new(-0.5, -2, 0), CLOTH)
	local rl = newPart("Right Leg", Vector3.new(1, 2, 1), homeCF * CFrame.new(0.5, -2, 0), CLOTH)

	for _, p in ipairs({ hrp, torso, head, eyes, la, ra, ll, rl }) do
		p.Parent = model
	end
	weldTo(hrp, torso)
	weldTo(hrp, head)
	weldTo(torso, eyes)
	weldTo(torso, la)
	weldTo(torso, ra)
	weldTo(torso, ll)
	weldTo(torso, rl)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = cfg.HEALTH
	humanoid.Health = cfg.HEALTH
	humanoid.WalkSpeed = cfg.WALK_SPEED
	humanoid.JumpPower = 0
	humanoid.AutoRotate = true
	humanoid.Parent = model

	model.PrimaryPart = hrp
	model.Parent = folder
	buildNameplate(head)

	pcall(function()
		hrp:SetNetworkOwner(nil) -- server drives the walk, no ghost jitter
	end)

	return model
end

local function findNearestCharacter(hrp: Part): (Player?, number)
	local nearest: Player? = nil
	local nearestDist = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local d = (root.Position - hrp.Position).Magnitude
			if d < nearestDist then
				nearest = player
				nearestDist = d
			end
		end
	end
	return nearest, nearestDist
end

local function runAI(model: Model, humanoid: Humanoid, hrp: Part, homePos: Vector3)
	local roamTick = 0
	task.spawn(function()
		while model.Parent and humanoid.Health > 0 do
			task.wait(cfg.TICK)
			local target, dist = findNearestCharacter(hrp)
			if target and target.Character then
				local root = target.Character:FindFirstChild("HumanoidRootPart")
				if not root then
					continue
				end
				if dist <= cfg.ATTACK_RANGE then
					humanoid:MoveTo(hrp.Position) -- plant and strike
					local now = os.clock()
					if now - (attackClock[model] or 0) >= cfg.ATTACK_COOLDOWN then
						attackClock[model] = now
						local phum = target.Character:FindFirstChildOfClass("Humanoid")
						if phum then
							phum:TakeDamage(cfg.DAMAGE)
						end
					end
				elseif dist <= cfg.AGGRO_RADIUS then
					humanoid:MoveTo(root.Position)
				end
			else
				roamTick += 1
				if roamTick >= 10 then
					roamTick = 0
					local angle = math.random() * math.pi * 2
					local radius = 6 + math.random() * cfg.ROAM_RADIUS
					humanoid:MoveTo(homePos + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
				end
			end
		end
	end)
end

local function defeat(model: Model)
	local humanoid = alive[model]
	if not humanoid or humanoid.Health > 0 then
		return
	end
	alive[model] = nil

	local killer = lastHitBy[model]
	lastHitBy[model] = nil
	if killer and killer.Parent then
		EconomyService.award(killer, cfg.CASH_REWARD, cfg.XP_REWARD, "infected_defeated")
		DataService.update(killer, function(d)
			d.Stats.InfectedDefeated = (d.Stats.InfectedDefeated or 0) + 1
			if math.random() < cfg.MEDICAL_DROP_CHANCE then
				d.Inventory.Medical = (d.Inventory.Medical or 0) + 1
				Net.event("TOAST"):FireClient(killer, {
					text = "Scavenged the infected: +1 Medical supply",
					duration = 3,
				})
			end
		end)
		InfectedService.Events.Defeated:Fire(killer, model)
	end

	local homeCF = model.PrimaryPart and model.PrimaryPart.CFrame or CFrame.new()
	task.delay(cfg.DESPAWN_DELAY, function()
		if model.Parent then
			model:Destroy()
		end
	end)
	task.delay(cfg.RESPAWN_DELAY, function()
		spawnAt(homeCF)
	end)
end

spawnAt = function(cf: CFrame)
	local model = spawnRig(cf)
	if not model then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		return
	end
	alive[model] = humanoid
	humanoid.Died:Connect(function()
		defeat(model)
	end)
	runAI(model, humanoid, hrp, cf.Position)
end

-- Public combat API (used by the crowbar tool script)
function InfectedService.findTarget(position: Vector3, maxDist: number): Model?
	local best: Model? = nil
	local bestDist = maxDist
	for zombie in pairs(alive) do
		local root = zombie:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (root.Position - position).Magnitude
			if d < bestDist then
				best = zombie
				bestDist = d
			end
		end
	end
	return best
end

function InfectedService.hurt(zombie: Model, dmg: number, attacker: Player?)
	local humanoid = alive[zombie]
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if attacker then
		lastHitBy[zombie] = attacker
	end
	humanoid:TakeDamage(math.max(0, dmg))
end

function InfectedService.Init()
	task.spawn(function()
		local meridian = workspace:WaitForChild("Meridian", 30)
		if not meridian then
			warn("[InfectedService] Meridian missing — no infected spawned")
			return
		end
		local f = Instance.new("Folder")
		f.Name = "Infected"
		f.Parent = meridian
		folder = f

		local markers = meridian:WaitForChild("InfectedSpawns", 20)
		if not markers then
			warn("[InfectedService] InfectedSpawns markers missing")
			return
		end
		for _, marker in ipairs(markers:GetChildren()) do
			if marker:IsA("BasePart") then
				local cf = marker.CFrame + Vector3.new(0, 3.2, 0)
				spawnAt(cf)
			end
		end
		print(("[InfectedService] staged %d infected from markers"):format(#markers:GetChildren()))
	end)
end

return InfectedService