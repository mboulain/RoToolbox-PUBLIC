# RoJuice

> A composable UI juice library for Roblox.

RoJuice is a lightweight, modular and composable UI feedback system designed for Roblox.

The philosophy behind RoJuice was simple:

- Make effects extremely easy to use
- Make effects composable
- Avoid giant configuration-heavy systems
- Keep effects isolated and reusable
- Standardize lifecycle behavior
- Allow creator effects and target effects to work together naturally

---

# Table of Contents

1. Philosophy
2. Installation
3. Basic Usage
4. Effect Lifecycle
5. Composability
6. OnEnd Callbacks
7. Creator Effects vs Target Effects
8. Effect API Reference
9. Best Practices
10. Creating Custom Effects
11. Common Patterns
12. Troubleshooting

---

# Philosophy

RoJuice is built around a very simple idea:

```lua
RoJuice:Effect(...):Start()
```

Every effect follows the same architecture.

Effects are:

- Self-contained
- Easy to compose
- Easy to cancel
- Easy to cleanup
- Easy to extend

Instead of creating giant monolithic effects, RoJuice encourages combining multiple small effects together.

Example:

```lua
local orb = RoJuice:FloatingRow("+10", {
	Parent = playerGui,
	Image = "rbxassetid://123456",
}):Start()

RoJuice:Hover(orb):Start()
RoJuice:Glow(orb):Start()
RoJuice:Trail(orb, {
	Duration = math.huge,
}):Start()
```

---

# Installation

Recommended structure:

```text
ReplicatedStorage
└── Source
    └── Tools
        └── RoJuice
            ├── RoJuice.luau
            ├── EffectBase.luau
            ├── Helpers.luau
            ├── Types.luau
            └── Feedbacks
```

Require RoJuice:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoJuice = require(
	ReplicatedStorage.Source.Tools.RoJuice.RoJuice
)
```

---

# Basic Usage

## Target Effects

Target effects modify an existing GuiObject.

```lua
RoJuice:Press(button):Start()
RoJuice:Shake(button):Start()
RoJuice:Glow(button):Start()
```

## Creator Effects

Creator effects create their own UI.

```lua
RoJuice:FloatingText("+10 XP", {
	Parent = screenGui,
}):Start()
```

---

# Effect Lifecycle

All effects follow the same lifecycle:

```lua
local effect = RoJuice:Pulse(button)

effect:Start()
effect:Cancel()
effect:Destroy()
```

## Start

Starts the effect.

```lua
effect:Start()
```

## Cancel

Stops the effect immediately.

```lua
effect:Cancel()
```

Cancel usually:

- Stops tweens
- Disconnects connections
- Restores original state

## Destroy

Fully destroys the effect.

```lua
effect:Destroy()
```

Destroy also calls Cancel.

---

# OnEnd Callbacks

Effects can be sequenced using `OnEnd`.

```lua
local pop = RoJuice:Pop(button)

pop.OnEnd = function()
	RoJuice:Glow(button):Start()
end

pop:Start()
```

Important:

Temporary effects must call:

```lua
self:Finish()
```

when they complete naturally.

`Finish()`:

- Triggers `OnEnd`
- Cleans up the effect
- Destroys the effect if `DestroyOnEnd == true`

Infinite effects only call `Finish()` if:

- They have a Duration
- They are explicitly completed

---

# Creator Effects vs Target Effects

## Target Effects

These modify an existing UI.

Examples:

- Press
- Pulse
- Fade
- Glow
- Hover
- Shake
- Trail
- Follow

Usage:

```lua
RoJuice:Glow(button):Start()
```

## Creator Effects

These create their own UI.

Examples:

- FloatingText
- FloatingRow
- FlyTo
- Toast
- RadialBurst

Usage:

```lua
RoJuice:Toast("Inventory Full", {
	Parent = playerGui,
}):Start()
```

---

# Composability

One of the core goals of RoJuice.

Effects can stack naturally.

Example:

```lua
local icon = RoJuice:FloatingRow("+10", {
	Parent = screenGui,
	Image = "rbxassetid://123456",
}):Start()

RoJuice:Hover(icon):Start()
RoJuice:Glow(icon):Start()
RoJuice:Trail(icon, {
	Duration = math.huge,
}):Start()
```

Effects accepting `TargetLike` can receive:

- GuiObject
- Another effect with `GetInstance()`

This allows chaining creator effects into modifier effects.

---

# GetInstance()

Creator effects expose:

```lua
effect:GetInstance()
```

This allows them to be reused by other effects.

Example:

```lua
local floating = RoJuice:FloatingText("+10", {
	Parent = screenGui,
}):Start()

RoJuice:Fade(floating):Start()
```

---

# Helpers

Helpers are exposed directly:

```lua
RoJuice.Helpers
```

Example:

```lua
local screenPos = RoJuice.Helpers.WorldToScreenPosition(worldPosition)
```

---

# Effect API Reference

---

# Press

Scales down then restores a GuiObject.

## Usage

```lua
RoJuice:Press(button):Start()
```

## Options

| Property | Type | Description |
|---|---|---|
| Scale | number | Press scale |
| Duration | number | Total duration |
| EasingStyle | Enum.EasingStyle | Tween easing |
| EasingDirection | Enum.EasingDirection | Tween direction |

---

# Pulse

Creates a pulse scale effect.

## Usage

```lua
RoJuice:Pulse(button):Start()
```

## Options

| Property | Type |
|---|---|
| Scale | number |
| Duration | number |
| Loops | number |

---

# Bounce

Performs a strong elastic bounce.

## Usage

```lua
RoJuice:Bounce(button):Start()
```

## Notes

Bounce is more exaggerated than Pop.

---

# Pop

Quick responsive scale feedback.

## Usage

```lua
RoJuice:Pop(button):Start()
```

## Notes

Pop is shorter and snappier than Bounce.

---

# Shake

Shakes a GuiObject.

## Usage

```lua
RoJuice:Shake(button, {
	Intensity = 8,
	Duration = 0.25,
}):Start()
```

## Options

| Property | Type |
|---|---|
| Intensity | number |
| Duration | number |
| Frequency | number |
| Axis | "X" \| "Y" \| "XY" |
| Chaotic | boolean |
| Jitter | number |
| ImpulseChance | number |
| ImpulseMultiplier | number |

---

# Wiggle

Rotational shake effect.

## Usage

```lua
RoJuice:Wiggle(button):Start()
```

## Options

| Property | Type |
|---|---|
| MaxAngles | number |
| Wiggles | number |
| Speed | number |
| Duration | number |
| Randomness | number |
| RestoreAtEnd | boolean |
| EasingStyle | Enum.EasingStyle |
| EasingDirection | Enum.EasingDirection |
| DestroyOnEnd | boolean |

---

# Rotate

Rotates a GuiObject.

## Usage

```lua
RoJuice:Rotate(button, {
	To = 360,
}):Start()
```

## Options

| Property | Type |
|---|---|
| From | number |
| To | number |
| Duration | number |

---

# Slide

Moves a GuiObject from one position to another.

## Usage

```lua
RoJuice:Slide(frame, {
	From = UDim2.fromScale(0, 0.5),
	To = UDim2.fromScale(0.5, 0.5),
}):Start()
```

## Notes

Using explicit From/To makes show/hide animations easier.

---

# Fade

Fades UI transparency.

## Usage

```lua
RoJuice:Fade(frame):Start()
```

## Notes

Supports restoration of original transparency.

---

# Glow

Animates a UIStroke glow.

## Usage

```lua
RoJuice:Glow(button):Start()
```

## Options

| Property | Type |
|---|---|
| Color | Color3 |
| Thickness | number |
| Duration | number |
| Loops | number |

---

# ColorShift

Temporarily changes UI colors.

## Usage

```lua
RoJuice:ColorShift(button, {
	To = Color3.fromRGB(255, 0, 0),
}):Start()
```

## Notes

Automatically restores original color.

---

# Hover

Sinusoidal floating movement.

## Usage

```lua
RoJuice:Hover(icon):Start()
```

## Options

| Property | Type |
|---|---|
| Amplitude | number |
| Speed | number |
| Axis | "X" \| "Y" \| "Both" |
| RotationAmplitude | number |
| RotationSpeed | number |
| Duration | number |

---

# Follow

Makes a GuiObject follow another object.

## Usage

```lua
RoJuice:Follow(follower, target, {
	Delay = 0.15,
}):Start()
```

## Supported Targets

- GuiObject
- Effects with GetInstance()
- Mouse

## Mouse Example

```lua
RoJuice:Follow(button, Players.LocalPlayer:GetMouse(), {
	Delay = 0.1,
}):Start()
```

## Options

| Property | Type |
|---|---|
| Delay | number |
| Offset | UDim2 |
| Duration | number |
| SnapOnStart | boolean |

---

# Trail

Creates visual afterimages.

## Usage

```lua
RoJuice:Trail(button, {
	Duration = math.huge,
}):Start()
```

## Options

| Property | Type |
|---|---|
| Duration | number |
| Interval | number |
| FadeOut | number |
| MaxClones | number |
| ScaleMultiplier | number |

## Notes

Avoid:

```lua
MaxClones = math.huge
```

unless you understand the performance implications.

---

# FloatingText

Creates floating text.

## Usage

```lua
RoJuice:FloatingText("+10 XP", {
	Parent = screenGui,
}):Start()
```

## Notes

Returns its created GuiObject through GetInstance().

---

# FloatingRow

Creates icon + text rows.

## Usage

```lua
RoJuice:FloatingRow("+10", {
	Parent = screenGui,
	Image = "rbxassetid://123456",
}):Start()
```

---

# FlyTo

Spawns icons flying from point A to point B.

## Usage

```lua
RoJuice:FlyTo("rbxassetid://123456", {
	Parent = screenGui,
	From = UDim2.fromScale(0.2, 0.8),
	To = UDim2.fromScale(0.8, 0.2),
}):Start()
```

## Common Use Cases

- Coins
- Loot
- XP pickups
- Currency collection

---

# Toast

Temporary notification card.

## Usage

```lua
RoJuice:Toast("Inventory Full", {
	Parent = screenGui,
	Icon = "rbxassetid://123456",
}):Start()
```

---

# RadialBurst

Spawns multiple particles/icons outward.

## Usage

```lua
RoJuice:RadialBurst("rbxassetid://123456", {
	Parent = screenGui,
	Position = UDim2.fromScale(0.5, 0.5),
	Count = 12,
}):Start()
```

## Common Use Cases

- Reward bursts
- Critical hits
- Explosions
- Unlock effects

---

# Best Practices

## Prefer Composition

Instead of creating giant effects:

```lua
RoJuice:Hover(icon):Start()
RoJuice:Glow(icon):Start()
RoJuice:Trail(icon):Start()
```

## Always Provide Parent For Creator Effects

```lua
RoJuice:Toast("Hello", {
	Parent = screenGui,
})
```

## Use Finish() In Temporary Effects

Temporary effects should end with:

```lua
self:Finish()
```

not:

```lua
self:Destroy()
```

---

# Creating Custom Effects

Recommended architecture:

```lua
local MyEffect = {}
MyEffect.__index = MyEffect
```

Implement:

```lua
Start()
Cancel()
Destroy()
GetInstance()
```

Temporary effects should call:

```lua
self:Finish()
```

Infinite effects should only call Finish when appropriate.

---

# Common Patterns

## Reward Pickup

```lua
local reward = RoJuice:FloatingRow("+50", {
	Parent = screenGui,
	Image = coinImage,
}):Start()

RoJuice:Hover(reward):Start()
RoJuice:Glow(reward):Start()
```

---

## Mouse Followers

```lua
local follow = RoJuice:Follow(button, Players.LocalPlayer:GetMouse(), {
	Delay = 0.1,
}):Start()

RoJuice:Trail(follow, {
	Duration = math.huge,
}):Start()
```

---

## Sequencing

```lua
local pop = RoJuice:Pop(button)

pop.OnEnd = function()
	RoJuice:Glow(button):Start()
end

pop:Start()
```

---

# Troubleshooting

## Nothing Appears

Most creator effects require:

```lua
Parent = someGui
```

## Follow Doesn't Work With Mouse

Use:

```lua
Players.LocalPlayer:GetMouse()
```

and ensure Follow supports mouse targets.

## Effects Not Triggering OnEnd

Ensure the effect calls:

```lua
self:Finish()
```

at natural completion.

---

# Complete Option Reference

This section documents all effect options in detail.

---

# BounceOptions

```lua
BounceOptions = {
	CompressScale: number?,
	BounceScale: number?,
	Duration: number?,

	CompressRatio: number?,
	BounceRatio: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}
```

| Property | Description |
|---|---|
| CompressScale | Scale applied during the initial compression phase |
| BounceScale | Maximum scale reached during the bounce |
| Duration | Total duration of the effect |
| CompressRatio | Percentage of time spent compressing |
| BounceRatio | Percentage of time spent bouncing |
| EasingStyle | Tween easing style |
| EasingDirection | Tween easing direction |

---

# PopOptions

```lua
PopOptions = {
	StartScale: number?,
	PopScale: number?,
	Duration: number?,

	PopRatio: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}
```

| Property | Description |
|---|---|
| StartScale | Initial scale before the pop starts |
| PopScale | Maximum scale reached during the pop |
| Duration | Total effect duration |
| PopRatio | Percentage of duration used for the pop phase |
| EasingStyle | Tween easing style |
| EasingDirection | Tween easing direction |

---

# PressOptions

```lua
PressOptions = {
	Scale: number?,
	Duration: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}
```

| Property | Description |
|---|---|
| Scale | Target scale while pressed |
| Duration | Total duration |
| EasingStyle | Tween easing style |
| EasingDirection | Tween easing direction |

---

# PulseOptions

```lua
PulseOptions = {
	Scale: number?,
	Duration: number?,
	Loops: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}
```

| Property | Description |
|---|---|
| Scale | Maximum pulse scale |
| Duration | Duration of one pulse |
| Loops | Number of repetitions |
| EasingStyle | Tween easing style |
| EasingDirection | Tween easing direction |

---

# FadeOptions

```lua
FadingOptions = {
	From: number?,
	To: number?,
	Duration: number?,
	AffectText: boolean?,
	AffectImages: boolean?,
	AffectBackground: boolean?,
	RestoreOnEnd: boolean?,
}
```

| Property | Description |
|---|---|
| From | Starting transparency |
| To | Target transparency |
| Duration | Total fade duration |
| AffectText | Whether text transparency is affected |
| AffectImages | Whether image transparency is affected |
| AffectBackground | Whether background transparency is affected |
| RestoreOnEnd | Restores original transparency after completion |

---

# GlowOptions

```lua
GlowOptions = {
	Color: Color3?,
	Thickness: number?,
	FromTransparency: number?,
	ToTransparency: number?,
	Duration: number?,
	Loops: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}
```

| Property | Description |
|---|---|
| Color | Glow stroke color |
| Thickness | Stroke thickness |
| FromTransparency | Initial transparency |
| ToTransparency | Final transparency |
| Duration | Duration of one glow cycle |
| Loops | Number of glow loops |
| EasingStyle | Tween easing style |
| EasingDirection | Tween easing direction |

---

# HoverOptions

```lua
HoverOptions = {
	Amplitude: number?,
	Speed: number?,
	Axis: "X" | "Y" | "Both"?,
	Offset: UDim2?,
	Duration: number?,
	RotationAmplitude: number?,
	RotationSpeed: number?,
}
```

| Property | Description |
|---|---|
| Amplitude | Hover movement distance |
| Speed | Hover oscillation speed |
| Axis | Movement axis |
| Offset | Base positional offset |
| Duration | Optional lifetime |
| RotationAmplitude | Rotational hover intensity |
| RotationSpeed | Rotational oscillation speed |

---

# FollowOptions

```lua
FollowOptions = {
	Delay: number?,
	Duration: number?,
	Offset: UDim2?,
	SnapOnStart: boolean?,
	StopIfTargetRemoved: boolean?,
	EasingSpeed: number?,
}
```

| Property | Description |
|---|---|
| Delay | Delay before following target movement |
| Duration | Optional lifetime |
| Offset | Positional offset from target |
| SnapOnStart | Immediately snaps to target at start |
| StopIfTargetRemoved | Automatically destroys effect if target disappears |
| EasingSpeed | Follow interpolation speed |

---

# TrailOptions

```lua
TrailOptions = {
	Parent: Instance?,
	Duration: number?,
	Interval: number?,
	FadeOut: number?,
	MaxClones: number?,
	StartTransparency: number?,
	EndTransparency: number?,
	ScaleMultiplier: number?,
	ZIndexOffset: number?,
}
```

| Property | Description |
|---|---|
| Parent | Optional parent override for clones |
| Duration | Lifetime of the trail emitter |
| Interval | Delay between clone spawns |
| FadeOut | Clone fade duration |
| MaxClones | Maximum simultaneous clones |
| StartTransparency | Initial clone transparency |
| EndTransparency | Final clone transparency |
| ScaleMultiplier | Clone scale multiplier |
| ZIndexOffset | ZIndex offset applied to clones |

---

# SlideOptions

```lua
SlideOptions = {
	From: UDim2?,
	To: UDim2?,
	Duration: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}
```

| Property | Description |
|---|---|
| From | Starting position |
| To | Target position |
| Duration | Slide duration |
| EasingStyle | Tween easing style |
| EasingDirection | Tween easing direction |

---

# RotateOptions

```lua
RotateOptions = {
	From: number?,
	To: number?,
	Duration: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}
```

| Property | Description |
|---|---|
| From | Initial rotation |
| To | Target rotation |
| Duration | Rotation duration |
| EasingStyle | Tween easing style |
| EasingDirection | Tween easing direction |

---

# FloatingTextOptions

```lua
FloatingTextOptions = {
	Parent: Instance?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextColor3: Color3?,
	TextSize: number?,
	Font: Enum.Font?,
	Duration: number?,
}
```

| Property | Description |
|---|---|
| Parent | Parent GUI |
| Position | Initial position |
| AnchorPoint | Anchor point |
| TextColor3 | Text color |
| TextSize | Text size |
| Font | Text font |
| Duration | Lifetime duration |

---

# FloatingRowOptions

```lua
FloatingRowOptions = {
	Parent: Instance?,
	Image: string?,
	ImageSize: UDim2?,
	ImageColor3: Color3?,
	TextColor3: Color3?,
	TextSize: number?,
	Duration: number?,
}
```

| Property | Description |
|---|---|
| Parent | Parent GUI |
| Image | Optional icon asset |
| ImageSize | Icon size |
| ImageColor3 | Icon color |
| TextColor3 | Text color |
| TextSize | Text size |
| Duration | Lifetime duration |

---

# FlyToOptions

```lua
FlyToOptions = {
	Parent: Instance?,
	From: UDim2?,
	To: UDim2?,
	Count: number?,
	Duration: number?,
	Spread: number?,
	RandomRotation: boolean?,
}
```

| Property | Description |
|---|---|
| Parent | Parent GUI |
| From | Spawn position |
| To | Destination position |
| Count | Number of flying icons |
| Duration | Travel duration |
| Spread | Random positional spread |
| RandomRotation | Enables random icon rotation |

---

# ToastOptions

```lua
ToastOptions = {
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
}
```

| Property | Description |
|---|---|
| Parent | Parent GUI |
| Text | Notification text |
| Icon | Optional icon |
| Position | Final toast position |
| AnchorPoint | Root anchor point |
| Size | Root size |
| AutomaticSize | Automatic sizing mode |
| ZIndex | Root ZIndex |
| BackgroundColor3 | Background color |
| BackgroundTransparency | Background transparency |
| CornerRadius | Corner radius |
| Padding | Internal padding |
| TextColor3 | Text color |
| TextTransparency | Text transparency |
| TextSize | Text size |
| Font | Text font |
| RichText | Enables rich text |
| IconSize | Icon size |
| IconColor3 | Icon color |
| IconTransparency | Icon transparency |
| Duration | Hold duration |
| FadeIn | Fade in duration |
| FadeOut | Fade out duration |
| SlideFrom | Starting slide offset |

---

# RadialBurstOptions

```lua
RadialBurstOptions = {
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
}
```

| Property | Description |
|---|---|
| Parent | Parent GUI |
| Position | Burst center position |
| AnchorPoint | Root anchor point |
| ZIndex | Root ZIndex |
| Count | Number of particles |
| Size | Particle size |
| Radius | Final burst radius |
| StartRadius | Initial spawn radius |
| Duration | Burst duration |
| FadeOut | Enables particle fade out |
| RandomRotation | Enables random initial rotations |
| Spin | Rotation added during movement |
| ImageColor3 | Particle color |
| ImageTransparency | Initial transparency |
| EasingStyle | Tween easing style |
| EasingDirection | Tween easing direction |

---

# Final Notes

RoJuice was designed to make UI feedback:

- Fast to implement
- Easy to compose
- Easy to maintain
- Pleasant to read

The goal is not to create giant all-in-one systems.

The goal is to provide small, reusable, composable building blocks.

