local Signal = require(script.Parent.Signal)

local ObservableValue = {}
ObservableValue.__index = ObservableValue

export type ObservableValue<T> = typeof(setmetatable({} :: {
	_value: T,
	_changed: any,
}, ObservableValue))

function ObservableValue.new<T>(initialValue: T): ObservableValue<T>
	local self = setmetatable({}, ObservableValue)

	self._value = initialValue
	self._changed = Signal.new()

	return self
end

function ObservableValue:Get()
	return self._value
end

function ObservableValue:Set(newValue)
	if self._value == newValue then
		return
	end

	self._value = newValue
	self._changed:Fire(newValue)
end

function ObservableValue:Observe(callback, fireImmediately: boolean?)
	assert(type(callback) == "function", "ObservableValue:Observe(callback) expects a function.")

	local connection = self._changed:Connect(callback)

	if fireImmediately ~= false then
		callback(self._value)
	end

	return connection
end

function ObservableValue:Destroy()
	self._changed:Destroy()
end

return ObservableValue