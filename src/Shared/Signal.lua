--!strict
-- Lightweight signal implementation (similar API to RBXScriptSignal).

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
	Destroy: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	Destroy: (self: Signal<T...>) -> (),
}

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} :: { [any]: (T...) -> () } }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local connection = { Connected = true }
	handlers[connection] = fn

	function connection.Disconnect(conn)
		conn.Connected = false
		handlers[conn] = nil
	end
	connection.Destroy = connection.Disconnect

	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	for _, fn in pairs(self._handlers) do
		task.spawn(fn, ...)
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Destroy()
	table.clear(self._handlers)
end

return Signal
