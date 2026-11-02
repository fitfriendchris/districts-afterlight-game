-- HomeUI.client.lua — home console purchases (furniture catalog)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local UIKit = require(script.Parent.UIKit)

local gui, frame = UIKit.panel("HomeUI", UDim2.fromOffset(400, 440), UDim2.new(0.5, 210, 0.5, -220))
gui.Enabled = false
gui.DisplayOrder = 20

UIKit.label(frame, "APARTMENT 3B — HOME CONSOLE", UDim2.new(1, -70, 0, 26), UDim2.fromOffset(16, 10), 17, Color3.fromRGB(255, 214, 130))
UIKit.label(frame, "Furnish your place. It stays yours.", UDim2.new(1, -70, 0, 16), UDim2.fromOffset(16, 34), 13, Color3.fromRGB(200, 200, 210))
UIKit.button(frame, "X", UDim2.fromOffset(30, 30), UDim2.new(1, -40, 0, 10), function()
	gui.Enabled = false
end)

local scroller = UIKit.scroller(frame, UDim2.new(1, -24, 1, -92), UDim2.fromOffset(12, 66))

Net.event("HOME_ACT").OnClientEvent:Connect(function(payload)
	if not payload or payload.action ~= "Open" then
		return
	end
	gui.Enabled = true
	for _, child in ipairs(scroller:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local rowIdx = 0
	for _, item in ipairs(payload.catalog or {}) do
		rowIdx += 1
		local rf = Instance.new("Frame")
		rf.Size = UDim2.new(1, 0, 0, 104)
		rf.BackgroundColor3 = Color3.fromRGB(38, 50, 70)
		rf.Parent = scroller
		UIKit.corner(rf, 8)
		rf.LayoutOrder = rowIdx
		UIKit.label(rf, item.name, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 6), 17)
		UIKit.label(rf, ("$%d"):format(item.price), UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 30), 14, Color3.fromRGB(160, 230, 160))
		local desc = UIKit.label(rf, item.description or "", UDim2.new(1, -110, 0, 16), UDim2.fromOffset(10, 52), 12, Color3.fromRGB(175, 175, 185))
		desc.TextWrapped = false
		if item.owned then
			UIKit.label(rf, "OWNED", UDim2.fromOffset(80, 28), UDim2.fromOffset(14, 70), 13, Color3.fromRGB(140, 200, 255))
		else
			UIKit.button(rf, "Buy", UDim2.fromOffset(90, 30), UDim2.fromOffset(12, 66), function()
				Net.event("HOME_ACT"):FireServer({ action = "Buy", id = item.id })
			end)
		end
	end
end)