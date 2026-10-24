-- EconomyConfig.lua — Phase 1 economy tuning (server-authoritative)
-- Clients never compute rewards; services read these numbers exclusively.

local EconomyConfig = {
	BASE_STARTING_CASH = 250,

	CONTRACT = {
		NAME = "Curbside Delivery",
		CASH_REWARD = 60,   -- per completed delivery
		XP_REWARD = 25,     -- per completed delivery
		PICKUP_CASH = 10,   -- partial credit so a dropped session still pays a little
		PICKUP_XP = 5,
		COOLDOWN = 5,       -- seconds between accept cycles
		MAX_ACTIVE_TARGETS = 4, -- delivery addresses in Meridian (must match world build)
	},

	INTERACT_DISTANCE = 24, -- server-side distance gate for all interactive acts (studs)
}

return EconomyConfig