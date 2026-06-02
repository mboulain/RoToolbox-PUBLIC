--!strict
-- FloatingTextUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

type DirectionName = "Up" | "Down" | "Left" | "Right"

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

	Direction: DirectionName?,
	Offset: UDim2?,
	Distance: number?,
	Duration: number?,
	Delay: number?,
	FadeOut: boolean?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	Template: TextLabel?,
	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type FloatingTextUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },
	_ownedInstances: { Instance },

	_text: string,
	_options: Options,
	_root: Frame,
	_content: TextLabel,
}, {} :: any))

local FloatingTextUI = {}
FloatingTextUI.__index = FloatingTextUI
setmetatable(FloatingTextUI, { __index = EffectBase })

local DEFAULT_SIZE = UDim2.fromOffset(160, 40)
local DEFAULT_POSITION = UDim2.fromScale(0.5, 0.5)
local DEFAULT_ANCHOR = Vector2.new(0.5, 0.5)

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

	if options.ZIndex ~= nil then
		label.ZIndex = options.ZIndex
	end
end

local function makeContent(text: string, options: Options): TextLabel
	local label: TextLabel

	if options.Template then
		label = options.Template:Clone()
	else
		label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.RichText = true
		label.TextScaled = false
		label.TextWrapped = false
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.35
		label.TextSize = 24
		label.Font = Enum.Font.GothamBold
	end

	label.Name = "RoJuice_FloatingTextContent"
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)

	applyTextOptions(label, text, options)

	return label
end

local function makeRoot(content: TextLabel, options: Options): Frame
	local root = Instance.new("Frame")
	root.Name = "RoJuice_FloatingTextRoot"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ClipsDescendants = false
	root.Active = false
	root.Selectable = false

	local contentSize = content.Size
	local rootSize = options.Size
	if rootSize == nil or rootSize == UDim2.new() then
		rootSize = if contentSize ~= UDim2.new() then contentSize else DEFAULT_SIZE
	end

	root.Size = rootSize :: UDim2
	root.Position = options.Position or DEFAULT_POSITION
	root.AnchorPoint = options.AnchorPoint or DEFAULT_ANCHOR
	root.ZIndex = options.ZIndex or content.ZIndex

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

function FloatingTextUI.new(text: string, options: Options?): FloatingTextUI
	assert(text ~= nil, "FloatingTextUI.new(text, options?) text is nil")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, FloatingTextUI)

	self.OnEnd = opts.OnEnd
	self._text = text
	self._options = opts

	local content = makeContent(text, opts)
	local root = makeRoot(content, opts)

	self._root = root
	self._content = content

	self:Own(root)

	if opts.Parent then
		root.Parent = opts.Parent
	end

	return self
end

function FloatingTextUI:GetInstance(): TextLabel?
	if self._destroyed then
		return nil
	end

	return self._content
end

function FloatingTextUI:GetTarget(): TextLabel?
	return self:GetInstance()
end

function FloatingTextUI:GetRootInstance(): Frame?
	if self._destroyed then
		return nil
	end

	return self._root
end

function FloatingTextUI:Start(): FloatingTextUI
	if self._destroyed then
		return self
	end

	local root = self._root
	local content = self._content
	local options = self._options

	if not root.Parent then
		warn("[RoJuice.FloatingTextUI] No Parent. Pass { Parent = yourScreenGuiOrFrame }.")
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

	local rootGoal: { [string]: any } = {
		Position = endPosition,
	}

	local contentGoal: { [string]: any } = {}
	if fadeOut then
		contentGoal.TextTransparency = 1
		contentGoal.TextStrokeTransparency = 1
		contentGoal.BackgroundTransparency = 1
	end

	task.spawn(function()
		if not self:IsAlive(token) then
			return
		end

		local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection, 0, false, delay)
		local rootTween = self:TrackTween(TweenService:Create(root, tweenInfo, rootGoal))
		rootTween:Play()

		if fadeOut then
			local contentTween = self:TrackTween(TweenService:Create(content, tweenInfo, contentGoal))
			contentTween:Play()
		end

		if not waitTween(self, rootTween, token) then
			return
		end

		self:Finish()
	end)

	return self
end

return FloatingTextUI
