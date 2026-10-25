--!strict
-- SettlementConfig.lua — Phase 4: buildable settlement structures.
-- All numbers here are the single source of truth (services read; never hardcode).
export type StructureKey = "WORKBENCH" | "LOOM" | "GENERATOR" | "MEDSTATION" | "STORAGE"

local SettlementConfig = {
	BUILD_PADS = 4,          -- foundation pads near the home lot
	MAX_LEVEL = 3,
	COLLECT_XP = 15,
	UPGRADE_XP = 30,
	BUILD_XP = 40,
	LEVEL_MULT = { 1.0, 1.6, 2.4 }, -- production yield multiplier per level
	UPGRADE_MULT = { 0, 2, 3 },     -- upgrade to Lv2 costs 2× base, Lv3 3× base
	REFUND_RATE = 0.3,       -- demolish refund fraction (floored per material)

	STRUCTURES = {
		WORKBENCH = {
			Name = "Workbench",
			Color = { 120, 96, 62 },
			Cost = { Scrap = 8, Fabric = 4 },
			Produces = { kind = "Inventory", item = "Scrap", amount = 2 },
			Interval = 120,
			Radius = 2.0, Height = 1.1,
		},
		LOOM = {
			Name = "Loom",
			Color = { 148, 118, 96 },
			Cost = { Scrap = 6, Fabric = 8 },
			Produces = { kind = "Inventory", item = "Fabric", amount = 2 },
			Interval = 150,
			Radius = 2.0, Height = 1.6,
		},
		GENERATOR = {
			Name = "Generator",
			Color = { 96, 108, 96 },
			Cost = { Scrap = 12 },
			Produces = { kind = "Cash", amount = 30 },
			Interval = 90,
			Radius = 2.2, Height = 1.3,
		},
		MEDSTATION = {
			Name = "Med Station",
			Color = { 210, 224, 214 },
			Cost = { Scrap = 8, Fabric = 5, Medical = 1 },
			Produces = { kind = "Inventory", item = "Medical", amount = 1 },
			Interval = 240,
			Radius = 2.0, Height = 1.2,
		},
		STORAGE = {
			Name = "Storage Crate",
			Color = { 88, 92, 104 },
			Cost = { Scrap = 5 },
			Produces = nil, -- passive: +1 to every other structure's bank cap
			Interval = 0,
			Radius = 1.8, Height = 1.0,
		},
	},

	CAP_MULT = 3, -- banks hold up to 3 intervals' worth before idle
}

return SettlementConfig