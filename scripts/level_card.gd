class_name LevelCard
extends Button

## One recipe book in the picker: a leather book standing on a shelf, with its star beside it.

const CARD := Vector2(204, 206)
const PLANK_Y := 126.0  ## where the shelf runs, seen from the top of the card
const BOOK_WIDTH := 82.0
const HEIGHTS: Array[float] = [104, 112, 100, 108, 103]  ## not all books are equally tall
const GILT := Color("e3b95c")

var number := 1
var suggested := false  ## the next book to try glows
var star: LevelStar
var _cover := Color.WHITE
var _lines: Array[String] = []


func _init(p_number: int = 1) -> void:
	number = p_number
	size = CARD
	custom_minimum_size = CARD
	focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var settings: Dictionary = GameData.LEVELS[number - 1]
	var t := (number - 1) / float(GameData.LEVELS.size() - 1)
	_cover = Color.from_hsv(0.36 + 0.5 * t, 0.52, 0.55)  # green for easy ... pink for hard
	_lines = [
		"%s letters%s" % [_span(settings.min_len, settings.max_len), ", mixed" if settings.get("mixed", false) else ""],
		"find %s, gaps %s" % [_span(GameData.missing_span(settings).x, GameData.missing_span(settings).y),
			"shown" if settings.gaps_visible else "hidden"],
	]
	star = LevelStar.new()
	star.show_empty = true
	star.position = Vector2(146, PLANK_Y - 44)
	star.size = star.custom_minimum_size
	add_child(star)


func _span(a: int, b: int) -> String:
	return str(a) if a == b else "%d-%d" % [a, b]


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var hover := is_hovered()
	var book := Rect2(0, 0, BOOK_WIDTH, HEIGHTS[(number * 2) % HEIGHTS.size()])
	book.position = Vector2((CARD.x - BOOK_WIDTH) * 0.5, PLANK_Y - book.size.y)
	var c := book.get_center()
	if suggested:
		var pulse := 0.5 + 0.5 * sin(t * 2.5)
		for i in 4:
			draw_circle(c, 58.0 + i * 8.0, Color(1.0, 0.85, 0.35, 0.05 + 0.04 * pulse))
	if hover:
		book.position.y -= 5.0  # the book lifts off the shelf a little
	_draw_book(book, _cover.lightened(0.12) if hover else _cover)
	var font := ThemeDB.fallback_font
	var fs := 32
	var mid := book.position + Vector2(44.5, book.size.y * 0.37)  # middle of the front cover
	var y := mid.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	var at := Vector2(mid.x - 40, y)
	draw_string_outline(font, at, str(number), HORIZONTAL_ALIGNMENT_CENTER, 80, fs, 8, Color("2c1c14"))
	draw_string(font, at, str(number), HORIZONTAL_ALIGNMENT_CENTER, 80, fs, Color.WHITE)
	draw_string(font, Vector2(0, PLANK_Y + 44), _lines[0], HORIZONTAL_ALIGNMENT_CENTER, CARD.x, 18, MenuKit.CREAM)
	draw_string(font, Vector2(0, PLANK_Y + 68), _lines[1], HORIZONTAL_ALIGNMENT_CENTER, CARD.x, 16, Color("e8c27a"))


## A closed leather book, standing with its front to you. Spine on the left, pages on the right.
func _draw_book(r: Rect2, cover: Color) -> void:
	# Back cover and pages peek out on the right.
	_rounded(r, cover.darkened(0.45), 6)
	draw_rect(Rect2(r.position + Vector2(20, 4), Vector2(r.size.x - 23, r.size.y - 8)), Color("ecdcb4"))
	for i in 2:
		var x := r.end.x - 5.0 + i * 1.5
		draw_line(Vector2(x, r.position.y + 5), Vector2(x, r.end.y - 5), Color("b79d6b"), 0.8)
	# A ribbon hangs out between the pages.
	var rx := r.end.x - 24.0
	draw_colored_polygon(PackedVector2Array([Vector2(rx, r.end.y - 3), Vector2(rx + 9, r.end.y - 3),
		Vector2(rx + 9, r.end.y + 13), Vector2(rx + 4.5, r.end.y + 8), Vector2(rx, r.end.y + 13)]), Color("b3433f"))
	# Front cover and spine.
	var front := Rect2(r.position, Vector2(r.size.x - 6, r.size.y))
	_rounded(front, cover, 6)
	_rounded(Rect2(r.position, Vector2(13, r.size.y)), cover.darkened(0.28), 6)
	draw_line(r.position + Vector2(13, 1), Vector2(r.position.x + 13, r.end.y - 1), cover.darkened(0.5), 1.5)
	for part in [0.14, 0.84]:
		draw_line(r.position + Vector2(0, r.size.y * part), r.position + Vector2(13, r.size.y * part), GILT, 2.5)
	# Gilded frame with corners, and the recipe's flask under the number.
	var frame := Rect2(front.position + Vector2(18, 6), front.size - Vector2(23, 12))
	draw_rect(frame, Color(GILT, 0.75), false, 1.5)
	for corner in [frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]:
		draw_circle(corner, 3.0, GILT)
	PotionArt.draw_flask(self, Vector2(frame.get_center().x, r.end.y - 22), 1.1, Color.from_hsv(cover.h, 0.5, 0.85))


func _rounded(r: Rect2, color: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)
