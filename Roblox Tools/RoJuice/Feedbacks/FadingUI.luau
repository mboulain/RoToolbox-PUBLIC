--!strict
-- FadingUI (RoJuice)

local TweenService = game:GetService("TweenService")

local EffectBase = require(script.Parent.Parent.EffectBase)

type Timing = {
	FadeIn: number?,
	Duration: number?,
	FadeOut: number?,
	Delay: number?,
}

export type Options = {
	Timing: Timing?,
	FadeIn: number?,
	Duration: number?,
	FadeOut: number?,
	Delay: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	IncludeDescendants: boolean?,

	FollowDescendants: boolean?,

	HiddenTransparency: number?,

	RestoreOnEnd: boolean?,

	DestroyOnEnd: boolean?,
	OnEnd: ((self: any) -> ())?,
}

type TransparencySnapshot = { [string]: number }
type SnapshotMap = { [Instance]: TransparencySnapshot }
type Entry = { Obj: Instance, Prop: string }

export type FadingUI = typeof(setmetatable({} :: {
	DestroyOnEnd: boolean,
	OnEnd: ((self: any) -> ())?,

	_destroyed: boolean,
	_token: number,
	_cleanups: { any },

	_target: GuiObject,
	_options: Options,

	_originals: SnapshotMap,
	_entriesVisible: { Entry },

	_completedNaturally: boolean,
	_t0: number,
	_t1: number,
	_t2: number,
	_t3: number,
}, {} :: any))

local FadingUI = {}
FadingUI.__index = FadingUI
setmetatable(FadingUI, { __index = EffectBase })

local function waitSeconds(self: any, seconds: number, token: number): boolean
	local start = os.clock()
	while self:IsAlive(token) and os.clock() - start < seconds do
		task.wait()
	end
	return self:IsAlive(token)
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

local function setEntry(entry: Entry, value: number)
	if entry.Obj.Parent == nil then
		return
	end

	pcall(function()
		(entry.Obj :: any)[entry.Prop] = value
	end)
end

function FadingUI.new(target: GuiObject, options: Options?): FadingUI
	assert(target ~= nil, "FadingUI.new(target, options?) target is nil")
	assert(target:IsA("GuiObject"), "FadingUI.new(target, options?) target must be a GuiObject")

	local opts = options or {}
	local self = EffectBase.new(opts.DestroyOnEnd) :: any
	setmetatable(self, FadingUI)

	self.OnEnd = opts.OnEnd
	self._target = target
	self._options = opts

	self._originals = {}
	self._entriesVisible = {}

	self._completedNaturally = false
	self._t0 = 0
	self._t1 = 0
	self._t2 = 0
	self._t3 = 0

	return self
end

function FadingUI:GetInstance(): nil
	return nil
end

function FadingUI:GetTarget(): GuiObject
	return self._target
end

function FadingUI:_remember(obj: Instance, prop: string, value: number)
	local map = self._originals[obj]
	if not map then
		map = {}
		self._originals[obj] = map
	end

	if map[prop] ~= nil then
		return
	end

	map[prop] = value

	if value < 1 then
		table.insert(self._entriesVisible, {
			Obj = obj,
			Prop = prop,
		})
	end
end

function FadingUI:_registerTransparencies(obj: Instance)
	if obj:IsA("GuiObject") then
		self:_remember(obj, "BackgroundTransparency", obj.BackgroundTransparency)

		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			local textObj = obj :: any
			self:_remember(obj, "TextTransparency", textObj.TextTransparency)
			self:_remember(obj, "TextStrokeTransparency", textObj.TextStrokeTransparency)
		end

		if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
			local imageObj = obj :: any
			self:_remember(obj, "ImageTransparency", imageObj.ImageTransparency)
		end
	end

	if obj:IsA("UIStroke") then
		self:_remember(obj, "Transparency", obj.Transparency)
	end

	if obj:IsA("CanvasGroup") then
		self:_remember(obj, "GroupTransparency", obj.GroupTransparency)
	end
end

function FadingUI:_restore()
	for inst, props in pairs(self._originals) do
		if inst.Parent == nil then
			continue
		end

		for prop, value in pairs(props) do
			pcall(function()
				(inst :: any)[prop] = value
			end)
		end
	end
end

function FadingUI:_phaseAt(now: number): "Before" | "FadeIn" | "Hold" | "FadeOut" | "After"
	if now < self._t0 then return "Before" end
	if now < self._t1 then return "FadeIn" end
	if now < self._t2 then return "Hold" end
	if now < self._t3 then return "FadeOut" end
	return "After"
end

function FadingUI:_applyNewEntry(entry: Entry, token: number)
	if not self:IsAlive(token) then
		return
	end

	local snap = self._originals[entry.Obj] and self._originals[entry.Obj][entry.Prop]
	if snap == nil then
		return
	end

	local hidden = math.clamp(self._options.HiddenTransparency or 1, 0, 1)
	if snap >= hidden then
		setEntry(entry, hidden)
		return
	end

	local now = os.clock()
	local phase = self:_phaseAt(now)
	local easingStyle = self._options.EasingStyle or Enum.EasingStyle.Quad
	local easingDirection = self._options.EasingDirection or Enum.EasingDirection.Out

	if phase == "Before" then
		setEntry(entry, hidden)
		return
	end

	if phase == "FadeIn" then
		local remaining = math.max(0, self._t1 - now)
		setEntry(entry, hidden)
		if remaining <= 0 then
			setEntry(entry, snap)
		else
			local tween = self:TrackTween(TweenService:Create(entry.Obj, TweenInfo.new(remaining, easingStyle, easingDirection), {
				[entry.Prop] = snap,
			}))
			tween:Play()
		end
		return
	end

	if phase == "Hold" then
		setEntry(entry, snap)
		return
	end

	if phase == "FadeOut" then
		local remaining = math.max(0, self._t3 - now)
		setEntry(entry, snap)
		if remaining <= 0 then
			setEntry(entry, hidden)
		else
			local tween = self:TrackTween(TweenService:Create(entry.Obj, TweenInfo.new(remaining, easingStyle, easingDirection), {
				[entry.Prop] = hidden,
			}))
			tween:Play()
		end
		return
	end

	setEntry(entry, hidden)
end

function FadingUI:Cancel()
	if self._destroyed then
		return
	end

	EffectBase.Cancel(self)

	if not self._completedNaturally or self._options.RestoreOnEnd == true then
		self:_restore()
	end
end

function FadingUI:Destroy()
	if self._destroyed then
		return
	end

	self:Cancel()
	self._destroyed = true
end

function FadingUI:Finish()
	if self._destroyed then
		return
	end

	self._completedNaturally = true

	if self._options.RestoreOnEnd == true then
		self:_restore()
	end

	EffectBase.Finish(self)
end

function FadingUI:Start(): FadingUI
	if self._destroyed then
		return self
	end

	local target = self._target
	if not target or not target.Parent then
		warn("[RoJuice.FadingUI] Target has no parent or was destroyed.")
		self:Finish()
		return self
	end

	local token = self:BeginRun()
	local options = self._options
	local timing = options.Timing

	local fadeIn = math.max(0, (timing and timing.FadeIn) or options.FadeIn or 0.2)
	local duration = math.max(0, (timing and timing.Duration) or options.Duration or 0)
	local fadeOut = math.max(0, (timing and timing.FadeOut) or options.FadeOut or 0.5)
	local delay = math.max(0, (timing and timing.Delay) or options.Delay or 0)

	local hidden = math.clamp(options.HiddenTransparency or 1, 0, 1)
	local easingStyle = options.EasingStyle or Enum.EasingStyle.Quad
	local easingDirection = options.EasingDirection or Enum.EasingDirection.Out
	local includeDescendants = if options.IncludeDescendants == nil then true else options.IncludeDescendants
	local followDescendants = if options.FollowDescendants == nil then true else options.FollowDescendants

	self._completedNaturally = false
	self._originals = {}
	self._entriesVisible = {}

	local now = os.clock()
	self._t0 = now + delay
	self._t1 = self._t0 + fadeIn
	self._t2 = self._t1 + duration
	self._t3 = self._t2 + fadeOut

	self:_registerTransparencies(target)

	if includeDescendants then
		for _, descendant in ipairs(target:GetDescendants()) do
			self:_registerTransparencies(descendant)
		end
	end

	for _, entry in ipairs(self._entriesVisible) do
		setEntry(entry, hidden)
	end

	if followDescendants then
		local connection = target.DescendantAdded:Connect(function(descendant: Instance)
			if not self:IsAlive(token) then
				return
			end

			local before = #self._entriesVisible
			self:_registerTransparencies(descendant)

			for index = before + 1, #self._entriesVisible do
				self:_applyNewEntry(self._entriesVisible[index], token)
			end
		end)

		self:TrackConnection(connection)
	end

	task.spawn(function()
		if not waitSeconds(self, delay, token) then
			return
		end

		local fadeInTweens = {}
		for _, entry in ipairs(self._entriesVisible) do
			local snap = self._originals[entry.Obj] and self._originals[entry.Obj][entry.Prop]
			if snap ~= nil then
				if fadeIn <= 0 then
					setEntry(entry, snap)
				else
					local tween = self:TrackTween(TweenService:Create(entry.Obj, TweenInfo.new(fadeIn, easingStyle, easingDirection), {
						[entry.Prop] = snap,
					}))
					table.insert(fadeInTweens, tween)
					tween:Play()
				end
			end
		end

		if fadeInTweens[1] and not waitTween(self, fadeInTweens[1], token) then
			return
		end

		if not waitSeconds(self, duration, token) then
			return
		end

		local fadeOutTweens = {}
		for _, entry in ipairs(self._entriesVisible) do
			if fadeOut <= 0 then
				setEntry(entry, hidden)
			else
				local tween = self:TrackTween(TweenService:Create(entry.Obj, TweenInfo.new(fadeOut, easingStyle, easingDirection), {
					[entry.Prop] = hidden,
				}))
				table.insert(fadeOutTweens, tween)
				tween:Play()
			end
		end

		if fadeOutTweens[1] and not waitTween(self, fadeOutTweens[1], token) then
			return
		end

		self:Finish()
	end)

	return self
end

return FadingUI
