--!strict
-- ColorShiftUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type ColorShiftProperty =
	"BackgroundColor3"
	| "TextColor3"
	| "ImageColor3"
	| "TextStrokeColor3"

export type ColorShiftOptions = {
	Property: ColorShiftProperty?,

	From: Color3?,
	To: Color3,

	Duration: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type ColorShiftUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_target: GuiObject,
	_options: ColorShiftOptions,

	_originalColor: Color3?,
	_property: ColorShiftProperty?,
	_tween: Tween?,
}, {} :: any))

local ColorShiftUI = {}
ColorShiftUI.__index = ColorShiftUI
setmetatable(ColorShiftUI, { __index = EffectBase })

local DEFAULTS = {
	Duration = 0.25,
	EasingStyle = Enum.EasingStyle.Quad,
	EasingDirection = Enum.EasingDirection.Out,
}

local function hasProperty(instance: Instance, propertyName: string): boolean
	local ok = pcall(function()
		local _ = (instance :: any)[propertyName]
	end)

	return ok
end

local function inferProperty(target: GuiObject): ColorShiftProperty
	if target:IsA("TextLabel") or target:IsA("TextButton") or target:IsA("TextBox") then
		return "TextColor3"
	end

	if target:IsA("ImageLabel") or target:IsA("ImageButton") then
		return "ImageColor3"
	end

	return "BackgroundColor3"
end

function ColorShiftUI.new(target: GuiObject, options: ColorShiftOptions): ColorShiftUI
	assert(target ~= nil, "ColorShiftUI.new target is nil")
	assert(target:IsA("GuiObject"), "ColorShiftUI.new target must be a GuiObject")
	assert(options ~= nil, "ColorShiftUI.new options is nil")
	assert(options.To ~= nil, "ColorShiftUI.new options.To is nil")

	local opts = options
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, ColorShiftUI)

	self.OnEnd = opts.OnEnd

	self._target = target
	self._options = opts

	self._originalColor = nil
	self._property = nil
	self._tween = nil

	return self
end

function ColorShiftUI:GetInstance(): GuiObject?
	if self._destroyed then
		return nil
	end

	return self._target
end

function ColorShiftUI:GetTarget(): GuiObject
	return self._target
end

function ColorShiftUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)

	self._tween = nil

	if self._property and self._originalColor then
		pcall(function()
			(self._target :: any)[self._property] = self._originalColor
		end)
	end
end

function ColorShiftUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()
	self._destroyed = true
end

function ColorShiftUI:Start(): ColorShiftUI
	if self._destroyed then
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	local property = options.Property or inferProperty(self._target)

	assert(
		hasProperty(self._target, property),
		"ColorShift target does not support property: " .. property
	)

	self._property = property
	self._originalColor = (self._target :: any)[property]

	if options.From then
		(self._target :: any)[property] = options.From
	end

	local duration = math.max(0.01, options.Duration or DEFAULTS.Duration)
	local easingStyle = options.EasingStyle or DEFAULTS.EasingStyle
	local easingDirection = options.EasingDirection or DEFAULTS.EasingDirection

	local tween = self:TrackTween(TweenService:Create(
		self._target,
		TweenInfo.new(duration, easingStyle, easingDirection),
		{
			[property] = options.To,
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

return ColorShiftUI