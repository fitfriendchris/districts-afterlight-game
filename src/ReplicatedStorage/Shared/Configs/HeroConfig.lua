-- HeroConfig.lua — Phase 3 hero economy + squad tuning (server-authoritative)
-- Clients may read these numbers for display only; all spending is validated server-side.

local HeroConfig = {
	SQUAD_SIZE = 2, -- deployable allies at once

	-- Recruit costs: cash + materials per rarity
	RECRUIT_CASH = { Common = 200, Rare = 480, Epic = 950, Legendary = 1800 },
	RECRUIT_MATERIALS = {
		Common = { Scrap = 2 },
		Rare = { Scrap = 3, Fabric = 2 },
		Epic = { Scrap = 4, Fabric = 3, Medical = 1 },
		Legendary = { Scrap = 6, Fabric = 5, Medical = 3 },
	},

	-- Star evolution: cost per current star (medical supplies + cash)
	MAX_STAR = 5,
	STAR_MEDICAL = { 1, 2, 4, 6, 9 },
	STAR_CASH = { 150, 300, 600, 1200, 2400 },

	XP_RECRUIT = 25,
	XP_EVOLVE = 60,

	-- Gear (purchased with materials per hero; single tier per slot)
	GEAR = {
		WEAPON = { COST_SCRAP = 6, DAMAGE_MULT = 0.15 },
		ARMOR = { COST_SCRAP = 5, COST_FABRIC = 2, HEALTH_MULT = 0.5 },
	},

	-- Ally combat behavior
	ALLY = {
		TICK = 0.5,
		ATTACK_RANGE = 26.0, -- heroes engage from farther than infected aggro
		ATTACK_COOLDOWN = 1.6,
		BASE_DAMAGE = 14.0,
		BASE_HEALTH = 90.0,
		WALK_SPEED = 17.0,
		FOLLOW_OFFSET = 4.5,
		ENGAGE_KEEP = 30.0, -- leash: stop fighting when the player is this far from home spot
	},

	-- Specializations (unlock at star 2)
	SPECIALIZATION_UNLOCK_STAR = 2,
	SPECIALIZATIONS = {
		Vanguard = { DAMAGE_MULT = 0.25, desc = "+25% ally damage" },
		Guardian = { HEALTH_MULT = 0.5, desc = "+50% ally health" },
		Meditech = { MEDICAL_BONUS = 0.15, desc = "+15% medical drop chance" },
	},
}

return HeroConfig