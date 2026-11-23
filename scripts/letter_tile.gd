class_name LetterTile
extends Node2D

## One letter.
## Fixed letters (movable = false) float over the cauldron in a gas bubble.
## Movable letters lie on the table; once dropped into the word they float in a bubble too.

const SIZE := 64.0          ## size of a table tile
const BUBBLE_RADIUS := 38.0
const FONT_SIZE := 40

var letter := ""
var movable := true
var home_position := Vector2.ZERO
var home_rotation := 0.0
var in_word := false:
	set(value):
		in_word = value
		queue_redraw()

var _phase := randf() * TAU
var _box: StyleBoxFlat
var _shadow: StyleBoxFlat


func _init(p_letter: String = "", p_movable: bool = true) -> void:
	letter = p_letter.to_upper()
	movable = p_movable
	_box = _make_box(Color("f3e2b8"), Color("8b5a2b"))
	_shadow = _make_box(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0))


func is_floating() -> bool:
	return not movable or in_word


func _process(_delta: float) -> void:
	if is_floating():
		queue_redraw()


func contains_point(global_point: Vector2) -> bool:
	var local := to_local(global_point)
	var half := SIZE * 0.5
	return absf(local.x) <= half and absf(local.y) <= half


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if not is_floating():
		var half := SIZE * 0.5
		var rect := Rect2(-half, -half, SIZE, SIZE)
		var baseline := (font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) * 0.5
		draw_style_box(_shadow, Rect2(rect.position + Vector2(3, 5), rect.size))
		draw_style_box(_box, rect)
		draw_string(font, Vector2(-half, baseline), letter, HORIZONTAL_ALIGNMENT_CENTER, SIZE, FONT_SIZE, Color("4a2c17"))
		return

	var o := bob_offset(_phase)
	draw_bubble(self, o, BUBBLE_RADIUS, false, false)
	var fs := FONT_SIZE + 4
	var baseline := (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	var pos := o + Vector2(-SIZE * 0.5, baseline)
	# Letters you placed glow warm gold; the cauldron's own letters are pale green.
	var fill := Color("ffe08a") if movable else Color("e9ffd9")
	var outline := Color("4a2c17") if movable else Color("1d3b22")
	draw_string_outline(font, pos, letter, HORIZONTAL_ALIGNMENT_CENTER, SIZE, fs, 8, outline)
	draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_CENTER, SIZE, fs, fill)


## Gentle floating motion, shared by letters and empty gaps.
static func bob_offset(phase: float) -> Vector2:
	var t := Time.get_ticks_msec() / 1000.0
	return Vector2(sin(t * 1.1 + phase) * 4.0, sin(t * 1.7 + phase * 1.3) * 6.0)


## A see-through gas bubble with a little shine.
static func draw_bubble(ci: CanvasItem, c: Vector2, r: float, dashed: bool, glow: bool) -> void:
	ci.draw_circle(c, r, Color(0.85, 1.0, 0.9, 0.32 if glow else 0.14))
	var ring := Color(0.92, 1.0, 0.95, 0.95 if glow else 0.55)
	if dashed:
		var segments := 18
		for i in segments:
			var a := TAU * i / segments
			ci.draw_arc(c, r, a, a + TAU / segments * 0.55, 4, ring, 3.0, true)
	else:
		ci.draw_arc(c, r, 0.0, TAU, 40, ring, 2.0, true)
	ci.draw_arc(c, r * 0.72, -2.7, -1.8, 8, Color(1, 1, 1, 0.6), 3.0, true)


static func _make_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	return sb
