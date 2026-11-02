-- ClanUI.client.lua — Phase 5/6: Clan Hall — found, join, donate, group
-- contracts, alliances, and the live territory board.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local ClanConfig = require(ReplicatedStorage.Shared.Configs.ClanConfig)
local UIKit = require(script.Parent.UIKit)

local panelGui, panel = UIKit.panel("ClanUI", UDim2.fromOffset(540, 440), UDim2.new(0.5, -270, 1, -480))
panel.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
panel.BackgroundTransparency = 0.08
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 210, 130)
stroke.Transparency = 0.55
stroke.Parent = panel
panelGui.DisplayOrder = 27
panelGui.Enabled = false

local title = UIKit.label(panel, "CLAN HALL — survive together, rebuild together", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 8), 17, Color3.fromRGB(255, 214, 130))
title.LayoutOrder = 0

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -24, 1, -48)
body.Position = UDim2.fromOffset(12, 40)
body.BackgroundTransparency = 1
body.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = body

-- ------------------------------------------------------------- mine row ----
local mineRow = Instance.new("Frame")
mineRow.Size = UDim2.new(1, 0, 0, 58)
mineRow.BackgroundColor3 = Color3.fromRGB(33, 44, 63)
mineRow.BorderSizePixel = 0
mineRow.LayoutOrder = 0
mineRow.Parent = body
UIKit.corner(mineRow, 6)

local mineText = UIKit.label(mineRow, "You are clanless — found a clan ($500 + 20 scrap) or join one below.", UDim2.new(1, -16, 1, -34), UDim2.fromOffset(8, 5), 13, Color3.fromRGB(230, 238, 220))
mineText.TextXAlignment = Enum.TextXAlignment.Left
mineText.LayoutOrder = 0

local function smallButton(parent, text, x, w, onClick, color)
	local b = UIKit.button(parent, text, UDim2.fromOffset(w, 26), UDim2.new(0, x, 1, -30), onClick)
	b.TextSize = 13
	if color then
		b.BackgroundColor3 = color
	end
	return b
end

local function input(parent, placeholder, x, w)
	local box = Instance.new("TextBox")
	box.Size = UDim2.fromOffset(w, 26)
	box.Position = UDim2.new(0, x, 1, -30)
	box.BackgroundColor3 = Color3.fromRGB(44, 56, 78)
	box.TextColor3 = Color3.fromRGB(235, 240, 250)
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Color3.fromRGB(120, 128, 140)
	box.Font = Enum.Font.Gotham
	box.TextSize = 13
	box.ClearTextOnFocus = false
	box.Parent = parent
	UIKit.corner(box, 4)
	return box
end

local nameBox = input(mineRow, "clan name", 8, 150)
local tagBox = input(mineRow, "TAG", 164, 60)
local foundBtn = smallButton(mineRow, "Found clan ($)", 232, 120, function()
	Net.event("CLAN_ACT"):FireServer({ action = "Create", name = nameBox.Text, tag = tagBox.Text })
end, Color3.fromRGB(240, 160, 60))

local donateBox = input(mineRow, "donate $", 8, 110)
local donateBtn = smallButton(mineRow, "Donate", 126, 100, function()
	Net.event("CLAN_ACT"):FireServer({ action = "Donate", amount = tonumber(donateBox.Text) or 0 })
end, Color3.fromRGB(160, 130, 60))
local contractBtn = smallButton(mineRow, "Start group contract", 234, 150, function()
	Net.event("CLAN_ACT"):FireServer({ action = "Contract" })
end, Color3.fromRGB(70, 90, 200))
local leaveBtn = smallButton(mineRow, "Leave clan", 392, 92, function()
	Net.event("CLAN_ACT"):FireServer({ action = "Leave" })
end, Color3.fromRGB(150, 70, 70))

local function setFounderMode(isMember: boolean)
	nameBox.Visible = not isMember
	tagBox.Visible = not isMember
	foundBtn.Visible = not isMember
	donateBox.Visible = isMember
	donateBtn.Visible = isMember
	contractBtn.Visible = isMember
	leaveBtn.Visible = isMember
end

-- ------------------------------------------------------------ ally row ----
local allyRow = Instance.new("Frame")
allyRow.Size = UDim2.new(1, 0, 0, 30)
allyRow.BackgroundColor3 = Color3.fromRGB(29, 39, 55)
allyRow.BorderSizePixel = 0
allyRow.LayoutOrder = 1
allyRow.Parent = body
UIKit.corner(allyRow, 6)

local allyText = UIKit.label(allyRow, "Alliances — founders only, max 2: allied clans capture zones faster and share bonuses", UDim2.new(0.58, 0, 1, -4), UDim2.fromOffset(8, 2), 12, Color3.fromRGB(200, 210, 225))
allyText.TextXAlignment = Enum.TextXAlignment.Left
allyText.LayoutOrder = 0

local acceptBtn = smallButton(allyRow, "Accept offer", 330, 100, function()
	if state.Offer then
		Net.event("CLAN_ACT"):FireServer({ action = "AllyAccept", id = state.Offer.Id })
	end
end, Color3.fromRGB(90, 160, 90))
acceptBtn.Visible = false
local breakBtn = smallButton(allyRow, "Break ally", 438, 90, function()
	if state.Mine and state.Mine.AllyIds and state.Mine.AllyIds[1] then
		Net.event("CLAN_ACT"):FireServer({ action = "AllyBreak", id = state.Mine.AllyIds[1] })
	end
end, Color3.fromRGB(150, 70, 70))
breakBtn.Visible = false

-- ---------------------------------------------------------- clan list ----
local clansFrame = Instance.new("Frame")
clansFrame.Size = UDim2.new(1, 0, 0, 148)
clansFrame.BackgroundTransparency = 1
clansFrame.LayoutOrder = 2
clansFrame.Parent = body
local clanList = Instance.new("UIListLayout")
clanList.Padding = UDim.new(0, 3)
clanList.Parent = clansFrame

-- ------------------------------------------------------- territory rows ----
local zoneHeader = UIKit.label(body, "TERRITORY — park your clan in a zone to drain the banner and flip ownership", UDim2.new(1, -16, 0, 16), UDim2.fromOffset(8, 2), 12, Color3.fromRGB(255, 214, 130))
zoneHeader.LayoutOrder = 3

local zonesFrame = Instance.new("Frame")
zonesFrame.Size = UDim2.new(1, 0, 0, 86)
zonesFrame.BackgroundTransparency = 1
zonesFrame.LayoutOrder = 4
zonesFrame.Parent = body
local zoneList = Instance.new("UIListLayout")
zoneList.Padding = UDim.new(0, 3)
zoneList.Parent = zonesFrame

local state = {
	Clans = {},
	MemberOf = nil,
	Donated = 0,
	Mine = nil,
	Offer = nil,
	Zones = {},
}

-- ------------------------------------------------------------- rendering ----
local function syncClans()
	for _, child in ipairs(clansFrame:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local shown = 0
	for _, clan in ipairs(state.Clans) do
		if clan.Id ~= state.MemberOf then
			shown += 1
			if shown <= 4 then
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 34)
				row.BackgroundColor3 = Color3.fromRGB(25, 33, 48)
				row.BorderSizePixel = 0
				row.LayoutOrder = shown
				row.Parent = clansFrame
				UIKit.corner(row, 6)
				local label = UIKit.label(row, ("[%s] %s — %d members — bank $%d%s%s"):format(
					clan.Tag, clan.Name, clan.Members, clan.Bank,
					clan.Contract and ("  — contract %d/%d"):format(clan.Contract.Progress, clan.Contract.Required) or "",
					clan.Allied ~= nil and clan.Allied ~= "" and ("  — allied " .. clan.Allied) or ""),
					UDim2.new(0.68, 0, 1, -8), UDim2.fromOffset(8, 5), 12, Color3.fromRGB(220, 228, 238))
				label.TextXAlignment = Enum.TextXAlignment.Left
				if not state.MemberOf then
					smallButton(row, "Join", 380, 90, function()
						Net.event("CLAN_ACT"):FireServer({ action = "Join", id = clan.Id })
					end, Color3.fromRGB(240, 160, 60))
				else
					smallButton(row, "Ally", 384, 86, function()
						Net.event("CLAN_ACT"):FireServer({ action = "AllyOffer", id = clan.Id })
					end, Color3.fromRGB(120, 100, 200)).Visible = state.Mine ~= nil and state.Mine.Leader == true
				end
			end
		end
	end
	if shown == 0 then
		local empty = UIKit.label(clansFrame, state.MemberOf and "Your clan stands alone in Meridian — allies and rivals appear here." or "No clans yet — be the first founder.", UDim2.new(1, -8, 1, -8), UDim2.fromOffset(8, 5), 13, Color3.fromRGB(130, 138, 150))
		empty.TextXAlignment = Enum.TextXAlignment.Left
	end
end

local function syncZones()
	for _, child in ipairs(zonesFrame:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	for i, zone in ipairs(state.Zones) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 26)
		row.BackgroundColor3 = Color3.fromRGB(25, 33, 48)
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = zonesFrame
		UIKit.corner(row, 6)
		local label = UIKit.label(row, ("%s — banner: %s"):format(zone.Name, zone.OwnerTag or "FREE"),
			UDim2.new(1, -16, 1, -4), UDim2.fromOffset(8, 2), 12, Color3.fromRGB(215, 222, 232))
		label.TextXAlignment = Enum.TextXAlignment.Left
	end
end

local function syncMine()
	if state.Mine then
		local mine = state.Mine
		mineText.Text = ("[%s] %s — bank $%d%s%s — donated by you $%d %s"):format(
			mine.Tag, mine.Name, mine.Bank,
			mine.Contract and ("  — group contract %d/%d (deliver ANY package, it counts!)"):format(mine.Contract.Progress, mine.Contract.Required) or "",
			mine.Allies ~= nil and mine.Allies ~= "" and ("  — allies: " .. mine.Allies) or "",
			state.Donated,
			mine.Members >= ClanConfig.MEMBER_CAP and "(full)" or ("(%d/%d members)"):format(mine.Members, ClanConfig.MEMBER_CAP))
		contractBtn.Visible = mine.Contract == nil
		setFounderMode(true)
		local leader = mine.Leader == true
		acceptBtn.Visible = leader and state.Offer ~= nil
		if acceptBtn.Visible and state.Offer then
			acceptBtn.Text = ("Accept [%s]"):format(state.Offer.Tag)
		end
		breakBtn.Visible = leader and mine.AllyIds ~= nil and #mine.AllyIds > 0
	else
		mineText.Text = "You are clanless — found a clan ($500 + 20 scrap) or join one in the list."
		setFounderMode(false)
		acceptBtn.Visible = false
		breakBtn.Visible = false
		state.Offer = nil
	end
	syncClans()
	syncZones()
end

-- ------------------------------------------------------------- sync in ----
Net.event("CLAN_SYNC").OnClientEvent:Connect(function(payload)
	local isData = payload.Clans ~= nil
	if payload.Open then
		panelGui.Enabled = not panelGui.Enabled
	end
	if isData then
		state.Clans = payload.Clans
		state.MemberOf = payload.MemberOf
		state.Donated = payload.Donated or 0
		state.Mine = payload.Mine
		state.Offer = payload.Offer
	end
	if panelGui.Enabled then
		syncMine()
	end
end)

Net.event("TERRITORY_SYNC").OnClientEvent:Connect(function(payload)
	if payload.Zones then
		state.Zones = payload.Zones
	end
	if panelGui.Enabled then
		syncZones()
	end
end)