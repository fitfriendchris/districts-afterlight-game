-- ContractService.lua — "Curbside Delivery": the first job loop (Phase 1)
-- Blueprint tasks 7 + 14: repeatable contract, valid positions server-side.
-- Flow: Take Contract (job board) -> Pick Up Package (depot) -> Deliver (address).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local EconomyConfig = require(ReplicatedStorage.Shared.Configs.EconomyConfig)
local MissionDefinitions = require(ReplicatedStorage.Shared.Definitions.MissionDefinitions)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local ContractService = {}
ContractService.Events = {
	Accepted = Signal.new(), -- (player, targetIndex)
	Delivered = Signal.new(), -- (player)
}

local function rootPos(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function distanceTo(player: Player, point: Vector3): number
	local pos = rootPos(player)
	if not pos then
		return math.huge
	end
	return (pos - point).Magnitude
end

local function targetVector(index: number): Vector3
	local t = WorldLayout.DELIVERY_TARGETS[index]
	return Vector3.new(t.x, t.y, t.z)
end

local function respond(player: Player, payload)
	Net.fireTo(player, "CONTRACT_ACT", payload)
end

function ContractService.initVans() end

function ContractService.Init()
	local meridian = nil
	task.spawn(function()
		meridian = workspace:WaitForChild("Meridian", 30)
		local plaza = meridian:WaitForChild("Plaza", 30)
		local board = plaza:WaitForChild("JobBoard", 30)
		local depot = plaza:WaitForChild("PackageDepot", 30)

		local boardPrompt = Instance.new("ProximityPrompt")
		boardPrompt.ActionText = "Take Contract"
		boardPrompt.ObjectText = "Meridian Courier Co."
		boardPrompt.HoldDuration = 0.3
		boardPrompt.RequiresLineOfSight = false
		boardPrompt.Parent = board
		boardPrompt.Triggered:Connect(function(player)
			local data = DataService.get(player)
			local cfg = EconomyConfig.CONTRACT
			if data.Contract.Active then
				respond(player, { action = "Info", text = "Finish your current delivery first." })
				return
			end
			if (os.clock() - (data.Stats.LastContractAt or 0)) < cfg.COOLDOWN then
				respond(player, { action = "Info", text = "Wait a moment for the next dispatch." })
				return
			end
			local target = math.random(1, cfg.MAX_ACTIVE_TARGETS)
			DataService.update(player, function(d)
				d.Contract.Active = { Target = target, HasPackage = false, AcceptedAt = os.clock() }
				d.Stats.LastContractAt = os.clock()
			end)
			ContractService.Events.Accepted:Fire(player, target)
			respond(player, {
				action = "Accepted",
				target = target,
				address = MissionDefinitions.DELIVERY_ADDRESSES[target],
			})
		end)

		local depotPrompt = Instance.new("ProximityPrompt")
		depotPrompt.ActionText = "Pick Up Package"
		depotPrompt.ObjectText = "Courier Depot"
		depotPrompt.HoldDuration = 0.3
		depotPrompt.RequiresLineOfSight = false
		depotPrompt.Parent = depot
		depotPrompt.Triggered:Connect(function(player)
			local data = DataService.get(player)
			local active = data.Contract.Active
			if not active then
				respond(player, { action = "Info", text = "Take a contract from the job board first." })
				return
			end
			if active.HasPackage then
				respond(player, { action = "Info", text = "You're already carrying the package." })
				return
			end
			DataService.update(player, function(d)
				d.Contract.Active.HasPackage = true
				d.Stats.Pickups = (d.Stats.Pickups or 0) + 1
			end)
			EconomyService.award(player, EconomyConfig.CONTRACT.PICKUP_CASH, EconomyConfig.CONTRACT.PICKUP_XP, "contract_pickup")
			respond(player, {
				action = "PickedUp",
				target = active.Target,
				address = MissionDefinitions.DELIVERY_ADDRESSES[active.Target],
				targetPos = { x = targetVector(active.Target).X, y = targetVector(active.Target).Y, z = targetVector(active.Target).Z },
			})
		end)
	end)

	Net.event("CONTRACT_ACT").OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" or payload.action ~= "Deliver" then
			return -- clients may only ask to deliver
		end
		local data = DataService.get(player)
		local active = data and data.Contract.Active
		if not (active and active.HasPackage) then
			return
		end
		local point = targetVector(active.Target)
		if distanceTo(player, point) > (EconomyConfig.INTERACT_DISTANCE + 12) then
			respond(player, { action = "Info", text = "Get closer to the delivery point." })
			return
		end
		DataService.update(player, function(d)
			d.Stats.Deliveries = (d.Stats.Deliveries or 0) + 1
			d.Stats.ContractsDone = (d.Stats.ContractsDone or 0) + 1
			d.Contract.Active = nil
		end)
		EconomyService.award(player, EconomyConfig.CONTRACT.CASH_REWARD, EconomyConfig.CONTRACT.XP_REWARD, "contract_deliver")
		ContractService.Events.Delivered:Fire(player)
		Net.fireTo(player, "TOAST", {
			text = ("Delivered! +%d cash, +%d XP"):format(EconomyConfig.CONTRACT.CASH_REWARD, EconomyConfig.CONTRACT.XP_REWARD),
			duration = 4,
		})
		respond(player, { action = "Delivered" })
	end)
end

return ContractService