--!strict
-- PopUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type PopOptions = {
	StartScale: number?,
	PopScale: number?,
	Duration: number?,

	PopRatio: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type PopUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_target: GuiObject,
	_options: PopOptions,

	_scale: UIScale?,
	_ownsScale: boolean,
	_originalScale: number,
}, {} :: any))

local PopUI = {}
PopUI.__index = PopUI
setmetatable(PopUI, { __index = EffectBase })

local SCALE_NAME = "RoJuice_PopScale"

local DEFAULTS = {
	StartScale = 0,
	PopScale = 1.12,
	Duration = 0.25,

	PopRatio = 0.65,

	EasingStyle = Enum.EasingStyle.Back,
	EasingDirection = Enum.EasingDirection.Out,
}

local function waitTween(self: any, tween: Tween, token: number): boolean
	local completed = false
	local connection = tween.Completed:Connect(function()
		completed = true
	end)

	self:TrackConnection(connection)

	while self:IsAlive(token) and not completed do
		task.wait()
	end

	pcall(function()
		connection:Disconnect()
	end)

	return self:IsAlive(token)
end

function PopUI.new(target: GuiObject, options: PopOptions?): PopUI
	assert(target ~= nil, "PopUI.new target is nil")
	assert(target:IsA("GuiObject"), "PopUI.new target must be a GuiObject")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, PopUI)

	self.OnEnd = opts.OnEnd
	self._target = target
	self._options = opts

	self._scale = nil
	self._ownsScale = false
	self._originalScale = 1

	return self
end

function PopUI:GetInstance(): GuiObject?
	if self._destroyed then
		return nil
	end

	return self._target
end

function PopUI:GetTarget(): GuiObject
	return self._target
end

function PopUI:_getOrCreateScale(): (UIScale, boolean)
	local existing = self._target:FindFirstChild(SCALE_NAME)
	if existing and existing:IsA("UIScale") then
		return existing, false
	end

	local scale = Instance.new("UIScale")
	scale.Name = SCALE_NAME
	scale.Scale = 1
	scale.Parent = self._target

	return scale, true
end

function PopUI:_restore()
	if self._scale then
		self._scale.Scale = self._originalScale
	end
end

function PopUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)
	self:_restore()
end

function PopUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()

	if self._ownsScale and self._scale then
		self._scale:Destroy()
	end

	self._destroyed = true
	self._scale = nil
end

function PopUI:Start(): PopUI
	if self._destroyed then
		return self
	end

	local target = self._target
	if not target or not target.Parent then
		warn("[RoJuice.PopUI] Target has no parent or was destroyed.")
		self:Finish()
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	self._scale, self._ownsScale = self:_getOrCreateScale()
	self._originalScale = self._scale.Scale

	local duration = math.max(0.01, options.Duration or DEFAULTS.Duration)

	local startScale = options.StartScale
	if startScale == nil then
		startScale = DEFAULTS.StartScale
	end

	local popScale = options.PopScale or DEFAULTS.PopScale

	local popRatio = options.PopRatio or DEFAULTS.PopRatio
	popRatio = math.clamp(popRatio, 0.05, 0.95)

	local popDuration = duration * popRatio
	local returnDuration = duration * (1 - popRatio)

	local easingStyle = options.EasingStyle or DEFAULTS.EasingStyle
	local easingDirection = options.EasingDirection or DEFAULTS.EasingDirection

	self._scale.Scale = self._originalScale * startScale

	task.spawn(function()
		if not self:IsAlive(token) then
			return
		end

		local popTween = self:TrackTween(TweenService:Create(
			self._scale :: UIScale,
			TweenInfo.new(popDuration, easingStyle, easingDirection),
			{
				Scale = self._originalScale * popScale,
			}
		))

		popTween:Play()

		if not waitTween(self, popTween, token) then
			return
		end

		local returnTween = self:TrackTween(TweenService:Create(
			self._scale :: UIScale,
			TweenInfo.new(returnDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Scale = self._originalScale,
			}
		))

		returnTween:Play()

		if not waitTween(self, returnTween, token) then
			return
		end

		self:_restore()

		if self._ownsScale and self._scale then
			self._scale:Destroy()
			self._scale = nil
		end

		self:Finish()
	end)

	return self
end

return PopUI