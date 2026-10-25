--!strict
-- ClanConfig.lua — Phase 5: clans + group contracts tuning.

local ClanConfig = {
	CREATE_CASH = 500,
	CREATE_SCRAP = 20,
	MEMBER_CAP = 8,
	NAME_MIN = 3,
	NAME_MAX = 20,
	TAG_MIN = 2,
	TAG_MAX = 4,
	LEAVE_COOLDOWN = 10, -- seconds between clan membership changes per player

	DONATE_MIN = 50,
	DONATE_MAX = 5000,

	CONTRACT = {
		REQUIRED_DELIVERIES = 2, -- shared by the whole clan
		CASH_REWARD = 260,       -- into the clan bank on completion
		CASH_SHARE = 100,        -- to the delivering member
		XP_SHARE = 20,
		COOLDOWN = 30,           -- seconds between clan contracts
	},

	SAVE_INTERVAL = 120,
}

return ClanConfig