class_name BookFinale
extends Control

## The big moment when a recipe book is brewed to the end, shown over the end screen: first that it is
## complete, then the hourglass pours its stars into the star. A click skips it.

signal finished

const TITLE := "RECIPES COMPLETE!"
const STAR_AT := Vector2(640, 350)
const ALONE := 2.3         ## seconds it takes without stars from the hourglass
const GLASS_IN := 1.4      ## when the hourglass comes in
const POUR := 2.0          ## when its stars start to fly
const POUR_TIME := 1.3     ## until the last one takes off
const FLY := 0.45
const SLAM := POUR + POUR_TIME + FLY  ## when "HOURGLASS BONUS" lands
const LAST := SLAM + 1.9
const FADE := 0.3
const CONFETTI := [Color("ffd45c"), Color("e2553f"), Color("6fa8ff"), Color("e86fd0"), Color("6fd08a"), Color("fff3d6")]

var plain := 0.0     ## points for guessing in this run
var time := 0.0      ## stars from the hourglass in this run
var fast := 0        ## levels brewed in time
var words := 10
var book := 1
var age := 0.0
var _glass: SandTimer
var _star: LevelStar


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_star = LevelStar.new()
	_star.radius = 105.0
	_star.size = Vector2(230, 230)
	_star.position = STAR_AT - _star.size * 0.5
	_star.pivot_offset = _star.size * 0.5
	add_child(_star)
	_glass = SandTimer.new()
	_glass.bare = true
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.pivot_offset = SandTimer.MIDDLE
	_glass.scale = Vector2.ONE * 2.6
	add_child(_glass)


func start(result: Dictionary) -> void:
	book = result.level
	plain = result.plain
	time = result.time
	words = maxi(1, result.words.size())
	fast = result.words.filter(func(w: Dictionary) -> bool: return w.get("fast", false)).size()
	age = 0.0
	_glass.start(1.0)
	_glass.won = true
	modulate.a = 1.0
	visible = true
	_place()


func length() -> float:
	return LAST if time > 0.0 else ALONE


## Stars from the hourglass that have reached the big star.
func arrived() -> float:
	if time <= 0.0:
		return 0.0
	return time if age >= SLAM else floorf(time * clampf((age - POUR - FLY) / POUR_TIME, 0.0, 1.0))


func skip() -> void:
	if visible:
		visible = false
		finished.emit()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	age += delta
	modulate.a = clampf((length() - age) / FADE, 0.0, 1.0)
	_place()
	if age >= length():
		skip()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if age > 0.4:
			skip()


## Also beside the 1280 x 720 on a wider screen.
func _has_point(point: Vector2) -> bool:
	return ScreenLayout.rect().has_point(point)


func _place() -> void:
	var beat := 0.0  # it jumps with every star that arrives
	if time > 0.0 and age > POUR + FLY and age < SLAM:
		beat = 0.07 * absf(sin((age - POUR) * 16.0))
	if time > 0.0 and age >= SLAM:
		beat = 0.35 * exp(-(age - SLAM) * 5.0)
	_star.scale = Vector2.ONE * maxf(0.01, _back(clampf((age - 0.35) / 0.5, 0.0, 1.0)) + beat)
	_star.position.x = STAR_AT.x + 130.0 * _smooth((age - GLASS_IN) / 0.5) * float(time > 0.0) - _star.size.x * 0.5
	var counted := plain if age >= 1.2 else floorf(plain * _smooth((age - 0.5) / 0.7))
	_star.set_record(true, counted + arrived(), plain >= words or (time > 0.0 and age >= SLAM))
	_glass.visible = time > 0.0 and age > GLASS_IN
	var wobble := sin(age * 22.0) * 4.0 * float(age > POUR and age < SLAM)
	var x := lerpf(-320.0 - ScreenLayout.extra.x, 440.0, _back(clampf((age - GLASS_IN) / 0.5, 0.0, 1.0)))
	_glass.position = Vector2(x + wobble, STAR_AT.y + 4.0) - SandTimer.MIDDLE
	_glass.left = 1.0 - clampf((age - POUR) / POUR_TIME, 0.0, 1.0)
	_glass.running = age > POUR and _glass.left > 0.0
	queue_redraw()


func _smooth(t: float) -> float:
	return smoothstep(0.0, 1.0, t)


## 0 to 1, a little too far and back.
func _back(t: float) -> float:
	var u := t - 1.0
	return 1.0 + 2.7 * u * u * u + 1.7 * u * u


func _draw() -> void:
	var all := ScreenLayout.rect()
	draw_rect(all, Color(0.09, 0.05, 0.03, 0.97 * clampf(age / 0.25, 0.0, 1.0)))
	var c := _star.position + _star.size * 0.5
	var bright := clampf((age - 0.2) / 0.5, 0.0, 1.0)
	for i in 16:  # the rays of the star
		var a := age * 0.35 + TAU * i / 16.0
		var side := Vector2.from_angle(a + PI / 2) * 125.0
		var tip := Vector2.from_angle(a) * 1600.0
		draw_colored_polygon(PackedVector2Array([c, c + tip + side, c + tip - side]), Color(1, 0.82, 0.35, 0.1 * bright))
	for i in 5:
		draw_circle(c, 120.0 + i * 22.0, Color(1, 0.82, 0.35, 0.07 * bright))
	if time > 0.0 and age >= SLAM:  # rings when it is all in
		for k in 3:
			var r := (age - SLAM - k * 0.12) * 900.0
			if r > 0.0:
				draw_arc(c, r, 0.0, TAU, 96, Color(1, 0.88, 0.5, clampf(1.0 - r / 800.0, 0.0, 1.0)), 10.0, true)
	_draw_confetti(all)
	# The title, letter by letter.
	var font := ThemeDB.fallback_font
	var fs := 68
	var x := 640.0 - font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
	for i in TITLE.length():
		var ch := TITLE[i]
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var t := clampf((age - 0.1 - i * 0.035) / 0.35, 0.0, 1.0)
		if t > 0.0:
			var bob := sin(age * 4.0 + i * 0.5) * 4.0
			draw_set_transform(Vector2(x + w * 0.5, 110.0 + bob), 0.0, Vector2.ONE * maxf(0.01, _back(t)))
			draw_string_outline(font, Vector2(-w * 0.5, 22), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 18, Color("3a1d0a"))
			draw_string(font, Vector2(-w * 0.5, 22), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffd45c"))
		x += w
	draw_set_transform(Vector2.ZERO)
	_text("Brew recipes %d" % book, 186, 28, clampf((age - 0.6) / 0.3, 0.0, 1.0), Color("fff3d6"), 1.0)
	if time > 0.0:
		_draw_pouring(c)
	_text(ScreenLayout.say("Click to go on"), 688, 18, clampf((age - 1.0) / 0.4, 0.0, 0.5), Color("fff3d6"), 1.0)


func _draw_pouring(c: Vector2) -> void:
	# Its stars fly over in an arc.
	var from := _glass.position + SandTimer.MIDDLE
	var n := clampi(roundi(time), 1, 30)
	for i in n:
		var t := (age - POUR - POUR_TIME * i / float(n)) / FLY
		if t > 0.0 and t < 1.0:
			var over := (from + c) * 0.5 + Vector2(0, -190.0 - 25.0 * (i % 3))
			var at := from.lerp(over, t).lerp(over.lerp(c, t), t)
			for k in 3:
				draw_circle(at, 30.0 - k * 7.0, Color(1, 0.85, 0.4, 0.12))
			LevelStar.draw_star(self, at, 24.0, 1.0)
	# What the hourglass gives, big.
	if age >= SLAM:
		var t := clampf((age - SLAM) / 0.22, 0.0, 1.0)
		_text("HOURGLASS BONUS  +%s" % MenuKit.points_text(time), 560, 60, t, Color("ffe9a0"), lerpf(2.6, 1.0, t * t))
		var told := "Every level brewed in time!" if fast >= words else "%d of %d levels brewed in time" % [fast, words]
		_text(told, 622, 30, clampf((age - SLAM - 0.25) / 0.3, 0.0, 1.0), Color("fff3d6"), 1.0)
	elif age > POUR:
		_text("+%s" % MenuKit.points_text(arrived()), 560, 60, 1.0, Color("ffd45c"), 1.0)


func _draw_confetti(all: Rect2) -> void:
	for i in 80:
		var y := (age - 0.3 - (i % 20) * 0.06) * (130.0 + (i * 37) % 140)
		if y <= 0.0 or y > all.size.y + 40.0:
			continue
		var x := all.position.x + fmod(i * 97.3, all.size.x) + sin(age * 2.5 + i) * 24.0
		draw_set_transform(Vector2(x, all.position.y - 20.0 + y), age * (2.0 + i % 4) + i, Vector2(1.0, 0.35 + 0.65 * absf(sin(age * 4.0 + i))))
		draw_rect(Rect2(-6, -4, 12, 8), CONFETTI[i % CONFETTI.size()])
	draw_set_transform(Vector2.ZERO)


## A centered line of text, as big as `grow` times.
func _text(text: String, y: float, fs: int, alpha: float, color: Color, grow: float) -> void:
	if alpha <= 0.0:
		return
	var font := ThemeDB.fallback_font
	draw_set_transform(Vector2(640, y), 0.0, Vector2.ONE * grow)
	var at := Vector2(-640, fs * 0.35)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 1280, fs, maxi(6, fs / 5), Color(0.2, 0.1, 0.03, alpha))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 1280, fs, Color(color, alpha))
	draw_set_transform(Vector2.ZERO)
