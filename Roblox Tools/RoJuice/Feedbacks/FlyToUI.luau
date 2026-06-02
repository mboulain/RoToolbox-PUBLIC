--!strict
-- FlyToUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

export type PointLike = UDim2 | GuiObject | any

export type Options = {
	Parent: Instance?,

	From: PointLike?,
	To: PointLike?,

	Count: number?,
	Delay: number?,
	Interval: number?,
	Duration: number?,

	Size: UDim2?,
	ImageColor3: Color3?,
	ImageTransparency: number?,
	BackgroundTransparency: number?,
	ZIndex: number?,

	Spread: number?,
	ArcHeight: number?,
	RandomArc: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	FadeIn: number?,
	FadeOut: number?,
	EndTransparency: number?,
	ScaleFrom: number?,
	ScaleTo: number?,

	DestroyOnEnd: boolean?,
	OnEachArrive: ((index: number, token: ImageLabel) -> ())?,
	OnEnd: ((self: any) -> ())?,
}

export type FlyToUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },
	_ownedInstances: { Instance },

	_image: string,
	_options: Options,
	_root: Frame?,
}, {} :: any))

local FlyToUI = {}
FlyToUI.__index = FlyToUI
setmetatable(FlyToUI, { __index = EffectBase })

local DEFAULT_SIZE = UDim2.fromOffset(24, 24)
local DEFAULT_POSITION = UDim2.fromScale(0.5, 0.5)

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function lerpVector2(a: Vector2, b: Vector2, alpha: number): Vector2
	return a + (b - a) * alpha
end

local function quadraticBezier(p0: Vector2, p1: Vector2, p2: Vector2, alpha: number): Vector2
	local a = lerpVector2(p0, p1, alpha)
	local b = lerpVector2(p1, p2, alpha)
	return lerpVector2(a, b, alpha)
end

local function isImageId(value: any): boolean
	if typeof(value) ~= "string" then
		return false
	end

	return string.sub(value, 1, 13) == "rbxassetid://" or string.sub(value, 1, 6) == "rbx://"
end

local function resolveGuiObject(value: any): GuiObject?
	if value == nil then
		return nil
	end

	if typeof(value) == "Instance" then
		if value:IsA("GuiObject") then
			return value :: GuiObject
		end
		return nil
	end

	if typeof(value) == "table" and typeof(value.GetInstance) == "function" then
		local instance = value:GetInstance()
		if typeof(instance) == "Instance" and instance:IsA("GuiObject") then
			return instance :: GuiObject
		end
	end

	return nil
end

local function makeRoot(parent: Instance, zIndex: number?): Frame
	local root = Instance.new("Frame")
	root.Name = "RoJuice_FlyToRoot"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ClipsDescendants = false
	root.Active = false
	root.Selectable = false
	root.Size = UDim2.fromScale(1, 1)
	root.Position = UDim2.fromScale(0, 0)
	root.AnchorPoint = Vector2.new(0, 0)
	root.ZIndex = zIndex or 1000
	root.Parent = parent
	return root
end

local function udim2ToLocalVector2(position: UDim2, root: GuiObject): Vector2
	local size = root.AbsoluteSize
	return Vector2.new(
		position.X.Scale * size.X + position.X.Offset,
		position.Y.Scale * size.Y + position.Y.Offset
	)
end

local function guiObjectCenterInRoot(gui: GuiObject, root: GuiObject): Vector2
	local guiCenter = gui.AbsolutePosition + (gui.AbsoluteSize * gui.AnchorPoint)
	return guiCenter - root.AbsolutePosition
end

local function resolvePoint(point: PointLike?, root: GuiObject): Vector2
	if point == nil then
		return udim2ToLocalVector2(DEFAULT_POSITION, root)
	end

	if typeof(point) == "UDim2" then
		return udim2ToLocalVector2(point :: UDim2, root)
	end

	local gui = resolveGuiObject(point)
	if gui then
		return guiObjectCenterInRoot(gui, root)
	end

	warn("[RoJuice.FlyToUI] Invalid point. Expected UDim2, GuiObject, or effect with GetInstance().")
	return udim2ToLocalVector2(DEFAULT_POSITION, root)
end

local function makeToken(image: string, options: Options, parent: Instance, index: number): ImageLabel
	local token = Instance.new("ImageLabel")
	token.Name = "RoJuice_FlyToken"
	token.BackgroundTransparency = if options.BackgroundTransparency ~= nil then options.BackgroundTransparency else 1
	token.BorderSizePixel = 0
	token.AnchorPoint = Vector2.new(0.5, 0.5)
	token.Size = options.Size or DEFAULT_SIZE
	token.Image = image
	token.ImageColor3 = options.ImageColor3 or Color3.fromRGB(255, 255, 255)
	token.ImageTransparency = if options.ImageTransparency ~= nil then options.ImageTransparency else 0
	token.ZIndex = (options.ZIndex or 1000) + index
	token.Parent = parent

	local scale = Instance.new("UIScale")	scale.Name = "RoJuice_FlyTokenScale"
	scale.Scale = options.ScaleFrom or 1
	scale.Parent = token

	return token
end

local function setTokenPosition(token: GuiObject, position: Vector2)
	token.Position = UDim2.fromOffset(position.X, position.Y)
end

local function setTokenTransparency(token: ImageLabel, transparency: number)
	token.ImageTransparency = clamp01(transparency)
end

local function waitSeconds(self: any, token: number, seconds: number): boolean
	if seconds <= 0 then
		return self:IsAlive(token)
	end

	local start = os.clock()
	while self:IsAlive(token) and os.clock() - start < seconds do
		task.wait()
	end

	return self:IsAlive(token)
end

function FlyToUI.new(image: string, options: Options?): FlyToUI
	assert(image ~= nil, "FlyToUI.new(image, options?) image is nil")
	assert(isImageId(image), "FlyToUI.new(image, options?) image must be an image id")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, FlyToUI)

	self.OnEnd = opts.OnEnd
	self._image = image
	self._options = opts
	self._root = nil

	return self
end

function FlyToUI:GetInstance(): Frame?
	if self._destroyed then
		return nil
	end

	return self._root
end

function FlyToUI:GetRootInstance(): Frame?
	return self:GetInstance()
end

function FlyToUI:SetFrom(from: PointLike): FlyToUI
	if not self._destroyed then
		self._options.From = from
	end
	return self
end

function FlyToUI:SetTo(to: PointLike): FlyToUI
	if not self._destroyed then
		self._options.To = to
	end
	return self
end

function FlyToUI:Start(): FlyToUI
	if self._destroyed then
		return self
	end

	local options = self._options
	if options.Parent == nil then
		warn("[RoJuice.FlyToUI] No Parent. Pass { Parent = yourScreenGuiOrFrame }.")
		self:Finish()
		return self
	end

	local token = self:BeginRun()

	local root = makeRoot(options.Parent, options.ZIndex)
	self._root = root
	self:Own(root)

	local count = math.max(1, math.floor(options.Count or 10))
	local delay = math.max(0, options.Delay or 0)
	local interval = math.max(0, options.Interval or 0.03)
	local duration = math.max(0.05, options.Duration or 0.55)

	local spread = math.max(0, options.Spread or 14)
	local arcHeight = options.ArcHeight or 40
	local randomArc = clamp01(options.RandomArc or 0.35)
	local easingStyle = options.EasingStyle or Enum.EasingStyle.Quad
	local easingDirection = options.EasingDirection or Enum.EasingDirection.Out

	local fadeIn = math.max(0, options.FadeIn or 0)
	local fadeOut = math.max(0, options.FadeOut or 0.12)
	local endTransparency = clamp01(if options.EndTransparency ~= nil then options.EndTransparency else 1)
	local baseTransparency = clamp01(if options.ImageTransparency ~= nil then options.ImageTransparency else 0)

	local scaleFrom = options.ScaleFrom or 1
	local scaleTo = options.ScaleTo or 1
	local onEachArrive = options.OnEachArrive

	task.spawn(function()
		if not waitSeconds(self, token, delay) then
			return
		end

		local from = resolvePoint(options.From, root)
		local to = resolvePoint(options.To, root)

		for i = 1, count do
			if not self:IsAlive(token) then
				return
			end

			local flyToken = makeToken(self._image, options, root, i)
			self:Own(flyToken)

			local offset = Vector2.new(
				(math.random() * 2 - 1) * spread,
				(math.random() * 2 - 1) * spread
			)
			local startPosition = from + offset
			local middle = (startPosition + to) * 0.5
			local arcJitter = 1 + ((math.random() * 2 - 1) * randomArc)
			local control = middle + Vector2.new(0, -arcHeight * arcJitter)

			setTokenPosition(flyToken, startPosition)

			local scale = flyToken:FindFirstChildOfClass("UIScale") :: UIScale?
			if scale then
				scale.Scale = scaleFrom
			end

			if fadeIn > 0 then
				setTokenTransparency(flyToken, 1)
			else
				setTokenTransparency(flyToken, baseTransparency)
			end

			local driver = Instance.new("NumberValue")
			driver.Name = "RoJuice_FlyTokenDriver"
			driver.Value = 0
			driver.Parent = flyToken
			self:Own(driver)

			local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
			local tween = self:TrackTween(TweenService:Create(driver, tweenInfo, { Value = 1 }))

			self:TrackConnection(driver.Changed:Connect(function()
				if not self:IsAlive(token) or not flyToken.Parent then
					return
				end

				local alpha = clamp01(driver.Value)
				local position = quadraticBezier(startPosition, control, to, alpha)
				setTokenPosition(flyToken, position)

				if scale then
					scale.Scale = lerp(scaleFrom, scaleTo, alpha)
				end

				local transparency = baseTransparency
				local fadeInRatio = if fadeIn > 0 then math.min(1, fadeIn / duration) else 0
				local fadeOutRatio = if fadeOut > 0 then math.min(1, fadeOut / duration) else 0

				if fadeInRatio > 0 and alpha <= fadeInRatio then
					transparency = lerp(1, baseTransparency, alpha / fadeInRatio)
				end

				if fadeOutRatio > 0 and alpha >= 1 - fadeOutRatio then
					transparency = lerp(baseTransparency, endTransparency, (alpha - (1 - fadeOutRatio)) / fadeOutRatio)
				end

				setTokenTransparency(flyToken, transparency)
			end))

			self:TrackConnection(tween.Completed:Connect(function()
				if not self:IsAlive(token) then
					return
				end

				if onEachArrive then
					task.spawn(function()
						local ok, err = pcall(onEachArrive, i, flyToken)
						if not ok then
							warn("[RoJuice.FlyToUI] OnEachArrive error:", err)
						end
					end)
				end

				if flyToken.Parent then
					flyToken:Destroy()
				end
			end))

			tween:Play()

			if i < count and not waitSeconds(self, token, interval) then
				return
			end
		end

		local totalWait = duration + 0.03
		if not waitSeconds(self, token, totalWait) then
			return
		end

		self:Finish()
	end)

	return self
end

return FlyToUI
