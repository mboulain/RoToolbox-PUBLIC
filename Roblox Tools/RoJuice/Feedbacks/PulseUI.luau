--!strict
-- PulseUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

type Timing = {
	Out: number?,
	In: number?,
	Delay: number?,
}

export type Options = {
	Scale: number?,
	Pulses: number?,
	Loop: boolean?,

	Timing: Timing?,
	Out: number?,
	In: number?,
	Delay: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type PulseUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_target: GuiObject,
	_options: Options,
	_scale: UIScale?,
	_ownsScale: boolean,
	_baseScale: number?,
}, {} :: any))

local PulseUI = {}
PulseUI.__index = PulseUI
setmetatable(PulseUI, { __index = EffectBase })

local SCALE_NAME = "RoJuice_PulseScale"

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

function PulseUI.new(target: GuiObject, options: Options?): PulseUI
	assert(target ~= nil, "PulseUI.new(target, options?) target is nil")
	assert(target:IsA("GuiObject"), "PulseUI.new(target, options?) target must be a GuiObject")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, PulseUI)

	self.OnEnd = opts.OnEnd
	self._target = target
	self._options = opts
	self._scale = nil
	self._ownsScale = false
	self._baseScale = nil

	return self
end

function PulseUI:GetInstance(): nil
	return nil
end

function PulseUI:GetTarget(): GuiObject
	return self._target
end

function PulseUI:_getOrCreateScale(): (UIScale, boolean)
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

function PulseUI:_restore()
	if self._scale and self._baseScale ~= nil then
		self._scale.Scale = self._baseScale
	end
end

function PulseUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)
	self:_restore()
end

function PulseUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()

	if self._scale and self._ownsScale then
		self._scale:Destroy()
	end

	self._destroyed = true
	self._scale = nil
end

function PulseUI:Start(): PulseUI
	if self._destroyed then
		return self
	end

	local target = self._target
	if not target or not target.Parent then
		warn("[RoJuice.PulseUI] Target has no parent or was destroyed.")
		self:Finish()
		return self
	end

	local token = self:BeginRun()
	local options = self._options
	local timing = options.Timing

	local outTime = math.max(0, (timing and timing.Out) or options.Out or 0.18)
	local inTime = math.max(0, (timing and timing.In) or options.In or 0.18)
	local delay = math.max(0, (timing and timing.Delay) or options.Delay or 0)

	local targetScale = options.Scale or 1.08
	local pulses = math.max(1, options.Pulses or 1)
	local loop = if options.Loop == nil then false else options.Loop

	local easingStyle = options.EasingStyle or Enum.EasingStyle.Quad
	local easingDirection = options.EasingDirection or Enum.EasingDirection.Out

	self._scale, self._ownsScale = self:_getOrCreateScale()
	self._baseScale = self._scale.Scale

	task.spawn(function()
		if delay > 0 then
			local start = os.clock()
			while self:IsAlive(token) and os.clock() - start < delay do
				task.wait()
			end
		end

		local count = 0

		while self:IsAlive(token) and (loop or count < pulses) do
			count += 1

			local scaleOut = self:TrackTween(TweenService:Create(self._scale :: UIScale, TweenInfo.new(outTime, easingStyle, easingDirection), {
				Scale = targetScale,
			}))

			scaleOut:Play()

			if not waitTween(self, scaleOut, token) then
				return
			end

			local scaleIn = self:TrackTween(TweenService:Create(self._scale :: UIScale, TweenInfo.new(inTime, easingStyle, Enum.EasingDirection.InOut), {
				Scale = self._baseScale or 1,
			}))

			scaleIn:Play()

			if not waitTween(self, scaleIn, token) then
				return
			end
		end

		self:_restore()
		self:Finish()
	end)

	return self
end

return PulseUI
