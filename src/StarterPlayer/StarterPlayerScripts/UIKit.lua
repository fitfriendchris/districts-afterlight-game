-- UIKit.client.lua — shared UI factory, "Stylized Tactical Low-Poly" theme
-- Palette law (visual master spec §4):
--   panel slate #1E293B · CTA mint #00FF88 · store gold #FFD700 ·
--   clan cyan #38BDF8 · health ruby #EF4444 · bold white text, black strokes
local UIKit = {}

local COLORS = {
	panel = Color3.fromRGB(30, 41, 59),      -- #1E293B slate
	panelDeep = Color3.fromRGB(13, 18, 28),
	mint = Color3.fromRGB(0, 255, 136),      -- #00FF88 primary CTA
	gold = Color3.fromRGB(255, 215, 0),      -- #FFD700 store
	cyan = Color3.fromRGB(56, 189, 248),     -- #38BDF8 clan / info
	ruby = Color3.fromRGB(239, 68, 68),      -- #EF4444 health / danger
	text = Color3.fromRGB(240, 244, 250),
	textDim = Color3.fromRGB(178, 190, 205),
	stroke = Color3.fromRGB(10, 14, 20),
}
UIKit.COLORS = COLORS

function UIKit.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

function UIKit.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or COLORS.stroke
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UIKit.gradients(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
	return g
end

function UIKit.panel(name: string, size: UDim2, position: UDim2): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = COLORS.panel
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = gui
	UIKit.corner(frame, 12)
	UIKit.stroke(frame, COLORS.stroke, 3)
	local glowStroke = Instance.new("UIStroke")
	glowStroke.Color = COLORS.cyan
	glowStroke.Transparency = 0.82
	glowStroke.Thickness = 6
	glowStroke.Parent = frame
	UIKit.gradients(frame, Color3.fromRGB(36, 49, 70), Color3.fromRGB(18, 25, 38))

	return gui, frame
end

function UIKit.label(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = textSize or 16
	label.TextColor3 = color or COLORS.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

-- Primary CTA: neon mint, bold black text, pulsing glow feel
function UIKit.buttonPrimary(parent: Instance, text: string, size: UDim2, position: UDim2, onClick: () -> ()): TextButton
	return UIKit.cta(parent, text, size, position, onClick, COLORS.mint, Color3.fromRGB(6, 26, 16))
end

-- Store CTA: gold with dark text, for purchases
function UIKit.buttonGold(parent: Instance, text: string, size: UDim2, position: UDim2, onClick: () -> ()): TextButton
	return UIKit.cta(parent, text, size, position, onClick, COLORS.gold, Color3.fromRGB(34, 24, 4))
end

-- Danger / close: ruby
function UIKit.buttonDanger(parent: Instance, text: string, size: UDim2, position: UDim2, onClick: () -> ()): TextButton
	return UIKit.cta(parent, text, size, position, onClick, COLORS.ruby, Color3.fromRGB(30, 6, 6))
end

function UIKit.cta(parent: Instance, text: string, size: UDim2, position: UDim2, onClick: () -> (), base: Color3, textColor: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = base
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 16
	button.TextColor3 = textColor
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent
	UIKit.corner(button, 10)
	UIKit.stroke(button, COLORS.stroke, 2, 0.15)
	local gleam = UIKit.gradients(button, base, Color3.new(
		math.max(base.R - 0.22, 0), math.max(base.G - 0.22, 0), math.max(base.B - 0.22, 0)))
	gleam.Rotation = 115
	button.Activated:Connect(function()
		onClick()
	end)
	return button
end

function UIKit.button(parent: Instance, text: string, size: UDim2, position: UDim2, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(46, 60, 84)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = COLORS.text
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent
	UIKit.corner(button, 10)
	UIKit.stroke(button, COLORS.stroke, 2, 0.2)
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
	sf.ScrollBarImageColor3 = COLORS.cyan
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