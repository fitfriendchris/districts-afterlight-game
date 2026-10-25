-- MainHUD.client.lua — cash, level, XP bar, objective tracker, toasts, deliver button
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local ProgressionConfig = require(ReplicatedStorage.Shared.Configs.ProgressionConfig)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local root = script.Parent -- StarterPlayerScripts folder

local gui, frame = UIKit.panel("MainHUD", UDim2.fromOffset(240, 116), UDim2.new(0, 12, 0, 12))
frame.BackgroundTransparency = 0.35
gui.DisplayOrder = 5

local cashLabel = UIKit.label(frame, "Cash: $250", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(12, 8), 20, Color3.fromRGB(150, 235, 150))
local levelLabel = UIKit.label(frame, "Level 1", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(12, 34), 15, Color3.fromRGB(200, 210, 235))
local suppliesLabel = UIKit.label(frame, "Scrap 0 ·  Fabric 0 ·  Meds 0", UDim2.new(1, -16, 0, 16), UDim2.fromOffset(12, 56), 13, Color3.fromRGB(160, 200, 168))

local xpBack = Instance.new("Frame")
xpBack.Size = UDim2.new(1, -24, 0, 8)
xpBack.Position = UDim2.fromOffset(12, 76)
xpBack.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
xpBack.BorderSizePixel = 0
xpBack.Parent = frame
UIKit.corner(xpBack, 4)

local xpFill = Instance.new("Frame")
xpFill.Size = UDim2.new(0, 0, 1, 0)
xpFill.BackgroundColor3 = Color3.fromRGB(255, 200, 90)
xpFill.BorderSizePixel = 0
xpFill.Parent = xpBack
UIKit.corner(xpFill, 4)

-- Objective tracker (right side)
local objGui, objFrame = UIKit.panel("ObjectiveTracker", UDim2.fromOffset(300, 84), UDim2.new(1, -312, 0, 12))
objFrame.BackgroundColor3 = Color3.fromRGB(14, 20, 26)
objFrame.BackgroundTransparency = 0.3
local objTitle = UIKit.label(objFrame, "Getting on Your Feet", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(12, 8), 14, Color3.fromRGB(255, 214, 130))
local objText = UIKit.label(objFrame, "", UDim2.new(1, -16, 0, 40), UDim2.fromOffset(12, 30), 15, Color3.fromRGB(230, 230, 238))
objText.TextWrapped = true

-- Toasts (top center)
local toastHolder = Instance.new("Frame")
toastHolder.AnchorPoint = Vector2.new(0.5, 0)
toastHolder.Position = UDim2.new(0.5, 0, 0, 16)
toastHolder.Size = UDim2.fromOffset(420, 200)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 6)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Parent = toastHolder

local function toast(text: string, duration: number)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 30)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	t.BackgroundTransparency = 0.15
	t.Font = Enum.Font.SourceSansBold
	t.TextSize = 16
	t.TextColor3 = Color3.fromRGB(255, 240, 210)
	t.Text = text
	t.TextWrapped = true
	t.Parent = toastHolder
	UIKit.corner(t, 8)
	task.delay(duration or 3, function()
		t:Destroy()
	end)
end

-- Deliver button (visible while carrying a package)
local deliverButton = UIKit.button(gui, "DELIVER PACKAGE", UDim2.fromOffset(200, 46), UDim2.new(0.5, -100, 1, -66), function()
	Net.event("CONTRACT_ACT"):FireServer({ action = "Deliver" })
end)
deliverButton.BackgroundColor3 = Color3.fromRGB(255, 140, 50)
deliverButton.Visible = false
deliverButton.ZIndex = 10

local currentTarget = nil
local currentHasPackage = false

local function setDeliverVisible(hasPackage: boolean, targetIndex: number?)
	currentHasPackage = hasPackage
	deliverButton.Visible = hasPackage
	if targetIndex then
		currentTarget = targetIndex
	end
end

Net.event("PROFILE_SYNC").OnClientEvent:Connect(function(profile)
	cashLabel.Text = ("Cash: $%d"):format(profile.Cash or 0)
	local level = ProgressionConfig.levelFromXP(profile.XP or 0)
	levelLabel.Text = ("Level %d  •  XP %d"):format(level, profile.XP or 0)
	local frac = ProgressionConfig.xpProgress(level, profile.XP or 0)
	xpFill.Size = UDim2.fromScale(frac, 1)
	local inv = profile.Inventory or {}
	suppliesLabel.Text = ("Scrap %d ·  Fabric %d ·  Meds %d"):format(inv.Scrap or 0, inv.Fabric or 0, inv.Medical or 0)
	if profile.Contract and profile.Contract.HasPackage then
		setDeliverVisible(true, profile.Contract.Target)
	else
		setDeliverVisible(false, nil)
	end
end)

Net.event("OBJECTIVE_SYNC").OnClientEvent:Connect(function(payload)
	objTitle.Text = payload.title or ""
	local text = payload.text or ""
	if payload.max then
		text = text .. ("  (%d/%d)"):format(payload.progress or 0, payload.max)
	end
	objText.Text = text
end)

Net.event("TOAST").OnClientEvent:Connect(function(payload)
	if typeof(payload) == "string" then
		payload = { text = payload }
	end
	toast(payload.text or "", payload.duration or 3)
end)

-- First-arrival welcome
local welcomed = false
Net.event("PROFILE_SYNC").OnClientEvent:Once(function()
	if welcomed then
		return
	end
	welcomed = true
	toast("Welcome to Meridian. Say hi to Marcus at the plaza fountain.", 6)
end)

-- delivery beacon
local beacon = nil
local function clearBeacon()
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
end

local function showBeacon(targetIndex: number)
	clearBeacon()
	local t = WorldLayout.DELIVERY_TARGETS[targetIndex]
	if not t then
		return
	end
	beacon = Instance.new("Part")
	beacon.Name = "DeliveryBeacon"
	beacon.Size = Vector3.new(2.4, 90, 2.4)
	beacon.Position = Vector3.new(t.x, t.y + 45, t.z)
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.Transparency = 0.55
	beacon.Color = Color3.fromRGB(255, 160, 60)
	beacon.Material = Enum.Material.Neon
	beacon.Parent = workspace

	local plate = Instance.new("BillboardGui")
	plate.Size = UDim2.fromOffset(220, 34)
	plate.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	plate.AlwaysOnTop = true
	plate.Parent = beacon
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.SourceSansBold
	text.TextColor3 = Color3.fromRGB(255, 190, 90)
	text.Text = "Deliver Here"
	text.Parent = plate
end

Net.event("CONTRACT_ACT").OnClientEvent:Connect(function(payload)
	if payload.action == "Accepted" then
		toast(("Contract: deliver to %s. Pick up your package at the depot."):format(payload.address or "the address"), 5)
		setDeliverVisible(false, nil)
	elseif payload.action == "PickedUp" then
		setDeliverVisible(true, payload.target)
		if payload.targetPos then
			showBeacon(payload.target)
		end
	elseif payload.action == "Delivered" then
		clearBeacon()
		setDeliverVisible(false, nil)
	elseif payload.action == "Info" then
		toast(payload.text or "", 3)
	end
end)