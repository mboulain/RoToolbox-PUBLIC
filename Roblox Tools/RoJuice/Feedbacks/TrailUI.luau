--!strict
-- TrailUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type TrailOptions = {
	Parent: Instance?,

	Duration: number?,
	Interval: number?,
	FadeOut: number?,

	MaxClones: number?,

	StartTransparency: number?,
	EndTransparency: number?,

	ScaleMultiplier: number?,
	ZIndexOffset: number?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type TrailUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_target: GuiObject,
	_options: TrailOptions,

	_clones: { GuiObject },
}, {} :: any))

local TrailUI = {}
TrailUI.__index = TrailUI
setmetatable(TrailUI, { __index = EffectBase })

local DEFAULTS = {
	Duration = 0.45,
	Interval = 0.04,
	FadeOut = 0.3,

	MaxClones = 12,

	StartTransparency = 0.35,
	EndTransparency = 1,

	ScaleMultiplier = 1,
	ZIndexOffset = -1,
}

local function getParent(target: GuiObject, options: TrailOptions): Instance?
	return options.Parent or target.Parent
end

local function setTransparencyRecursive(instance: Instance, transparency: number)
	if instance:IsA("GuiObject") then
		instance.BackgroundTransparency = math.max(instance.BackgroundTransparency, transparency)

		if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
			local text = instance :: any
			text.TextTransparency = math.max(text.TextTransparency, transparency)
			text.TextStrokeTransparency = math.max(text.TextStrokeTransparency, transparency)
		end

		if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
			local image = instance :: any
			image.ImageTransparency = math.max(image.ImageTransparency, transparency)
		end
	end

	if instance:IsA("UIStroke") then
		instance.Transparency = math.max(instance.Transparency, transparency)
	end

	for _, child in ipairs(instance:GetChildren()) do
		setTransparencyRecursive(child, transparency)
	end
end

local function tweenTransparencyRecursive(self: TrailUI, instance: Instance, duration: number, transparency: number)
	if instance:IsA("GuiObject") then
		local goals = {
			BackgroundTransparency = transparency,
		} :: { [string]: any }

		if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
			goals.TextTransparency = transparency
			goals.TextStrokeTransparency = transparency
		end

		if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
			goals.ImageTransparency = transparency
		end

		local tween = self:TrackTween(TweenService:Create(
			instance,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			goals
		))

		tween:Play()
	end

	if instance:IsA("UIStroke") then
		local tween = self:TrackTween(TweenService:Create(
			instance,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Transparency = transparency,
			}
		))

		tween:Play()
	end

	for _, child in ipairs(instance:GetChildren()) do
		tweenTransparencyRecursive(self, child, duration, transparency)
	end
end

local function applyScale(clone: GuiObject, multiplier: number)
	if multiplier == 1 then
		return
	end

	local scale = clone:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "RoJuice_TrailScale"
		scale.Scale = 1
		scale.Parent = clone
	end

	scale.Scale *= multiplier
end

function TrailUI.new(target: GuiObject, options: TrailOptions?): TrailUI
	assert(target ~= nil, "TrailUI.new target is nil")
	assert(target:IsA("GuiObject"), "TrailUI.new target must be a GuiObject")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, TrailUI)

	self.OnEnd = opts.OnEnd
	self._target = target
	self._options = opts

	self._clones = {}

	return self
end

function TrailUI:GetInstance(): GuiObject?
	if self._destroyed then
		return nil
	end

	return self._target
end

function TrailUI:GetTarget(): GuiObject
	return self._target
end

function TrailUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)

	for _, clone in ipairs(self._clones) do
		if clone.Parent then
			clone:Destroy()
		end
	end

	table.clear(self._clones)
end

function TrailUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()
	self._destroyed = true
end

function TrailUI:_SpawnClone()
	local options = self._options
	local parent = getParent(self._target, options)
	if not parent then
		return
	end

	local clone = self._target:Clone()
	clone.Name = "RoJuice_TrailClone"
	clone.Parent = parent
	clone.Position = self._target.Position
	clone.AnchorPoint = self._target.AnchorPoint
	clone.Size = self._target.Size
	clone.Rotation = self._target.Rotation
	clone.ZIndex = self._target.ZIndex + (options.ZIndexOffset or DEFAULTS.ZIndexOffset)

	self:Own(clone)
	table.insert(self._clones, clone)

	applyScale(clone, options.ScaleMultiplier or DEFAULTS.ScaleMultiplier)
	setTransparencyRecursive(clone, options.StartTransparency or DEFAULTS.StartTransparency)

	local maxClones = math.max(1, options.MaxClones or DEFAULTS.MaxClones)
	while #self._clones > maxClones do
		local old = table.remove(self._clones, 1)
		if old and old.Parent then
			old:Destroy()
		end
	end

	local fadeOut = math.max(0.01, options.FadeOut or DEFAULTS.FadeOut)
	local endTransparency = options.EndTransparency or DEFAULTS.EndTransparency

	tweenTransparencyRecursive(self, clone, fadeOut, endTransparency)

	task.delay(fadeOut, function()
		if clone.Parent then
			clone:Destroy()
		end
	end)
end

function TrailUI:Start(): TrailUI
	if self._destroyed then
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	local duration = math.max(0.01, options.Duration or DEFAULTS.Duration)
	local interval = math.max(0.01, options.Interval or DEFAULTS.Interval)

	task.spawn(function()
		local elapsed = 0

		while elapsed < duration do
			if not self:IsAlive(token) then
				return
			end

			if self._target.Parent == nil then
				self:Destroy()
				return
			end

			self:_SpawnClone()

			task.wait(interval)
			elapsed += interval
		end

		if not self:IsAlive(token) then
			return
		end

		self:Finish()
	end)

	return self
end

return TrailUI