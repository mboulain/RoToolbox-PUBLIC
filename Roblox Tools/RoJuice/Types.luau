local Types = {}

export type EffectWithGuiInstance = {
	GetInstance: (self: any) -> GuiObject?,
	Start: (self: any) -> any,
	Cancel: (self: any) -> (),
	Destroy: (self: any) -> (),
}

export type PressTiming = {
	Down: number?,
	Hold: number?,
	Up: number?,
	Delay: number?,
}

export type PressOptions = {
	PressedScale: number?,
	Timing: PressTiming?,
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
	OnEnd: ((effect: any) -> ())?,
}


export type PulseTiming = {
	Out: number?,
	In: number?,
	Delay: number?,
}

export type PulseOptions = {
	Scale: number?,

	Pulses: number?,

	Loop: boolean?,

	Timing: PulseTiming?,
	Out: number?,
	In: number?,
	Delay: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	DestroyOnEnd: boolean?,
	OnEnd: ((effect: any) -> ())?,
}


export type FadingTiming = {
	FadeIn: number?,
	Duration: number?,
	FadeOut: number?,
	Delay: number?,
}

export type FadingOptions = {
	Timing: FadingTiming?,
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
	OnEnd: ((effect: any) -> ())?,
}

export type ShakeAxis = "X" | "Y" | "XY"

export type ShakeOptions = {
	Intensity: number?,

	Duration: number?,

	Frequency: number?,

	Axis: ShakeAxis?,

	Chaotic: boolean?,
	Jitter: number?,
	ImpulseChance: number?,
	ImpulseMultiplier: number?,

	RestoreOnEnd: boolean?,

	DestroyOnEnd: boolean?,
	OnEnd: ((effect: any) -> ())?,
}

export type WiggleOptions = {
	MaxAngle: number?,

	Wiggles: number?,

	Speed: number?,

	Duration: number?,

	Randomness: number?,

	RestoreOnEnd: boolean?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	DestroyOnEnd: boolean?,
	OnEnd: ((effect: any) -> ())?,
}

export type FloatingTextDirection = "Up" | "Down" | "Left" | "Right"

export type FloatingTextOptions = {
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
	Direction: FloatingTextDirection?,
	Offset: UDim2?,
	Distance: number?,
	Duration: number?,
	Delay: number?,
	FadeOut: boolean?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	Template: TextLabel?,
	DestroyOnEnd: boolean?,
	OnEnd: ((effect: any) -> ())?,
}

export type FloatingRowImageSide = "Left" | "Right"

export type FloatingRowOptions = {
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
	ImageSide: FloatingRowImageSide?,
	Padding: number?,

	Direction: FloatingTextDirection?,
	Offset: UDim2?,
	Distance: number?,
	Duration: number?,
	Delay: number?,
	FadeOut: boolean?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,

	DestroyOnEnd: boolean?,
	OnEnd: ((effect: any) -> ())?,
}

export type FlyToPoint = UDim2 | GuiObject | EffectWithGuiInstance

export type FlyToOptions = {
	Parent: Instance?,
	From: FlyToPoint?,
	To: FlyToPoint?,

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
	OnEnd: ((effect: any) -> ())?,
}

export type BounceOptions = {
	CompressScale: number?,
	BounceScale: number?,
	Duration: number?,

	CompressRatio: number?,
	BounceRatio: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}

export type PopOptions = {
	StartScale: number?,
	PopScale: number?,
	Duration: number?,

	PopRatio: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}

export type SlideOptions = {
	From: UDim2?,
	To: UDim2?,

	Duration: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}

export type RotateOptions = {
	From: number?,
	To: number?,

	Duration: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}

export type GlowOptions = {
	Color: Color3?,
	Thickness: number?,

	FromTransparency: number?,
	ToTransparency: number?,

	Duration: number?,
	Loops: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}

export type ColorShiftProperty =
	"BackgroundColor3"
	| "TextColor3"
	| "ImageColor3"
	| "TextStrokeColor3"

export type ColorShiftOptions = {
	Property: ColorShiftProperty?,

	From: Color3?,
	To: Color3,

	Duration: number?,

	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}

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
}

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
}

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
}

export type FollowOptions = {
	Delay: number?,
	Duration: number?,

	Offset: UDim2?,

	SnapOnStart: boolean?,
	StopIfTargetRemoved: boolean?,

	EasingSpeed: number?,
}

export type HoverOptions = {
	Amplitude: number?,
	Speed: number?,

	Axis: "X" | "Y" | "Both"?,

	Offset: UDim2?,

	Duration: number?,

	RotationAmplitude: number?,
	RotationSpeed: number?,
}

return Types
