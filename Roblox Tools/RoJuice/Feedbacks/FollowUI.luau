--!strict
-- FollowUI (RoJuice)

local RunService = game:GetService("RunService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type FollowOptions = {
	Delay: number?,
	Duration: number?,

	Offset: UDim2?,

	SnapOnStart: boolean?,
	StopIfTargetRemoved: boolean?,

	EasingSpeed: number?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type FollowUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_follower: GuiObject,
	_target: any,
	_options: FollowOptions,

	_originalPosition: UDim2?,
}, {} :: any))

local FollowUI = {}
FollowUI.__index = FollowUI
setmetatable(FollowUI, { __index = EffectBase })

local DEFAULTS = {
	Delay = 0.12,
	Duration = nil,

	Offset = UDim2.fromOffset(0, 0),

	SnapOnStart = false,
	StopIfTargetRemoved = true,

	EasingSpeed = 16,
}

local function addUDim2(a: UDim2, b: UDim2): UDim2
	return UDim2.new(
		a.X.Scale + b.X.Scale,
		a.X.Offset + b.X.Offset,
		a.Y.Scale + b.Y.Scale,
		a.Y.Offset + b.Y.Offset
	)
end

local function lerpUDim2(a: UDim2, b: UDim2, alpha: number): UDim2
	return UDim2.new(
		a.X.Scale + (b.X.Scale - a.X.Scale) * alpha,
		a.X.Offset + (b.X.Offset - a.X.Offset) * alpha,
		a.Y.Scale + (b.Y.Scale - a.Y.Scale) * alpha,
		a.Y.Offset + (b.Y.Offset - a.Y.Offset) * alpha
	)
end

local function getTargetPosition(target: any): UDim2?
	if typeof(target) == "Instance" and target:IsA("GuiObject") then
		return target.Position
	end

	if typeof(target) == "table" and typeof(target.GetInstance) == "function" then
		local instance = target:GetInstance()
		if instance and instance:IsA("GuiObject") then
			return instance.Position
		end
	end

	local okX, x = pcall(function()
		return target.X
	end)

	local okY, y = pcall(function()
		return target.Y
	end)

	if okX and okY and typeof(x) == "number" and typeof(y) == "number" then
		return UDim2.fromOffset(x, y)
	end

	return nil
end

function FollowUI.new(follower: GuiObject, target: any, options: FollowOptions?): FollowUI
	assert(follower ~= nil, "FollowUI.new follower is nil")
	assert(follower:IsA("GuiObject"), "FollowUI.new follower must be a GuiObject")
	assert(target ~= nil, "FollowUI.new target is nil")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, FollowUI)

	self.OnEnd = opts.OnEnd
	self._follower = follower
	self._target = target
	self._options = opts

	self._originalPosition = nil

	return self
end

function FollowUI:GetInstance(): GuiObject?
	if self._destroyed then
		return nil
	end

	return self._follower
end

function FollowUI:GetTarget(): GuiObject
	return self._follower
end

function FollowUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)

	if self._originalPosition then
		self._follower.Position = self._originalPosition
	end
end

function FollowUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()
	self._destroyed = true
end

function FollowUI:Start(): FollowUI
	if self._destroyed then
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	self._originalPosition = self._follower.Position

	local delay = math.max(0, options.Delay or DEFAULTS.Delay)
	local duration = options.Duration
	local offset = options.Offset or DEFAULTS.Offset

	local snapOnStart = if options.SnapOnStart == nil then DEFAULTS.SnapOnStart else options.SnapOnStart
	local stopIfTargetRemoved = if options.StopIfTargetRemoved == nil then DEFAULTS.StopIfTargetRemoved else options.StopIfTargetRemoved

	local easingSpeed = math.max(0.01, options.EasingSpeed or DEFAULTS.EasingSpeed)

	local elapsed = 0
	local history: { { Time: number, Position: UDim2 } } = {}

	if snapOnStart then
		local rawPosition = getTargetPosition(self._target)
		if rawPosition then
			self._follower.Position = addUDim2(rawPosition, offset)
		end
	end

	local connection = RunService.RenderStepped:Connect(function(dt)
		if not self:IsAlive(token) then
			return
		end

		if self._follower.Parent == nil then
			self:Destroy()
			return
		end

		if typeof(self._target) == "Instance"
			and self._target:IsA("GuiObject")
			and self._target.Parent == nil
		then
			if stopIfTargetRemoved then
				self:Destroy()
			end
			return
		end

		elapsed += dt

		if duration ~= nil and elapsed >= duration then
			self:Finish()
			return
		end

		local rawPosition = getTargetPosition(self._target)
		if not rawPosition then
			return
		end

		local now = os.clock()
		local targetPosition = addUDim2(rawPosition, offset)

		table.insert(history, {
			Time = now,
			Position = targetPosition,
		})

		local wantedTime = now - delay
		local delayedPosition = targetPosition

		for i = #history, 1, -1 do
			local entry = history[i]
			if entry.Time <= wantedTime then
				delayedPosition = entry.Position
				break
			end
		end

		while #history > 0 and history[1].Time < now - math.max(delay * 2, 1) do
			table.remove(history, 1)
		end

		local alpha = math.clamp(dt * easingSpeed, 0, 1)
		self._follower.Position = lerpUDim2(self._follower.Position, delayedPosition, alpha)
	end)

	self:TrackConnection(connection)

	return self
end

return FollowUI