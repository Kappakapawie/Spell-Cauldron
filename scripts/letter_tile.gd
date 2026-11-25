class_name LetterTile
extends Node2D

## One letter.
## Fixed letters (movable = false) float over the cauldron in a gas bubble.
## Movable letters lie on the table; once dropped into the word they float in a bubble too.

const SIZE := 64.0          ## size of a table tile
const BUBBLE_RADIUS := 38.0
const FONT_SIZE := 40
const VOWEL := Color("d8232f")      ## vowels are red, consonants black: tiles, bubbles and the raven's pointers
const CONSONANT := Color("17151a")

var letter := ""
var movable := true
var show_kind := true       ## colored as a vowel or a consonant (not on the title screen)
var home_position := Vector2.ZERO
var home_rotation := 0.0
var in_word := false:
	set(value):
		in_word = value
		queue_redraw()

## The owl pointed this letter out: it is surely in the word.
var revealed := false:
	set(value):
		revealed = value
		queue_redraw()

## The chameleon's verdict after you let go of the letter: 1 = right place, -1 = wrong, 0 = none.
var verdict := 0
var verdict_left := 0.0     ## seconds the verdict still shows
const VERDICT_TIME := 2.5

var _phase := randf() * TAU
var _box: StyleBoxFlat
var _shadow: StyleBoxFlat
var _gold: StyleBoxFlat


func _init(p_letter: String = "", p_movable: bool = true) -> void:
	letter = p_letter.to_upper()
	movable = p_movable
	var kind := kind_color()
	_box = _make_box(Color("b5242e") if kind == VOWEL else Color("2b282e"), Color("ef8f86") if kind == VOWEL else Color("8d8792"))
	_shadow = _make_box(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0))
	_gold = _make_box(_box.bg_color, Color("ffd45c"))
	_gold.set_border_width_all(5)


static func is_vowel(p_letter: String) -> bool:
	return p_letter.to_upper() in ["A", "E", "I", "O", "U"]


func kind_color() -> Color:
	return VOWEL if is_vowel(letter) else CONSONANT


func judge(right: bool) -> void:
	verdict = 1 if right else -1
	verdict_left = VERDICT_TIME
	queue_redraw()


func clear_verdict() -> void:
	verdict = 0
	verdict_left = 0.0


func is_floating() -> bool:
	return not movable or in_word


func _process(delta: float) -> void:
	if verdict != 0:
		verdict_left -= delta
		if verdict_left <= 0.0:
			clear_verdict()
	if is_floating() or revealed:
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
		if revealed:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 350.0)
			for i in 4:
				draw_circle(Vector2.ZERO, half + 6.0 + i * 6.0, Color(1.0, 0.85, 0.3, 0.1 + 0.08 * pulse))
		draw_style_box(_gold if revealed else _box, rect)
		draw_string(font, Vector2(-half, baseline), letter, HORIZONTAL_ALIGNMENT_CENTER, SIZE, FONT_SIZE, Color("fff3d6"))
		return

	var o := bob_offset(_phase)
	if show_kind:
		draw_circle(o, BUBBLE_RADIUS, Color(kind_color(), 0.72))
	draw_bubble(self, o, BUBBLE_RADIUS, false, false)
	if revealed:
		draw_arc(o, BUBBLE_RADIUS, 0.0, TAU, 40, Color("ffd45c"), 4.0, true)
	var fs := FONT_SIZE + 4
	var baseline := (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	var pos := o + Vector2(-SIZE * 0.5, baseline)
	# Letters you placed glow warm gold; the cauldron's own letters are pale green.
	var fill := Color("ffe08a") if movable else Color("e9ffd9")
	var outline := Color("4a2c17") if movable else Color("1d3b22")
	if show_kind:
		outline = kind_color().darkened(0.55)
	draw_string_outline(font, pos, letter, HORIZONTAL_ALIGNMENT_CENTER, SIZE, fs, 8, outline)
	draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_CENTER, SIZE, fs, fill)
	if verdict != 0:
		_draw_verdict(o)


## Green ring and a tick, or red ring and a cross (so it does not depend on color alone).
func _draw_verdict(o: Vector2) -> void:
	var a := minf(1.0, verdict_left / 0.5)
	var col := Color("4bd15f") if verdict > 0 else Color("ff4b3e")
	draw_arc(o, BUBBLE_RADIUS + 4.0, 0.0, TAU, 48, Color(col, a), 6.0, true)
	var b := o + Vector2(28, -28)
	draw_circle(b, 14.0, Color(0.1, 0.08, 0.06, 0.9 * a))
	draw_circle(b, 12.0, Color(col, a))
	var ink := Color(1, 1, 1, a)
	if verdict > 0:
		draw_polyline(PackedVector2Array([b + Vector2(-6, 0), b + Vector2(-1, 5), b + Vector2(7, -5)]), ink, 3.5, true)
	else:
		draw_line(b + Vector2(-5, -5), b + Vector2(5, 5), ink, 3.5, true)
		draw_line(b + Vector2(5, -5), b + Vector2(-5, 5), ink, 3.5, true)


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
