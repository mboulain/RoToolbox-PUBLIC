--!strict
-- SlideUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type SlideOptions = {
	From: UDim2?,
	To: UDim2?,

	Duration: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type SlideUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_target: GuiObject,
	_options: SlideOptions,

	_originalPosition: UDim2?,
	_tween: Tween?,
}, {} :: any))

local SlideUI = {}
SlideUI.__index = SlideUI
setmetatable(SlideUI, { __index = EffectBase })

local DEFAULTS = {
	Duration = 0.25,
	EasingStyle = Enum.EasingStyle.Quad,
	EasingDirection = Enum.EasingDirection.Out,
}

function SlideUI.new(target: GuiObject, options: SlideOptions?): SlideUI
	assert(target ~= nil, "SlideUI.new target is nil")
	assert(target:IsA("GuiObject"), "SlideUI.new target must be a GuiObject")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, SlideUI)

	self.OnEnd = opts.OnEnd
	self._target = target
	self._options = opts

	self._originalPosition = nil
	self._tween = nil

	return self
end

function SlideUI:GetInstance(): GuiObject?
	if self._destroyed then
		return nil
	end

	return self._target
end

function SlideUI:GetTarget(): GuiObject
	return self._target
end

function SlideUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)

	self._tween = nil

	if self._originalPosition then
		self._target.Position = self._originalPosition
	end
end

function SlideUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()
	self._destroyed = true
end

function SlideUI:Start(): SlideUI
	if self._destroyed then
		return self
	end

	local target = self._target
	if not target or not target.Parent then
		warn("[RoJuice.SlideUI] Target has no parent or was destroyed.")
		self:Finish()
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	self._originalPosition = target.Position

	local from = options.From or target.Position
	local to = options.To or target.Position

	local duration = math.max(0.01, options.Duration or DEFAULTS.Duration)
	local easingStyle = options.EasingStyle or DEFAULTS.EasingStyle
	local easingDirection = options.EasingDirection or DEFAULTS.EasingDirection

	target.Position = from

	local tween = self:TrackTween(TweenService:Create(
		target,
		TweenInfo.new(duration, easingStyle, easingDirection),
		{
			Position = to,
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

return SlideUI