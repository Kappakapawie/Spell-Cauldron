class_name LetterTile
extends Node2D

## One letter.
## Fixed letters (movable = false) float in the cauldron and can't be moved.
## Movable letters lie on the table and can be dragged into the word.

const SIZE := 64.0
const FONT_SIZE := 40

var letter := ""
var movable := true
var home_position := Vector2.ZERO
var home_rotation := 0.0
var in_word := false:
	set(value):
		in_word = value
		queue_redraw()

var _box: StyleBoxFlat
var _box_placed: StyleBoxFlat
var _shadow: StyleBoxFlat


func _init(p_letter: String = "", p_movable: bool = true) -> void:
	letter = p_letter.to_upper()
	movable = p_movable
	_box = _make_box(Color("f3e2b8"), Color("8b5a2b"))
	_box_placed = _make_box(Color("fff4d6"), Color("ffd45c"))
	_shadow = _make_box(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0))


func contains_point(global_point: Vector2) -> bool:
	var local := to_local(global_point)
	var half := SIZE * 0.5
	return absf(local.x) <= half and absf(local.y) <= half


func _draw() -> void:
	var half := SIZE * 0.5
	var rect := Rect2(-half, -half, SIZE, SIZE)
	var font := ThemeDB.fallback_font
	if movable:
		var baseline := (font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) * 0.5
		draw_style_box(_shadow, Rect2(rect.position + Vector2(3, 5), rect.size))
		draw_style_box(_box_placed if in_word else _box, rect)
		draw_string(font, Vector2(-half, baseline), letter, HORIZONTAL_ALIGNMENT_CENTER, SIZE, FONT_SIZE, Color("4a2c17"))
	else:
		var fs := FONT_SIZE + 6
		var baseline := (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_circle(Vector2.ZERO, half * 0.85, Color(0.75, 1.0, 0.7, 0.16))
		draw_string_outline(font, Vector2(-half, baseline), letter, HORIZONTAL_ALIGNMENT_CENTER, SIZE, fs, 8, Color("1d3b22"))
		draw_string(font, Vector2(-half, baseline), letter, HORIZONTAL_ALIGNMENT_CENTER, SIZE, fs, Color("e9ffd9"))


static func _make_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	return sb
