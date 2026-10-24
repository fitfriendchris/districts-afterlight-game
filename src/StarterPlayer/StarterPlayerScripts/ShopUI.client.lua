-- ShopUI.client.lua — catalog list with buy/equip (server sends full refresh)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local UIKit = require(script.Parent.UIKit)

local gui, frame = UIKit.panel("ShopUI", UDim2.fromOffset(400, 440), UDim2.new(0.5, -200, 0.5, -220))
gui.Enabled = false
gui.DisplayOrder = 20

UIKit.label(frame, "MERIDIAN OUTFITTERS", UDim2.new(1, -70, 0, 26), UDim2.fromOffset(16, 10), 18, Color3.fromRGB(255, 214, 130))
UIKit.label(frame, "Cash cosmetics — no gameplay advantage", UDim2.new(1, -70, 0, 16), UDim2.fromOffset(16, 34), 13, Color3.fromRGB(200, 200, 210))
UIKit.button(frame, "X", UDim2.fromOffset(30, 30), UDim2.new(1, -40, 0, 10), function()
	gui.Enabled = false
end)

local scroller = UIKit.scroller(frame, UDim2.new(1, -24, 1, -92), UDim2.fromOffset(12, 66))

local function row(parent: Instance, height: number, order: number): Frame
	local rf = Instance.new("Frame")
	rf.Size = UDim2.new(1, 0, 0, height)
	rf.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
	rf.Parent = parent
	UIKit.corner(rf, 8)
	rf.LayoutOrder = order
	return rf
end

Net.event("SHOP_ACT").OnClientEvent:Connect(function(payload)
	if not payload or payload.action ~= "Open" then
		return
	end
	gui.Enabled = true
	for _, child in ipairs(scroller:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local rowIdx = 0
	for _, item in ipairs(payload.items or {}) do
		rowIdx += 1
		local rf = row(scroller, 92, rowIdx)
		UIKit.label(rf, item.name, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 6), 17)
		UIKit.label(rf, ("$%d"):format(item.price), UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 30), 14, Color3.fromRGB(160, 230, 160))
		if item.owned then
			UIKit.label(rf, "OWNED", UDim2.fromOffset(80, 28), UDim2.fromOffset(10, 56), 13, Color3.fromRGB(140, 200, 255)).TextXAlignment = Enum.TextXAlignment.Center
		else
			UIKit.button(rf, "Buy", UDim2.fromOffset(90, 30), UDim2.fromOffset(12, 54), function()
				Net.event("SHOP_ACT"):FireServer({ action = "Buy", id = item.id })
			end)
		end
	end
	if payload.jacketColors and #payload.jacketColors > 0 then
		-- jacket color equip rows appear when the jacket is owned
		local jacketItem = nil
		for _, item in ipairs(payload.items) do
			if item.id == "JACKET" then
				jacketItem = item
			end
		end
		if jacketItem and jacketItem.owned then
			UIKit.label(scroller, "JACKET COLORS", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 0), 14, Color3.fromRGB(255, 214, 130)).LayoutOrder = rowIdx + 1
			for idx, jc in ipairs(payload.jacketColors) do
				local rf = row(scroller, 44, rowIdx + 1 + idx)
				local swatch = Instance.new("Frame")
				swatch.Size = UDim2.fromOffset(24, 24)
				swatch.Position = UDim2.fromOffset(10, 10)
				swatch.BackgroundColor3 = Color3.fromRGB(jc.color[1], jc.color[2], jc.color[3])
				swatch.BorderSizePixel = 0
				swatch.Parent = rf
				UIKit.corner(swatch, 6)
				UIKit.label(rf, jc.name, UDim2.new(1, -110, 1, 0), UDim2.fromOffset(44, 0), 15)
				if jc.active then
					UIKit.label(rf, "EQUIPPED", UDim2.fromOffset(90, 26), UDim2.new(1, -100, 0.5, -13), 12, Color3.fromRGB(140, 200, 255))
				else
					UIKit.button(rf, "Equip", UDim2.fromOffset(70, 28), UDim2.new(1, -80, 0.5, -14), function()
						Net.event("SHOP_ACT"):FireServer({ action = "Equip", slot = "jacketColor", id = jc.id })
					end)
				end
			end
		end
	end
end)