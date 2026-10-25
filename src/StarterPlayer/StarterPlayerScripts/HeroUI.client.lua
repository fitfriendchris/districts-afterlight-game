-- HeroUI.client.lua — Phase 3 Heroes Hall: roster, recruit, evolve, gear, deploy, spec
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local HeroConfig = require(ReplicatedStorage.Shared.Configs.HeroConfig)
local HeroDefinitions = require(ReplicatedStorage.Shared.Definitions.HeroDefinitions)
local UIKit = require(script.Parent.UIKit)

local panelGui, panel = UIKit.panel("HeroUI", UDim2.fromOffset(500, 430), UDim2.new(0.5, -250, 1, -470))
panel.BackgroundColor3 = Color3.fromRGB(16, 17, 21)
panel.BackgroundTransparency = 0.08
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 210, 130)
stroke.Transparency = 0.55
stroke.Parent = panel
panelGui.DisplayOrder = 25
panelGui.Enabled = false

local title = UIKit.label(panel, "HEROES HALL — survivors worth fighting beside", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 8), 17, Color3.fromRGB(255, 214, 130))
title.LayoutOrder = 0

local listFrame = Instance.new("Frame")
listFrame.Size = UDim2.new(1, -24, 1, -44)
listFrame.Position = UDim2.fromOffset(12, 36)
listFrame.BackgroundTransparency = 1
listFrame.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = listFrame

local rows: { [string]: Frame } = {}

local function actionButton(parent, text, x, width, onClick, color: Color3?)
	local b = UIKit.button(parent, text, UDim2.fromOffset(width, 26), UDim2.new(0, x, 1, -30), onClick)
	b.TextSize = 13
	if color then
		b.BackgroundColor3 = color
	end
	return b
end

local function syncPanel(Heroes)
	for _, heroDef in ipairs(HeroDefinitions.HEROES) do
		local entry = Heroes and Heroes.Roster and Heroes.Roster[heroDef.id]
		local row = rows[heroDef.id]
		if row then
			row:Destroy()
			rows[heroDef.id] = nil
		end
		row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundColor3 = entry and Color3.fromRGB(26, 30, 40) or Color3.fromRGB(20, 22, 28)
		row.BorderSizePixel = 0
		row.LayoutOrder = heroDef.rarity == "Legendary" and 1 or heroDef.rarity == "Epic" and 2 or heroDef.rarity == "Rare" and 3 or 4
		row.Parent = listFrame
		UIKit.corner(row, 6)
		rows[heroDef.id] = row

		local rarityColor = heroDef.rarity == "Legendary" and Color3.fromRGB(255, 190, 90)
			or heroDef.rarity == "Epic" and Color3.fromRGB(196, 120, 255)
			or heroDef.rarity == "Rare" and Color3.fromRGB(110, 190, 255)
			or Color3.fromRGB(200, 200, 205)

		local name = UIKit.label(row, ("%-22s %s • %s%s"):format(heroDef.name, heroDef.role, string.rep("★", entry and entry.Star or 0), entry and "" or " (" .. heroDef.rarity .. ")"), UDim2.new(0.6, 0, 1, -8), UDim2.fromOffset(8, 5), 14, rarityColor)
		name.TextXAlignment = Enum.TextXAlignment.Left
		if entry then
			local active = table.find(Heroes.Active or {}, heroDef.id) ~= nil
			actionButton(row, active and "Recall" or "Deploy", 305, 74, function()
				Net.event("HERO_ACT"):FireServer({ action = "Deploy", id = heroDef.id, on = not active })
			end, active and Color3.fromRGB(60, 120, 70) or Color3.fromRGB(70, 90, 200))

			local specText = entry.Spec == "" and "Spec" or ("→%s"):format(entry.Spec)
			actionButton(row, specText, 384, 100, function()
				-- cycle through specializations
				local cycle = { "", "Vanguard", "Guardian", "Meditech" }
				local at = table.find(cycle, entry.Spec or "") or 1
				Net.event("HERO_ACT"):FireServer({ action = "SetSpec", id = heroDef.id, spec = cycle[(at % #cycle) + 1] })
			end, Color3.fromRGB(90, 70, 130))

			if not entry.Weapon then
				actionButton(row, ("Wpn %d S"):format(HeroConfig.GEAR.WEAPON.COST_SCRAP), 12, 92, function()
					Net.event("HERO_ACT"):FireServer({ action = "Gear", id = heroDef.id, slot = "Weapon" })
				end, Color3.fromRGB(70, 76, 86))
			else
				UIKit.label(row, "wpn ✓", UDim2.fromOffset(40, 13), UDim2.fromOffset(16, 10), 12, Color3.fromRGB(120, 220, 140))
			end
			if not entry.Armor then
				actionButton(row, ("Arm %dS %dF"):format(HeroConfig.GEAR.ARMOR.COST_SCRAP, HeroConfig.GEAR.ARMOR.COST_FABRIC), 112, 92, function()
					Net.event("HERO_ACT"):FireServer({ action = "Gear", id = heroDef.id, slot = "Armor" })
				end, Color3.fromRGB(70, 76, 86))
			else
				UIKit.label(row, "arm ✓", UDim2.fromOffset(40, 13), UDim2.fromOffset(116, 10), 12, Color3.fromRGB(120, 220, 140))
			end
			if entry.Star < HeroConfig.MAX_STAR then
				actionButton(row, ("★%d (%d Med)"):format(entry.Star + 1, HeroConfig.STAR_MEDICAL[entry.Star] or 0), 210, 88, function()
					Net.event("HERO_ACT"):FireServer({ action = "StarUp", id = heroDef.id })
				end, Color3.fromRGB(160, 130, 60))
			end
		else
			local cost = HeroConfig.RECRUIT_CASH[heroDef.rarity]
			actionButton(row, ("Recruit $%d"):format(cost), 210, 128, function()
				Net.event("HERO_ACT"):FireServer({ action = "Recruit", id = heroDef.id })
			end, Color3.fromRGB(240, 160, 60))
			local mats = HeroConfig.RECRUIT_MATERIALS[heroDef.rarity]
			local parts = {}
			for m, a in pairs(mats) do
				table.insert(parts, ("%d %s"):format(a, m))
			end
			local req = UIKit.label(row, "needs " .. table.concat(parts, ", "), UDim2.new(0.34, 0, 1, -10), UDim2.new(0.62, 0, 0, 6), 11, Color3.fromRGB(170, 200, 190))
			req.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
end

local function sendRosterRequest()
	Net.event("HERO_ACT"):FireServer({ action = "Refresh" })
end

Net.event("HERO_SYNC").OnClientEvent:Connect(function(payload)
	if payload.Open then
		panelGui.Enabled = not panelGui.Enabled
		if panelGui.Enabled and payload.Heroes then
			syncPanel(payload.Heroes)
		end
	elseif payload.Heroes then
		syncPanel(payload.Heroes)
	end
end)

-- keep the panel data fresh while open (PROFILE_SYNC carries Heroes)
Net.event("PROFILE_SYNC").OnClientEvent:Connect(function(profile)
	if panelGui.Enabled and profile.Heroes then
		syncPanel(profile.Heroes)
	end
end)

sendRosterRequest()