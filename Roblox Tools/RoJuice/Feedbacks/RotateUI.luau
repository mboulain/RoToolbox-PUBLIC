--!strict
-- RotateUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type RotateOptions = {
	From: number?,
	To: number?,

	Duration: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type RotateUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_target: GuiObject,
	_options: RotateOptions,

	_originalRotation: number?,
	_tween: Tween?,
}, {} :: any))

local RotateUI = {}
RotateUI.__index = RotateUI
setmetatable(RotateUI, { __index = EffectBase })

local DEFAULTS = {
	Duration = 0.25,
	EasingStyle = Enum.EasingStyle.Quad,
	EasingDirection = Enum.EasingDirection.Out,
}

function RotateUI.new(target: GuiObject, options: RotateOptions?): RotateUI
	assert(target ~= nil, "RotateUI.new target is nil")
	assert(target:IsA("GuiObject"), "RotateUI.new target must be a GuiObject")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, RotateUI)

	self.OnEnd = opts.OnEnd
	self._target = target
	self._options = opts

	self._originalRotation = nil
	self._tween = nil

	return self
end

function RotateUI:GetInstance(): GuiObject?
	if self._destroyed then
		return nil
	end

	return self._target
end

function RotateUI:GetTarget(): GuiObject
	return self._target
end

function RotateUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)

	self._tween = nil

	if self._originalRotation ~= nil then
		self._target.Rotation = self._originalRotation
	end
end

function RotateUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()
	self._destroyed = true
end

function RotateUI:Start(): RotateUI
	if self._destroyed then
		return self
	end

	local target = self._target
	if not target or not target.Parent then
		warn("[RoJuice.RotateUI] Target has no parent or was destroyed.")
		self:Finish()
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	self._originalRotation = target.Rotation

	local from = options.From
	if from == nil then
		from = target.Rotation
	end

	local to = options.To
	if to == nil then
		to = target.Rotation + 360
	end

	local duration = math.max(0.01, options.Duration or DEFAULTS.Duration)
	local easingStyle = options.EasingStyle or DEFAULTS.EasingStyle
	local easingDirection = options.EasingDirection or DEFAULTS.EasingDirection

	target.Rotation = from

	local tween = self:TrackTween(TweenService:Create(
		target,
		TweenInfo.new(duration, easingStyle, easingDirection),
		{
			Rotation = to,
		}
	))

	self._tween = tween
	tween:Play()

	local connection = tween.Completed:Connect(function()
		if not self:IsAlive(token) then
			return
		end

		self._tween = nil
		self:Finish()
	end)

	self:TrackConnection(connection)

	return self
end

return RotateUI