local Types = require(script.Parent.Types)
local Helpers = require(script.Parent.Helpers)

-- Target Modifiers
local PressUI = require(script.Parent.Feedbacks.PressUI)
local PulseUI = require(script.Parent.Feedbacks.PulseUI)
local FadingUI = require(script.Parent.Feedbacks.FadingUI)
local ShakeUI = require(script.Parent.Feedbacks.ShakeUI)
local WiggleUI = require(script.Parent.Feedbacks.WiggleUI)
local BounceUI = require(script.Parent.Feedbacks.BounceUI)
local PopUI = require(script.Parent.Feedbacks.PopUI)
local SlideUI = require(script.Parent.Feedbacks.SlideUI)
local RotateUI = require(script.Parent.Feedbacks.RotateUI)
local GlowUI = require(script.Parent.Feedbacks.GlowUI)
local ColorShiftUI = require(script.Parent.Feedbacks.ColorShiftUI)
local TrailUI = require(script.Parent.Feedbacks.TrailUI)
local HoverUI = require(script.Parent.Feedbacks.HoverUI)

-- Instance spawners
local FloatingTextUI = require(script.Parent.Feedbacks.FloatingTextUI)
local FloatingRow = require(script.Parent.Feedbacks.FloatingRow)
local FlyToUI = require(script.Parent.Feedbacks.FlyToUI)
local ToastUI = require(script.Parent.Feedbacks.ToastUI)
local RadialBurstUI = require(script.Parent.Feedbacks.RadialBurstUI)

-- Advanced effects
local FollowUI = require(script.Parent.Feedbacks.FollowUI)

local RoJuice = {}
RoJuice.__index = RoJuice
RoJuice.Types = Types
RoJuice.Helpers = Helpers

export type TargetLike = GuiObject | Types.EffectWithGuiInstance

export type RoJuice = typeof(setmetatable({} :: {
	Parent: Instance?,
	Types: any,
	Helpers: any,
}, RoJuice))

local function resolveGuiObject(value: any, methodName: string): GuiObject
	assert(value ~= nil, methodName .. " target is nil")

	if typeof(value) == "Instance" then
		assert(value:IsA("GuiObject"), methodName .. " target must be a GuiObject")
		return value :: GuiObject
	end

	if typeof(value) == "table" and typeof(value.GetInstance) == "function" then
		local instance = value:GetInstance()
		assert(instance ~= nil, methodName .. " effect:GetInstance() returned nil")
		assert(instance:IsA("GuiObject"), methodName .. " effect:GetInstance() must return a GuiObject")
		return instance :: GuiObject
	end

	error(methodName .. " target must be a GuiObject or an effect with GetInstance()", 3)
end

function RoJuice.new(): RoJuice
	local self = setmetatable({}, RoJuice) :: any
	return self
end

-- TARGET MODIFIERS
function RoJuice:Press(target: TargetLike, options: Types.PressOptions?): any
	return PressUI.new(resolveGuiObject(target, "RoJuice:Press(target, options?)"), options)
end

function RoJuice:Pulse(target: TargetLike, options: Types.PulseOptions?): any
	return PulseUI.new(resolveGuiObject(target, "RoJuice:Pulse(target, options?)"), options)
end

function RoJuice:Fade(target: TargetLike, options: Types.FadingOptions?): any
	return FadingUI.new(resolveGuiObject(target, "RoJuice:Fade(target, options?)"), options)
end

function RoJuice:Shake(target: TargetLike, options: Types.ShakeOptions?): any
	return ShakeUI.new(resolveGuiObject(target, "RoJuice:Shake(target, options?)"), options)
end

function RoJuice:Wiggle(target: TargetLike, options: Types.WiggleOptions?): any
	return WiggleUI.new(resolveGuiObject(target, "RoJuice:Wiggle(target, options?)"), options)
end

function RoJuice:Bounce(target: TargetLike, options: Types.BounceOptions?): any
	return BounceUI.new(resolveGuiObject(target, "RoJuice:Bounce(target, options?)"), options)
end

function RoJuice:Pop(target: TargetLike, options: Types.PopOptions?): any
	return PopUI.new(resolveGuiObject(target, "RoJuice:Pop(target, options?)"), options)
end

function RoJuice:Slide(target: TargetLike, options: Types.SlideOptions?): any
	return SlideUI.new(resolveGuiObject(target, "RoJuice:Slide(target, options?)"), options)
end

function RoJuice:Rotate(target: TargetLike, options: Types.RotateOptions?): any
	return RotateUI.new(resolveGuiObject(target, "RoJuice:Rotate(target, options?)"), options)
end

function RoJuice:Glow(target: TargetLike, options: Types.GlowOptions?): any
	return GlowUI.new(resolveGuiObject(target, "RoJuice:Glow(target, options?)"), options)
end

function RoJuice:ColorShift(target: TargetLike, options: Types.ColorShiftOptions?): any
	return ColorShiftUI.new(resolveGuiObject(target, "RoJuice:ColorShift(target, options?)"), options)
end

function RoJuice:Trail(target: TargetLike, options: Types.TrailOptions?): any
	return TrailUI.new(resolveGuiObject(target, "RoJuice:Trail(target, options?)"), options)
end

function RoJuice:Hover(target: TargetLike, options: Types.HoverOptions?): any
	return HoverUI.new(resolveGuiObject(target, "RoJuice:Hover(target, options?)"), options)
end

-- INSTANCES SPAWNERS
function RoJuice:FloatingText(text: string, options: Types.FloatingTextOptions?): any
	local opts = table.clone(options or {}) :: any
	if opts.Parent == nil then
		opts.Parent = self.Parent
	end

	return FloatingTextUI.new(text, opts)
end

function RoJuice:FloatingRow(text: string, options: Types.FloatingRowOptions?): any
	local opts = table.clone(options or {}) :: any
	if opts.Parent == nil then
		opts.Parent = self.Parent
	end

	return FloatingRow.new(text, opts)
end

function RoJuice:FlyTo(image: string, options: Types.FlyToOptions?): any
	local opts = table.clone(options or {}) :: any
	if opts.Parent == nil then
		opts.Parent = self.Parent
	end

	return FlyToUI.new(image, opts)
end

function RoJuice:Toast(message: string, options: Types.ToastOptions?): any
	local opts = table.clone(options or {}) :: any
	if opts.Parent == nil then
		opts.Parent = self.Parent
	end

	return ToastUI.new(message, opts)
end

function RoJuice:RadialBurst(image: string, options: Types.RadialBurstOptions?): any
	local opts = table.clone(options or {}) :: any
	if opts.Parent == nil then
		opts.Parent = self.Parent
	end

	return RadialBurstUI.new(image, opts)
end

-- ADVANCED EFFECTS
function RoJuice:Follow(follower: TargetLike, target: any, options: Types.FollowOptions?): any
	return FollowUI.new(
		resolveGuiObject(follower, "RoJuice:Follow(follower, target, options?) follower"),
		target,
		options
	)
end

return RoJuice
