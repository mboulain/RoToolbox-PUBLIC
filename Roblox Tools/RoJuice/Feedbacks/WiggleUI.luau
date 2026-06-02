--!strict
-- WiggleUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type Options = {
	MaxAngle: number?,
	Wiggles: number?,
	Speed: number?,
	Duration: number?,
	Randomness: number?,
	RestoreOnEnd: boolean?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type WiggleUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_target: GuiObject,
	_options: Options,
	_baseRotation: number?,
}, {} :: any))

local WiggleUI = {}
WiggleUI.__index = WiggleUI
setmetatable(WiggleUI, { __index = EffectBase })

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function randSign(): number
	return if math.random(0, 1) == 0 then -1 else 1
end

local function computeStepTime(duration: number?, speed: number, wiggles: number): number
	if duration ~= nil then
		if duration <= 0 then
			return 0
		end
		return duration / math.max(1, wiggles)
	end

	return math.max(0, speed)
end

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

function WiggleUI.new(target: GuiObject, options: Options?): WiggleUI
	assert(target ~= nil, "WiggleUI.new(target, options?) target is nil")
	assert(target:IsA("GuiObject"), "WiggleUI.new(target, options?) target must be a GuiObject")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, WiggleUI)

	self.OnEnd = opts.OnEnd
	self._target = target
	self._options = opts
	self._baseRotation = nil

	return self
end

function WiggleUI:GetInstance(): nil
	return nil
end

function WiggleUI:GetTarget(): GuiObject
	return self._target
end

function WiggleUI:_restore()
	local restore = if self._options.RestoreOnEnd == nil then true else self._options.RestoreOnEnd
	if restore and self._target and self._baseRotation ~= nil then
		self._target.Rotation = self._baseRotation
	end
end

function WiggleUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)
	self:_restore()
end

function WiggleUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()
	self._destroyed = true
	self._baseRotation = nil
end

function WiggleUI:Start(): WiggleUI
	if self._destroyed then
		return self
	end

	local target = self._target
	if not target or not target.Parent then
		warn("[RoJuice.WiggleUI] Target has no parent or was destroyed.")
		self:Finish()
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	self._baseRotation = target.Rotation

	local maxAngle = options.MaxAngle or 10
	local wiggles = math.max(1, math.floor(options.Wiggles or 8))
	local speed = options.Speed or 0.05
	local stepTime = computeStepTime(options.Duration, speed, wiggles)
	local randomness = clamp01(options.Randomness or 1)
	local easingStyle = options.EasingStyle or Enum.EasingStyle.Quad
	local easingDirection = options.EasingDirection or Enum.EasingDirection.InOut

	local function tweenTo(rotation: number, duration: number): boolean
		if not self:IsAlive(token) then
			return false
		end

		if not target.Parent then
			return false
		end

		local tween = self:TrackTween(TweenService:Create(target, TweenInfo.new(duration, easingStyle, easingDirection), {
			Rotation = rotation,
		}))

		tween:Play()
		return waitTween(self, tween, token)
	end

	task.spawn(function()
		for _ = 1, wiggles do
			if not self:IsAlive(token) then
				return
			end

			local ampJitter = 1
			if randomness > 0 then
				ampJitter = 1 + ((math.random() * 2 - 1) * 0.35 * randomness)
			end

			local angle = maxAngle * ampJitter * randSign()
			local goal = (self._baseRotation or 0) + angle

			if not tweenTo(goal, stepTime) then
				return
			end
		end

		local restore = if options.RestoreOnEnd == nil then true else options.RestoreOnEnd
		if restore and self:IsAlive(token) and self._baseRotation ~= nil then
			if not tweenTo(self._baseRotation, math.max(0.05, stepTime)) then
				return
			end
		end

		if not self:IsAlive(token) then
			return
		end

		self:Finish()
	end)

	return self
end

return WiggleUI
