-- ShopService.lua — Meridian Outfitters: cash-only cosmetics (Phase 1)
-- No gacha, no gamepasses yet: deterministic catalog per blueprint §10F.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local ItemDefinitions = require(ReplicatedStorage.Shared.Definitions.ItemDefinitions)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local VehicleService = require(script.Parent.VehicleService)

local ShopService = {}

local shopConsole

local function ownedMap(player: Player)
	local data = DataService.get(player)
	local owned = {}
	for _, id in ipairs(data.Cosmetics.Owned or {}) do
		owned[id] = true
	end
	return owned
end

local function openPayload(player: Player)
	local owned = ownedMap(player)
	local cosmetics = DataService.get(player).Cosmetics
	local items = {}
	for _, def in ipairs(ItemDefinitions.CATALOG) do
		table.insert(items, { id = def.id, kind = def.kind, name = def.name, price = def.price, owned = owned[def.id] or false })
	end
	local colors = {}
	for _, jc in ipairs(ItemDefinitions.JACKET_COLORS) do
		table.insert(colors, {
			id = jc.id,
			name = jc.name,
			color = { jc.color.R * 255, jc.color.G * 255, jc.color.B * 255 },
			active = cosmetics.Equipped.JacketColor == jc.id,
		})
	end
	return { action = "Open", items = items, jacketColors = colors, cash = DataService.get(player).Cash }
end

local function applyJacket(player: Player, color: Color3)
	local character = player.Character
	if not character then
		return
	end
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if not bodyColors then
		bodyColors = Instance.new("BodyColors")
		bodyColors.Parent = character
	end
	bodyColors.TorsoColor3 = color
	bodyColors.LeftArmColor3 = color
	bodyColors.RightArmColor3 = color
end

function ShopService.Init()
	task.spawn(function()
		local meridian = workspace:WaitForChild("Meridian", 30)
		local shop = meridian:WaitForChild("Shop", 30)
		shopConsole = shop:WaitForChild("ShopConsole", 30)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Browse Shop"
		prompt.ObjectText = "Meridian Outfitters"
		prompt.HoldDuration = 0.3
		prompt.RequiresLineOfSight = false
		prompt.Parent = shopConsole
		prompt.Triggered:Connect(function(player)
			Net.fireTo(player, "SHOP_ACT", openPayload(player))
		end)
	end)

	-- paint a freshly claimed van with the player's equipped wrap
	VehicleService.Events.VanClaimed:Connect(function(player, van)
		local data = DataService.get(player)
		local wrapId = data.Cosmetics.Equipped.VanWrap
		if wrapId then
			local def = ItemDefinitions.find(wrapId)
			if def and def.kind == "vanWrap" then
				VehicleService.applyPaint(player, def.color)
			end
		end
		local nameplate = Instance.new("BillboardGui")
		nameplate.Name = "OwnerPlate"
		nameplate.Size = UDim2.fromOffset(150, 30)
		nameplate.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
		nameplate.AlwaysOnTop = false
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 230, 160)
		text.Text = player.Name .. "'s Van"
		text.Parent = nameplate
		local chassisForPlate = van:FindFirstChild("Chassis")
		if chassisForPlate then
			nameplate.Parent = chassisForPlate
		else
			nameplate.Parent = van
		end
	end)

	Net.event("SHOP_ACT").OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" then
			return
		end
		local action = payload.action
		if action == "Buy" then
			local def = ItemDefinitions.find(payload.id)
			if not def then
				return
			end
			local owned = ownedMap(player)
			if owned[def.id] then
				Net.fireTo(player, "TOAST", { text = "Already owned.", duration = 3 })
				return
			end
			if not EconomyService.spend(player, def.price, "shop:" .. def.id) then
				Net.fireTo(player, "TOAST", { text = "Not enough cash.", duration = 3 })
				return
			end
			DataService.update(player, function(data)
				table.insert(data.Cosmetics.Owned, def.id)
				if def.kind == "vanWrap" then
					data.Cosmetics.Equipped.VanWrap = def.id
				end
			end)
			if def.kind == "vanWrap" then
				VehicleService.applyPaint(player, def.color)
			elseif def.kind == "jacket" then
				applyJacket(player, Color3.fromRGB(178, 44, 44))
			end
			Net.fireTo(player, "TOAST", { text = def.name .. " purchased!", duration = 3 })
			Net.fireTo(player, "SHOP_ACT", openPayload(player))
		elseif action == "Equip" then
			local data = DataService.get(player)
			if payload.slot == "jacketColor" then
				if table.find(data.Cosmetics.Owned, "JACKET") then
					local chosen = nil
					for _, jc in ipairs(ItemDefinitions.JACKET_COLORS) do
						if jc.id == payload.id then
							chosen = jc
						end
					end
					if chosen then
						DataService.update(player, function(d)
							d.Cosmetics.Equipped.JacketColor = chosen.id
						end)
						applyJacket(player, chosen.color)
						Net.fireTo(player, "SHOP_ACT", openPayload(player))
					end
				end
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.5)
			local data = DataService.get(player)
			if data and table.find(data.Cosmetics.Owned, "JACKET") then
				local jc = data.Cosmetics.Equipped.JacketColor or "JK_CRIMSON"
				for _, item in ipairs(ItemDefinitions.JACKET_COLORS) do
					if item.id == jc then
						applyJacket(player, item.color)
					end
				end
			end
		end)
	end)
end

return ShopService