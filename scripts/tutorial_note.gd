class_name TutorialNote
extends Control

## A small parchment message with a pointer, for the first steps of a new game.

var tip := Vector2.ZERO  ## what it points at, on the screen
var _label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_label = MenuKit.label("", 21 if ScreenLayout.roomy() else 17, MenuKit.INK)
	_label.add_theme_constant_override("line_spacing", -2)
	_label.position = Vector2(14, 10)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)


## Shows the text in `rect`, pointing at `at`. Without a text it hides.
func say(text: String, rect := Rect2(), at := Vector2.ZERO) -> void:
	if text != "" and not visible:
		pivot_offset = rect.size * 0.5
		scale = Vector2.ONE * 0.6
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.35)
	visible = text != ""
	if not visible:
		return
	position = rect.position
	size = rect.size
	tip = at
	_label.text = text
	_label.size = rect.size - Vector2(28, 20)
	queue_redraw()


func _draw() -> void:
	var paper := Color("fbf1d6")
	var edge := Color("c99a5b")
	var to := tip - position
	# The pointer: a triangle from the side that faces the tip.
	var base := to.clamp(Vector2(34, 0), Vector2(size.x - 34, size.y))
	var bob := (to - base).normalized() * 4.0 * sin(Time.get_ticks_msec() / 220.0)
	if absf(to.y - base.y) > 1.0:
		var pts := PackedVector2Array([base + Vector2(-13, 0), base + Vector2(13, 0), to + bob])
		draw_colored_polygon(pts, edge)
	var box := StyleBoxFlat.new()
	box.bg_color = paper
	box.border_color = edge
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = 5
	draw_style_box(box, Rect2(Vector2.ZERO, size))
