-- EconomyService.lua — server-authoritative cash and XP (Phase 0)
-- Every grant and spend passes through here; clients can only request acts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local ProgressionConfig = require(ReplicatedStorage.Shared.Configs.ProgressionConfig)
local DataService = require(script.Parent.DataService)

local EconomyService = {}

-- Clamp protects against a service bug draining a save; tune per system.
local MAX_SINGLE_AWARD = 100000

function EconomyService.award(player: Player, cash: number? , xp: number?, reason: string?)
	cash = math.floor(tonumber(cash) or 0)
	xp = math.floor(tonumber(xp) or 0)
	if cash <= 0 and xp <= 0 then
		return false
	end
	if cash > MAX_SINGLE_AWARD or xp > 5000 then
		warn("[EconomyService] rejected oversized award: " .. tostring(reason))
		return false
	end
	DataService.update(player, function(data)
		if cash > 0 then
			data.Cash = (data.Cash or 0) + cash
		end
		if xp > 0 then
			local before = ProgressionConfig.levelFromXP(data.XP or 0)
			data.XP = (data.XP or 0) + xp
			local after = ProgressionConfig.levelFromXP(data.XP)
			if after > before and after <= ProgressionConfig.MAX_LEVEL then
				Net.event("TOAST"):FireClient(player, {
					text = ("LEVEL UP — Level %d"):format(after),
					duration = 4,
				})
			end
		end
	end)
	return true
end

function EconomyService.spend(player: Player, amount: number, reason: string?)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return false
	end
	local ok = false
	DataService.update(player, function(data)
		if (data.Cash or 0) >= amount then
			data.Cash -= amount
			ok = true
		end
	end)
	return ok
end

function EconomyService.balance(player: Player): number
	local data = DataService.get(player)
	return data and data.Cash or 0
end

function EconomyService.Init() end

return EconomyService