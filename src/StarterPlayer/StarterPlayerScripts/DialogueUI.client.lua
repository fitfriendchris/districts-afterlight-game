-- DialogueUI.client.lua — bottom dialogue panel with choices
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local UIKit = require(script.Parent.UIKit)

local gui, frame = UIKit.panel("DialogueUI", UDim2.fromOffset(560, 210), UDim2.new(0.5, -280, 1, -240))
frame.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
gui.Enabled = false
gui.DisplayOrder = 20

local speakerLabel = UIKit.label(frame, "Marcus", UDim2.new(1, -60, 0, 24), UDim2.fromOffset(16, 10), 18, Color3.fromRGB(255, 214, 130))
local bodyLabel = UIKit.label(frame, "", UDim2.new(1, -32, 0, 64), UDim2.fromOffset(16, 38), 17)
bodyLabel.TextWrapped = true

local choiceFrame = Instance.new("Frame")
choiceFrame.Position = UDim2.fromOffset(14, 112)
choiceFrame.Size = UDim2.new(1, -28, 0, 80)
choiceFrame.BackgroundTransparency = 1
choiceFrame.Parent = frame
local choiceLayout = Instance.new("UIListLayout")
choiceLayout.Padding = UDim.new(0, 6)
choiceLayout.SortOrder = Enum.SortOrder.LayoutOrder
choiceLayout.Parent = choiceFrame

local function clearChoices()
	for _, child in ipairs(choiceFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function close()
	gui.Enabled = false
end

Net.event("DIALOGUE_OPEN").OnClientEvent:Connect(function(payload)
	if not payload or not payload.text then
		gui.Enabled = false
		return
	end
	speakerLabel.Text = payload.speaker or ""
	bodyLabel.Text = payload.text or ""
	clearChoices()
	local i = 0
	for _, choice in ipairs(payload.choices or {}) do
		i += 1
		UIKit.button(choiceFrame, choice.text, UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 0), function()
			Net.event("DIALOGUE_RESPOND"):FireServer(choice.id)
			if choice.id == "ok" then
				close()
			end
		end).LayoutOrder = i
	end
	gui.Enabled = true
end)