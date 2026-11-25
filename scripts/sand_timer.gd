class_name SandTimer
extends Control

## The enchanted hourglass at the top of the screen. Its sand runs out while you think;
## a level brewed before it is empty gives 1 extra star. With Golden sand also up to 5 more: the more sand
## is left, the more.

const MIDDLE := Vector2(60, 54)
const BULB := 38.0        ## height of one half of the glass
const WIDE := 23.0        ## half the width at the caps
const NECK := 2.2         ## half the width of the neck
const SLICES := 32
const BONUS := 5         ## stars Golden sand adds when the glass is almost full
const GRACE := 2.0       ## seconds that cost nothing of them

var total := 1.0
var left := 1.0
var running := false      ## the sand is falling now (not while stirring or paused)
var golden := false       ## Golden sand is learned
var bare := false         ## only the glass, without the text below it
var won := false          ## the level was brewed in time
var _pop := 0.0
var _turn := 0.0          ## 1 to 0 while it is being turned over for a new word
var _area := 0.0          ## of one half of the glass


func _init() -> void:
	size = Vector2(120, 130)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "Brew this level before the sand runs out\nfor 1 extra star. Once it runs out,\nit stays empty for the rest of these recipes."
	for i in SLICES:
		_area += _width((i + 0.5) / SLICES)


func start(seconds: float) -> void:
	total = seconds
	left = seconds
	won = false
	_turn = 1.0


## It ran out earlier in this book: it stays empty.
func lose() -> void:
	left = 0.0
	_turn = 0.0


## Stars Golden sand would add now.
func bonus() -> int:
	if not golden or left <= 0.0:
		return 0
	return roundi(BONUS * clampf(left / maxf(1.0, total - GRACE), 0.0, 1.0))


func win() -> void:
	won = true
	_pop = 1.0


func _process(delta: float) -> void:
	_pop = maxf(0.0, _pop - delta)
	_turn = maxf(0.0, _turn - delta / 0.45)
	if is_visible_in_tree():
		queue_redraw()


## Half the width of the glass: t = 0 at a cap, 1 at the neck.
func _width(t: float) -> float:
	return NECK + (WIDE - NECK) * pow(maxf(0.0, cos(t * PI * 0.5)), 0.75)


## How far from the cap (0) to the neck (1) the glass is, when `share` of its sand lies on
## the neck side (from_neck) or on the cap side of that point.
func _level(share: float, from_neck: bool) -> float:
	var need := share * _area
	var sum := 0.0
	for i in SLICES:
		var k := SLICES - 1 - i if from_neck else i
		var slice := _width((k + 0.5) / SLICES)
		if sum + slice >= need:
			var part := (need - sum) / slice
			return (k + 1 - part) / SLICES if from_neck else (k + part) / SLICES
		sum += slice
	return 0.0 if from_neck else 1.0


func _draw() -> void:
	var part := clampf(left / total, 0.0, 1.0)
	var over := left <= 0.0 and not won
	var font := ThemeDB.fallback_font
	if won:
		for i in 4:
			draw_circle(MIDDLE, 46.0 + i * 5.0 + 8.0 * _pop, Color(1, 0.85, 0.35, 0.07 + 0.05 * _pop))
	# Turned over for a new word: all the sand starts at the bottom and goes round with the glass.
	draw_set_transform(MIDDLE, PI * _turn * _turn * (3.0 - 2.0 * _turn))
	if _turn > 0.0:
		part = 1.0
	var sand := Color("ffd45c")
	if not won and _turn == 0.0 and part < 0.4:
		sand = Color("f0903c") if part >= 0.2 else Color("e2553f")
	# Glass
	var outline := PackedVector2Array()
	for i in SLICES + 1:
		outline.append(Vector2(_width(i / float(SLICES)), -BULB + BULB * i / SLICES))
	for i in SLICES + 1:
		outline.append(Vector2(_width(1.0 - i / float(SLICES)), BULB * i / SLICES))
	for i in SLICES + 1:
		outline.append(Vector2(-_width(i / float(SLICES)), BULB - BULB * i / SLICES))
	for i in SLICES + 1:
		outline.append(Vector2(-_width(1.0 - i / float(SLICES)), -BULB * i / SLICES))
	_fill(outline, Color(0.75, 0.88, 1.0, 0.1 if over else 0.2))
	# Sand above the neck, sinking in the middle
	if part > 0.004:
		var top := _level(part, true)
		var pts := PackedVector2Array()
		for i in 13:
			var u := -1.0 + i / 6.0
			var dip := 5.0 * (1.0 - u * u) * minf(1.0, (1.0 - top) * 3.0)
			pts.append(Vector2(u * _inside(top), -BULB + BULB * top + dip))
		for i in range(0, 13):
			var t := lerpf(top, 1.0, i / 12.0)
			pts.append(Vector2(_inside(t), -BULB + BULB * t))
		for i in range(0, 13):
			var t := lerpf(1.0, top, i / 12.0)
			pts.append(Vector2(-_inside(t), -BULB + BULB * t))
		_fill(pts, sand)
	# Sand below, heaped up
	var heap_y := BULB
	if part < 0.996:
		var level := _level(1.0 - part, false)
		var pts := PackedVector2Array()
		var heap := 6.0 * minf(1.0, (1.0 - part) * 5.0) * minf(1.0, part * 5.0)
		heap_y = BULB - BULB * level - heap
		for i in 13:
			var u := -1.0 + i / 6.0
			pts.append(Vector2(u * _inside(level), BULB - BULB * level - heap * (1.0 - absf(u))))
		for i in range(0, 13):
			var t := lerpf(level, 0.0, i / 12.0)
			pts.append(Vector2(_inside(t), BULB - BULB * t))
		for i in range(0, 13):
			var t := lerpf(0.0, level, i / 12.0)
			pts.append(Vector2(-_inside(t), BULB - BULB * t))
		_fill(pts, sand.darkened(0.08) if not over else sand.darkened(0.45))
	# The falling grains
	if running and part > 0.0 and _turn == 0.0:
		draw_line(Vector2(0, -3), Vector2(0, heap_y), sand, 2.2)
		var t := Time.get_ticks_msec() / 1000.0
		for i in 5:
			var fall := fmod(t * 1.8 + i * 0.2, 1.0)
			draw_circle(Vector2(sin(t * 9.0 + i * 2.1) * 1.6, lerpf(0.0, heap_y, fall)), 1.6, sand.lightened(0.3))
	outline.append(outline[0])
	draw_polyline(outline, Color(0.9, 0.96, 1.0, 0.35 if over else 0.75), 2.0, true)
	draw_line(Vector2(-13, -BULB + 7), Vector2(-11, -BULB + 19), Color(1, 1, 1, 0.5), 2.5, true)  # a glint
	# Wooden frame
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 28, -BULB), Vector2(side * 28, BULB), Color("6b4226"), 4.0)
		var cap := StyleBoxFlat.new()
		cap.bg_color = Color("8a5a32")
		cap.border_color = Color("c99a5b")
		cap.set_border_width_all(1)
		cap.set_corner_radius_all(4)
		draw_style_box(cap, Rect2(-34, side * (BULB + 4.0) - 5.0, 68, 10))
	draw_set_transform(Vector2.ZERO)
	if bare:
		return
	# Below the glass, so the theme has room beside it.
	var fs := 15 if over else 20 + roundi(12.0 * _pop)
	var text := "+%d!" % (1 + bonus()) if won else ("too late" if over else "+%d" % (1 + bonus()))
	draw_string(font, Vector2(MIDDLE.x - 60, MIDDLE.y + BULB + 32), text, HORIZONTAL_ALIGNMENT_CENTER, 120, fs,
		Color(1, 0.95, 0.85, 0.5) if over else (Color("ffe9a0") if won else MenuKit.CREAM))


func _inside(t: float) -> float:
	return maxf(0.6, _width(t) - 1.5)


## Fills a left-right symmetric shape; thin slivers that can't be filled are skipped.
func _fill(pts: PackedVector2Array, color: Color) -> void:
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, color)
