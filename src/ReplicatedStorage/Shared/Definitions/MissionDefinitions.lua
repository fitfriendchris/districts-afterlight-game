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
	{ id = "DONE",          text = "Chapter 1 complete — catch the evening news on the plaza screen" },
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