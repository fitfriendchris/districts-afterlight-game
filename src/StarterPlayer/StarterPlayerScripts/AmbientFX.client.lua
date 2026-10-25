--!strict
-- AmbientFX.client.lua — Phase 9: subtle world motion.
-- Neon glow sources (lamps, fountain orb, screens) breathe instead of sitting flat.

local TweenService = game:GetService("TweenService")

task.spawn(function()
	local root = workspace:WaitForChild("Meridian", 20)
	if not root then
		return
	end
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Material == Enum.Material.Neon then
			local base = inst.Color
			local to = Color3.new(
				math.min(base.R * 1.25, 1),
				math.min(base.G * 1.25, 1),
				math.min(base.B * 1.25, 1)
			)
			local info = TweenInfo.new(
				1.6 + math.random() * 0.8,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1, -- infinite
				true, -- reverse
				math.random() * 2 -- stagger
			)
			TweenService:Create(inst, info, { Color = to }):Play()
		end
	end
end)