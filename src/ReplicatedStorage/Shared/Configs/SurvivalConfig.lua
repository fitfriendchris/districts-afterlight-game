-- SurvivalConfig.lua — Phase 2 survival + infected tuning (server-authoritative)
-- Clients never compute rewards; services read these numbers exclusively.

local SurvivalConfig = {
	SCAVENGE = {
		XP_REWARD = 8,
		COOLDOWN = 60.0, -- per pile; servers the respawn rhythm
		MATERIALS_MIN = 1,
		MATERIALS_MAX = 3,
	},

	INFECTED = {
		HEALTH = 100.0,
		WALK_SPEED = 12.0,
		DAMAGE = 12.0,
		ATTACK_COOLDOWN = 1.2,
		ATTACK_RANGE = 4.0,
		AGGRO_RADIUS = 55.0,
		ROAM_RADIUS = 28.0,
		TICK = 0.4, -- AI loop interval
		RESPAWN_DELAY = 45.0,
		DESPAWN_DELAY = 2.5, -- corpse cleanup after defeat
		XP_REWARD = 30,
		CASH_REWARD = 45,
		MEDICAL_DROP_CHANCE = 0.4,
	},

	CROWBAR = {
		DAMAGE = 34.0,
		RANGE = 8.0,
		FACE_DOT = 0.25, -- must roughly face the swing target
		COOLDOWN = 0.55,
	},

	FORTIFY = {
		SCRAP_COST = 4,
		XP_REWARD = 40,
	},
}

return SurvivalConfig