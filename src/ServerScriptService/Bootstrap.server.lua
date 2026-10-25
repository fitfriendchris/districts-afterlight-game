-- Bootstrap.server.lua — service registration + world ambience
-- Blueprint Phase 0: establish services in a fixed order.

local Lighting = game:GetService("Lighting")

-- Golden hour ambience for the "good days" (world reacts later in CampaignService)
pcall(function()
	Lighting.ClockTime = 16.5
	Lighting.Brightness = 2.6
	Lighting.OutdoorAmbient = Color3.fromRGB(118, 114, 128)
	Lighting.Ambient = Color3.fromRGB(42, 42, 48)
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(200, 180, 170)
	Lighting.FogEnd = 1200
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
end)

local services = script.Parent:WaitForChild("Services")

local ORDER = {
	"DataService",
	"EconomyService",
	"CampaignService",
	"VehicleService",
	"HomeService",
	"ShopService",
	"SurvivalService",
	"InfectedService",
	"HeroService",
	"SettlementService",
	"ContractService",
	"ClanService",
	"DialogueService",
	"MissionService",
}

for _, name in ipairs(ORDER) do
	local module = require(services:WaitForChild(name))
	if module.Init then
		module.Init()
	end
end

print("[Districts: Afterlight] services initialized: " .. table.concat(ORDER, ", "))