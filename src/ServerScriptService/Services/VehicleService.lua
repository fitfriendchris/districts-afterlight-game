-- VehicleService.lua — van claim + cosmetic paint (Phase 1: one meaningful vehicle)
-- Sitting in an unclaimed van claims it for you; hopping releases it.
-- Wraps bought at Meridian Outfitters paint your claimed van.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local VehicleService = {}
VehicleService.Events = {
	VanClaimed = Signal.new(), -- (player, vanModel)
	VanReleased = Signal.new(), -- (player)
}

local claims = {} -- [Player] = vanModel
local releaseJobs = {}

local function findVans()
	local meridian = workspace:WaitForChild("Meridian", 30)
	local vans = meridian:WaitForChild("Vans", 30)
	if not vans then
		return {}
	end
	local out = {}
	for _, model in ipairs(vans:GetChildren()) do
		if model:IsA("Model") and model:FindFirstChildOfClass("VehicleSeat") then
			table.insert(out, model)
		end
	end
	return out
end

local function release(player: Player)
	local van = claims[player]
	if not van then
		return
	end
	claims[player] = nil
	local job = releaseJobs[player]
	if job then
		task.cancel(job)
		releaseJobs[player] = nil
	end
	VehicleService.Events.VanReleased:Fire(player, van)
end

local function isClaimed(van: Model): boolean
	for _, v in pairs(claims) do
		if v == van then
			return true
		end
	end
	return false
end

function VehicleService.getClaimed(player: Player)
	return claims[player]
end

function VehicleService.applyPaint(player: Player, color: Color3)
	local van = claims[player]
	if van then
		local chassis = van:FindFirstChild("Chassis")
		if chassis then
			chassis.Color = color
		end
		local seat = van:FindFirstChildOfClass("VehicleSeat")
		if seat then
			seat.Color = color
		end
	end
end

function VehicleService.Init()
	task.spawn(function()
		local vans = findVans()
		for _, van in ipairs(vans) do
			local seat = van:FindFirstChildOfClass("VehicleSeat")
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				local occupant = seat.Occupant
				if occupant then
					local player = Players:GetPlayerFromCharacter(occupant.Parent)
					if player then
						if not isClaimed(van) then
							local old = claims[player]
							if old and old ~= van then
								release(player)
							end
							claims[player] = van
							VehicleService.Events.VanClaimed:Fire(player, van)
						end
					end
				else
					-- released: give a short grace so physics settles, then free the van
					local player = nil
					for p, v in pairs(claims) do
						if v == van then
							player = p
						end
					end
					if player then
						if releaseJobs[player] then
							task.cancel(releaseJobs[player])
						end
						releaseJobs[player] = task.delay(3, function()
							release(player)
						end)
					end
				end
			end)
		end

		Players.PlayerRemoving:Connect(function(player)
			release(player)
		end)
	end)
end

return VehicleService