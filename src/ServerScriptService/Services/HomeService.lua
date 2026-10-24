-- HomeService.lua — Apartment 3B home console: purchases spawn furniture (Phase 1)
-- Blueprint task 9: "Create one home with an interactable upgrade."

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local HomeDefinitions = require(ReplicatedStorage.Shared.Definitions.HomeDefinitions)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local HomeService = {}
HomeService.Events = {
	Opened = Signal.new(), -- (player)
	ItemBought = Signal.new(), -- (player, itemId)
}

local homeFolder

local function catalogFor(player: Player)
	local data = DataService.get(player)
	local owned = {}
	for _, id in ipairs(data.Home.Furniture or {}) do
		owned[id] = true
	end
	local out = {}
	for _, def in ipairs(HomeDefinitions.FURNITURE) do
		table.insert(out, {
			id = def.id,
			name = def.name,
			price = def.price,
			description = def.description,
			owned = owned[def.id] or false,
		})
	end
	return out
end

local function spawnFurniture(player: Player, def)
	local origin = WorldLayout.HOME_INTERIOR
	local folderName = "F_" .. tostring(player.UserId)
	local folder = homeFolder:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = homeFolder
	end
	for _, recipe in ipairs(def.recipes) do
		local part = Instance.new("Part")
		part.Name = def.id
		part.Size = Vector3.new(recipe.size[1], recipe.size[2], recipe.size[3])
		part.Position = Vector3.new(origin.x + recipe.pos[1], origin.y + recipe.pos[2], origin.z + recipe.pos[3])
		part.Color = Color3.fromRGB(recipe.color[1], recipe.color[2], recipe.color[3])
		part.Material = (Enum.Material :: any)[recipe.material] or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.Parent = folder

		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(120, 26)
		tag.StudsOffsetWorldSpace = Vector3.new(0, recipe.size[2], 0)
		tag.AlwaysOnTop = false
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.TextStrokeTransparency = 0.4
		text.Text = def.name .. " — " .. player.Name
		text.Parent = tag
		tag.Parent = part
		break -- one tag per definition, on its first recipe part
	end
end

function HomeService.open(player: Player)
	HomeService.Events.Opened:Fire(player)
	Net.fireTo(player, "HOME_ACT", { action = "Open", catalog = catalogFor(player) })
end

local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
	HomeService.open(player)
end

function HomeService.Init()
	task.spawn(function()
		local meridian = workspace:WaitForChild("Meridian", 30)
		local home = meridian:WaitForChild("Home", 30)
		local console = home:WaitForChild("HomeConsole", 30)
		homeFolder = Instance.new("Folder")
		homeFolder.Name = "Furniture"
		homeFolder.Parent = home

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open Home Console"
		prompt.ObjectText = "Apartment 3B"
		prompt.HoldDuration = 0.3
		prompt.RequiresLineOfSight = false
		prompt.Parent = console
		prompt.Triggered:Connect(onPromptTriggered)
	end)

	Net.event("HOME_ACT").OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" then
			return
		end
		local action = payload.action
		if action == "Buy" then
			local def = HomeDefinitions.find(payload.id)
			if not def then
				Net.fireTo(player, "TOAST", { text = "Unknown item.", duration = 3 })
				return
			end
			local data = DataService.get(player)
			if table.find(data.Home.Furniture, def.id) then
				Net.fireTo(player, "TOAST", { text = "Already owned.", duration = 3 })
				return
			end
			if not EconomyService.spend(player, def.price, "home:" .. def.id) then
				Net.fireTo(player, "TOAST", { text = "Not enough cash.", duration = 3 })
				return
			end
			DataService.update(player, function(d)
				table.insert(d.Home.Furniture, def.id)
			end)
			spawnFurniture(player, def)
			HomeService.Events.ItemBought:Fire(player, def.id)
			Net.fireTo(player, "TOAST", { text = def.name .. " delivered!", duration = 3 })
			HomeService.open(player) -- refresh
		end
	end)
end

return HomeService