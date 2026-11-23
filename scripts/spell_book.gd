class_name SpellBook
extends Control

## The upgrade menu as an old spell book with a skill tree.
## - Drag the page to look around.
## - Hover a spell to read it. Unlearned spells are written in a strange tongue.
## - Hold the mouse on a spell to learn it: the words decipher while you hold.
##
## The game (main.gd) provides: SKILL_TREE, skill_info(id), skill_buy(id), skill_click(id).

const HOLD_TIME := 1.3
const NODE_R := 38.0
const BOOK := Rect2(120, 30, 1040, 660)
const MAX_PAN := Vector2(420, 260)
const PLAIN := "abcdefghijklmnopqrstuvwxyz"
const RUNES := "qzvkyxwjhpgbmdlncftsueaior"  ## the strange tongue: a letter swap

var game: Node
var emoji_font: Font
var offset := Vector2.ZERO
var hover_id := ""
var hold_id := ""
var hold_t := 0.0
var dragging := false
var shake_id := ""
var shake_t := 0.0
var flash := {}  ## id -> seconds of "just learned" glow left

var canvas: Control
var _italic: FontVariation
var _title_font: FontVariation


func _init() -> void:
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_italic = FontVariation.new()
	_italic.base_font = ThemeDB.fallback_font
	_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.25, 1), Vector2.ZERO)
	_title_font = FontVariation.new()
	_title_font.base_font = ThemeDB.fallback_font
	_title_font.variation_embolden = 0.7
	_title_font.spacing_glyph = 2

	canvas = Control.new()
	canvas.position = BOOK.position + Vector2(30, 104)
	canvas.size = BOOK.size - Vector2(60, 196)  # stops above the hint line at the foot of the page
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_tree)
	canvas.gui_input.connect(_canvas_input)
	canvas.mouse_exited.connect(_on_canvas_exit)
	add_child(canvas)

	var close := Button.new()
	close.text = "Close the book"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(200, 44)
	close.position = Vector2(BOOK.get_center().x - 100, BOOK.end.y - 58)
	close.pressed.connect(close_book)
	add_child(close)


func _on_canvas_exit() -> void:
	hover_id = ""
	hold_id = ""
	dragging = false


func open_book() -> void:
	offset = Vector2.ZERO
	hover_id = ""
	hold_id = ""
	visible = true


func close_book() -> void:
	visible = false
	hold_id = ""


func refresh() -> void:
	queue_redraw()
	canvas.queue_redraw()


# ---------------------------------------------------------------- positions

func _origin() -> Vector2:
	return Vector2(canvas.size.x * 0.5, 54) + offset


func node_center(id: String) -> Vector2:
	for n in game.SKILL_TREE:
		if n.id == id:
			var c: Vector2 = _origin() + n.pos
			if id == shake_id and shake_t > 0.0:
				c.x += sin(shake_t * 60.0) * 6.0
			return c
	return Vector2.ZERO


## Screen position of a spell (used by tests and the Ctrl/Alt shortcuts).
func node_global_pos(id: String) -> Vector2:
	return canvas.global_position + node_center(id)


## Which spell is under this screen point ("" for none).
func node_at(global_p: Vector2) -> String:
	var local := global_p - canvas.global_position
	if not Rect2(Vector2.ZERO, canvas.size).has_point(local):
		return ""
	for n in game.SKILL_TREE:
		if local.distance_to(node_center(n.id)) <= NODE_R + 4.0:
			return n.id
	return ""


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	# Clicking outside the book closes it.
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not BOOK.has_point(mb.position):
		close_book()


func _canvas_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			var id := node_at(canvas.global_position + mb.position)
			if id == "":
				dragging = true
				return
			var info: Dictionary = game.skill_info(id)
			if info.toggle:
				game.skill_click(id)
				refresh()
			elif info.can_buy:
				hold_id = id
				hold_t = 0.0
			else:
				shake_id = id
				shake_t = 0.35
		else:
			dragging = false
			hold_id = ""
		return
	var mm := event as InputEventMouseMotion
	if mm:
		if dragging:
			offset = (offset + mm.relative).clamp(-MAX_PAN, MAX_PAN)
		hover_id = node_at(canvas.global_position + mm.position)
		if hold_id != "" and hover_id != hold_id:
			hold_id = ""  # slid off the spell: stop learning
		canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover_id != "" \
			else (Control.CURSOR_DRAG if dragging else Control.CURSOR_ARROW)


func _process(delta: float) -> void:
	if not visible:
		return
	if hold_id != "":
		hold_t += delta
		if hold_t >= HOLD_TIME:
			var id := hold_id
			hold_id = ""
			if game.skill_buy(id):
				flash[id] = 1.2
	if shake_t > 0.0:
		shake_t -= delta
	for id in flash.keys():
		flash[id] -= delta
		if flash[id] <= 0.0:
			flash.erase(id)
	refresh()


# ---------------------------------------------------------------- the strange tongue

## Turns text into gibberish; the first `reveal` fraction of it stays readable.
static func garble(text: String, reveal: float) -> String:
	var keep := int(text.length() * clampf(reveal, 0.0, 1.0))
	var out := ""
	for i in text.length():
		var ch := text[i]
		if i < keep:
			out += ch
			continue
		var lower := ch.to_lower()
		var k := PLAIN.find(lower)
		if k < 0:
			out += ch
		else:
			var g := RUNES[k]
			out += g.to_upper() if ch != lower else g
	return out


static func _wrap(text: String, max_chars: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		if line != "" and line.length() + 1 + word.length() > max_chars:
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		lines.append(line)
	return lines


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	# Leather cover
	var cover := StyleBoxFlat.new()
	cover.bg_color = Color("5a2e1c")
	cover.border_color = Color("2e160c")
	cover.set_border_width_all(4)
	cover.set_corner_radius_all(18)
	draw_style_box(cover, BOOK.grow(16))
	# Two parchment pages and the spine
	var page := StyleBoxFlat.new()
	page.bg_color = Color("f1e2bd")
	page.set_corner_radius_all(8)
	var half := BOOK.size.x * 0.5
	draw_style_box(page, Rect2(BOOK.position, Vector2(half - 2, BOOK.size.y)))
	draw_style_box(page, Rect2(BOOK.position + Vector2(half + 2, 0), Vector2(half - 2, BOOK.size.y)))
	var spine_x := BOOK.get_center().x
	for i in 6:
		draw_rect(Rect2(spine_x - 18 + i * 3, BOOK.position.y, 36 - i * 6, BOOK.size.y), Color(0.45, 0.28, 0.12, 0.05))
	draw_line(Vector2(spine_x, BOOK.position.y), Vector2(spine_x, BOOK.end.y), Color(0.35, 0.2, 0.1, 0.5), 2.0)
	# Title and plain stats
	draw_string(_title_font, Vector2(BOOK.position.x, BOOK.position.y + 50), "Book of Shelves & Spells",
		HORIZONTAL_ALIGNMENT_CENTER, BOOK.size.x, 34, Color("4a2c17"))
	var stats: String = game.book_stats_text()
	draw_string(font, Vector2(BOOK.position.x, BOOK.position.y + 84), stats,
		HORIZONTAL_ALIGNMENT_CENTER, BOOK.size.x, 19, Color("8a5a1a"))
	draw_string(_italic, Vector2(BOOK.position.x, BOOK.end.y - 72),
		"Hover a spell to read it  -  hold the mouse on it to learn it  -  drag the page to look around",
		HORIZONTAL_ALIGNMENT_CENTER, BOOK.size.x, 15, Color(0.35, 0.22, 0.1, 0.75))


func _draw_tree() -> void:
	var font := ThemeDB.fallback_font
	var t := Time.get_ticks_msec() / 1000.0
	var ink := Color(0.35, 0.22, 0.1, 0.55)
	# Ink lines between spells
	for n in game.SKILL_TREE:
		if n.parent == "":
			continue
		var a := node_center(n.parent)
		var b := node_center(n.id)
		var learned: bool = game.skill_info(n.id).understood
		canvas.draw_dashed_line(a, b, Color("c99a3a") if learned else ink, 3.0, 10.0, true, true)
	# Spell medallions
	for n in game.SKILL_TREE:
		var info: Dictionary = game.skill_info(n.id)
		var c := node_center(n.id)
		var ring := Color(0.45, 0.33, 0.22, 0.7)
		var fill := Color("e3cf9f")
		var icon_alpha := 0.45
		if info.understood:
			ring = Color("d9a441")
			fill = Color("f7e7b5")
			icon_alpha = 1.0
		if info.can_buy:
			ring = Color("4fae6a").lerp(Color("9be3a3"), 0.5 + 0.5 * sin(t * 3.0))
			icon_alpha = 1.0
			canvas.draw_circle(c, NODE_R + 9, Color(0.4, 0.85, 0.5, 0.18))
		if flash.has(n.id):
			canvas.draw_circle(c, NODE_R + 16, Color(1.0, 0.85, 0.3, 0.35 * flash[n.id]))
		if n.id == hover_id:
			canvas.draw_circle(c, NODE_R + 6, Color(1, 1, 1, 0.25))
		canvas.draw_circle(c, NODE_R, fill)
		canvas.draw_arc(c, NODE_R, 0.0, TAU, 48, ring, 4.0, true)
		canvas.draw_arc(c, NODE_R - 7, 0.0, TAU, 48, Color(ring, 0.35), 1.5, true)
		var fs := 34
		var baseline := (emoji_font.get_ascent(fs) - emoji_font.get_descent(fs)) * 0.5
		canvas.draw_string(emoji_font, c + Vector2(-40, baseline), n.icon,
			HORIZONTAL_ALIGNMENT_CENTER, 80, fs, Color(1, 1, 1, icon_alpha))
		canvas.draw_string(font, c + Vector2(-90, NODE_R + 22), info.status_text,
			HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Color("4a2c17"))
		if n.id == hold_id:
			var frac := hold_t / HOLD_TIME
			canvas.draw_arc(c, NODE_R + 8, -PI / 2, -PI / 2 + TAU * frac, 48, Color("ffd45c"), 6.0, true)
	if hover_id != "":
		_draw_tooltip(hover_id)


func _draw_tooltip(id: String) -> void:
	var info: Dictionary = game.skill_info(id)
	var c := node_center(id)
	var reveal := 1.0 if info.understood else 0.0
	if id == hold_id:
		reveal = hold_t / HOLD_TIME
	var title := garble(info.title, reveal)
	var lines := _wrap(info.desc, 34)
	var w := 330.0
	var h := 64.0 + lines.size() * 22.0 + 30.0
	var pos := c + Vector2(NODE_R + 18, -h * 0.5)
	if pos.x + w > canvas.size.x - 6:
		pos.x = c.x - NODE_R - 18 - w
	pos.y = clampf(pos.y, 6, canvas.size.y - h - 6)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("fbf1d6")
	box.border_color = Color("8b5a2b")
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.shadow_color = Color(0, 0, 0, 0.25)
	box.shadow_size = 6
	canvas.draw_style_box(box, Rect2(pos, Vector2(w, h)))
	var rune_col := Color("5b3a7a")
	canvas.draw_string(_title_font, pos + Vector2(16, 32), title, HORIZONTAL_ALIGNMENT_LEFT, w - 32, 20, rune_col)
	# The description deciphers along with the title, line by line.
	var total := 0
	for l in lines:
		total += l.length()
	var shown_chars := int(total * reveal)
	var y := pos.y + 60
	for l in lines:
		var r := clampf(float(shown_chars) / float(maxi(1, l.length())), 0.0, 1.0)
		shown_chars -= l.length()
		canvas.draw_string(_italic, Vector2(pos.x + 16, y), garble(l, r), HORIZONTAL_ALIGNMENT_LEFT, w - 32, 17, rune_col)
		y += 22
	# Cost / requirement always in plain words.
	canvas.draw_string(ThemeDB.fallback_font, Vector2(pos.x + 16, pos.y + h - 14), info.hint,
		HORIZONTAL_ALIGNMENT_LEFT, w - 32, 15, Color("8a5a1a"))
