class_name UnlockFlight
extends Control

## Something new was unlocked: its medallion pops up over the cauldron, then flies into the button of the spell book.

const R := 46.0
const POP_TIME := 0.4
const SHOW_TIME := 1.1
const FLY_TIME := 0.65

var icon := ""
var text := ""
var emoji_font: Font
var target: Button
var _age := 0.0
var _label_alpha := 1.0
var _from := Vector2.ZERO
var _aim := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func start(from: Vector2, button: Button) -> void:
	target = button
	_from = from
	_aim = button.get_global_rect().get_center()
	position = from
	scale = Vector2.ONE * 0.1
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(SHOW_TIME)
	tw.tween_method(_fly, 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_arrive)


## Along an arc, getting smaller.
func _fly(t: float) -> void:
	var over := (_from + _aim) * 0.5 + Vector2(0, -170)
	position = _from.lerp(over, t).lerp(over.lerp(_aim, t), t)
	scale = Vector2.ONE * lerpf(1.0, 0.3, t)
	_label_alpha = maxf(0.0, 1.0 - t * 4.0)


## The button swallows it with a bounce and a golden flash.
func _arrive() -> void:
	if is_instance_valid(target) and target.is_visible_in_tree():
		target.pivot_offset = target.size * 0.5
		var tw := target.create_tween()
		target.scale = Vector2.ONE
		target.modulate = Color(1.9, 1.6, 0.8)
		tw.tween_property(target, "scale", Vector2.ONE * 1.18, 0.1)
		tw.tween_property(target, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(target, "modulate", Color.WHITE, 0.6)
	queue_free()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	# Turning rays, so it can't be missed.
	for i in 10:
		var a := _age * 0.8 + TAU * i / 10.0
		var side := Vector2.from_angle(a + PI / 2) * 9.0
		var tip := Vector2.from_angle(a) * (R + 34.0 + 6.0 * sin(_age * 4.0 + i))
		draw_colored_polygon(PackedVector2Array([Vector2.from_angle(a) * R + side, Vector2.from_angle(a) * R - side, tip]), Color(1, 0.85, 0.35, 0.55))
	draw_circle(Vector2.ZERO, R + 8, Color(1.0, 0.85, 0.35, 0.35))
	draw_circle(Vector2.ZERO, R, Color("f7e7b5"))
	draw_arc(Vector2.ZERO, R, 0.0, TAU, 48, Color("d9a441"), 5.0, true)
	var art := MenuKit.drawing(icon)
	if art:
		draw_texture_rect(art, Rect2(-28, -28, 56, 56), false)
	else:
		var fs := 44
		var baseline := (emoji_font.get_ascent(fs) - emoji_font.get_descent(fs)) * 0.5
		draw_string(emoji_font, Vector2(-50, baseline), icon, HORIZONTAL_ALIGNMENT_CENTER, 100, fs)
	var font := ThemeDB.fallback_font
	var at := Vector2(-250, R + 52)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 500, 26, 10, Color(0.2, 0.1, 0.03, _label_alpha))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 500, 26, Color(1.0, 0.88, 0.5, _label_alpha))
