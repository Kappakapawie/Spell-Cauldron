class_name LevelPicker
extends Control

## Choose a book of brew recipes: leather books on shelves, ten to a shelf, each with its star.
## Page 1 holds all the normal books, page 2 the mystery books (their theme is a secret).

signal level_chosen(level: int)
signal back_pressed
signal book_pressed

const PER_SHELF := 10
const STEP := 112.0
const SHELF_Y: Array[float] = [272.0, 422.0, 572.0]
const PAGES := 2

var cards: Array[LevelCard] = []
var page := -1           ## 0 = the normal books, 1 = the mystery books (-1 = not decided yet)
var page_label: Label
var info_label: Label    ## what the book under the mouse asks of you
var earlier: Button
var later: Button
var total_star: LevelStar
var book_button: Button


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_centered_label("Choose your brew recipes", 42, MenuKit.CREAM, 28)
	page_label = _centered_label("", 22, Color("e8c27a"), 82)
	info_label = _centered_label("", 18, MenuKit.CREAM, 112)
	total_star = LevelStar.new()
	total_star.radius = 42.0
	total_star.position = Vector2(590, 624)
	total_star.size = Vector2(100, 92)
	add_child(total_star)
	for n in range(1, GameData.book_count() + 1):
		var card := LevelCard.new(n)
		var i := GameData.book_number(n) - 1  # its place on its own page
		var zoom := 1.14 if ScreenLayout.roomy() else 1.0
		var x := 640.0 + (i % PER_SHELF - (PER_SHELF - 1) * 0.5) * STEP * (1.2 if ScreenLayout.roomy() else 1.0)
		card.scale = Vector2.ONE * zoom
		card.position = Vector2(x - LevelCard.CARD.x * 0.5 * zoom, SHELF_Y[(i / PER_SHELF) % SHELF_Y.size()] - LevelCard.PLANK_Y * zoom)
		card.pressed.connect(func() -> void: level_chosen.emit(card.number))
		card.mouse_entered.connect(func() -> void: info_label.text = card.tooltip_text.replace("\n", "  -  "))
		card.mouse_exited.connect(func() -> void: info_label.text = "")
		add_child(card)
		cards.append(card)
	earlier = MenuKit.button("<", Vector2(ScreenLayout.pick(54, 90), ScreenLayout.pick(72, 110)), func() -> void: show_page(page - 1))
	earlier.position = Vector2(8 - ScreenLayout.edge(), 372)
	add_child(earlier)
	later = MenuKit.button(">", Vector2(ScreenLayout.pick(54, 90), ScreenLayout.pick(72, 110)), func() -> void: show_page(page + 1))
	later.position = Vector2(ScreenLayout.pick(1218, 1182) + ScreenLayout.edge(), 372)
	add_child(later)
	for b: Button in [earlier, later]:
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_color_override("font_color", MenuKit.GOLD)
	var back := MenuKit.button("Back", Vector2(160, 52), back_pressed.emit)
	back.position = Vector2(70 - ScreenLayout.edge(), 648)
	add_child(back)
	book_button = MenuKit.button("Spell book", Vector2(160, 52), book_pressed.emit)
	book_button.position = Vector2(1050 + ScreenLayout.edge(), 648)
	add_child(book_button)


func _centered_label(text: String, font_size: int, color: Color, y: float) -> Label:
	var l := MenuKit.label(text, font_size, color)
	l.position = Vector2(0, y)
	l.size = Vector2(1280, font_size + 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


func show_page(n: int) -> void:
	page = clampi(n, 0, PAGES - 1)
	for card in cards:
		card.visible = card.mystery == (page == 1)
	earlier.visible = page > 0
	later.visible = page < PAGES - 1
	info_label.text = ""
	page_label.text = "Brew recipes 1-%d" % GameData.LEVELS.size() if page == 0 \
		else "Mystery recipes 1-%d: the theme is a secret" % GameData.MYSTERY_LIKE.size()
	queue_redraw()


## Turns to the page this book is on.
func show_book(n: int) -> void:
	show_page(1 if GameData.is_mystery(n) else 0)


func refresh(records: Dictionary, total_stars: float) -> void:
	total_star.set_record(true, total_stars, true)
	var found := {}  # per page
	for card in cards:
		var rec: Dictionary = records.get(card.number, {})
		var conquered: bool = rec.get("conquered", false)
		card.star.set_record(not rec.is_empty(), float(rec.get("best", 0.0)), conquered)
		# The first book on each page that is not conquered yet is the one to try next.
		card.suggested = not found.has(card.mystery) and not conquered
		if card.suggested:
			found[card.mystery] = true
		if card.suggested and page < 0:
			show_book(card.number)
	if page < 0:
		show_page(0)


## Which level's card is under this screen point (0 for none).
func level_at(global_p: Vector2) -> int:
	for card in cards:
		if card.visible and card.get_global_rect().has_point(global_p):
			return card.number
	return 0


func _draw() -> void:
	var all := ScreenLayout.rect()
	draw_rect(all, Color("4b3226"))
	for x in range(-800, 2081, 80):
		if x >= all.position.x and x <= all.end.x:
			draw_line(Vector2(x, all.position.y), Vector2(x, all.end.y), Color("3e291f"), 3.0)
	var wide := ScreenLayout.edge()
	var shelves := ceili(float(GameData.LEVELS.size() if page <= 0 else GameData.MYSTERY_LIKE.size()) / PER_SHELF)
	for y in SHELF_Y.slice(0, shelves):
		draw_rect(Rect2(70 - wide, y + 16, 1140 + wide * 2.0, 6), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(70 - wide, y, 1140 + wide * 2.0, 16), Color("8a5a32"))
		draw_rect(Rect2(70 - wide, y, 1140 + wide * 2.0, 4), Color("a8743f"))


## Also beside the 1280 x 720 on a wider screen: nothing behind it can be touched.
func _has_point(point: Vector2) -> bool:
	return ScreenLayout.rect().has_point(point)
