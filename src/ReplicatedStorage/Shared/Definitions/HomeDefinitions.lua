-- HomeDefinitions.lua — Apartment 3B furniture catalog + placement recipes
-- `slot` = center position of the spawned part, studs relative to the home's
-- interior origin (floor plane at Y=0), +X east, +Z south. Owner part spawns
-- once per purchase and never moves.

local HomeDefinitions = {}

HomeDefinitions.FURNITURE = {
	{
		id = "BED", name = "Bed Frame", price = 120, description = "Sleep like the old world.",
		recipes = {
			{ size = {4.5, 1.4, 7}, pos = {-6.5, 0.7, -4},        color = {88, 68, 52},   material = "WoodPlanks" },
			{ size = {4.5, 0.8, 7}, pos = {-6.5, 1.5, -4},        color = {220, 220, 224}, material = "SmoothPlastic" },
		},
	},
	{
		id = "RUG", name = "Area Rug", price = 80, description = "Ties the whole room together.",
		recipes = {
			{ size = {10, 0.12, 8}, pos = {0, 0.06, 1}, color = {140, 60, 60}, material = "SmoothPlastic" },
		},
	},
	{
		id = "TV", name = "Flatscreen TV", price = 260, description = "Catches the last live broadcasts.",
		recipes = {
			{ size = {0.4, 4, 7},   pos = {7.8, 4.2, 0},  color = {18, 18, 22},  material = "SmoothPlastic" },
			{ size = {0.5, 0.5, 3}, pos = {7.8, 1.9, 0},  color = {80, 80, 84},  material = "Metal" },
		},
	},
	{
		id = "SHELF", name = "Cargo Shelf", price = 180, description = "Room for whatever comes next.",
		recipes = {
			{ size = {2.4, 6, 3},   pos = {6.6, 3.0, -6.8}, color = {96, 84, 70}, material = "WoodPlanks" },
		},
	},
	{
		id = "LAMP", name = "Floor Lamp", price = 100, description = "Warm light. Some comfort worth keeping.",
		recipes = {
			{ size = {0.35, 5.2, 0.35}, pos = {-8.2, 2.6, 5.0},  color = {120, 120, 124}, material = "Metal" },
			{ size = {1.6, 1.2, 1.6},   pos = {-8.2, 5.5, 5.0},  color = {255, 226, 170}, material = "Neon" },
		},
	},
}

function HomeDefinitions.find(id: string)
	for _, item in ipairs(HomeDefinitions.FURNITURE) do
		if item.id == id then
			return item
		end
	end
	return nil
end

return HomeDefinitions