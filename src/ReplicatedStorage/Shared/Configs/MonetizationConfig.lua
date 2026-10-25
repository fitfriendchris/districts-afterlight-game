--!strict
-- MonetizationConfig.lua — Phase 8: dev products + supporter pass.
-- IDs are set AFTER the place is published (Roblox asset IDs); nil IDs keep
-- the slice's prompts dormant — the service tolerates an unpublished game.

type ProductDef = {
	Kind: string,
	Amount: number?, -- Cash products: cash granted
	Medical: number?, -- Supplies products: medical granted
	Scrap: number?, -- Supplies products: scrap granted
	Name: string,
}

local MonetizationConfig = {
	-- Developer products: [robloxProductId] = { Kind, Amount/Medical/Scrap, Name }
	PRODUCTS = {} :: { [number]: ProductDef },
	-- Permanent Supporter pass: +10% contract payouts
	-- https://www.roblox.com/game-pass/2053295760
	SUPPORTER_PASS_ID = 2053295760,
	SUPPORTER_MULT = 1.10,
}
-- CashCache: +$250 (Kind = "Cash")  https://www.roblox.com/catalog/3722080498
MonetizationConfig.PRODUCTS[3722080498] = { Kind = "Cash", Amount = 250, Name = "Cash Cache" }
-- MedSupply: 5 medical + 20 scrap (Kind = "Supplies")  https://www.roblox.com/catalog/3722080599
MonetizationConfig.PRODUCTS[3722080599] = { Kind = "Supplies", Medical = 5, Scrap = 20, Name = "Med Supplies Pack" }

return MonetizationConfig