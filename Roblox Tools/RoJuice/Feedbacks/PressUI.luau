--!strict
-- PressUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

type Timing = {
	Down: number?,
	Hold: number?,
	Up: number?,
	Delay: number?,
}

export type Options = {
	PressedScale: number?,
	Timing: Timing?,
	Down: number?,
	Hold: number?,
	Up: number?,
	Delay: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	UseColorFeedback: boolean?,
	ColorMultiplier: number?,
	OnlyIfButton: boolean?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

export type PressUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_target: GuiObject,
	_options: Options,
	_scale: UIScale?,
	_ownsScale: boolean,
	_baseScale: number?,
	_baseImageColor: Color3?,
	_baseTextColor: Color3?,
}, {} :: any))

local PressUI = {}
PressUI.__index = PressUI
setmetatable(PressUI, { __index = EffectBase })

local SCALE_NAME = "RoJuice_PressScale"

local function multiplyColor(color: Color3, multiplier: number): Color3
	multiplier = math.clamp(multiplier, 0, 1)
	return Color3.new(color.R * multiplier, color.G * multiplier, color.B * multiplier)
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

function PressUI.new(target: GuiObject, options: Options?): PressUI
	assert(target ~= nil, "PressUI.new(target, options?) target is nil")
	assert(target:IsA("GuiObject"), "PressUI.new(target, options?) target must be a GuiObject")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, PressUI)

	self.OnEnd = opts.OnEnd
	self._target = target
	self._options = opts
	self._scale = nil
	self._ownsScale = false
	self._baseScale = nil
	self._baseImageColor = nil
	self._baseTextColor = nil

	return self
end

function PressUI:GetInstance(): nil
	return nil
end

function PressUI:GetTarget(): GuiObject
	return self._target
end

function PressUI:_getOrCreateScale(): (UIScale, boolean)
	local existing = self._target:FindFirstChild(SCALE_NAME)
	if existing and existing:IsA("UIScale") then
		return existing, false
	end

	local scale = Instance.new("UIScale")
	scale.Name = SCALE_NAME
	scale.Scale = 1
	scale.Parent = self._target

	return scale, true
end

function PressUI:_restore()
	if self._scale and self._baseScale ~= nil then
		self._scale.Scale = self._baseScale
	end

	local target = self._target

	if self._baseImageColor and (target:IsA("ImageButton") or target:IsA("ImageLabel")) then
		(target :: any).ImageColor3 = self._baseImageColor
	end

	if self._baseTextColor and (target:IsA("TextButton") or target:IsA("TextLabel") or target:IsA("TextBox")) then
		(target :: any).TextColor3 = self._baseTextColor
	end
end

function PressUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)
	self:_restore()
end

function PressUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()

	if self._scale and self._ownsScale then
		self._scale:Destroy()
	end

	self._destroyed = true
	self._scale = nil
end

function PressUI:Start(): PressUI
	if self._destroyed then
		return self
	end

	local target = self._target
	if not target or not target.Parent then
		warn("[RoJuice.PressUI] Target has no parent or was destroyed.")
		self:Finish()
		return self
	end

	local token = self:BeginRun()
	local options = self._options
	local timing = options.Timing

	local down = math.max(0, (timing and timing.Down) or options.Down or 0.08)
	local hold = math.max(0, (timing and timing.Hold) or options.Hold or 0.03)
	local up = math.max(0, (timing and timing.Up) or options.Up or 0.10)
	local delay = math.max(0, (timing and timing.Delay) or options.Delay or 0)

	local pressedScale = options.PressedScale or 0.92
	local easingStyle = options.EasingStyle or Enum.EasingStyle.Quad
	local easingDirection = options.EasingDirection or Enum.EasingDirection.Out

	self._scale, self._ownsScale = self:_getOrCreateScale()
	self._baseScale = self._scale.Scale

	local useColor = if options.UseColorFeedback == nil then true else options.UseColorFeedback
	local onlyIfButton = if options.OnlyIfButton == nil then true else options.OnlyIfButton
	local colorMultiplier = options.ColorMultiplier or 0.92
	local canUseColor = useColor and (not onlyIfButton or target:IsA("GuiButton"))

	local imageGoal: Color3? = nil
	local textGoal: Color3? = nil

	if canUseColor then
		if target:IsA("ImageButton") or target:IsA("ImageLabel") then
			self._baseImageColor = (target :: any).ImageColor3
			imageGoal = multiplyColor(self._baseImageColor :: Color3, colorMultiplier)
		end

		if target:IsA("TextButton") or target:IsA("TextLabel") or target:IsA("TextBox") then
			self._baseTextColor = (target :: any).TextColor3
			textGoal = multiplyColor(self._baseTextColor :: Color3, colorMultiplier)
		end
	end

	task.spawn(function()
		if not self:IsAlive(token) then
			return
		end

		local downInfo = TweenInfo.new(down, easingStyle, easingDirection, 0, false, delay)
		local scaleDown = self:TrackTween(TweenService:Create(self._scale :: UIScale, downInfo, {
			Scale = pressedScale,
		}))

		local imageDown: Tween? = nil
		local textDown: Tween? = nil

		if imageGoal then
			imageDown = self:TrackTween(TweenService:Create(target, downInfo, {
				ImageColor3 = imageGoal,
			}))
		end

		if textGoal then
			textDown = self:TrackTween(TweenService:Create(target, downInfo, {
				TextColor3 = textGoal,
			}))
		end

		scaleDown:Play()
		if imageDown then imageDown:Play() end
		if textDown then textDown:Play() end

		if not waitTween(self, scaleDown, token) then
			return
		end

		local holdStart = os.clock()
		while self:IsAlive(token) and os.clock() - holdStart < hold do
			task.wait()
		end

		if not self:IsAlive(token) then
			return
		end

		local upInfo = TweenInfo.new(up, easingStyle, Enum.EasingDirection.InOut)
		local scaleUp = self:TrackTween(TweenService:Create(self._scale :: UIScale, upInfo, {
			Scale = self._baseScale or 1,
		}))

		local imageUp: Tween? = nil
		local textUp: Tween? = nil

		if self._baseImageColor then
			imageUp = self:TrackTween(TweenService:Create(target, upInfo, {
				ImageColor3 = self._baseImageColor,
			}))
		end

		if self._baseTextColor then
			textUp = self:TrackTween(TweenService:Create(target, upInfo, {
				TextColor3 = self._baseTextColor,
			}))
		end

		scaleUp:Play()
		if imageUp then imageUp:Play() end
		if textUp then textUp:Play() end

		if not waitTween(self, scaleUp, token) then
			return
		end

		self:_restore()
		self:Finish()
	end)

	return self
end

return PressUI
