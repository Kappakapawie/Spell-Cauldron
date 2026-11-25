class_name SandOut
extends Control

## The sand has run out. The first times nobody can miss it: the hourglass comes to the middle, loses its
## last grains, shakes, and says what is lost. Later only the small hourglass shows it.
## Nothing is blocked meanwhile: the word can still be brewed.

const SHOWS := 3          ## how often it is shown big
const CENTER := Vector2(640, 250)
const COME := 0.45
const EMPTY := 1.1        ## when the last grain falls
const GO := 3.6
const BACK := 0.45
const BIG := 3.1

var age := -1.0           ## below 0: not shown
var _small: SandTimer     ## the one at the top of the screen
var _glass: SandTimer


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_glass = SandTimer.new()
	_glass.bare = true
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.pivot_offset = SandTimer.MIDDLE
	add_child(_glass)


func start(small: SandTimer) -> void:
	_small = small
	_small.modulate.a = 0.0
	_glass.start(1.0)
	_glass.lose()
	age = 0.0
	visible = true
	_place()


func stop() -> void:
	if age < 0.0:
		return
	age = -1.0
	visible = false
	_small.modulate.a = 1.0


func _process(delta: float) -> void:
	if age < 0.0:
		return
	age += delta
	if age >= GO + BACK:
		stop()
	else:
		_place()


## 1 while it is in the middle, 0 at the top of the screen.
func _there() -> float:
	return smoothstep(0.0, COME, age) * (1.0 - smoothstep(GO, GO + BACK, age))


func _place() -> void:
	var there := _there()
	var home := _small.position + SandTimer.MIDDLE
	var shake := Vector2.ZERO
	if age > EMPTY:
		shake = Vector2(sin(age * 70.0), cos(age * 57.0)) * 16.0 * exp(-(age - EMPTY) * 4.0)
	_glass.scale = Vector2.ONE * lerpf(1.0, BIG, there)
	_glass.position = home.lerp(CENTER, there) + shake - SandTimer.MIDDLE
	_glass.left = 0.16 * maxf(0.0, 1.0 - age / EMPTY)
	_glass.running = _glass.left > 0.0
	queue_redraw()


func _draw() -> void:
	var all := ScreenLayout.rect()
	var there := _there()
	draw_rect(all, Color(0.08, 0.02, 0.01, 0.66 * there))
	# Red edges that beat, and a flash with the last grain.
	var beat := 0.5 + 0.5 * sin(age * 9.0)
	for i in 6:
		draw_rect(all.grow(-5.0 - i * 10.0), Color(0.9, 0.2, 0.12, (0.5 - i * 0.08) * there * (0.45 + 0.55 * beat)), false, 10.0)
	for i in 4:
		draw_circle(CENTER, 120.0 + i * 30.0, Color(0.9, 0.25, 0.15, 0.09 * there * (0.6 + 0.4 * beat)))
	if age > EMPTY:
		var band := clampf((age - EMPTY) / 0.2, 0.0, 1.0) * there  # so the cauldron's letters do not show through the text
		draw_rect(Rect2(all.position.x, 396, all.size.x, 196), Color(0.1, 0.03, 0.02, 0.88 * band))
		draw_rect(all, Color(1.0, 0.3, 0.2, 0.4 * exp(-(age - EMPTY) * 5.0)))
		var t := clampf((age - EMPTY) / 0.2, 0.0, 1.0)
		_text("OUT OF SAND!", 450, 76, t * there, Color("ff8a6a"), lerpf(2.4, 1.0, t * t))
		_text("No more hourglass stars in these recipes", 520, 32, clampf((age - EMPTY - 0.3) / 0.3, 0.0, 1.0) * there, Color("fff3d6"), 1.0)
		_text("You can still brew the rest, and try again next time", 562, 24, clampf((age - EMPTY - 0.6) / 0.3, 0.0, 1.0) * there, Color("e8c27a"), 1.0)


func _text(text: String, y: float, fs: int, alpha: float, color: Color, grow: float) -> void:
	if alpha <= 0.0:
		return
	var font := ThemeDB.fallback_font
	draw_set_transform(Vector2(640, y), 0.0, Vector2.ONE * grow)
	var at := Vector2(-640, fs * 0.35)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 1280, fs, maxi(6, fs / 5), Color(0.15, 0.04, 0.02, alpha))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 1280, fs, Color(color, alpha))
	draw_set_transform(Vector2.ZERO)
