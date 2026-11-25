class_name SpellBook
extends Control

## The upgrade menu as an old spell book with a skill tree.
## - Drag the page to look around.
## - Hover a spell to read it. Unlearned spells are written in a strange tongue.
## - Hold the mouse on a spell to learn it: the words decipher while you hold.
##   Short on points? Then it stops part-way: half the price deciphers half the words.
##
## The word themes grow from a node of their own beside the spells.
##
## The game (main.gd) provides: tree_nodes(), skill_info(id), skill_buy(id).

const HOLD_TIME := 1.3
const NODE_R := 38.0
var BOOK := Rect2(44, 22, 1192, 676)
var ZOOM := 0.82            ## the tree is drawn this much smaller, so it all fits on the page
const ROOT_AT := Vector2(-194, -13)  ## where the cauldron is, from the middle of the page
const MAX_PAN := Vector2(620, 420)
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
var _label_font: FontVariation


func _init() -> void:
	if ScreenLayout.phone:
		BOOK = Rect2(44, 22, 1192, 676).grow_individual(ScreenLayout.edge(), 8, ScreenLayout.edge(), 8)
		ZOOM = 0.92
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

	_label_font = FontVariation.new()
	_label_font.base_font = ThemeDB.fallback_font
	_label_font.variation_embolden = 0.6

	canvas = Control.new()
	var top := ScreenLayout.pick(98, 62)  # on a phone the lines above and below it take less room
	canvas.position = BOOK.position + Vector2(20, top)
	canvas.scale = Vector2.ONE * ZOOM
	canvas.size = (BOOK.size - Vector2(40, top + ScreenLayout.pick(88, 72))) / ZOOM  # stops above the foot of the page
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_tree)
	canvas.gui_input.connect(_canvas_input)
	canvas.mouse_exited.connect(_on_canvas_exit)
	add_child(canvas)

	var close := Button.new()
	close.text = "Close the book"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(ScreenLayout.pick(200, 260), ScreenLayout.pick(44, 56))
	close.position = Vector2(BOOK.get_center().x - close.custom_minimum_size.x * 0.5, BOOK.end.y - ScreenLayout.pick(58, 66))
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


func nodes() -> Array:
	return game.tree_nodes()


func close_book() -> void:
	visible = false
	hold_id = ""


func refresh() -> void:
	queue_redraw()
	canvas.queue_redraw()


# ---------------------------------------------------------------- positions

func _origin() -> Vector2:
	return canvas.size * 0.5 + ROOT_AT + offset


func node_center(id: String) -> Vector2:
	for n in nodes():
		if n.id == id:
			var c: Vector2 = _origin() + n.pos
			if id == shake_id and shake_t > 0.0:
				c.x += sin(shake_t * 60.0) * 6.0
			return c
	return Vector2.ZERO


## Screen position of a spell (used by tests and the Ctrl/Alt shortcuts).
func node_global_pos(id: String) -> Vector2:
	return canvas.global_position + node_center(id) * ZOOM


## Which spell is under this screen point ("" for none).
func node_at(global_p: Vector2) -> String:
	return _node_at_local((global_p - canvas.global_position) / ZOOM)


func _node_at_local(local: Vector2) -> String:
	if not Rect2(Vector2.ZERO, canvas.size).has_point(local):
		return ""
	for n in nodes():
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
			var id := _node_at_local(mb.position)
			hover_id = id  # a finger can't hover: what it touches is explained
			if id == "":
				dragging = true
				return
			var info: Dictionary = game.skill_info(id)
			if info.afford > 0.0:
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
		hover_id = _node_at_local(mm.position)
		if hold_id != "" and hover_id != hold_id:
			hold_id = ""  # slid off the spell: stop learning
		canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover_id != "" \
			else (Control.CURSOR_DRAG if dragging else Control.CURSOR_ARROW)


func _process(delta: float) -> void:
	if not visible:
		return
	if hold_id != "":
		var info: Dictionary = game.skill_info(hold_id)
		var limit: float = HOLD_TIME * info.afford
		var was_below := hold_t < limit
		hold_t = minf(hold_t + delta, limit)
		if hold_t >= limit and info.can_buy:
			var id := hold_id
			hold_id = ""
			if game.skill_buy(id):
				flash[id] = 1.2
				if game.skill_info(id).can_buy:
					hold_id = id  # still held: the next rank fills at the same pace
					hold_t = 0.0
		elif hold_t >= limit and was_below:
			# As far as the points reach: it stops here, and stays readable while held.
			shake_id = hold_id
			shake_t = 0.35
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
	draw_rect(ScreenLayout.rect(), Color(0, 0, 0, 0.6))
	# Leather cover
	var cover := StyleBoxFlat.new()
	cover.bg_color = Color("5a2e1c")
	cover.border_color = Color("2e160c")
	cover.set_border_width_all(4)
	cover.set_corner_radius_all(18)
	draw_style_box(cover, BOOK.grow(16))
	# Two parchment pages that meet in a soft fold (kept faint: the spells sit on top of it)
	var page := StyleBoxFlat.new()
	page.bg_color = Color("f1e2bd")
	page.set_corner_radius_all(8)
	draw_style_box(page, BOOK)
	var spine_x := BOOK.get_center().x
	for i in 12:
		var w := 48.0 - i * 4.0
		draw_rect(Rect2(spine_x - w * 0.5, BOOK.position.y, w, BOOK.size.y), Color(0.45, 0.28, 0.12, 0.009))
	draw_line(Vector2(spine_x, BOOK.position.y), Vector2(spine_x, BOOK.end.y), Color(0.45, 0.28, 0.12, 0.12), 1.0)
	# Title and plain stats
	var phone := ScreenLayout.phone
	draw_string(_title_font, Vector2(BOOK.position.x + (40.0 if phone else 0.0), BOOK.position.y + (46.0 if phone else 50.0)), "Book of Shelves & Spells",
		HORIZONTAL_ALIGNMENT_LEFT if phone else HORIZONTAL_ALIGNMENT_CENTER, BOOK.size.x, 34, Color("4a2c17"))
	# Knowledge, and all your stars in the star symbol beside it.
	var stats: String = game.book_stats_text()
	var fs := 26 if phone else 19
	var stats_w := font.get_string_size(stats, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var stats_x := BOOK.end.x - 40.0 - stats_w - 84.0 if phone else BOOK.get_center().x - (stats_w + 74.0) * 0.5
	var stats_y := BOOK.position.y + (46.0 if phone else 86.0)
	draw_string(font, Vector2(stats_x, stats_y), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("8a5a1a"))
	LevelStar.draw_star(self, Vector2(stats_x + stats_w + 48.0, stats_y - 3.0 - (6.0 if phone else 0.0)), 26.0 if phone else 23.0, game.total_stars())
	var foot: String = game.book_tip()
	var said := foot != ""
	if not said:
		foot = ScreenLayout.say("Hover a spell to read it  -  hold the mouse on it to learn it  -  drag the page to look around")
	if phone:  # beside the button
		var w := BOOK.size.x * 0.5 - 130.0 - 60.0
		draw_multiline_string(_title_font if said else _italic, Vector2(BOOK.position.x + 40, BOOK.end.y - 40), foot,
			HORIZONTAL_ALIGNMENT_LEFT, w, 19, 2, Color("5b3a7a") if said else Color(0.35, 0.22, 0.1, 0.75))
	elif said:
		draw_string(_title_font, Vector2(BOOK.position.x, BOOK.end.y - 70), foot, HORIZONTAL_ALIGNMENT_CENTER, BOOK.size.x, 20, Color("5b3a7a"))
	else:
		draw_string(_italic, Vector2(BOOK.position.x, BOOK.end.y - 72), foot,
			HORIZONTAL_ALIGNMENT_CENTER, BOOK.size.x, 15, Color(0.35, 0.22, 0.1, 0.75))


func _draw_tree() -> void:
	var font := ThemeDB.fallback_font
	var t := Time.get_ticks_msec() / 1000.0
	var ink := Color(0.35, 0.22, 0.1, 0.55)
	# Ink lines between spells
	for n in nodes():
		if n.parent == "":
			continue
		var a := node_center(n.parent)
		var b := node_center(n.id)
		if n.has("side"):  # a theme: a twig from the trunk below the starting node
			a = Vector2(a.x, b.y)
		var learned: bool = game.skill_info(n.id).understood
		canvas.draw_dashed_line(a, b, Color("c99a3a") if learned else ink, 3.0, 10.0, true, true)
	# The trunk of the themes
	var top := node_center("themes")
	var lowest := top.y
	for n in nodes():
		if n.has("side"):
			lowest = maxf(lowest, node_center(n.id).y)
	canvas.draw_dashed_line(top, Vector2(top.x, lowest), Color("c99a3a"), 3.0, 10.0, true, true)
	# Spell medallions
	for n in nodes():
		var info: Dictionary = game.skill_info(n.id)
		var c := node_center(n.id)
		var ring := Color(0.45, 0.33, 0.22, 0.7)
		var fill := Color("e3cf9f")
		var icon_alpha := 0.45
		if info.understood:
			ring = Color("d9a441")
			fill = Color("f7e7b5")
			icon_alpha = 1.0
		if info.get("open", false):
			# Unlocked: shown straight away, also before you have the knowledge for it; it pulses once you have.
			ring = Color("4fae6a")
			icon_alpha = 1.0
			if info.can_buy:
				ring = ring.lerp(Color("9be3a3"), 0.5 + 0.5 * sin(t * 3.0))
				canvas.draw_circle(c, NODE_R + 9, Color(0.4, 0.85, 0.5, 0.18))
		if flash.has(n.id):
			canvas.draw_circle(c, NODE_R + 16, Color(1.0, 0.85, 0.3, 0.35 * flash[n.id]))
		if n.id == hover_id:
			canvas.draw_circle(c, NODE_R + 6, Color(1, 1, 1, 0.25))
		canvas.draw_circle(c, NODE_R, fill)
		canvas.draw_arc(c, NODE_R, 0.0, TAU, 48, ring, 4.0, true)
		canvas.draw_arc(c, NODE_R - 7, 0.0, TAU, 48, Color(ring, 0.35), 1.5, true)
		var fs := int(ScreenLayout.pick(34, 46))
		var baseline := (emoji_font.get_ascent(fs) - emoji_font.get_descent(fs)) * 0.5
		var art := MenuKit.drawing(n.icon)
		if art:
			canvas.draw_texture_rect(art, Rect2(c - Vector2.ONE * ScreenLayout.pick(22, 29), Vector2.ONE * ScreenLayout.pick(44, 58)), false, Color(1, 1, 1, icon_alpha))
		else:
			canvas.draw_string(emoji_font, c + Vector2(-40, baseline), n.icon,
				HORIZONTAL_ALIGNMENT_CENTER, 80, fs, Color(1, 1, 1, icon_alpha))
		if info.has("unspelled"):
			_draw_unspelled(c, info.unspelled, t)
			_draw_theme_tag(c, info.spell_theme)
		if info.has("stars"):  # all your stars, or the stars a spell still needs
			var mine: bool = n.id == "root"
			LevelStar.draw_star(canvas, c + Vector2(0, NODE_R + 21), 22.0 if mine else 19.0, info.stars,
				Color("ffd45c") if mine else Color("f3e0a8"))
		else:
			if info.has("label"):
				_draw_theme_label(c, n.get("side", 1), info)
			else:
				canvas.draw_string(font, c + Vector2(-90, NODE_R + 22), info.status_text,
					HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Color("4a2c17"))
		if n.id == hold_id:
			var frac := hold_t / HOLD_TIME
			canvas.draw_arc(c, NODE_R + 8, -PI / 2, -PI / 2 + TAU * frac, 48, Color("ffd45c"), 6.0, true)
	var wanted: String = game.book_points_at()
	if wanted != "" and hold_id != wanted:
		canvas.draw_string(emoji_font, node_center(wanted) + Vector2(-112 + 7.0 * sin(t * 5.0), 14), "👉", HORIZONTAL_ALIGNMENT_CENTER, 60, 38)
	if hover_id != "":
		_draw_tooltip(hover_id)


## A theme's name and price, beside its medallion.
func _draw_theme_label(c: Vector2, side: int, info: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var lines: PackedStringArray = String(info.label).replace(" & ", " &\n").split("\n")
	var w := 110.0
	var x := c.x + NODE_R + 9.0 if side > 0 else c.x - NODE_R - 9.0 - w
	var align := HORIZONTAL_ALIGNMENT_LEFT if side > 0 else HORIZONTAL_ALIGNMENT_RIGHT
	var y := c.y + 6.0 - lines.size() * 9.0
	for l in lines:
		canvas.draw_string(_label_font, Vector2(x, y), l, align, w, 16, Color("4a2c17"))
		y += 19.0
	canvas.draw_string(font, Vector2(x, y), info.status_text, align, w, 14, Color("8a5a1a"))


## An animal whose name was not spelled yet: greyed out, and the letters of its name float away from it.
func _draw_unspelled(c: Vector2, word: String, t: float) -> void:
	canvas.draw_circle(c, NODE_R + 1, Color(0.62, 0.6, 0.57, 0.55))
	var font := ThemeDB.fallback_font
	for i in word.length():
		var life := fmod(t * 0.28 + i * 0.618, 1.0)
		var side := (i / maxf(1.0, word.length() - 1.0) - 0.5) * 2.0  # -1 left ... 1 right
		var at := c + Vector2(side * (10.0 + 30.0 * life) + sin(t * 2.0 + i * 1.7) * 4.0, 6.0 - 58.0 * life)
		var alpha := sin(life * PI)
		canvas.draw_string_outline(font, at + Vector2(-20, 6), word[i], HORIZONTAL_ALIGNMENT_CENTER, 40, 19, 5, Color(1, 0.97, 0.88, 0.8 * alpha))
		canvas.draw_string(font, at + Vector2(-20, 6), word[i], HORIZONTAL_ALIGNMENT_CENTER, 40, 19, Color(0.36, 0.23, 0.48, alpha))


## A ribbon across it says in which theme its name can be spelled.
func _draw_theme_tag(c: Vector2, theme: String) -> void:
	var text := theme.get_slice(" & ", 0)
	var fs := 13
	var text_w := _label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := text_w + 32.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color("efe0ff")
	box.border_color = Color("7a5a9a")
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	var rect := Rect2(c + Vector2(-w * 0.5, 13), Vector2(w, 22))
	canvas.draw_style_box(box, rect)
	canvas.draw_string(emoji_font, rect.position + Vector2(5, 16), GameData.THEME_ICONS.get(theme, ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	canvas.draw_string(_label_font, rect.position + Vector2(25, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("4a2c6a"))


## How much of a spell's text is readable right now (0 to 1).
func reveal_of(id: String, info: Dictionary) -> float:
	if id == hold_id and not info.has("plain") and (info.can_buy or not info.understood):
		return hold_t / HOLD_TIME
	return 1.0 if info.understood or info.has("plain") else 0.0


func _draw_tooltip(id: String) -> void:
	var info: Dictionary = game.skill_info(id)
	var c := node_center(id)
	var reveal := reveal_of(id, info)
	var title := garble(info.title, reveal)
	var lines := _wrap(info.desc, 34)
	var w := 330.0
	var special := _wrap(info.get("special", ""), 38)  # how it is unlocked, if that is special: always readable
	var h := 64.0 + lines.size() * 22.0 + 30.0 + special.size() * 20.0 + (6.0 if not special.is_empty() else 0.0)
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
	var font := ThemeDB.fallback_font
	y += 4
	for l in special:
		canvas.draw_string(_label_font, Vector2(pos.x + 16, y), l, HORIZONTAL_ALIGNMENT_LEFT, w - 32, 15, Color("2f6b3f"))
		y += 20
	var at := Vector2(pos.x + 16, pos.y + h - 14)
	canvas.draw_string(font, at, info.hint, HORIZONTAL_ALIGNMENT_LEFT, w - 32, 15, Color("8a5a1a"))
	if info.has("need_stars"):
		at.x += font.get_string_size(info.hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 22.0
		LevelStar.draw_star(canvas, at + Vector2(0, -6), 16.0, info.need_stars, Color("f3e0a8"))
		at.x += 24.0
		canvas.draw_string(font, at, "you have", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("8a5a1a"))
		at.x += font.get_string_size("you have", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 22.0
		LevelStar.draw_star(canvas, at + Vector2(0, -6), 16.0, game.total_stars())


## Also beside the 1280 x 720 on a wider screen: nothing behind it can be touched.
func _has_point(point: Vector2) -> bool:
	return ScreenLayout.rect().has_point(point)
