-- UIKit.client.lua — tiny shared UI factory for the Phase 1 panels
local UIKit = {}

function UIKit.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

function UIKit.panel(name: string, size: UDim2, position: UDim2): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Color3.fromRGB(16, 17, 21)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = gui
	UIKit.corner(frame, 10)

	local layout = Instance.new("UIStroke")
	layout.Color = Color3.fromRGB(255, 210, 130)
	layout.Transparency = 0.55
	layout.Parent = frame

	return gui, frame
end

function UIKit.label(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SourceSansSemibold
	label.TextSize = textSize or 16
	label.TextColor3 = color or Color3.fromRGB(235, 235, 240)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

function UIKit.button(parent: Instance, text: string, size: UDim2, position: UDim2, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(48, 52, 66)
	button.Font = Enum.Font.SourceSansBold
	button.TextSize = 15
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent
	UIKit.corner(button, 7)
	button.Activated:Connect(function()
		onClick()
	end)
	return button
end

function UIKit.scroller(parent: Instance, size: UDim2, position: UDim2): ScrollingFrame
	local sf = Instance.new("ScrollingFrame")
	sf.Size = size
	sf.Position = position
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.ScrollBarThickness = 5
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.Parent = parent
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = sf
	return sf
end

return UIKit