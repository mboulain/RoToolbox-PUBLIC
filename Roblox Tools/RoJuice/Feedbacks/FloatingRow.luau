--!strict
-- FloatingRow (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

type DirectionName = "Up" | "Down" | "Left" | "Right"
type ImageSide = "Left" | "Right"

export type Options = {
	Parent: Instance?,
	Position: UDim2?,
	Size: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,

	TextColor3: Color3?,
	TextTransparency: number?,
	TextSize: number?,
	Font: Enum.Font?,
	TextStrokeTransparency: number?,
	BackgroundTransparency: number?,
	RichText: boolean?,

	Image: string?,
	ImageSize: UDim2?,
	ImageColor3: Color3?,
	ImageTransparency: number?,
	ImageScaleType: Enum.ScaleType?,
	ImageSide: ImageSide?,
	Padding: number?,

	Direction: DirectionName?,
	Offset: UDim2?,
	Distance: number?,
	Duration: number?,
	Delay: number?,
	FadeOut: boolean?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type FloatingRow = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },
	_ownedInstances: { Instance },

	_text: string,
	_options: Options,
	_root: Frame,
	_content: CanvasGroup,
	_icon: ImageLabel,
	_label: TextLabel,
}, {} :: any))

local FloatingRow = {}
FloatingRow.__index = FloatingRow
setmetatable(FloatingRow, { __index = EffectBase })

local DEFAULT_SIZE = UDim2.fromOffset(160, 40)
local DEFAULT_POSITION = UDim2.fromScale(0.5, 0.5)
local DEFAULT_ANCHOR = Vector2.new(0.5, 0.5)
local DEFAULT_IMAGE_SIZE = UDim2.fromOffset(24, 24)

local function directionOffset(direction: DirectionName?, distance: number): UDim2
	local dir = direction or "Up"

	if dir == "Down" then
		return UDim2.fromOffset(0, distance)
	elseif dir == "Left" then
		return UDim2.fromOffset(-distance, 0)
	elseif dir == "Right" then
		return UDim2.fromOffset(distance, 0)
	end

	return UDim2.fromOffset(0, -distance)
end

local function applyTextOptions(label: TextLabel, text: string, options: Options)
	label.Text = text

	if options.TextColor3 ~= nil then
		label.TextColor3 = options.TextColor3
	end

	if options.TextTransparency ~= nil then
		label.TextTransparency = options.TextTransparency
	end

	if options.TextSize ~= nil then
		label.TextSize = options.TextSize
	end

	if options.Font ~= nil then
		label.Font = options.Font
	end

	if options.TextStrokeTransparency ~= nil then
		label.TextStrokeTransparency = options.TextStrokeTransparency
	end

	if options.BackgroundTransparency ~= nil then
		label.BackgroundTransparency = options.BackgroundTransparency
	end

	if options.RichText ~= nil then
		label.RichText = options.RichText
	end

	if options.ZIndex ~= nil then
		label.ZIndex = options.ZIndex
	end
end

local function applyImageOptions(icon: ImageLabel, options: Options)
	icon.Image = options.Image or ""
	icon.Visible = options.Image ~= nil and options.Image ~= ""

	if options.ImageSize ~= nil then
		icon.Size = options.ImageSize
	end

	if options.ImageColor3 ~= nil then
		icon.ImageColor3 = options.ImageColor3
	end

	if options.ImageTransparency ~= nil then
		icon.ImageTransparency = options.ImageTransparency
	end

	if options.ImageScaleType ~= nil then
		icon.ScaleType = options.ImageScaleType
	end

	if options.ZIndex ~= nil then
		icon.ZIndex = options.ZIndex
	end
end

local function makeContent(text: string, options: Options): (CanvasGroup, ImageLabel, TextLabel)
	local content = Instance.new("CanvasGroup")
	content.Name = "RoJuice_FloatingRowContent"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.GroupTransparency = 0
	content.AutomaticSize = Enum.AutomaticSize.XY
	content.Size = UDim2.fromOffset(0, 0)
	content.Position = UDim2.fromScale(0.5, 0.5)
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.ClipsDescendants = false
	content.Active = false
	content.Selectable = false

	local layout = Instance.new("UIListLayout")
	layout.Name = "RowLayout"
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, options.Padding or 6)
	layout.Parent = content

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Size = options.ImageSize or DEFAULT_IMAGE_SIZE
	icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	icon.ImageTransparency = 0
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = content

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.RichText = true
	label.TextScaled = false
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.TextSize = 24
	label.Font = Enum.Font.GothamBold
	label.Parent = content

	local imageSide = options.ImageSide or "Left"
	if imageSide == "Right" then
		label.LayoutOrder = 1
		icon.LayoutOrder = 2
	else
		icon.LayoutOrder = 1
		label.LayoutOrder = 2
	end

	applyImageOptions(icon, options)
	applyTextOptions(label, text, options)

	return content, icon, label
end

local function makeRoot(content: CanvasGroup, options: Options): Frame
	local root = Instance.new("Frame")
	root.Name = "RoJuice_FloatingRowRoot"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ClipsDescendants = false
	root.Active = false
	root.Selectable = false

	root.Size = options.Size or DEFAULT_SIZE
	root.Position = options.Position or DEFAULT_POSITION
	root.AnchorPoint = options.AnchorPoint or DEFAULT_ANCHOR
	root.ZIndex = options.ZIndex or 1

	content.Parent = root
	return root
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

function FloatingRow.new(text: string, options: Options?): FloatingRow
	assert(text ~= nil, "FloatingRow.new(text, options?) text is nil")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, FloatingRow)

	self.OnEnd = opts.OnEnd
	self._text = text
	self._options = opts

	local content, icon, label = makeContent(text, opts)
	local root = makeRoot(content, opts)

	self._root = root
	self._content = content
	self._icon = icon
	self._label = label

	self:Own(root)

	if opts.Parent then
		root.Parent = opts.Parent
	end

	return self
end

function FloatingRow:GetInstance(): CanvasGroup?
	if self._destroyed then
		return nil
	end

	return self._content
end

function FloatingRow:GetTarget(): CanvasGroup?
	return self:GetInstance()
end

function FloatingRow:GetRootInstance(): Frame?
	if self._destroyed then
		return nil
	end

	return self._root
end

function FloatingRow:GetIcon(): ImageLabel?
	if self._destroyed then
		return nil
	end

	return self._icon
end

function FloatingRow:GetText(): TextLabel?
	if self._destroyed then
		return nil
	end

	return self._label
end

function FloatingRow:Start(): FloatingRow
	if self._destroyed then
		return self
	end

	local root = self._root
	local content = self._content
	local options = self._options

	if not root.Parent then
		warn("[RoJuice.FloatingRow] No Parent. Pass { Parent = yourScreenGuiOrFrame }.")
		self:Finish()
		return self
	end

	local token = self:BeginRun()

	local duration = math.max(0, options.Duration or 0.55)
	local delay = math.max(0, options.Delay or 0)
	local fadeOut = if options.FadeOut == nil then true else options.FadeOut
	local easingStyle = options.EasingStyle or Enum.EasingStyle.Quad
	local easingDirection = options.EasingDirection or Enum.EasingDirection.Out

	local startPosition = root.Position
	local offset = options.Offset or directionOffset(options.Direction, options.Distance or 36)
	local endPosition = startPosition + offset

	task.spawn(function()
		if not self:IsAlive(token) then
			return
		end

		local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection, 0, false, delay)
		local rootTween = self:TrackTween(TweenService:Create(root, tweenInfo, {
			Position = endPosition,
		}))
		rootTween:Play()

		if fadeOut then
			local contentTween = self:TrackTween(TweenService:Create(content, tweenInfo, {
				GroupTransparency = 1,
			}))
			contentTween:Play()
		end

		if not waitTween(self, rootTween, token) then
			return
		end

		self:Finish()
	end)

	return self
end

return FloatingRow
