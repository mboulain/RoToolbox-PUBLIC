local Signal = {}
Signal.__index = Signal

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = typeof(setmetatable({} :: {
	_destroyed: boolean,
	_listeners: { [number]: (T...) -> () },
	_nextId: number,
}, Signal))

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({}, Signal)

	self._destroyed = false
	self._listeners = {}
	self._nextId = 0

	return self
end

function Signal:Connect<T...>(callback: (T...) -> ()): Connection
	assert(not self._destroyed, "Cannot connect to a destroyed Signal.")
	assert(type(callback) == "function", "Signal:Connect(callback) expects a function.")

	self._nextId += 1
	local id = self._nextId
	self._listeners[id] = callback

	local connection = {
		Connected = true,
	}

	local parentSignal = self

	function connection:Disconnect()
		if not self.Connected then
			return
		end

		self.Connected = false
		parentSignal._listeners[id] = nil
	end

	return connection
end

function Signal:Fire<T...>(...: T...)
	if self._destroyed then
		return
	end

	for _, callback in self._listeners do
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[RoSpeech.Signal] Listener error: " .. tostring(err))
		end
	end
end

function Signal:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	table.clear(self._listeners)
end

return Signal