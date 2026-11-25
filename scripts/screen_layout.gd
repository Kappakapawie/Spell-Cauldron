class_name ScreenLayout
extends RefCounted

## The PC screen is 1280 x 720. A phone held sideways is wider: the game keeps its 1280 x 720 in the middle,
## what stands at the sides moves outward into the extra room, and what you touch is bigger.
## Everything is still placed in those 1280 x 720 coordinates; (0, 0) to rect() is what the screen shows.

const BASE := Vector2(1280, 720)
const NOTCH := 34.0  ## kept free at both ends of a phone, for the camera and the round corners

static var phone := false
static var forced := false  ## tests try the phone version
static var extra := Vector2.ZERO  ## room left and right / above and below the 1280 x 720


## A real phone or tablet (an app, or in its browser), or the PC started with "-- --phone" to try it.
static func detect() -> bool:
	if forced:
		return true
	for feature in ["mobile", "web_android", "web_ios"]:
		if OS.has_feature(feature):
			return true
	return "--phone" in OS.get_cmdline_user_args()


static func measure(view: Vector2) -> void:
	extra = ((view - BASE) * 0.5).max(Vector2.ZERO) if phone else Vector2.ZERO


## Everything the screen shows.
static func rect() -> Rect2:
	return Rect2(-extra, BASE + extra * 2.0)


## How far the things at the sides move outward.
static func edge() -> float:
	return maxf(0.0, extra.x - NOTCH) if phone else 0.0


## A phone with room at the sides (nearly all of them).
static func roomy() -> bool:
	return phone and edge() >= 60.0


## How much bigger the letters on the table are.
static func touch() -> float:
	return 1.35 if roomy() else 1.0


## How much bigger the pets and the potions are.
static func icons() -> float:
	return 1.5 if roomy() else 1.0


## How much bigger the word in the cauldron can be.
static func word() -> float:
	return 1.25 if roomy() else 1.0


## The first number on the PC, the second on a phone.
static func pick(pc: float, on_phone: float) -> float:
	return on_phone if phone else pc


## There is no mouse on a phone.
static func say(text: String) -> String:
	if not phone:
		return text
	for pair in [["Hold the mouse", "Hold your finger"], ["hold the mouse", "hold your finger"], ["Hover a spell", "Tap a spell"],
			["Click", "Tap"], ["click", "tap"]]:
		text = text.replace(pair[0], pair[1])
	return text
