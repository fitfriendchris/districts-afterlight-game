-- SurvivalService.lua — Phase 2: scavenge nodes, safehouse barricade, crowbar grant
-- All material math and gating runs on the server; clients only trigger prompts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local SurvivalConfig = require(ReplicatedStorage.Shared.Configs.SurvivalConfig)

local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)

local SurvivalService = {}
SurvivalService.Events = {
	Scavenged = Signal.new(), -- (player)
	Fortified = Signal.new(), -- (player)
}

local scavengeBusy: { [BasePart]: boolean } = {}
local fortifyGuard: { [Player]: boolean } = {}

-- Crowbar: a code-built Tool; the swing Script runs server-side inside the tool.
local CROWBAR_LUAU = [[
local tool = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InfectedService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("InfectedService"))
local SurvivalConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("SurvivalConfig"))

local cfg = SurvivalConfig.CROWBAR
local last = 0

tool.Activated:Connect(function()
	if os.clock() - last < cfg.COOLDOWN then
		return
	end
	last = os.clock()
	local character = tool.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local target = InfectedService.findTarget(root.Position, cfg.RANGE)
	if not target then
		return
	end
	local zroot = target:FindFirstChild("HumanoidRootPart")
	if not zroot then
		return
	end
	local dir = (zroot.Position - root.Position)
	if dir.Magnitude < 0.1 then
		return
	end
	if root.CFrame.LookVector:Dot(dir.Unit) < cfg.FACE_DOT then
		return
	end
	InfectedService.hurt(target, cfg.DAMAGE, Players:GetPlayerFromCharacter(character))
end)
]]

local crowbarTemplate: Tool? = nil

local function buildCrowbarTemplate(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Crowbar"
	tool.ToolTip = "Swing at the infected (click while equipped)"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, 0, 0.8)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.35, 2.4)
	handle.Color = Color3.fromRGB(178, 44, 44)
	handle.Material = Enum.Material.Metal
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	local swingScript = Instance.new("Script")
	swingScript.Name = "CrowbarSwing"
	swingScript.Source = CROWBAR_LUAU
	swingScript.Parent = tool

	return tool
end

local function grantCrowbar(character: Model)
	local template = crowbarTemplate
	if not template then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end
	if backpack:FindFirstChild("Crowbar") or character:FindFirstChild("Crowbar") then
		return
	end
	template:Clone().Parent = backpack
end

-- Scavenge -------------------------------------------------------------------
local function doScavenge(player: Player, pile: BasePart)
	local cfgS = SurvivalConfig.SCAVENGE
	if scavengeBusy[pile] then
		return
	end
	scavengeBusy[pile] = true

	local data = DataService.get(player)
	if not data then
		scavengeBusy[pile] = nil
		return
	end

	local count = math.random(cfgS.MATERIALS_MIN, cfgS.MATERIALS_MAX)
	local scrap = 0
	local fabric = 0
	for _ = 1, count do
		if math.random() < 0.65 then
			scrap += 1
		else
			fabric += 1
		end
	end

	DataService.update(player, function(d)
		d.Inventory.Scrap = (d.Inventory.Scrap or 0) + scrap
		d.Inventory.Fabric = (d.Inventory.Fabric or 0) + fabric
		d.Stats.Scavenges = (d.Stats.Scavenges or 0) + 1
	end)
	EconomyService.award(player, 0, cfgS.XP_REWARD, "scavenge")
	Net.event("TOAST"):FireClient(player, {
		text = ("Scavenged debris: +%d scrap, +%d fabric"):format(scrap, fabric),
		duration = 3,
	})
	SurvivalService.Events.Scavenged:Fire(player)

	task.delay(cfgS.COOLDOWN, function()
		scavengeBusy[pile] = nil
	end)
end

-- Barricade ------------------------------------------------------------------
local function buildBoards(anchor: BasePart)
	local cf = anchor.CFrame
	local offsets = { { -1.1, -0.06, 0.05 }, { 0.05, 0.1, -0.07 }, { 1.2, -0.09, 0.04 } }
	for i, offset in ipairs(offsets) do
		local board = Instance.new("Part")
		board.Name = "Board" .. i
		board.Size = Vector3.new(5.6, 0.4, 0.3)
		board.CFrame = cf * CFrame.new(0, offset[1], offset[2]) * CFrame.Angles(0, 0, offset[3])
		board.Color = Color3.fromRGB(126, 92, 58)
		board.Material = Enum.Material.WoodPlanks
		board.Anchored = true
		board.Parent = anchor.Parent
	end
end

local function setupBarricade(anchor: BasePart)
	local cfgF = SurvivalConfig.FORTIFY
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Barricade"
	prompt.ObjectText = "Apartment 3B Entrance"
	prompt.HoldDuration = 1.0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		local data = DataService.get(player)
		if not data then
			return
		end
		if fortifyGuard[player] then
			return
		end
		fortifyGuard[player] = true
		task.delay(0.5, function()
			fortifyGuard[player] = nil
		end)

		if table.find(data.Campaign.Flags or {}, "safehouse_fortified") then
			Net.event("TOAST"):FireClient(player, {
				text = "Your safehouse is already barricaded",
				duration = 3,
			})
			return
		end
		if (data.Inventory.Scrap or 0) < cfgF.SCRAP_COST then
			Net.event("TOAST"):FireClient(player, {
				text = ("Barricading needs %d scrap — scavenge the north rubble first"):format(cfgF.SCRAP_COST),
				duration = 4,
			})
			return
		end

		DataService.update(player, function(d)
			d.Inventory.Scrap = (d.Inventory.Scrap or 0) - cfgF.SCRAP_COST
			d.Stats.Fortified = (d.Stats.Fortified or 0) + 1
			table.insert(d.Campaign.Flags, "safehouse_fortified")
		end)
		EconomyService.award(player, 0, cfgF.XP_REWARD, "fortify")
		buildBoards(anchor)
		Net.event("TOAST"):FireClient(player, {
			text = "Safehouse barricaded — the door holds",
			duration = 4,
		})
		SurvivalService.Events.Fortified:Fire(player)
	end)
end

function SurvivalService.Init()
	crowbarTemplate = buildCrowbarTemplate()

	-- crowbar: every spawn (tools vanish with the character, so re-grant freely)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.6)
			grantCrowbar(character)
		end)
		local current = player.Character
		if current then
			grantCrowbar(current)
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(character)
			task.wait(0.6)
			grantCrowbar(character)
		end)
		local current = player.Character
		if current then
			grantCrowbar(current)
		end
	end

	task.spawn(function()
		local meridian = workspace:WaitForChild("Meridian", 30)
		if not meridian then
			warn("[SurvivalService] Meridian missing — no survival nodes")
			return
		end

		local rubble = meridian:WaitForChild("Rubble", 20)
		if rubble then
			for _, node in ipairs(rubble:GetChildren()) do
				local target: BasePart? = nil
				if node:IsA("BasePart") then
					target = node
				elseif node:IsA("Model") then
					target = node:FindFirstChildWhichIsA("BasePart")
				end
				if not target then
					continue
				end
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Scavenge"
				prompt.ObjectText = "Rubble Pile"
				prompt.HoldDuration = 0.6
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt.Parent = target
				prompt.Triggered:Connect(function(player)
					doScavenge(player, target)
				end)
			end
		end

		local safehouse = meridian:WaitForChild("Safehouse", 20)
		local anchor = safehouse and safehouse:WaitForChild("BarricadeAnchor", 10)
		if anchor and anchor:IsA("BasePart") then
			setupBarricade(anchor)
		else
			warn("[SurvivalService] Safehouse barricade anchor missing")
		end
	end)
end

return SurvivalService