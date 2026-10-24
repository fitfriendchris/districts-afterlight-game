-- ProgressionConfig.lua — character level curve (Phase 1 band: 1-5 per blueprint)
local ProgressionConfig = {}

ProgressionConfig.MAX_LEVEL = 20

-- CUMULATIVE_XP[i] = minimum XP required to BE level i.
ProgressionConfig.CUMULATIVE_XP = {
	0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700,
	3300, 3950, 4650, 5400, 6200, 7050, 7950, 8900, 9900, 11000,
}

function ProgressionConfig.levelFromXP(xp: number): number
	local level = 1
	for i = 2, ProgressionConfig.MAX_LEVEL do
		if xp >= ProgressionConfig.CUMULATIVE_XP[i] then
			level = i
		end
	end
	return level
end

function ProgressionConfig.xpProgress(level: number, xp: number): (number, number)
	if level >= ProgressionConfig.MAX_LEVEL then
		return 1, 1
	end
	local floor = ProgressionConfig.CUMULATIVE_XP[level]
	local ceil = ProgressionConfig.CUMULATIVE_XP[level + 1]
	if floor >= ceil then
		return 1, 1
	end
	local a = xp - floor
	local span = ceil - floor
	return math.clamp(a / span, 0, 1), span
end

return ProgressionConfig