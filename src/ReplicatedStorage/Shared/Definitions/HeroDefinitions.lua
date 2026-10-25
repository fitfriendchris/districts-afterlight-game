-- HeroDefinitions.lua — Phase 3 recruitable hero roster
-- Rarity tiers: Common / Rare / Epic / Legendary (costs in HeroConfig).

local HeroDefinitions = {}

HeroDefinitions.HEROES = {
	{ id = "RIN",   name = "Rin the Runner",   role = "Scout",  rarity = "Common",    desc = "Fast eyes on every crosswalk." },
	{ id = "MOSS",  name = "Courier Moss",     role = "Fighter", rarity = "Common",   desc = "Delivered through worse than rain." },
	{ id = "SABLE", name = "Medic Sable",      role = "Medic",  rarity = "Rare",      desc = "Field stitches and steady hands." },
	{ id = "DORAN", name = "Warden Doran",     role = "Guard",  rarity = "Rare",      desc = "Held a stairwell for eleven hours." },
	{ id = "LYS",   name = "Arc Lys",          role = "Fighter", rarity = "Epic",     desc = "Turns alley ambushes into legends." },
	{ id = "VEL",   name = "Quartermistress Vel", role = "Logistics", rarity = "Epic", desc = "Counts scrap like currency." },
	{ id = "KANE",  name = "Sentinel Kane",    role = "Guard",  rarity = "Legendary", desc = "The last barricade standing." },
	{ id = "IVEY",  name = "Dr. Ivey",         role = "Medic",  rarity = "Legendary", desc = "Outlasted the Harbor outbreak." },
}

function HeroDefinitions.byId(id: string)
	for _, hero in ipairs(HeroDefinitions.HEROES) do
		if hero.id == id then
			return hero
		end
	end
	return nil
end

return HeroDefinitions