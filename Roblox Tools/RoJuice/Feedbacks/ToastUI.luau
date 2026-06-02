--!strict
-- ToastUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type ToastOptions = {
	Parent: Instance?,

	Text: string?,
	Icon: string?,

	Position: UDim2?,
	AnchorPoint: Vector2?,
	Size: UDim2?,
	AutomaticSize: Enum.AutomaticSize?,
	ZIndex: number?,

	BackgroundColor3: Color3?,
	BackgroundTransparency: number?,
	CornerRadius: UDim?,
	Padding: number?,

	TextColor3: Color3?,
	TextTransparency: number?,
	TextSize: number?,
	Font: Enum.Font?,
	RichText: boolean?,

	IconSize: UDim2?,
	IconColor3: Color3?,
	IconTransparency: number?,

	Duration: number?,
	FadeIn: number?,
	FadeOut: number?,

	SlideFrom: UDim2?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type ToastUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_text: string,
	_options: ToastOptions,

	_root: Frame?,
	_label: TextLabel?,
	_icon: ImageLabel?,
}, {} :: any))

local ToastUI = {}
ToastUI.__index = ToastUI
setmetatable(ToastUI, { __index = EffectBase })

local DEFAULTS = {
	Position = UDim2.fromScale(0.5, 0.15),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(260, 54),
	AutomaticSize = Enum.AutomaticSize.None,
	ZIndex = 1000,

	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	BackgroundTransparency = 0.1,
	CornerRadius = UDim.new(0, 12),
	Padding = 12,

	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextTransparency = 0,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	RichText = false,

	IconSize = UDim2.fromOffset(28, 28),
	IconColor3 = Color3.fromRGB(255, 255, 255),
	IconTransparency = 0,

	Duration = 2,
	FadeIn = 0.18,
	FadeOut = 0.25,

	SlideFrom = UDim2.fromOffset(0, -20),
}

local function addUDim2(a: UDim2, b: UDim2): UDim2
	return UDim2.new(
		a.X.Scale + b.X.Scale,
		a.X.Offset + b.X.Offset,
		a.Y.Scale + b.Y.Scale,
		a.Y.Offset + b.Y.Offset
	)
end

function ToastUI.new(text: string, options: ToastOptions?): ToastUI
	assert(typeof(text) == "string", "ToastUI.new text must be a string")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, ToastUI)

	self.OnEnd = opts.OnEnd

	self._text = text
	self._options = opts

	self._root = nil
	self._label = nil
	self._icon = nil

	return self
end

function ToastUI:_Build()
	if self._root then
		return
	end

	local options = self._options
	local parent = options.Parent
	assert(parent ~= nil, "ToastUI requires options.Parent")

	local root = Instance.new("Frame")
	root.Name = "RoJuice_Toast"
	root.Parent = parent
	root.Position = options.Position or DEFAULTS.Position
	root.AnchorPoint = options.AnchorPoint or DEFAULTS.AnchorPoint
	root.Size = options.Size or DEFAULTS.Size
	root.AutomaticSize = options.AutomaticSize or DEFAULTS.AutomaticSize
	root.ZIndex = options.ZIndex or DEFAULTS.ZIndex
	root.BackgroundColor3 = options.BackgroundColor3 or DEFAULTS.BackgroundColor3
	root.BackgroundTransparency = 1

	self:Own(root)
	self._root = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = options.CornerRadius or DEFAULTS.CornerRadius
	corner.Parent = root

	local padding = Instance.new("UIPadding")
	local paddingValue = options.Padding or DEFAULTS.Padding
	padding.PaddingLeft = UDim.new(0, paddingValue)
	padding.PaddingRight = UDim.new(0, paddingValue)
	padding.PaddingTop = UDim.new(0, paddingValue)
	padding.PaddingBottom = UDim.new(0, paddingValue)
	padding.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = root

	if options.Icon then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Parent = root
		icon.BackgroundTransparency = 1
		icon.Image = options.Icon
		icon.Size = options.IconSize or DEFAULTS.IconSize
		icon.ImageColor3 = options.IconColor3 or DEFAULTS.IconColor3
		icon.ImageTransparency = 1
		icon.ZIndex = root.ZIndex + 1
		icon.LayoutOrder = 1

		self._icon = icon
	end

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Parent = root
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, if options.Icon then -36 else 0, 1, 0)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.Text = options.Text or self._text
	label.TextColor3 = options.TextColor3 or DEFAULTS.TextColor3
	label.TextTransparency = 1
	label.TextSize = options.TextSize or DEFAULTS.TextSize
	label.Font = options.Font or DEFAULTS.Font
	label.RichText = if options.RichText == nil then DEFAULTS.RichText else options.RichText
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = root.ZIndex + 1
	label.LayoutOrder = 2

	self._label = label
end

function ToastUI:GetInstance(): GuiObject?
	if self._destroyed then
		return nil
	end

	self:_Build()
	return self._root
end

function ToastUI:GetTarget(): GuiObject?
	return self:GetInstance()
end

function ToastUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)
end

function ToastUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()
	self._destroyed = true

	self._root = nil
	self._label = nil
	self._icon = nil
end

function ToastUI:_Tween(instance: Instance, duration: number, goals: { [string]: any }): Tween
	local tween = self:TrackTween(TweenService:Create(
		instance,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goals
	))

	tween:Play()
	return tween
end

function ToastUI:Start(): ToastUI
	if self._destroyed then
		return self
	end

	local token = self:BeginRun()
	local options = self._options

	self:_Build()

	local root = self._root
	local label = self._label

	if not root or not label then
		return self
	end

	local finalPosition = options.Position or DEFAULTS.Position
	local startPosition = addUDim2(finalPosition, options.SlideFrom or DEFAULTS.SlideFrom)

	local backgroundTransparency = if options.BackgroundTransparency == nil
		then DEFAULTS.BackgroundTransparency
		else options.BackgroundTransparency

	local textTransparency = if options.TextTransparency == nil
		then DEFAULTS.TextTransparency
		else options.TextTransparency

	local iconTransparency = if options.IconTransparency == nil
		then DEFAULTS.IconTransparency
		else options.IconTransparency

	local fadeIn = math.max(0.01, options.FadeIn or DEFAULTS.FadeIn)
	local hold = math.max(0, options.Duration or DEFAULTS.Duration)
	local fadeOut = math.max(0.01, options.FadeOut or DEFAULTS.FadeOut)

	root.Position = startPosition
	root.BackgroundTransparency = 1
	label.TextTransparency = 1

	if self._icon then
		self._icon.ImageTransparency = 1
	end

	self:_Tween(root, fadeIn, {
		Position = finalPosition,
		BackgroundTransparency = backgroundTransparency,
	})

	self:_Tween(label, fadeIn, {
		TextTransparency = textTransparency,
	})

	if self._icon then
		self:_Tween(self._icon, fadeIn, {
			ImageTransparency = iconTransparency,
		})
	end

	task.delay(fadeIn + hold, function()
		if not self:IsAlive(token) then
			return
		end

		self:_Tween(root, fadeOut, {
			BackgroundTransparency = 1,
		})

		self:_Tween(label, fadeOut, {
			TextTransparency = 1,
		})

		if self._icon then
			self:_Tween(self._icon, fadeOut, {
				ImageTransparency = 1,
			})
		end

		task.delay(fadeOut, function()
			if not self:IsAlive(token) then
				return
			end

			self:Finish()
		end)
	end)

	return self
end

return ToastUI