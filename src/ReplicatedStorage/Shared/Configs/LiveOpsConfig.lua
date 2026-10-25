--!strict
-- LiveOpsConfig.lua — Phase 7: daily streak rewards + rotating community goal.

local LiveOpsConfig = {
	STREAK = {
		BASE_CASH = 60,                     -- day-1 payout
		CASH_STEP = 15,                     -- cash added per consecutive day
		MAX_STREAK = 7,                     -- payouts cap here (day 7 values repeat? no — streak keeps counting, rewards clamp to day 7)
		SCRAP_BY_DAY = { 2, 3, 4, 4, 5, 6, 8 },
		MEDICAL_BY_DAY = { 0, 0, 1, 0, 0, 1, 2 },
	},
	GOAL = {
		TARGET = 25,                        -- deliveries + infected defeats per UTC day
		CASH_REWARD = 50,
		SCRAP_REWARD = 1,
	},
}

return LiveOpsConfig