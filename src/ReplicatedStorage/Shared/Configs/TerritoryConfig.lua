--!strict
-- TerritoryConfig.lua — Phase 6: zone ownership + alliance capture rules.
-- Coordinates mirror WorldLayout (single source stays in build_place.py — this
-- config only carries rates/bonuses; zone CENTERS come from WorldLayout).

local TerritoryConfig = {
	-- influence accrual
	TICK = 2.0,               -- seconds between presence ticks (server loop)
	TICK_RATE = 2,            -- influence per member standing in zone per tick
	DEFENDED_RATE_MULT = 0.5, -- rival accrues at half rate while the owner's members are present
	ALLIED_RATE_MULT = 1.5,   -- allied clans present together accrue faster

	-- capture
	CAPTURE_INFLUENCE = 120,  -- influence needed to flip ownership
	DECAY_PER_TICK = 1,       -- influence drains from clans with nobody present

	-- alliance bonuses: owner gets full, allies get half
	-- (floored by the consuming services; Mult values multiply, Flat values add)
	ZONE_BONUS = {
		PLAZA = { Kind = "ContractCash", Mult = 1.15 },  -- contract deliver payout
		DEPOT = { Kind = "PickupCash", Flat = 5 },       -- package pickup payout
		YARD = { Kind = "YieldFlat", Flat = 1 },         -- settlement collect yield
	},
}

return TerritoryConfig