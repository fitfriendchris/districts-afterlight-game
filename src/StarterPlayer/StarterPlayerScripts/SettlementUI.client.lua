-- SettlementUI.client.lua — Phase 4: settlement board — build / collect / upgrade / demolish
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local SettlementConfig = require(ReplicatedStorage.Shared.Configs.SettlementConfig)
local UIKit = require(script.Parent.UIKit)

local panelGui, panel = UIKit.panel("SettlementUI", UDim2.fromOffset(560, 430), UDim2.new(0.5, -280, 1, -470))
panel.BackgroundColor3 = Color3.fromRGB(16, 17, 21)
panel.BackgroundTransparency = 0.08
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 210, 130)
stroke.Transparency = 0.55
stroke.Parent = panel
panelGui.DisplayOrder = 26
panelGui.Enabled = false

local title = UIKit.label(panel, "SETTLEMENT BOARD — build up Meridian's yard", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 8), 17, Color3.fromRGB(255, 214, 130))
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

local STRUCT_TYPES = { "WORKBENCH", "LOOM", "GENERATOR", "MEDSTATION", "STORAGE" }

local function costText(typeName: string): string
	local def = SettlementConfig.STRUCTURES[typeName]
	local parts = {}
	for item, amount in pairs(def.Cost) do
		table.insert(parts, ("%d%s"):format(amount, item:sub(1, 1)))
	end
	table.sort(parts)
	return table.concat(parts, "·")
end

local function smallButton(parent, text, x, w, onClick)
	local b = UIKit.button(parent, text, UDim2.fromOffset(w, 26), UDim2.new(0, x, 1, -30), onClick)
	b.TextSize = 13
	return b
end

local function syncPanel(Structures)
	-- clear rebuild (simple, list is tiny)
	for _, child in ipairs(listFrame:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	for padIndex = 1, SettlementConfig.BUILD_PADS do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
		row.BorderSizePixel = 0
		row.LayoutOrder = padIndex
		row.Parent = listFrame
		UIKit.corner(row, 6)

		local struct = nil
		for _, s in ipairs(Structures or {}) do
			if s.Pad == padIndex then
				struct = s
				break
			end
		end

		local label = nil
		if struct then
			local def = SettlementConfig.STRUCTURES[struct.Type]
			label = UIKit.label(row, ("PAD %d — %s Lv%d%s"):format(padIndex, def.Name, struct.Level, def.Produces and ("  (%s ready: %d)"):format(def.Produces.kind == "Cash" and "$" or def.Produces.item, math.floor(struct.Bank or 0)) or " (passive)"), UDim2.new(1, -240, 1, -8), UDim2.fromOffset(8, 5), 13, Color3.fromRGB(230, 238, 220))
			smallButton(row, "Collect", 288, 70, function()
				Net.event("SETTLEMENT_ACT"):FireServer({ action = "Collect", pad = padIndex })
			end)
			if struct.Level < SettlementConfig.MAX_LEVEL then
				smallButton(row, "Upgrade", 362, 70, function()
					Net.event("SETTLEMENT_ACT"):FireServer({ action = "Upgrade", pad = padIndex })
				end, Color3.fromRGB(160, 130, 60))
			end
			smallButton(row, "Demolish", 438, 70, function()
				Net.event("SETTLEMENT_ACT"):FireServer({ action = "Demolish", pad = padIndex })
			end, Color3.fromRGB(150, 70, 70))
		else
			label = UIKit.label(row, ("PAD %d — empty foundation"):format(padIndex), UDim2.new(0.30, 0, 1, -8), UDim2.fromOffset(8, 5), 13, Color3.fromRGB(160, 168, 180))
			local x = 192
			for _, typeName in ipairs(STRUCT_TYPES) do
				local def = SettlementConfig.STRUCTURES[typeName]
				smallButton(row, ("%s %s"):format(def.Name, costText(typeName)), x, 66, function()
					Net.event("SETTLEMENT_ACT"):FireServer({ action = "Build", pad = padIndex, type = typeName })
				end)
				x += 68
			end
		end
		label.TextXAlignment = Enum.TextXAlignment.Left
	end
end

Net.event("SETTLEMENT_SYNC").OnClientEvent:Connect(function(payload)
	if payload.Open then
		panelGui.Enabled = not panelGui.Enabled
		if panelGui.Enabled and payload.Structures then
			syncPanel(payload.Structures)
		end
	elseif payload.Structures and panelGui.Enabled then
		syncPanel(payload.Structures)
	end
end)

Net.event("PROFILE_SYNC").OnClientEvent:Connect(function(profile)
	if panelGui.Enabled and profile.Settlement then
		syncPanel(profile.Settlement.Structures)
	end
end)