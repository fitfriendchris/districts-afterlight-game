-- MissionDefinitions.lua — intro campaign "Getting on Your Feet" (Chapter 1)
local MissionDefinitions = {}

MissionDefinitions.INTRO_ID = "INTRO"
MissionDefinitions.INTRO_TITLE = "Getting on Your Feet"

-- Step index is stored in profile.Missions.INTRO.step (0-based).
MissionDefinitions.STEPS = {
	{ id = "TALK_MARCUS",   text = "Say hi to Marcus at Meridian Plaza (walk up, press E)" },
	{ id = "DO_DELIVERIES", text = "Finish 2 Curbside Delivery contracts (job board, plaza)" },
	{ id = "VISIT_HOME",    text = "Use the home console inside Apartment 3B (blue door east)" },
	{ id = "FURNISH",       text = "Buy your first furniture item from the home console" },
	{ id = "SCAVENGE",      text = "Scavenge 3 rubble piles for materials (look for debris in the north streets)" },
	{ id = "FIGHT_INFECTED", text = "The city is changing. Defeat an infected with your crowbar" },
	{ id = "FORTIFY_SAFEHOUSE", text = "Barricade the Apartment 3B entrance (needs 4 scrap)" },
	{ id = "DONE",          text = "Chapter 2 complete — Meridian has changed. More to come." },
}

-- Steps that show a numeric progress counter (id -> required amount)
MissionDefinitions.REQUIREMENTS = {
	DO_DELIVERIES = 2,
	SCAVENGE = 3,
	FIGHT_INFECTED = 1,
	FORTIFY_SAFEHOUSE = 1,
}

MissionDefinitions.DELIVERIES_REQUIRED = 2

-- Delivery addresses (index must match the DeliveryTarget part names in world)
MissionDefinitions.DELIVERY_ADDRESSES = {
	"12 Larkspur Row",
	"7 Meridian Gate Apartments",
	"340 Old Canal Street",
	"22 Ashfall Avenue",
}

return MissionDefinitions