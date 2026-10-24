-- ItemDefinitions.lua — cash-only cosmetics for Phase 1 (gameplay-neutral)
local ItemDefinitions = {}

ItemDefinitions.CATALOG = {
	{ id = "WRAP_MIDNIGHT", kind = "vanWrap", name = "Midnight Wrap",  price = 150, color = Color3.fromRGB(36, 70, 140) },
	{ id = "WRAP_SUNSET",   kind = "vanWrap", name = "Sunset Wrap",    price = 150, color = Color3.fromRGB(214, 106, 45) },
	{ id = "WRAP_FOREST",   kind = "vanWrap", name = "Forest Wrap",    price = 150, color = Color3.fromRGB(46, 112, 66) },
	{ id = "JACKET",        kind = "jacket",  name = "Jacket Collection", price = 100 },
}

-- Jacket purchase unlocks every color below; Equip picks one.
ItemDefinitions.JACKET_COLORS = {
	{ id = "JK_CRIMSON", name = "Crimson", color = Color3.fromRGB(178, 44, 44) },
	{ id = "JK_SLATE",   name = "Slate",   color = Color3.fromRGB(70, 76, 86) },
	{ id = "JK_GOLD",    name = "Gold",    color = Color3.fromRGB(196, 160, 60) },
}

function ItemDefinitions.find(id: string)
	for _, item in ipairs(ItemDefinitions.CATALOG) do
		if item.id == id then
			return item
		end
	end
	return nil
end

return ItemDefinitions