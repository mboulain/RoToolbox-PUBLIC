--!strict
-- ShakeUI (RoJuice)

local RunService = game:GetService("RunService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type Axis = "X" | "Y" | "XY"

export type Options = {
	Intensity: number?,
	Duration: number?,
	Frequency: number?,
	Axis: Axis?,

	Chaotic: boolean?,
	Jitter: number?,
	ImpulseChance: number?,
	ImpulseMultiplier: number?,

	RestoreOnEnd: boolean?,
	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type ShakeUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_target: GuiObject,
	_options: Options,
	_originalPosition: UDim2?,
	_elapsed: number,
	_nextTick: number,
	_seedX: number,
	_seedY: number,
}, {} :: any))

local ShakeUI = {}
ShakeUI.__index = ShakeUI
setmetatable(ShakeUI, { __index = EffectBase })

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function noise2(t: number, seed: number): number
	return (math.sin(t * 12.9898 + seed) * 0.6) + (math.cos(t * 7.233 + seed * 1.37) * 0.4)
end

function ShakeUI.new(target: GuiObject, options: Options?): ShakeUI
	assert(target ~= nil, "ShakeUI.new(target, options?) target is nil")
	assert(target:IsA("GuiObject"), "ShakeUI.new(target, options?) target must be a GuiObject")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, ShakeUI)

	self.OnEnd = opts.OnEnd
	self._target = target
	self._options = opts
	self._originalPosition = nil
	self._elapsed = 0
	self._nextTick = 0
	self._seedX = math.random() * 1000
	self._seedY = math.random() * 1000

	return self
end

function ShakeUI:GetInstance(): nil
	return nil
end

function ShakeUI:GetTarget(): GuiObject
	return self._target
end

function ShakeUI:_restore()
	if self._target and self._originalPosition then
		self._target.Position = self._originalPosition
	end
end

function ShakeUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)

	local restore = if self._options.RestoreOnEnd == nil then true else self._options.RestoreOnEnd
	if restore then
		self:_restore()
	end
end

function ShakeUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()
	self._destroyed = true
	self._originalPosition = nil
end

function ShakeUI:Start(): ShakeUI
	if self._destroyed then
		return self
	end

	local target = self._target
	if not target or not target.Parent then
		warn("[RoJuice.ShakeUI] Target has no parent or was destroyed.")
		self:Finish()
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	self._originalPosition = target.Position
	self._elapsed = 0
	self._nextTick = 0

	local intensity = math.max(0, options.Intensity or 8)
	local duration = math.max(0, options.Duration or 0.25)
	local frequency = options.Frequency
	local axis = options.Axis or "XY"

	local chaotic = if options.Chaotic == nil then true else options.Chaotic
	local jitter = clamp01(options.Jitter or 0.35)
	local impulseChance = clamp01(options.ImpulseChance or 0.12)
	local impulseMultiplier = math.max(0, options.ImpulseMultiplier or 1.8)

	if duration <= 0 or intensity <= 0 then
		self:_restore()
		self:Finish()
		return self
	end

	local connection = RunService.RenderStepped:Connect(function(dt: number)
		if not self:IsAlive(token) then
			return
		end

		if not target.Parent then
			self:Finish()
			return
		end

		self._elapsed += dt

		if self._elapsed >= duration then
			self:_restore()
			self:Finish()
			return
		end

		if frequency and frequency > 0 then
			self._nextTick -= dt
			if self._nextTick > 0 then
				return
			end
			self._nextTick = 1 / frequency
		end

		local progress = math.clamp(self._elapsed / duration, 0, 1)
		local decay = 1 - (progress * progress)

		local nX = noise2(self._elapsed, self._seedX)
		local nY = noise2(self._elapsed, self._seedY)
		local rX = math.random() * 2 - 1
		local rY = math.random() * 2 - 1

		local mixX = if chaotic then (nX * (1 - jitter) + rX * jitter) else rX
		local mixY = if chaotic then (nY * (1 - jitter) + rY * jitter) else rY

		local impulse = 1
		if chaotic and math.random() < impulseChance then
			impulse = impulseMultiplier
		end

		local amplitude = intensity * decay * impulse
		local offsetX = 0
		local offsetY = 0

		if axis == "X" or axis == "XY" then
			offsetX = math.floor(mixX * amplitude)
		end

		if axis == "Y" or axis == "XY" then
			offsetY = math.floor(mixY * amplitude)
		end

		local base = self._originalPosition :: UDim2
		target.Position = UDim2.new(
			base.X.Scale,
			base.X.Offset + offsetX,
			base.Y.Scale,
			base.Y.Offset + offsetY
		)
	end)

	self:TrackConnection(connection)
	return self
end

return ShakeUI
