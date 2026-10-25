--!strict
-- WorldFX.server.lua — Phase 9: ambient particles. Built-in rbxasset textures
-- render on every client; custom art can be swapped in after publishing.

local function meridian(): Instance
	return workspace:WaitForChild("Meridian", 30)
end

-- fountain sparkle shimmer ------------------------------------------------
task.spawn(function()
	local orb = meridian():FindFirstChild("FountainOrb", true)
	if orb and orb:IsA("BasePart") then
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fx.Rate = 6
		fx.Lifetime = NumberRange.new(0.6, 1.3)
		fx.Speed = NumberRange.new(0.4, 0.9)
		fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.15) })
		fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		fx.Color = ColorSequence.new(Color3.fromRGB(210, 230, 255))
		fx.LightEmission = 0.7
		fx.Parent = orb
	end
end)

-- infected spawn-point smoke ---------------------------------------------
task.spawn(function()
	local spawns = meridian():FindFirstChild("InfectedSpawns", true)
	if spawns then
		for _, marker in ipairs(spawns:GetChildren()) do
			if marker:IsA("BasePart") then
				local fx = Instance.new("ParticleEmitter")
				fx.Texture = "rbxasset://textures/particles/smoke_main.dds"
				fx.Rate = 1.5
				fx.Lifetime = NumberRange.new(3, 5)
				fx.Speed = NumberRange.new(0.2, 0.5)
				fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 5) })
				fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
				fx.Color = ColorSequence.new(Color3.fromRGB(58, 68, 58))
				fx.SpreadAngle = Vector2.new(70, 70)
				fx.Parent = marker
			end
		end
	end
end)

-- depot dust drift --------------------------------------------------------
task.spawn(function()
	local depot = meridian():FindFirstChild("PackageDepot", true)
	if depot and depot:IsA("BasePart") then
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = "rbxasset://textures/particles/smoke_main.dds"
		fx.Rate = 2
		fx.Lifetime = NumberRange.new(2.5, 4.5)
		fx.Speed = NumberRange.new(0.2, 0.6)
		fx.Acceleration = Vector3.new(0.6, 0.05, 0.2)
		fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 4.4) })
		fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 1) })
		fx.Color = ColorSequence.new(Color3.fromRGB(172, 158, 132))
		fx.SpreadAngle = Vector2.new(65, 65)
		fx.LightInfluence = 1
		fx.Parent = depot
	end
end)