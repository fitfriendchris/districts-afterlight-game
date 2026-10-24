-- Signal.lua — tiny dependency-free signal for service-to-service events
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	table.insert(self._handlers, fn)
	return {
		Disconnect = function()
			local i = table.find(self._handlers, fn)
			if i then table.remove(self._handlers, i) end
		end,
	}
end

function Signal:Fire(...)
	local snapshot = table.clone(self._handlers)
	for _, fn in ipairs(snapshot) do
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Signal] handler error: " .. tostring(err))
		end
	end
end

return Signal