--!strict
-- MonetizationService.lua — Phase 8: server-authoritative monetization.
-- ALL grants live here: developer-product receipts are validated, recorded
-- (idempotent per PurchaseId) and awarded; the Supporter game pass is
-- resolved once per join and wired into ContractService via a hook slot.
-- Dormant pre-publish: nil product/pass IDs make every prompt a no-op.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local DataService = require(ServerScriptService.Services.DataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local ContractService = require(ServerScriptService.Services.ContractService) -- one-way: no cycle

local cfg = MonetizationConfig
local MonetizationService = {}

-- --------------------------------------------------------------- grants ----
local function grant_product(player: Player, product)
	if product.Kind == "Cash" then
		EconomyService.award(player, product.Amount, 0, "devproduct_cash")
		Net.event("TOAST"):FireClient(player, { text = "+" .. tostring(product.Amount) .. " CASH — thank you for supporting Meridian", duration = 5 })
	elseif product.Kind == "Supplies" then
		DataService.update(player, function(d)
			d.Inventory.Medical = (d.Inventory.Medical or 0) + (product.Medical or 5)
			d.Inventory.Scrap = (d.Inventory.Scrap or 0) + (product.Scrap or 20)
		end)
		Net.event("TOAST"):FireClient(player, { text = "SUPPLY DROP RECEIVED — medical + scrap restocked", duration = 5 })
	end
end

-- ---------------------------------------------------------- receipts -------
local function processReceipt(player: Player, receipt): boolean
	local product = cfg.PRODUCTS[receipt.ProductId]
	if not product then
		return false -- unknown id: not granted (Roblox retries later)
	end
	local key = receipt.PurchaseId
		or (tostring(receipt.PlayerId) .. ":" .. tostring(receipt.ProductId) .. ":" .. tostring(receipt.TimePurchased))
	local isNew = nil
	DataService.update(player, function(d)
		if not d.Monetization.Receipts[key] then
			d.Monetization.Receipts[key] = true
			isNew = true
		end
	end)
	if isNew then
		grant_product(player, product)
	end
	return true
end

-- ------------------------------------------------------ supporter pass ----
local function passMult(player: Player): number
	local data = DataService.get(player)
	if data and data.Monetization.SupporterPass then
		return cfg.SUPPORTER_MULT
	end
	return 1.0
end

local function resolvePass(player: Player, data)
	local id = cfg.SUPPORTER_PASS_ID
	if not id then
		return -- dormant until published
	end
	local owns = false
	pcall(function()
		owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	data.Monetization.SupporterPass = owns
	if owns then
		Net.event("TOAST"):FireClient(player, { text = "SUPPORTER — contract payouts boosted", duration = 4 })
	end
end

-- ------------------------------------------------------------------ init ----
function MonetizationService.Init()
	-- ContractService hook slot: supporter payout multiplier
	ContractService.SupporterMultSlot = passMult

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, res = pcall(processReceipt, player, receipt)
		if not ok then
			warn("[MonetizationService] receipt error: " .. tostring(res))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if res then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- pass resolution once per join (before first delivery can benefit)
	DataService.Events.ProfileLoaded:Connect(function(player, data)
		resolvePass(player, data)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		local data = DataService.get(p)
		if data then
			resolvePass(p, data)
		end
	end

	-- support terminal prompt (part built by build_place.py, prompt added here)
	task.delay(3, function()
		local meridian = workspace:FindFirstChild("Meridian")
		local terminal = meridian and meridian:FindFirstChild("SupportTerminal", true)
		if not (terminal and terminal:IsA("BasePart")) then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Support Meridian"
		prompt.ObjectText = "Support Terminal"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.1
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.Parent = terminal
		prompt.Triggered:Connect(function(player)
			local ids = {}
			for pid in pairs(cfg.PRODUCTS) do
				table.insert(ids, pid)
			end
			if #ids == 0 then
				Net.event("TOAST"):FireClient(player, { text = "Support options arrive after launch — stay tuned", duration = 4 })
				return
			end
			MarketplaceService:PromptProductPurchase(player, ids[1])
		end)
	end)
end

return MonetizationService