-- DialogueService.lua — Marcus + dialogue trees (Phase 0 task 6, Phase 1 story seed)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local DataService = require(script.Parent.DataService)

local DialogueService = {}
DialogueService.Events = {
	MarcusTalked = Signal.new(),
}

local TREES = {
	MARCUS = {
		greet = {
			speaker = "Marcus",
			text = "New in Meridian, huh? Nice jacket. Take my advice — enjoy the good days while they last.",
			choices = {
				{ id = "city", text = "Tell me about Meridian" },
				{ id = "work", text = "Got any work?" },
				{ id = "news", text = "You hear that radio broadcast?" },
			},
		},
		city = {
			speaker = "Marcus",
			text = "Plaza's the heart of it. Find your corner of this city — make it yours before things get complicated.",
			choices = { { id = "back", text = "Back" } },
		},
		work = {
			speaker = "Marcus",
			text = "Courier Co. board is by the fountain. Deliveries, steady pay. Talk to the board, grab a package at the depot, drop it at the address. Simple.",
			choices = { { id = "ok", text = "On it" } },
			closes = true,
		},
		news = {
			speaker = "Marcus",
			text = "Radio's been strange lately. 'Unplanned outages near the harbor research facility.' Probably nothing. Probably.",
			choices = { { id = "ok", text = "...Right" } },
			closes = true,
		},
	},
}

local sessions = {} -- [Player] = { tree, node, talked }

local function send(player: Player, nodeId: string)
	local session = sessions[player]
	if not session then
		return
	end
	local tree = TREES[session.tree]
	local node = tree[nodeId]
	if not node then
		return
	end
	session.node = nodeId
	Net.fireTo(player, "DIALOGUE_OPEN", {
		speaker = node.speaker,
		text = node.text,
		choices = node.choices,
	})
end

local function closeAndMaybeMark(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	if session.tree == "MARCUS" and not session.talked then
		DataService.update(player, function(d)
			d.Missions.INTRO.Talked = true
		end)
		DialogueService.Events.MarcusTalked:Fire(player)
	end
end

function DialogueService.Init()
	task.spawn(function()
		local meridian = workspace:WaitForChild("Meridian", 30)
		local plaza = meridian:WaitForChild("Plaza", 30)
		local marcus = plaza:WaitForChild("Marcus", 30)
		local torso = marcus:WaitForChild("Torso", 30)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Talk"
		prompt.ObjectText = "Marcus"
		prompt.HoldDuration = 0.2
		prompt.RequiresLineOfSight = false
		prompt.Parent = torso
		prompt.Triggered:Connect(function(player)
			sessions[player] = { tree = "MARCUS", node = "greet", talked = false }
			send(player, "greet")
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)

	Net.event("DIALOGUE_RESPOND").OnServerEvent:Connect(function(player, choiceId)
		local session = sessions[player]
		if not session or type(choiceId) ~= "string" then
			return
		end
		local tree = TREES[session.tree]
		local node = tree and tree[session.node]
		if not node then
			return
		end
		local choice
		for _, c in ipairs(node.choices) do
			if c.id == choiceId then
				choice = c
			end
		end
		if not choice then
			return
		end
		if choiceId == "back" then
			send(player, session.node == "city" and "greet" or session.node)
			return
		end
		if node.closes or choice.id == "ok" then
			closeAndMaybeMark(player)
			return
		end
		local nextNode = tree[choiceId]
		if nextNode then
			send(player, choiceId)
		else
			closeAndMaybeMark(player)
		end
	end)
end

return DialogueService