class_name PotionIcon
extends Button

## Wisdom or Vision as a round icon, like the pets: click it to drink. The ring fills up with every drink,
## the badge says how many of them you had, and below it stands what the next one costs.

var kind := ""
var costs: CostIcons
var done := 0
var steps := 1
var note := ""
var locked := false
var _pop := 0.0


func _init(p_kind := "", width := 120.0) -> void:
	kind = p_kind
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
		add_theme_color_override(color, Color.TRANSPARENT)  # the text is drawn below the icon instead
	clip_text = true
	custom_minimum_size = Vector2(width, _radius() * 2.0 + (86.0 if ScreenLayout.roomy() else 54.0))
	costs = CostIcons.new()
	costs.position = Vector2(0, custom_minimum_size.y - 26.0 * ScreenLayout.icons())
	costs.size = Vector2(width, 24.0 * ScreenLayout.icons())
	add_child(costs)
	button_down.connect(func() -> void: _pop = 1.0)


func _radius() -> float:
	return 36.0 * ScreenLayout.icons()


func _label() -> String:
	return kind.capitalize()


## Not learned yet.
func show_locked(p_note: String) -> void:
	locked = true
	done = 0
	_show(p_note, [], false)


func show_drunk(p_done: int, p_steps: int, p_note: String, cost: Array[Color], usable: bool) -> void:
	locked = false
	done = p_done
	steps = p_steps
	_show(p_note, cost, usable)


func _show(p_note: String, cost: Array[Color], usable: bool) -> void:
	note = p_note
	disabled = not usable
	text = "%s\n(%s)" % [_label(), note] if note != "" else "%s %d/%d" % [_label(), done, steps]
	costs.set_costs(cost)
	queue_redraw()


func _process(delta: float) -> void:
	_pop = maxf(0.0, _pop - delta * 4.0)
	if is_visible_in_tree():
		queue_redraw()


## Only the round icon and its name can be clicked, not the empty corners.
func _has_point(point: Vector2) -> bool:
	return absf(point.x - size.x * 0.5) <= _radius() + 8.0 and Rect2(Vector2.ZERO, size).has_point(point)


func _draw() -> void:
	var r := _radius()
	var zoom := ScreenLayout.icons()
	var ready := not disabled and not locked
	var color: Color = PotionArt.COLORS[kind]
	var bob := sin(Time.get_ticks_msec() / 650.0 + (0.0 if kind == PotionArt.WISDOM else 1.5)) * 3.0 if ready else 0.0
	var c := Vector2(size.x * 0.5, r + 5.0 + bob)
	var hover := is_hovered() and ready and not ScreenLayout.phone
	if ready:
		draw_circle(c, r + 5.0, Color(color, 0.16))  # it glows when you can drink it
	draw_circle(c, r, Color(color, 0.3) if hover else Color(0, 0, 0, 0.25))
	draw_arc(c, r, 0.0, TAU, 40, Color(color, 0.75 if ready else 0.22), 4.0, true)
	if done > 0 and not locked:
		draw_arc(c, r, -PI / 2, -PI / 2 + TAU * done / float(maxi(1, steps)), 40, Color("f2c14e"), 5.0, true)
	var flask := zoom * 1.75 * (1.0 - 0.12 * _pop)
	var tint := color if ready else Color(color.lerp(Color("5a5048"), 0.65), 0.6)
	if locked:
		tint = Color("4a4038")
	PotionArt.draw_flask(self, c + Vector2(0, 7.0 * zoom), flask, tint)
	if not ready:
		draw_circle(c, r - 2.0, Color(0.16, 0.1, 0.07, 0.5 if locked else 0.35))
	var font := ThemeDB.fallback_font
	if not locked:
		var badge := c + Vector2(r - 6.0, -r + 8.0)
		var text_size := roundi(13 * ScreenLayout.pick(1.0, 1.25))
		draw_circle(badge, 15.0 * ScreenLayout.pick(1.0, 1.2), Color("f2c14e") if ready else Color(0.36, 0.3, 0.26))
		draw_string(font, badge + Vector2(-20, text_size * 0.36), "%d/%d" % [done, steps], HORIZONTAL_ALIGNMENT_CENTER, 40, text_size, Color("4a2c17") if ready else Color("e8d9bd"))
	else:
		# A small padlock.
		var at := c + Vector2(0, 2)
		draw_arc(at + Vector2(0, -6) * zoom, 7.0 * zoom, PI, TAU, 16, Color("e8c27a"), 3.0 * zoom, true)
		draw_rect(Rect2(at + Vector2(-10, -6) * zoom, Vector2(20, 16) * zoom), Color("e8c27a"))
	var y := r * 2.0 + 10.0
	var fs := int(ScreenLayout.pick(16, 23))
	draw_string(font, Vector2(0, y + fs), _label(), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, color.lightened(0.5) if ready else Color(1, 0.95, 0.85, 0.5))
	if note != "":
		var small := int(ScreenLayout.pick(14, 19))
		draw_string(font, Vector2(0, y + fs + small + 5.0), note, HORIZONTAL_ALIGNMENT_CENTER, size.x, small, Color(1, 0.95, 0.85, 0.7))
