--!strict
-- GlowUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type GlowOptions = {
	Color: Color3?,
	Thickness: number?,

	FromTransparency: number?,
	ToTransparency: number?,

	Duration: number?,
	Loops: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type GlowUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_target: GuiObject,
	_options: GlowOptions,

	_stroke: UIStroke?,
	_ownsStroke: boolean,

	_originalColor: Color3?,
	_originalThickness: number?,
	_originalTransparency: number?,

	_tween: Tween?,
}, {} :: any))

local GlowUI = {}
GlowUI.__index = GlowUI
setmetatable(GlowUI, { __index = EffectBase })

local DEFAULTS = {
	Color = Color3.fromRGB(255, 255, 255),
	Thickness = 2,

	FromTransparency = 1,
	ToTransparency = 0.15,

	Duration = 0.35,
	Loops = 1,

	EasingStyle = Enum.EasingStyle.Quad,
	EasingDirection = Enum.EasingDirection.Out,
}

local function getOrCreateStroke(target: GuiObject): (UIStroke, boolean)
	local existing = target:FindFirstChildOfClass("UIStroke")

	if existing then
		return existing, false
	end

	local stroke = Instance.new("UIStroke")
	stroke.Name = "RoJuice_GlowStroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = target

	return stroke, true
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

function GlowUI.new(target: GuiObject, options: GlowOptions?): GlowUI
	assert(target ~= nil, "GlowUI.new target is nil")
	assert(target:IsA("GuiObject"), "GlowUI.new target must be a GuiObject")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, GlowUI)

	self.OnEnd = opts.OnEnd
	self._target = target
	self._options = opts

	self._stroke = nil
	self._ownsStroke = false

	self._originalColor = nil
	self._originalThickness = nil
	self._originalTransparency = nil

	self._tween = nil

	return self
end

function GlowUI:GetInstance(): GuiObject?
	if self._destroyed then
		return nil
	end

	return self._target
end

function GlowUI:GetTarget(): GuiObject
	return self._target
end

function GlowUI:_restore()
	if not self._stroke then
		return
	end

	if self._originalColor then
		self._stroke.Color = self._originalColor
	end

	if self._originalThickness then
		self._stroke.Thickness = self._originalThickness
	end

	if self._originalTransparency then
		self._stroke.Transparency = self._originalTransparency
	end
end

function GlowUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)

	self._tween = nil
	self:_restore()
end

function GlowUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()

	if self._ownsStroke and self._stroke then
		self._stroke:Destroy()
	end

	self._destroyed = true
	self._stroke = nil
end

function GlowUI:Start(): GlowUI
	if self._destroyed then
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	local stroke, ownsStroke = getOrCreateStroke(self._target)

	self._stroke = stroke
	self._ownsStroke = ownsStroke

	self._originalColor = stroke.Color
	self._originalThickness = stroke.Thickness
	self._originalTransparency = stroke.Transparency

	stroke.Color = options.Color or DEFAULTS.Color
	stroke.Thickness = options.Thickness or DEFAULTS.Thickness
	stroke.Transparency = options.FromTransparency or DEFAULTS.FromTransparency

	local duration = math.max(0.01, options.Duration or DEFAULTS.Duration)
	local loops = math.max(1, options.Loops or DEFAULTS.Loops)

	local fromTransparency = if options.FromTransparency == nil
		then DEFAULTS.FromTransparency
		else options.FromTransparency

	local toTransparency = if options.ToTransparency == nil
		then DEFAULTS.ToTransparency
		else options.ToTransparency

	local easingStyle = options.EasingStyle or DEFAULTS.EasingStyle
	local easingDirection = options.EasingDirection or DEFAULTS.EasingDirection

	task.spawn(function()
		for _ = 1, loops do
			if not self:IsAlive(token) then
				return
			end

			stroke.Transparency = fromTransparency

			local tween = self:TrackTween(TweenService:Create(
				stroke,
				TweenInfo.new(duration, easingStyle, easingDirection),
				{
					Transparency = toTransparency,
				}
			))

			self._tween = tween
			tween:Play()

			if not waitTween(self, tween, token) then
				return
			end
		end

		if not self:IsAlive(token) then
			return
		end

		if self._ownsStroke and self._stroke then
			self._stroke:Destroy()
			self._stroke = nil
		else
			self:_restore()
		end

		self:Finish()
	end)

	return self
end

return GlowUI