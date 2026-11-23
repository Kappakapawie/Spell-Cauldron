class_name ThoughtCloud
extends Control

## The Wisdom hint: the word's meaning drifting above the cauldron like a thought.
## A hazy cloud, soft glowing slanted text, and little thought-dots rising from the brew.

const WIDTH := 620.0

var _label: Label
var _base := Vector2.ZERO
var _fade: Tween
var _shown := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(WIDTH - 80, 0)
	var italic := FontVariation.new()
	italic.base_font = ThemeDB.fallback_font
	italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	_label.add_theme_font_override("font", italic)
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(0.95, 0.93, 1.0, 0.92))
	# A wide, soft shadow with no offset works as a dreamy glow.
	_label.add_theme_color_override("font_shadow_color", Color(0.7, 0.62, 1.0, 0.45))
	_label.add_theme_constant_override("shadow_outline_size", 14)
	_label.add_theme_constant_override("shadow_offset_x", 0)
	_label.add_theme_constant_override("shadow_offset_y", 0)
	add_child(_label)
	modulate.a = 0.0
	visible = false


## Place the thought so its centre sits at `center`.
func setup(center: Vector2) -> void:
	_base = center
	_reposition()


func show_text(text: String) -> void:
	_label.text = text
	_reposition()
	_fade_to(true)


func hide_thought() -> void:
	_fade_to(false)


func toggle() -> void:
	_fade_to(not _shown)


func is_shown() -> bool:
	return _shown


func _reposition() -> void:
	# Fixed box: meanings are short (one or two lines), text is centred inside it.
	_label.size = Vector2(WIDTH - 80, 84)
	_label.position = Vector2(40, 18)
	size = Vector2(WIDTH, 120)


func _fade_to(on: bool) -> void:
	_shown = on
	if _fade:
		_fade.kill()
	if on:
		visible = true
	_fade = create_tween().set_trans(Tween.TRANS_SINE)
	_fade.tween_property(self, "modulate:a", 1.0 if on else 0.0, 0.8 if on else 0.4)
	if not on:
		_fade.tween_callback(func() -> void: visible = false)


func _process(_delta: float) -> void:
	if not visible:
		return
	var t := Time.get_ticks_msec() / 1000.0
	position = _base - size * 0.5 + Vector2(sin(t * 0.6) * 8.0, sin(t * 0.9) * 6.0)
	_label.modulate.a = 0.85 + 0.15 * sin(t * 1.3)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var w := size.x
	var h := size.y
	# Hazy cloud: many big, very faint overlapping puffs.
	var puffs := 9
	for i in puffs:
		var x := w * (0.08 + 0.84 * i / float(puffs - 1))
		var y := h * 0.5 + sin(t * 0.8 + i * 1.7) * 6.0
		var r := h * (0.55 + 0.12 * sin(t * 0.5 + i))
		for layer in 4:
			draw_circle(Vector2(x, y), r * (1.0 - layer * 0.18), Color(0.82, 0.78, 1.0, 0.035))
	# Little thought-dots drifting down toward the brew.
	var dots := [Vector2(w * 0.64, h + 14), Vector2(w * 0.67, h + 40), Vector2(w * 0.69, h + 62)]
	for i in dots.size():
		var p: Vector2 = dots[i] + Vector2(sin(t * 1.2 + i) * 3.0, 0)
		var r := 13.0 - i * 4.0
		draw_circle(p, r, Color(0.85, 0.8, 1.0, 0.18))
		draw_circle(p, r * 0.6, Color(0.9, 0.86, 1.0, 0.18))
