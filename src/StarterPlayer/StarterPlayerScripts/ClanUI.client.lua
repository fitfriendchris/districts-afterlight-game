-- ClanUI.client.lua — Phase 5: Clan Hall — found, join, donate, group contracts
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local ClanConfig = require(ReplicatedStorage.Shared.Configs.ClanConfig)
local UIKit = require(script.Parent.UIKit)

local panelGui, panel = UIKit.panel("ClanUI", UDim2.fromOffset(540, 420), UDim2.new(0.5, -270, 1, -460))
panel.BackgroundColor3 = Color3.fromRGB(16, 17, 21)
panel.BackgroundTransparency = 0.08
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 210, 130)
stroke.Transparency = 0.55
stroke.Parent = panel
panelGui.DisplayOrder = 27
panelGui.Enabled = false

local title = UIKit.label(panel, "CLAN HALL — survive together, rebuild together", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 8), 17, Color3.fromRGB(255, 214, 130))
title.LayoutOrder = 0

local mineRow = Instance.new("Frame")
mineRow.Size = UDim2.new(1, 0, 0, 58)
mineRow.BackgroundColor3 = Color3.fromRGB(26, 30, 40)
mineRow.BorderSizePixel = 0
mineRow.LayoutOrder = 0
UIKit.corner(mineRow, 6)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -24, 1, -48)
body.Position = UDim2.fromOffset(12, 40)
body.BackgroundTransparency = 1
body.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = body

mineRow.Parent = body

local mineText = UIKit.label(mineRow, "You are clanless — found a clan ($500 + 20 scrap) or join one below.", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 5), 13, Color3.fromRGB(230, 238, 220))
mineText.LayoutOrder = 0

local clansFrame = Instance.new("Frame")
clansFrame.Size = UDim2.new(1, 0, 0, 300)
clansFrame.BackgroundTransparency = 1
clansFrame.LayoutOrder = 1
clansFrame.Parent = body
local clanList = Instance.new("UIListLayout")
clanList.Padding = UDim.new(0, 3)
clanList.Parent = clansFrame

local state = {
	Clans = {},
	MemberOf = nil,
	Donated = 0,
}

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
	box.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
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

-- founder row lives inside mineRow only when clanless
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
local leaveBtn = smallButton(mineRow, "Leave clan", 392, 100, function()
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
			if shown <= 6 then
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 32)
				row.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
				row.BorderSizePixel = 0
				row.LayoutOrder = shown
				row.Parent = clansFrame
				UIKit.corner(row, 6)
				local label = UIKit.label(row, ("[%s] %s — %d members — bank $%d%s"):format(clan.Tag, clan.Name, clan.Members, clan.Bank, clan.Contract and ("  — contract %d/%d"):format(clan.Contract.Progress, clan.Contract.Required) or ""), UDim2.new(0.7, 0, 1, -8), UDim2.fromOffset(8, 5), 13, Color3.fromRGB(220, 228, 238))
				label.TextXAlignment = Enum.TextXAlignment.Left
				if not state.MemberOf then
					smallButton(row, "Join", 380, 90, function()
						Net.event("CLAN_ACT"):FireServer({ action = "Join", id = clan.Id })
					end, Color3.fromRGB(240, 160, 60))
				end
			end
		end
	end
	if shown == 0 then
		local empty = UIKit.label(clansFrame, state.MemberOf and "Your clan is in this list — members see bank + contract here." or "No clans yet — be the first founder.", UDim2.new(1, -8, 1, -8), UDim2.fromOffset(8, 5), 13, Color3.fromRGB(130, 138, 150))
		empty.TextXAlignment = Enum.TextXAlignment.Left
	end
end

local function syncMine()
	if state.MemberOf then
		local mine = nil
		for _, clan in ipairs(state.Clans) do
			if clan.Id == state.MemberOf then
				mine = clan
				break
			end
		end
		if mine then
			mineText.Text = ("[%s] %s — bank $%d%s — donated by you $%d %s"):format(
				mine.Tag, mine.Name, mine.Bank,
				mine.Contract and ("  — group contract %d/%d (deliver ANY package, it counts!)"):format(mine.Contract.Progress, mine.Contract.Required) or "",
				state.Donated,
				mine.Members >= ClanConfig.MEMBER_CAP and "(full)" or ("(%d/%d members)"):format(mine.Members, ClanConfig.MEMBER_CAP))
			contractBtn.Visible = mine.Contract == nil
			donateBtn.Visible = true
		else
			mineText.Text = ("You were in clan #%d — it has dissolved."):format(state.MemberOf)
		end
	else
		mineText.Text = "You are clanless — found a clan ($500 + 20 scrap) or join one in the list."
	end
	setFounderMode(state.MemberOf ~= nil)
	syncClans()
end

-- data payloads carry Clans; openBoard sends ONE payload with Open + data together
Net.event("CLAN_SYNC").OnClientEvent:Connect(function(payload)
	local isData = payload.Clans ~= nil
	if payload.Open then
		panelGui.Enabled = not panelGui.Enabled
	end
	if isData then
		state.Clans = payload.Clans
		state.MemberOf = payload.MemberOf
		state.Donated = payload.Donated or 0
	end
	if panelGui.Enabled then
		syncMine()
	end
end)