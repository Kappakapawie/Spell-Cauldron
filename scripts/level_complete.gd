class_name LevelComplete
extends Control

## End of a recipe book: first the big moment (BookFinale), then the star counts up, and every level (word) is listed with its points.

signal again_pressed
signal next_pressed
signal levels_pressed

const PANEL := Rect2(230, 50, 820, 620)

var emoji_font: Font
var title_label: Label
var message_label: Label
var unlock_label: Label
var next_button: Button
var star: LevelStar
var finale: BookFinale
var badge: Badge
var _grid: GridContainer
var _tween: Tween
var _goal := 0.0
var _golden := false


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	title_label = _centered(34, MenuKit.INK, 66)
	star = LevelStar.new()
	star.radius = 62.0
	star.on_parchment = true
	star.position = Vector2(565, 116)
	star.size = Vector2(150, 140)
	add_child(star)
	badge = Badge.new()
	badge.position = Vector2(758, 138)
	add_child(badge)
	message_label = _centered(24, Color("8a5a1a"), 254)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 40)
	_grid.add_theme_constant_override("v_separation", 4)
	var scroll := ScrollContainer.new()  # scrolls when a book has more than 10 levels
	scroll.position = Vector2(270, 304)
	scroll.size = Vector2(754, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.add_child(_grid)
	unlock_label = _centered(20, Color("5b3a7a"), 546)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)
	bar.position = Vector2(PANEL.position.x, 594)
	bar.size = Vector2(PANEL.size.x, 54)
	add_child(bar)
	bar.add_child(MenuKit.button("Choose recipes", Vector2(200, 54), levels_pressed.emit))
	bar.add_child(MenuKit.button("Play again", Vector2(200, 54), again_pressed.emit))
	next_button = MenuKit.button("Next recipes", Vector2(200, 54), next_pressed.emit)
	next_button.add_theme_color_override("font_color", MenuKit.GOLD)
	bar.add_child(next_button)
	finale = BookFinale.new()
	finale.finished.connect(_count_up)
	add_child(finale)


func _centered(font_size: int, color: Color, y: float) -> Label:
	var l := MenuKit.label("", font_size, color)
	l.position = Vector2(PANEL.position.x, y)
	l.size = Vector2(PANEL.size.x, font_size + 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


## result: {level (the book's number), plain, time (this run), best, best_plain, best_time (all runs),
##          best_before, perfect, was_conquered, has_next, hourglass (learned), lost (its sand ran out),
##          words: Array of {word, picture, points, fast, time}, unlocked: Array of spell names}
func show_result(result: Dictionary) -> void:
	title_label.text = "Brew recipes %d complete!" % result.level
	next_button.visible = result.has_next
	var text := ""
	if result.perfect:
		text = "Perfect again!" if result.was_conquered else "Perfect - recipes mastered!"
	elif result.best > result.best_before:
		text = "New best!"
	if result.best_time > 0.0:
		# Two scores: the best of each counts, also from different runs.
		text += "  This run: %s + %s in time.  Best: %s + %s" % [MenuKit.points_text(result.plain),
			MenuKit.points_text(result.time), MenuKit.points_text(result.best_plain), MenuKit.points_text(result.best_time)]
	elif result.best > result.plain:
		text += "This run: %s" % MenuKit.points_text(result.plain)
	message_label.text = text.strip_edges()
	var spells := PackedStringArray(result.unlocked)
	unlock_label.text = "" if spells.is_empty() else "New in the spell book: %s" % ", ".join(spells)
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	for w in result.words:
		_grid.add_child(_word_row(w))
	visible = true
	badge.font = emoji_font
	badge.visible = result.hourglass
	badge.time = result.time
	badge.lost = result.lost
	badge.queue_redraw()
	_goal = float(result.best)
	_golden = result.perfect or result.was_conquered
	if _tween:
		_tween.kill()
	_count_to(0.0)
	finale.start(result)


## The big moment is over (or skipped).
func _count_up() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_count_to, 0.0, _goal, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _golden:
		_tween.tween_callback(star.set_record.bind(true, _goal, true))
	badge.pop()


func _count_to(v: float) -> void:
	# Counts in tenths, and ends on the exact score.
	star.set_record(true, _goal if is_equal_approx(v, _goal) else snappedf(v, 0.1), false)


func _word_row(w: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(350, 42)
	h.add_theme_constant_override("separation", 10)
	var pic := MenuKit.picture(w.picture, 24, emoji_font)
	pic.custom_minimum_size.x = 44
	h.add_child(pic)
	var name_label := MenuKit.label(w.word, 22, MenuKit.INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_label)
	if w.get("fast", false):
		h.add_child(MenuKit.label("time +" + MenuKit.points_text(w.time), 17, Color("b8842a")))
	var full: bool = w.points >= 1.0
	h.add_child(MenuKit.label("+" + MenuKit.points_text(w.points), 22, Color("3d7a45") if full else Color("a0603a")))
	return h


func _draw() -> void:
	draw_rect(ScreenLayout.rect(), Color(0, 0, 0, 0.55))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f3e2b8")
	sb.border_color = Color("8b5a2b")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	draw_style_box(sb, PANEL)


## Also beside the 1280 x 720 on a wider screen: nothing behind it can be touched.
func _has_point(point: Vector2) -> bool:
	return ScreenLayout.rect().has_point(point)


## The stars the hourglass gave in this run, beside the star.
class Badge extends Control:
	var font: Font
	var time := 0.0
	var lost := false

	func _init() -> void:
		size = Vector2(200, 96)
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func pop() -> void:
		if time <= 0.0:
			return
		scale = Vector2.ONE * 1.5
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var good := time > 0.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("ffd45c") if good else Color("d9c9a0")
		sb.border_color = Color("b8842a") if good else Color("a58f66")
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(18)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		draw_string(font, Vector2(14, 56), "⏳", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 1.0 if good else 0.45))
		var ink := Color("4a2c17") if good else Color("7d6845")
		var letters := ThemeDB.fallback_font
		draw_string(letters, Vector2(62, 56), "+" + MenuKit.points_text(time), HORIZONTAL_ALIGNMENT_CENTER, 130, 46, ink)
		draw_string(letters, Vector2(0, 84), "the sand ran out" if lost else "in time", HORIZONTAL_ALIGNMENT_CENTER, 200, 17, ink)
