export type CleanupItem = RBXScriptConnection | Tween | Instance | (() -> ())

export type EffectBase = {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { CleanupItem },
	_ownedInstances: { Instance },

	BeginRun: (self: EffectBase) -> number,
	IsAlive: (self: EffectBase, token: number) -> boolean,
	Track: (self: EffectBase, item: CleanupItem) -> CleanupItem,
	TrackTween: (self: EffectBase, tween: Tween) -> Tween,
	TrackConnection: (self: EffectBase, connection: RBXScriptConnection) -> RBXScriptConnection,
	Own: (self: EffectBase, instance: Instance?) -> Instance?,
	Cancel: (self: EffectBase) -> (),
	Destroy: (self: EffectBase) -> (),
	Finish: (self: EffectBase) -> (),
	GetInstance: (self: EffectBase) -> Instance?,
	GetTarget: (self: EffectBase) -> Instance?,
	IsDestroyed: (self: EffectBase) -> boolean,
}

local EffectBase = {}
EffectBase.__index = EffectBase

local function cleanup(item: CleanupItem)
	local kind = typeof(item)

	if kind == "RBXScriptConnection" then
		pcall(function()
			(item :: RBXScriptConnection):Disconnect()
		end)
		return
	end

	if kind == "Instance" then
		pcall(function()
			(item :: Instance):Destroy()
		end)
		return
	end

	if kind == "function" then
		pcall(item :: () -> ())
		return
	end

	pcall(function()
		(item :: any):Cancel()
	end)
end

function EffectBase.new(destroyOnEnd: boolean?): EffectBase
	local self = setmetatable({}, EffectBase) :: any

	self.DestroyOnEnd = if destroyOnEnd == nil then true else destroyOnEnd
	self.OnEnd = nil

	self._destroyed = false
	self._token = 0
	self._cleanups = {}
	self._ownedInstances = {}

	return self
end

function EffectBase:BeginRun(): number
	self._token += 1
	return self._token
end

function EffectBase:IsAlive(token: number): boolean
	return not self._destroyed and self._token == token
end

function EffectBase:IsDestroyed(): boolean
	return self._destroyed
end

function EffectBase:Track(item: CleanupItem): CleanupItem
	if self._destroyed then
		cleanup(item)
		return item
	end

	table.insert(self._cleanups, item)
	return item
end

function EffectBase:TrackTween(tween: Tween): Tween
	self:Track(tween)
	return tween
end

function EffectBase:TrackConnection(connection: RBXScriptConnection): RBXScriptConnection
	self:Track(connection)
	return connection
end

function EffectBase:Own(instance: Instance?): Instance?
	if not instance then
		return nil
	end

	table.insert(self._ownedInstances, instance)
	self:Track(instance)
	return instance
end

function EffectBase:GetInstance(): Instance?
	return nil
end

function EffectBase:GetTarget(): Instance?
	return nil
end

function EffectBase:Cancel()
	if self._destroyed then
		return
	end

	self._token += 1

	for i = #self._cleanups, 1, -1 do
		cleanup(self._cleanups[i])
	end

	table.clear(self._cleanups)
	table.clear(self._ownedInstances)
end

function EffectBase:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()
	self.OnEnd = nil
	self._destroyed = true
end

function EffectBase:Finish()
	if self._destroyed then
		return
	end

	local onEnd = self.OnEnd

	if self.DestroyOnEnd then
		self.OnEnd = nil
	end

	if onEnd then
		task.spawn(function()
			local ok, err = pcall(onEnd, self)
			if not ok then
				warn("[RoJuice] OnEnd error:", err)
			end
		end)
	end

	if self.DestroyOnEnd then
		self:Destroy()
	end
end

return EffectBase
