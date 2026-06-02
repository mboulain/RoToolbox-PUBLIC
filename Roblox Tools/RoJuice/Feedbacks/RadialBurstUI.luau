--!strict
-- RadialBurstUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type RadialBurstOptions = {
	Parent: Instance?,

	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,

	Count: number?,
	Size: UDim2?,

	Radius: number?,
	StartRadius: number?,

	Duration: number?,
	FadeOut: boolean?,

	RandomRotation: boolean?,
	Spin: number?,

	ImageColor3: Color3?,
	ImageTransparency: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type RadialBurstUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_image: string,
	_options: RadialBurstOptions,

	_root: Frame?,
	_items: { ImageLabel },
}, {} :: any))

local RadialBurstUI = {}
RadialBurstUI.__index = RadialBurstUI
setmetatable(RadialBurstUI, { __index = EffectBase })

local DEFAULTS = {
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	ZIndex = 1000,

	Count = 10,
	Size = UDim2.fromOffset(24, 24),

	Radius = 70,
	StartRadius = 0,

	Duration = 0.45,
	FadeOut = true,

	RandomRotation = true,
	Spin = 90,

	ImageColor3 = Color3.fromRGB(255, 255, 255),
	ImageTransparency = 0,

	EasingStyle = Enum.EasingStyle.Quad,
	EasingDirection = Enum.EasingDirection.Out,
}

function RadialBurstUI.new(image: string, options: RadialBurstOptions?): RadialBurstUI
	assert(typeof(image) == "string", "RadialBurstUI.new image must be a string")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, RadialBurstUI)

	self.OnEnd = opts.OnEnd

	self._image = image
	self._options = opts

	self._root = nil
	self._items = {}

	return self
end

function RadialBurstUI:_Build()
	if self._root then
		return
	end

	local options = self._options
	assert(options.Parent ~= nil, "RadialBurstUI requires options.Parent")

	local root = Instance.new("Frame")
	root.Name = "RoJuice_RadialBurst"
	root.Parent = options.Parent
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(0, 0)
	root.Position = options.Position or DEFAULTS.Position
	root.AnchorPoint = options.AnchorPoint or DEFAULTS.AnchorPoint
	root.ZIndex = options.ZIndex or DEFAULTS.ZIndex

	self._root = self:Own(root) :: Frame
end

function RadialBurstUI:GetInstance(): GuiObject?
	if self._destroyed then
		return nil
	end

	self:_Build()
	return self._root
end

function RadialBurstUI:GetTarget(): GuiObject?
	return self:GetInstance()
end

function RadialBurstUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)
end

function RadialBurstUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()

	self._destroyed = true
	self._root = nil

	table.clear(self._items)
end

function RadialBurstUI:Start(): RadialBurstUI
	if self._destroyed then
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	self:_Build()

	local root = self._root
	if not root then
		return self
	end

	local count = math.max(1, options.Count or DEFAULTS.Count)
	local size = options.Size or DEFAULTS.Size
	local radius = options.Radius or DEFAULTS.Radius
	local startRadius = options.StartRadius or DEFAULTS.StartRadius
	local duration = math.max(0.01, options.Duration or DEFAULTS.Duration)

	local fadeOut = if options.FadeOut == nil
		then DEFAULTS.FadeOut
		else options.FadeOut

	local randomRotation = if options.RandomRotation == nil
		then DEFAULTS.RandomRotation
		else options.RandomRotation

	local spin = options.Spin or DEFAULTS.Spin

	local imageColor = options.ImageColor3 or DEFAULTS.ImageColor3

	local imageTransparency = if options.ImageTransparency == nil
		then DEFAULTS.ImageTransparency
		else options.ImageTransparency

	local easingStyle = options.EasingStyle or DEFAULTS.EasingStyle
	local easingDirection = options.EasingDirection or DEFAULTS.EasingDirection

	for i = 1, count do
		if not self:IsAlive(token) then
			return self
		end

		local angle = ((i - 1) / count) * math.pi * 2

		local startX = math.cos(angle) * startRadius
		local startY = math.sin(angle) * startRadius

		local endX = math.cos(angle) * radius
		local endY = math.sin(angle) * radius

		local item = Instance.new("ImageLabel")
		item.Name = "BurstItem"
		item.Parent = root
		item.BackgroundTransparency = 1
		item.AnchorPoint = Vector2.new(0.5, 0.5)
		item.Position = UDim2.fromOffset(startX, startY)
		item.Size = size
		item.Image = self._image
		item.ImageColor3 = imageColor
		item.ImageTransparency = imageTransparency
		item.ZIndex = root.ZIndex + 1

		if randomRotation then
			item.Rotation = math.random(0, 360)
		end

		self:Own(item)
		table.insert(self._items, item)

		local goals = {
			Position = UDim2.fromOffset(endX, endY),
			Rotation = item.Rotation + spin,
		} :: { [string]: any }

		if fadeOut then
			goals.ImageTransparency = 1
		end

		local tween = self:TrackTween(TweenService:Create(
			item,
			TweenInfo.new(duration, easingStyle, easingDirection),
			goals
		))

		tween:Play()
	end

	task.delay(duration, function()
		if not self:IsAlive(token) then
			return
		end

		self:Finish()
	end)

	return self
end

return RadialBurstUI