--!strict
-- HoverUI (RoJuice)

local RunService = game:GetService("RunService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type HoverOptions = {
	Amplitude: number?,
	Speed: number?,

	Axis: "X" | "Y" | "Both"?,

	Offset: UDim2?,

	Duration: number?,

	RotationAmplitude: number?,
	RotationSpeed: number?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type HoverUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_target: GuiObject,
	_options: HoverOptions,

	_originalPosition: UDim2?,
	_originalRotation: number?,
}, {} :: any))

local HoverUI = {}
HoverUI.__index = HoverUI
setmetatable(HoverUI, { __index = EffectBase })

local DEFAULTS = {
	Amplitude = 6,
	Speed = 2,

	Axis = "Y",

	Offset = UDim2.fromOffset(0, 0),

	Duration = nil,

	RotationAmplitude = 0,
	RotationSpeed = 1,
}

local function addUDim2(a: UDim2, b: UDim2): UDim2
	return UDim2.new(
		a.X.Scale + b.X.Scale,
		a.X.Offset + b.X.Offset,
		a.Y.Scale + b.Y.Scale,
		a.Y.Offset + b.Y.Offset
	)
end

function HoverUI.new(target: GuiObject, options: HoverOptions?): HoverUI
	assert(target ~= nil, "HoverUI.new target is nil")
	assert(target:IsA("GuiObject"), "HoverUI.new target must be a GuiObject")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, HoverUI)

	self.OnEnd = opts.OnEnd
	self._target = target
	self._options = opts

	self._originalPosition = nil
	self._originalRotation = nil

	return self
end

function HoverUI:GetInstance(): GuiObject?
	if self._destroyed then
		return nil
	end

	return self._target
end

function HoverUI:GetTarget(): GuiObject
	return self._target
end

function HoverUI:_restore()
	if self._originalPosition then
		self._target.Position = self._originalPosition
	end

	if self._originalRotation ~= nil then
		self._target.Rotation = self._originalRotation
	end
end

function HoverUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)
	self:_restore()
end

function HoverUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()
	self._destroyed = true
end

function HoverUI:Start(): HoverUI
	if self._destroyed then
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	self._originalPosition = self._target.Position
	self._originalRotation = self._target.Rotation

	local amplitude = options.Amplitude or DEFAULTS.Amplitude
	local speed = options.Speed or DEFAULTS.Speed

	local axis = options.Axis or DEFAULTS.Axis
	local offset = options.Offset or DEFAULTS.Offset

	local duration = options.Duration

	local rotationAmplitude = options.RotationAmplitude or DEFAULTS.RotationAmplitude
	local rotationSpeed = options.RotationSpeed or DEFAULTS.RotationSpeed

	local elapsed = 0

	local connection = RunService.RenderStepped:Connect(function(dt)
		if not self:IsAlive(token) then
			return
		end

		if self._target.Parent == nil then
			self:Destroy()
			return
		end

		elapsed += dt

		if duration ~= nil and elapsed >= duration then
			self:Finish()
			return
		end

		local wave = math.sin(elapsed * speed * math.pi * 2)

		local x = 0
		local y = 0

		if axis == "X" then
			x = wave * amplitude
		elseif axis == "Y" then
			y = wave * amplitude
		elseif axis == "Both" then
			x = math.cos(elapsed * speed * math.pi * 2) * amplitude
			y = math.sin(elapsed * speed * math.pi * 2) * amplitude
		end

		local hoverOffset = addUDim2(
			offset,
			UDim2.fromOffset(x, y)
		)

		self._target.Position = addUDim2(
			self._originalPosition :: UDim2,
			hoverOffset
		)

		if rotationAmplitude ~= 0 then
			local rotWave = math.sin(elapsed * rotationSpeed * math.pi * 2)

			self._target.Rotation =
				(self._originalRotation or 0)
				+ rotWave * rotationAmplitude
		end
	end)

	self:TrackConnection(connection)

	return self
end

return HoverUI