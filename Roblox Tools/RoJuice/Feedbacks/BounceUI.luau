--!strict
-- BounceUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type BounceOptions = {
	CompressScale: number?,
	BounceScale: number?,
	Duration: number?,

	CompressRatio: number?,
	BounceRatio: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}

export type BounceUI = {
	Start: (self: BounceUI) -> BounceUI,
	Cancel: (self: BounceUI) -> (),
	Destroy: (self: BounceUI) -> (),
	GetInstance: (self: BounceUI) -> GuiObject?,

	_target: GuiObject,
	_options: BounceOptions,

	_started: boolean,
	_destroyed: boolean,
	_token: number,

	_scale: UIScale?,
	_ownsScale: boolean,
	_originalScale: number,

	_tweens: { Tween },
}

local BounceUI = {}
BounceUI.__index = BounceUI
setmetatable(BounceUI, { __index = EffectBase })

local DEFAULTS = {
	CompressScale = 0.9,
	BounceScale = 1.12,
	Duration = 0.25,

	CompressRatio = 0.3,
	BounceRatio = 0.45,

	EasingStyle = Enum.EasingStyle.Back,
	EasingDirection = Enum.EasingDirection.Out,
}

local function getOrCreateScale(target: GuiObject): (UIScale, boolean)
	local existing = target:FindFirstChildOfClass("UIScale")

	if existing then
		return existing, false
	end

	local scale = Instance.new("UIScale")
	scale.Name = "RoJuice_BounceScale"
	scale.Scale = 1
	scale.Parent = target

	return scale, true
end

local function playTween(
	self: BounceUI,
	instance: Instance,
	duration: number,
	easingStyle: Enum.EasingStyle,
	easingDirection: Enum.EasingDirection,
	goals: { [string]: any }
): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, easingStyle, easingDirection),
		goals
	)

	table.insert(self._tweens, tween)
	tween:Play()

	return tween
end

local function waitTween(tween: Tween)
	local completed = false
	local connection: RBXScriptConnection?

	connection = tween.Completed:Connect(function()
		completed = true

		if connection then
			connection:Disconnect()
			connection = nil
		end
	end)

	while not completed do
		task.wait()
	end
end

function BounceUI.new(target: GuiObject, options: BounceOptions?): BounceUI
	assert(target ~= nil, "BounceUI.new target is nil")
	assert(target:IsA("GuiObject"), "BounceUI.new target must be a GuiObject")

	local opts = options or {}
	local self = EffectBase.new((opts :: any).DestroyOnEnd) :: any
	setmetatable(self, BounceUI)

	self.OnEnd = (opts :: any).OnEnd
	self._target = target
	self._options = opts

	self._scale = nil
	self._ownsScale = false
	self._originalScale = 1

	self._tweens = {}

	return self
end

function BounceUI:GetInstance(): GuiObject?
	if self._destroyed then
		return nil
	end

	return self._target
end

function BounceUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)

	if self._scale then
		self._scale.Scale = self._originalScale
	end
end

function BounceUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()

	self._destroyed = true

	if self._ownsScale and self._scale then
		self._scale:Destroy()
	end

	self._scale = nil
end

function BounceUI:Start(): BounceUI
	if self._destroyed then
		return self
	end

	if self._started then
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	local scale, ownsScale = getOrCreateScale(self._target)

	self._scale = scale
	self._ownsScale = ownsScale
	self._originalScale = scale.Scale

	local duration = math.max(0.01, options.Duration or DEFAULTS.Duration)

	local compressScale = options.CompressScale or DEFAULTS.CompressScale
	local bounceScale = options.BounceScale or DEFAULTS.BounceScale

	local compressRatio = options.CompressRatio or DEFAULTS.CompressRatio
	local bounceRatio = options.BounceRatio or DEFAULTS.BounceRatio

	compressRatio = math.clamp(compressRatio, 0.05, 0.9)
	bounceRatio = math.clamp(bounceRatio, 0.05, 0.9)

	local returnRatio = math.max(0.05, 1 - compressRatio - bounceRatio)

	local compressDuration = duration * compressRatio
	local bounceDuration = duration * bounceRatio
	local returnDuration = duration * returnRatio

	local easingStyle = options.EasingStyle or DEFAULTS.EasingStyle
	local easingDirection = options.EasingDirection or DEFAULTS.EasingDirection

	task.spawn(function()
		if not self:IsAlive(token) then
			return
		end

		local compressTween = playTween(
			self,
			scale,
			compressDuration,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			{ Scale = self._originalScale * compressScale }
		)

		waitTween(compressTween)

		if not self:IsAlive(token) then
			return
		end

		local bounceTween = playTween(
			self,
			scale,
			bounceDuration,
			easingStyle,
			easingDirection,
			{ Scale = self._originalScale * bounceScale }
		)

		waitTween(bounceTween)

		if not self:IsAlive(token) then
			return
		end

		local returnTween = playTween(
			self,
			scale,
			returnDuration,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			{ Scale = self._originalScale }
		)

		waitTween(returnTween)

		if not self:IsAlive(token) then
			return
		end

		if self._ownsScale and self._scale then
			self._scale:Destroy()
			self._scale = nil
		end

		self:Finish()
	end)

	return self
end

return BounceUI