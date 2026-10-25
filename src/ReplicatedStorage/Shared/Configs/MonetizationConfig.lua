--!strict
-- MonetizationConfig.lua — Phase 8: dev products + supporter pass.
-- IDs are set AFTER the place is published (Roblox asset IDs); nil IDs keep
-- the slice's prompts dormant — the service tolerates an unpublished game.

local MonetizationConfig = {
	-- Developer products: [robloxProductId] = { Kind, Amount, Name }
	PRODUCTS = {
		-- CashCache: +$250 (Kind = "Cash")
		-- MedSupply: 5 medical + 20 scrap (Kind = "Supplies")
	},
	-- Permanent Supporter pass: +10% contract payouts (Kind = "Mult")
	SUPPORTER_PASS_ID = nil,
	SUPPORTER_MULT = 1.10,
}

return MonetizationConfig