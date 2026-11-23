extends Node2D

## Spell Cauldron - rough prototype.
## Everything is drawn with simple shapes so we can test how the game feels
## before spending time on art.

const BREW_GREEN := Color("63c56f")
const BREW_GOLD := Color("ffd45c")
const BREW_MURKY := Color("6b4f7a")

const WORD_CENTER := Vector2(640, 300)
const WORD_MAX_WIDTH := 900.0
const WORD_STEP := LetterTile.BUBBLE_RADIUS * 2.0 + 8.0
const TABLE_Y := 655.0
const TABLE_STEP := 86.0
const DROP_RADIUS := 64.0
const BREW_CENTER := Vector2(640, 380)   ## middle of the soup, seen from above
const BREW_RADIUS := Vector2(290, 115)
const PICTURE_CENTER := Vector2(640, 425)
const ENGRAVING_Y := 560.0
const STIR_SWIPE := 150.0  ## how far left (pixels) you swipe over the brew to stir

var level := 1
var word_number := 0
var session_words: Array = []
var puzzle: Dictionary = {}
var round_id := 0  ## changes every new word, so old animations know to stop

var row: Array[Node2D] = []        ## the word in the cauldron, left to right
var tiles: Array[LetterTile] = []  ## every movable letter (on table or placed)
var row_step := WORD_STEP
var row_scale := 1.0

var dragged: LetterTile = null
var drag_offset := Vector2.ZERO
var busy := false
var hint_count := 0

var stirring := false
var stir_start := Vector2.ZERO
var stir_last_x := 0.0
var swirl_angle := 0.0:
	set(value):
		swirl_angle = value
		queue_redraw()
var brew_color: Color = BREW_GREEN:
	set(value):
		brew_color = value
		if bubbles:
			bubbles.color = value.lightened(0.35)
		queue_redraw()

var pieces: Node2D
var insert_marker: Marker
var hint_marker: Marker
var hint_tween: Tween
var swirl_tween: Tween
var bubbles: CPUParticles2D
var sparkles: CPUParticles2D
var smoke: CPUParticles2D

var picture_alpha := 0.0  ## how clear the picture in the brew is: 0 = hidden, 1 = sharp
var picture_tween: Tween

## Potion stock. Earned by brewing words, spent on the Wisdom / Vision buttons.
var potions := {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
var wisdom_level := 0      ## Wisdom potions drunk for this word (max _reveal_steps())
var wisdom_order: Array = []  ## order in which the meaning's words get revealed
var vision_level := 0      ## Vision potions drunk for this word (max _reveal_steps())

## Level score (out of 100): each word is worth 10 points. Drinking any Vision potion
## on a word removes 5, drinking any Wisdom potion removes 5. 100 = conquered.
const WORD_POINTS := 10
const HELP_PENALTY := 5
var level_points := 0      ## points earned so far in the current level run
var level_records := {}    ## level -> {"best": int, "conquered": bool}
var level_stars: Array[LevelStar] = []
const SAVE_PATH := "user://save.cfg"
var persist := true        ## false in tests, so they never touch the player's save
var incoming := {}         ## kind -> reward potions still flying to their shelf
var shelves := {}          ## kind -> PotionShelf
var potion_buttons := {}   ## kind -> Button
var emoji_font: SystemFont
var engrave_font: FontVariation
var spoon: Spoon

var progress_label: Label
var thought: ThoughtCloud   ## the Wisdom hint, floating above the cauldron
var score_label: Label

const START_SLOTS := 3        ## potions of one kind a shelf holds at first
const MAX_SLOTS := 10         ## the most a shelf can be upgraded to
const POINTS_PER_POTION := 10 ## every potion earned beyond a full shelf becomes points
var shelf_slots := {PotionArt.WISDOM: START_SLOTS, PotionArt.VISION: START_SLOTS}
var shop_panel: SpellBook     ## the Shelves menu: a spell book with a skill tree

## Star upgrades: unlocked by your total level stars (sum of best stars, max 1000),
## then bought with score points in the Shelves menu.
const UPGRADES := [
	{"id": "discount", "name": "Potion discount", "stars": 200, "price": 100,
		"desc": "Every drink costs 1 potion less (never below 1)."},
	{"id": "familiar", "name": "Owl familiar", "stars": 500, "price": 150,
		"desc": "Places one right letter every 10 seconds.\nCounts as help: -5 on that word."},
	{"id": "lucky", "name": "Lucky cauldron", "stars": 800, "price": 250,
		"desc": "Every brewed word gives 1 extra potion."},
]
const FAMILIAR_INTERVAL := 10.0
const FAMILIAR_POS := Vector2(232, 470)
var owned_upgrades := {}      ## upgrade id -> true
var familiar_on := true       ## the owl can be switched off for a perfect run
var familiar_time := 0.0
var familiar_helped := false  ## the owl placed a letter in this word
const WHERE_COST := 1         ## Where? costs this many Wisdom AND Vision potions
var where_paid := false       ## Where? already paid for this word
var where_button: Button
var auto_done := {}           ## hidden-gap words: missing index -> placed by the owl
var score := 0
var score_incoming := 0       ## points still flying to the score counter
var level_buttons: Array[Button] = []
var complete_panel: PanelContainer
var complete_label: Label
var next_level_button: Button


func _ready() -> void:
	var dot := _make_soft_circle(32)
	bubbles = _make_bubbles(dot)
	pieces = Node2D.new()
	add_child(pieces)
	insert_marker = Marker.new()
	insert_marker.kind = Marker.INSERT
	insert_marker.color = Color(1, 0.95, 0.75, 0.95)
	insert_marker.visible = false
	add_child(insert_marker)
	hint_marker = Marker.new()
	hint_marker.color = BREW_GOLD
	hint_marker.visible = false
	add_child(hint_marker)
	sparkles = _make_sparkles(dot)
	smoke = _make_smoke(dot)
	spoon = Spoon.new()
	spoon.visible = false
	add_child(spoon)
	emoji_font = SystemFont.new()
	emoji_font.font_names = PackedStringArray(["Segoe UI Emoji", "Apple Color Emoji", "Noto Color Emoji"])
	engrave_font = FontVariation.new()
	engrave_font.base_font = ThemeDB.fallback_font
	engrave_font.variation_embolden = 0.9
	engrave_font.spacing_glyph = 4
	_load_game()
	_build_ui()
	_start_level(1)


func _process(delta: float) -> void:
	queue_redraw()  # keeps the brew, picture and engraving alive
	if stirring:
		spoon.position = get_global_mouse_position()
	if _familiar_working():
		familiar_time += delta
		if familiar_time >= FAMILIAR_INTERVAL:
			familiar_time = 0.0
			_familiar_place()


# ---------------------------------------------------------------- Ctrl / Alt shortcuts

## Ctrl+click (fill = true) fills up or completes the value under the mouse;
## Alt+click (fill = false) removes its progress. Returns true if something was hit.
func _cheat_click(p: Vector2, fill: bool) -> bool:
	var hit := false
	if shop_panel.visible:
		# Spell book: shelf spells, upgrade spells, and the cauldron in the middle (all stars).
		var id := shop_panel.node_at(p)
		if id == "root":
			for n in range(1, GameData.LEVELS.size() + 1):
				if fill:
					level_records[n] = {"best": 100, "conquered": true}
				else:
					level_records.erase(n)
			hit = true
		elif id == "wisdom_shelf" or id == "vision_shelf":
			var kind := PotionArt.WISDOM if id == "wisdom_shelf" else PotionArt.VISION
			shelf_slots[kind] = MAX_SLOTS if fill else START_SLOTS
			potions[kind] = mini(potions[kind], shelf_slots[kind])
			hit = true
		elif id != "":
			if fill:
				owned_upgrades[id] = true
			else:
				owned_upgrades.erase(id)
			hit = true
	else:
		# Level stars (the whole column: button + star).
		for i in level_stars.size():
			if (level_stars[i].get_parent() as Control).get_global_rect().has_point(p):
				if fill:
					level_records[i + 1] = {"best": 100, "conquered": true}
				else:
					level_records.erase(i + 1)
				hit = true
		# Potion rows: the shelf of flasks and its button.
		for kind in shelves:
			if ((shelves[kind] as Control).get_parent() as Control).get_global_rect().has_point(p):
				potions[kind] = shelf_slots[kind] if fill else 0
				incoming[kind] = 0
				hit = true
		if score_label.get_global_rect().has_point(p):
			score = score + 1000 if fill else 0
			score_incoming = 0
			hit = true
		if progress_label.get_global_rect().has_point(p) and not complete_panel.visible:
			if fill:
				level_points = level_max()
				_show_level_complete()  # finish the level with full marks
			else:
				_start_level(level)  # start the level over
			hit = true
	if not hit:
		return false
	var fx := sparkles if fill else smoke
	fx.position = p
	_burst(fx)
	_save_game()
	_update_level_stars()
	_update_potion_ui()
	if shop_panel.visible:
		_update_shop()
	return true


# ---------------------------------------------------------------- owl familiar

func _has_familiar() -> bool:
	return owned_upgrades.has("familiar") and familiar_on


func _familiar_working() -> bool:
	return _has_familiar() and not puzzle.is_empty() and not busy and dragged == null \
		and not stirring and not complete_panel.visible and not shop_panel.visible \
		and _familiar_next_index() >= 0


## The next missing letter the owl would place, or -1 if there is nothing to do.
func _familiar_next_index() -> int:
	var word: String = puzzle.word
	for i in puzzle.missing:
		if puzzle.gaps_visible:
			var slot := _slot_for(i)
			if slot and not (slot.tile and slot.tile.letter == word[i]):
				return i
		elif not auto_done.has(i):
			return i
	return -1


func _slot_for(index: int) -> GapSlot:
	for item in row:
		var slot := item as GapSlot
		if slot and slot.index == index:
			return slot
	return null


## Puts one right letter into its right place.
func _familiar_place() -> void:
	var idx := _familiar_next_index()
	if idx < 0:
		return
	var word: String = puzzle.word
	var letter := word[idx]
	# Prefer a matching letter still on the table; otherwise move one the player placed.
	var t: LetterTile = null
	for tile in tiles:
		if tile.letter == letter and not tile.in_word:
			t = tile
			break
	if t == null:
		for tile in tiles:
			if tile.letter == letter and not tile.has_meta("auto"):
				t = tile
				break
	if t == null:
		return
	_take_out_of_word(t)
	if puzzle.gaps_visible:
		var slot := _slot_for(idx)
		if slot.tile:
			_send_home(slot.tile)
		slot.tile = t
	else:
		# Insert before the first fixed letter (or owl letter) that comes later in the word.
		var fixed_indices: Array = []
		for i in word.length():
			if not (i in puzzle.missing):
				fixed_indices.append(i)
		var pos := row.size()
		var k := 0
		for p in row.size():
			var lt := row[p] as LetterTile
			if lt == null:
				continue
			if not lt.movable:
				if int(fixed_indices[k]) > idx:
					pos = p
					break
				k += 1
			elif lt.has_meta("auto") and int(lt.get_meta("auto")) > idx:
				pos = p
				break
		row.insert(pos, t)
		auto_done[idx] = true
	t.set_meta("auto", idx)
	t.in_word = true
	familiar_helped = true
	_layout_row(true)
	sparkles.position = _target_of(t)
	_burst(sparkles)


func _forget_auto(t: LetterTile) -> void:
	if t.has_meta("auto"):
		auto_done.erase(int(t.get_meta("auto")))
		t.remove_meta("auto")


# ---------------------------------------------------------------- levels & words

func _start_level(n: int) -> void:
	level = n
	for i in level_buttons.size():
		level_buttons[i].set_pressed_no_signal(i + 1 == level)
	var settings: Dictionary = GameData.LEVELS[level - 1]
	session_words = _pick_words(settings)
	word_number = 0
	level_points = 0
	complete_panel.visible = false
	_start_word()


func _pick_words(settings: Dictionary) -> Array:
	var min_len: int = settings.min_len
	var max_len: int = settings.max_len
	var pool: Array = []
	for e in GameData.WORDS:
		var l := String(e[0]).length()
		if l >= min_len and l <= max_len:
			pool.append(e)
	pool.shuffle()
	var out: Array = []
	while out.size() < GameData.WORDS_PER_LEVEL:
		out.append(pool[out.size() % pool.size()])
	return out


func _start_word() -> void:
	round_id += 1
	busy = false
	dragged = null
	_stop_stirring()
	if swirl_tween:
		swirl_tween.kill()
	for c in pieces.get_children():
		c.queue_free()
	row.clear()
	tiles.clear()
	hint_count = 0
	hint_marker.visible = false
	insert_marker.visible = false
	thought.hide_thought()
	brew_color = BREW_GREEN

	puzzle = PuzzleMaker.make(session_words[word_number], GameData.LEVELS[level - 1])
	var word: String = puzzle.word
	var missing: Array = puzzle.missing
	var gaps_visible: bool = puzzle.gaps_visible

	for i in word.length():
		if i in missing:
			if gaps_visible:
				var slot := GapSlot.new()
				slot.index = i
				pieces.add_child(slot)
				row.append(slot)
		else:
			var f := LetterTile.new(word[i], false)
			pieces.add_child(f)
			row.append(f)
	_layout_row(false)
	for i in row.size():
		var item := row[i]
		var s := item.scale
		item.scale = Vector2.ZERO
		var tw := item.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(i * 0.04)
		tw.tween_property(item, "scale", s, 0.3)

	var letters: Array = puzzle.tiles
	var start_x := 640.0 - TABLE_STEP * (letters.size() - 1) / 2.0
	for i in letters.size():
		var t := LetterTile.new(letters[i], true)
		t.home_position = Vector2(start_x + i * TABLE_STEP, TABLE_Y + randf_range(-8, 8))
		t.home_rotation = randf_range(-0.15, 0.15)
		t.position = t.home_position
		t.rotation = t.home_rotation
		t.scale = Vector2.ZERO
		pieces.add_child(t)
		tiles.append(t)
		_tween_node(t, t.home_position, 1.0, t.home_rotation, 0.3)

	progress_label.text = "Word %d / %d" % [word_number + 1, GameData.WORDS_PER_LEVEL]

	# The picture stays hidden until a Vision potion is drunk.
	if picture_tween:
		picture_tween.kill()
	picture_alpha = 0.0
	vision_level = 0
	wisdom_level = 0
	wisdom_order = []
	familiar_time = 0.0
	familiar_helped = false
	where_paid = false
	auto_done = {}
	_update_potion_ui()


func _next_word() -> void:
	word_number += 1
	if word_number >= GameData.WORDS_PER_LEVEL:
		_show_level_complete()
	else:
		_start_word()


func _show_level_complete() -> void:
	busy = true
	# Record this run's points under the level's star. Perfect = every reward potion became points.
	var rec: Dictionary = level_records.get(level, {"best": 0, "conquered": false})
	var was_conquered: bool = rec.conquered
	var level_max_points := level_max()
	var perfect := level_points >= level_max_points
	rec.best = maxi(int(rec.best), level_points)
	rec.conquered = was_conquered or perfect
	level_records[level] = rec
	_save_game()
	_update_level_stars()
	var text := "Level %d complete!\nPoints: %d / %d" % [level, level_points, level_max_points]
	if was_conquered:
		text += "\nAlready conquered!"
	elif perfect:
		text += "\nPerfect - level conquered!"
	complete_label.text = text
	next_level_button.visible = level < GameData.LEVELS.size()
	complete_panel.visible = true
	sparkles.position = Vector2(640, 360)
	_burst(sparkles)


# ---------------------------------------------------------------- word layout

func _layout_row(animated: bool) -> void:
	var n := row.size()
	if n == 0:
		return
	row_step = minf(WORD_STEP, WORD_MAX_WIDTH / n)
	row_scale = row_step / WORD_STEP
	var start_x := WORD_CENTER.x - row_step * (n - 1) / 2.0
	for i in n:
		var item := row[i]
		var pos := Vector2(start_x + i * row_step, WORD_CENTER.y)
		item.set_meta("target", pos)
		_place(item, pos, animated)
		var slot := item as GapSlot
		if slot and slot.tile:
			_place(slot.tile, pos, animated)


func _place(node: Node2D, pos: Vector2, animated: bool) -> void:
	if animated:
		_tween_node(node, pos, row_scale, 0.0, 0.18)
	else:
		_kill_tween(node)
		node.position = pos
		node.scale = Vector2.ONE * row_scale
		node.rotation = 0.0


func _target_of(node: Node2D) -> Vector2:
	return node.get_meta("target", node.position)


func _tween_node(node: Node2D, pos: Vector2, scl: float, rot: float, duration: float) -> void:
	_kill_tween(node)
	var tw := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", pos, duration)
	tw.tween_property(node, "scale", Vector2.ONE * scl, duration)
	tw.tween_property(node, "rotation", rot, duration)
	node.set_meta("tween", tw)


func _kill_tween(node: Node2D) -> void:
	if node.has_meta("tween"):
		var old: Tween = node.get_meta("tween")
		if old and old.is_valid():
			old.kill()
		node.remove_meta("tween")


func _spelling() -> String:
	var s := ""
	for item in row:
		var slot := item as GapSlot
		if slot:
			s += slot.tile.letter if slot.tile else "_"
		else:
			s += (item as LetterTile).letter
	return s


func _word_filled() -> bool:
	var word: String = puzzle.word
	if puzzle.gaps_visible:
		return not _spelling().contains("_")
	return row.size() >= word.length()


# ---------------------------------------------------------------- input: drag & stir

func _unhandled_input(event: InputEvent) -> void:
	if busy or complete_panel.visible or shop_panel.visible:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var p := get_global_mouse_position()
		var t := _tile_at(p)
		if t:
			_begin_drag(t, p)
			get_viewport().set_input_as_handled()
		elif _on_brew(p):
			_start_stir(p)


func _start_stir(p: Vector2) -> void:
	stirring = true
	stir_start = p
	stir_last_x = p.x
	spoon.position = p
	spoon.visible = true


## Is the point over the liquid in the pot?
func _on_brew(p: Vector2) -> bool:
	var d := p - BREW_CENTER
	return pow(d.x / (BREW_RADIUS.x + 20.0), 2) + pow(d.y / (BREW_RADIUS.y + 30.0), 2) <= 1.0


func _input(event: InputEvent) -> void:
	# Ctrl+click fills up / completes a value, Alt+click removes its progress.
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
			and (click.ctrl_pressed or click.alt_pressed) and dragged == null:
		if _cheat_click(get_global_mouse_position(), click.ctrl_pressed):
			get_viewport().set_input_as_handled()
			return
	if dragged == null and not stirring:
		return
	var p := get_global_mouse_position()
	if event is InputEventMouseMotion:
		if dragged:
			_drag_to(p)
		else:
			_stir_motion(p)
	else:
		var mb := event as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if dragged:
				_drop()
			_stop_stirring()


func _stop_stirring() -> void:
	stirring = false
	if spoon:
		spoon.visible = false


func _tile_at(p: Vector2) -> LetterTile:
	for i in range(tiles.size() - 1, -1, -1):
		if tiles[i].contains_point(p):
			return tiles[i]
	return null


func _in_cauldron(p: Vector2) -> bool:
	var d := p - BREW_CENTER
	return pow(d.x / 330.0, 2) + pow(d.y / 165.0, 2) <= 1.0


func _begin_drag(t: LetterTile, p: Vector2) -> void:
	_take_out_of_word(t)
	dragged = t
	drag_offset = t.position - p
	_kill_tween(t)
	t.scale = Vector2.ONE * 1.12
	t.rotation = 0.0
	pieces.move_child(t, -1)
	tiles.erase(t)
	tiles.append(t)
	hint_marker.visible = false
	_layout_row(true)


func _drag_to(p: Vector2) -> void:
	dragged.position = p + drag_offset
	var c := dragged.position
	if puzzle.gaps_visible:
		var target := _nearest_slot(c)
		for item in row:
			var slot := item as GapSlot
			if slot:
				slot.glow = slot == target
	elif _over_word(c):
		insert_marker.position = Vector2(_insert_x(_insert_index(c.x)), WORD_CENTER.y)
		insert_marker.scale = Vector2.ONE * row_scale
		insert_marker.visible = true
	else:
		insert_marker.visible = false


func _drop() -> void:
	var t := dragged
	dragged = null
	insert_marker.visible = false
	var c := t.position
	var placed := false
	if puzzle.gaps_visible:
		var slot := _nearest_slot(c)
		for item in row:
			var s := item as GapSlot
			if s:
				s.glow = false
		if slot:
			if slot.tile:
				_send_home(slot.tile)
			slot.tile = t
			placed = true
	elif _over_word(c):
		row.insert(_insert_index(c.x), t)
		placed = true
	if placed:
		t.in_word = true
	else:
		_send_home(t)
	_layout_row(true)


func _take_out_of_word(t: LetterTile) -> void:
	for item in row:
		var slot := item as GapSlot
		if slot and slot.tile == t:
			slot.tile = null
	row.erase(t)
	t.in_word = false
	_forget_auto(t)


func _send_home(t: LetterTile) -> void:
	t.in_word = false
	_forget_auto(t)
	_tween_node(t, t.home_position, 1.0, t.home_rotation, 0.3)


func _nearest_slot(c: Vector2) -> GapSlot:
	var best: GapSlot = null
	var best_d := DROP_RADIUS
	for item in row:
		var slot := item as GapSlot
		if slot:
			var d := c.distance_to(_target_of(slot))
			if d < best_d:
				best_d = d
				best = slot
	return best


func _over_word(c: Vector2) -> bool:
	if row.is_empty():
		return absf(c.y - WORD_CENTER.y) < 80.0
	var left := _target_of(row[0]).x - 100.0
	var right := _target_of(row[-1]).x + 100.0
	return absf(c.y - WORD_CENTER.y) < 80.0 and c.x > left and c.x < right


func _insert_index(x: float) -> int:
	var idx := 0
	for item in row:
		if _target_of(item).x < x:
			idx += 1
	return idx


func _insert_x(idx: int) -> float:
	if row.is_empty():
		return WORD_CENTER.x
	if idx <= 0:
		return _target_of(row[0]).x - row_step * 0.5
	if idx >= row.size():
		return _target_of(row[-1]).x + row_step * 0.5
	return (_target_of(row[idx - 1]).x + _target_of(row[idx]).x) * 0.5


## Stirring = one swipe to the left across the brew.
func _stir_motion(p: Vector2) -> void:
	swirl_angle += (p.x - stir_last_x) * 0.012  # the soup swirls along with the spoon
	stir_last_x = p.x
	if stir_start.x - p.x >= STIR_SWIPE and _on_brew(p):
		_stop_stirring()
		_stir()


# ---------------------------------------------------------------- stirring & brewing

func _stir() -> void:
	if busy or complete_panel.visible:
		return
	busy = true
	hint_marker.visible = false
	var id := round_id
	await _swirl_letters()
	if id != round_id:
		return
	if not _word_filled():
		busy = false  # just a swirl; the engraving still says how many letters are missing
		return
	if _spelling() == puzzle.word:
		await _brew_success()
		if id != round_id:
			return
		_next_word()
	else:
		await _brew_fail()
		if id != round_id:
			return
		busy = false


func _swirl_letters() -> void:
	var homes: Array[Vector2] = []
	for item in row:
		_kill_tween(item)
		homes.append(_target_of(item))
		var slot := item as GapSlot
		if slot and slot.tile:
			_kill_tween(slot.tile)
	var start_angle := swirl_angle
	swirl_tween = create_tween()
	swirl_tween.tween_method(_swirl_step.bind(homes, start_angle), 0.0, 1.0, 1.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await swirl_tween.finished


func _swirl_step(t: float, homes: Array[Vector2], start_angle: float) -> void:
	var n := row.size()
	if n != homes.size():
		return
	var w := sin(t * PI)  # 0 at start and end, so letters always settle back in place
	for i in n:
		var a := TAU * i / n + t * TAU * 1.5
		var orbit := BREW_CENTER + Vector2(cos(a) * 220.0, sin(a) * 75.0 - 20.0)
		var pos := homes[i].lerp(orbit, w)
		row[i].position = pos
		var slot := row[i] as GapSlot
		if slot and slot.tile:
			slot.tile.position = pos
	swirl_angle = start_angle + t * TAU * 1.5


func _brew_success() -> void:
	sparkles.position = WORD_CENTER
	_burst(sparkles)
	var tw := create_tween()
	tw.tween_property(self, "brew_color", BREW_GOLD, 0.3)
	# The picture in the brew becomes sharp and clear.
	if picture_tween:
		picture_tween.kill()
	picture_tween = create_tween()
	picture_tween.tween_property(self, "picture_alpha", 1.0, 0.5)
	level_points += word_score()
	_award_potions()
	for i in row.size():
		var node: Node2D = row[i]
		var slot := node as GapSlot
		if slot:
			node = slot.tile
		var b := node.create_tween()
		b.tween_interval(i * 0.06)
		b.tween_property(node, "scale", Vector2.ONE * row_scale * 1.3, 0.15)
		b.tween_property(node, "scale", Vector2.ONE * row_scale, 0.2)
		b.parallel().tween_property(node, "modulate", Color(1, 0.92, 0.55), 0.2)
	await get_tree().create_timer(1.8).timeout


func _brew_fail() -> void:
	smoke.position = BREW_CENTER
	_burst(smoke)
	var tw := create_tween()
	tw.tween_property(self, "brew_color", BREW_MURKY, 0.25)
	tw.tween_interval(0.6)
	tw.tween_property(self, "brew_color", BREW_GREEN, 0.6)
	var shake := pieces.create_tween()
	for k in 6:
		shake.tween_property(pieces, "position", Vector2(10.0 if k % 2 == 0 else -10.0, 0), 0.05)
	shake.tween_property(pieces, "position", Vector2.ZERO, 0.05)
	await shake.finished
	# Wrong letters hop back to the table.
	var word: String = puzzle.word
	if puzzle.gaps_visible:
		for item in row:
			var slot := item as GapSlot
			if slot and slot.tile and slot.tile.letter != word[slot.index]:
				_send_home(slot.tile)
				slot.tile = null
	else:
		for t in tiles:
			if t.in_word:
				row.erase(t)
				_send_home(t)
	_layout_row(true)
	await get_tree().create_timer(0.4).timeout


# ---------------------------------------------------------------- hints

## Hidden gaps: the letters on each side of the spot slide apart for a moment.
func _push_letters_apart(x: float) -> void:
	for item in row:
		var home := _target_of(item)
		var dir := 1.0 if home.x > x else -1.0
		_kill_tween(item)
		var tw := item.create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(item, "position", home + Vector2(dir * 26.0 * row_scale, 0), 0.3)
		tw.tween_interval(2.0)
		tw.tween_property(item, "position", home, 0.4)
		item.set_meta("tween", tw)


func _show_where_hint() -> void:
	if busy or complete_panel.visible:
		return
	var word: String = puzzle.word
	var missing: Array = puzzle.missing
	var pos := WORD_CENTER

	if puzzle.gaps_visible:
		# Point at a gap that isn't correctly filled yet, cycling on each press.
		var open: Array[GapSlot] = []
		for item in row:
			var slot := item as GapSlot
			if slot and not (slot.tile and slot.tile.letter == word[slot.index]):
				open.append(slot)
		if open.is_empty():
			return  # all correct; the engraving already says "STIR THE POT!"
		var target := open[hint_count % open.size()]
		pos = _target_of(target)
		hint_marker.kind = Marker.HINT_BOX
	else:
		# Show the spot between the fixed letters where a missing letter belongs.
		var idx: int = missing[hint_count % missing.size()]
		var fixed: Array[Node2D] = []
		for item in row:
			var lt := item as LetterTile
			if lt and not lt.movable:
				fixed.append(lt)
		var before := 0
		for i in idx:
			if not (i in missing):
				before += 1
		var x: float
		if before == 0:
			x = _target_of(fixed[0]).x - row_step * 0.5
		elif before >= fixed.size():
			x = _target_of(fixed[-1]).x + row_step * 0.5
		else:
			x = (_target_of(fixed[before - 1]).x + _target_of(fixed[before]).x) * 0.5
		pos = Vector2(x, WORD_CENTER.y)
		hint_marker.kind = Marker.HINT_BAR

	# Costs 1 Wisdom + 1 Vision potion, once per word (then it cycles for free).
	if not where_paid:
		if potions[PotionArt.WISDOM] < WHERE_COST or potions[PotionArt.VISION] < WHERE_COST:
			return
		potions[PotionArt.WISDOM] -= WHERE_COST
		potions[PotionArt.VISION] -= WHERE_COST
		where_paid = true
		_save_game()
		_update_potion_ui()
	hint_count += 1
	if not puzzle.gaps_visible:
		_push_letters_apart(pos.x)

	hint_marker.position = pos
	hint_marker.scale = Vector2.ONE * row_scale
	hint_marker.queue_redraw()
	hint_marker.visible = true
	if hint_tween:
		hint_tween.kill()
	hint_marker.modulate.a = 1.0
	hint_tween = create_tween().set_loops(3)
	hint_tween.tween_property(hint_marker, "modulate:a", 0.25, 0.4)
	hint_tween.tween_property(hint_marker, "modulate:a", 1.0, 0.4)
	hint_tween.finished.connect(func() -> void: hint_marker.visible = false)


# ---------------------------------------------------------------- potions

## Potions it costs to drink one, by difficulty: 1,1,1,2,2,2,3,3,3,4.
func _potion_cost() -> int:
	var cost := 1 + (level - 1) / 3
	if owned_upgrades.has("discount"):
		cost -= 1
	return maxi(1, cost)


## Potions earned for brewing a word: bigger words give more (1-4), +1 with Lucky cauldron.
func _potion_reward() -> int:
	return _reward_for(puzzle.word) + (1 if owned_upgrades.has("lucky") else 0)


func _reward_for(word: String) -> int:
	var n := word.length()
	if n <= 4:
		return 1
	if n <= 6:
		return 2
	if n <= 9:
		return 3
	return 4


## How many potions it takes to learn everything. Easier levels reveal more per potion.
func _reveal_steps() -> int:
	if level <= 3:
		return 2
	if level <= 6:
		return 3
	return 4


## Picture clarity after each Vision potion; the last step is always the clearest (0.85).
func _vision_clarity(step: int) -> float:
	return 0.85 * pow(float(step) / _reveal_steps(), 0.8)


func _drink_wisdom() -> void:
	if complete_panel.visible:
		return
	if wisdom_level >= _reveal_steps():
		thought.toggle()  # already know it all: reopen for free
		return
	if not _pay(PotionArt.WISDOM):
		return
	wisdom_level += 1
	thought.show_text(_meaning_snippet())
	_update_potion_ui()


## The meaning with only some words revealed; hidden stretches become "…".
## Each Wisdom potion reveals more, longer (more useful) words first.
func _meaning_snippet() -> String:
	var words: PackedStringArray = String(puzzle.meaning).split(" ", false)
	if wisdom_order.size() != words.size():
		var long: Array = []
		var short: Array = []
		for i in words.size():
			(long if words[i].length() > 3 else short).append(i)
		long.shuffle()
		short.shuffle()
		wisdom_order = long + short
	var count := ceili(words.size() * float(wisdom_level) / _reveal_steps())
	var shown := {}
	for i in count:
		shown[wisdom_order[i]] = true
	var parts: Array = []
	for i in words.size():
		if shown.has(i):
			parts.append(words[i])
		elif parts.is_empty() or parts[-1] != "…":
			parts.append("…")
	return " ".join(parts)


func _drink_vision() -> void:
	if complete_panel.visible or vision_level >= _reveal_steps():
		return
	if not _pay(PotionArt.VISION):
		return
	vision_level += 1
	if picture_tween:
		picture_tween.kill()
	picture_tween = create_tween()
	picture_tween.tween_property(self, "picture_alpha", _vision_clarity(vision_level), 1.5) \
		.set_trans(Tween.TRANS_SINE)
	_update_potion_ui()


func _pay(kind: String) -> bool:
	var cost := _potion_cost()
	if potions[kind] < cost:
		return false
	potions[kind] -= cost
	_save_game()
	return true


## Potions are kept between play sessions in the player's save file.
func _load_game() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # first time playing: keep the starting potions
	for kind in potions.keys():
		potions[kind] = int(cfg.get_value("potions", kind, potions[kind]))
	score = int(cfg.get_value("progress", "score", 0))
	for kind in shelf_slots.keys():
		shelf_slots[kind] = clampi(int(cfg.get_value("shelves", kind, START_SLOTS)), START_SLOTS, MAX_SLOTS)
	for u in UPGRADES:
		if bool(cfg.get_value("upgrades", u.id, false)):
			owned_upgrades[u.id] = true
	familiar_on = bool(cfg.get_value("upgrades", "familiar_on", true))
	# Level stars use the out-of-100 scoring ("stars" section; older "levels" data is ignored).
	for n in range(1, GameData.LEVELS.size() + 1):
		if cfg.has_section_key("stars", "best_%d" % n):
			level_records[n] = {
				"best": int(cfg.get_value("stars", "best_%d" % n, 0)),
				"conquered": bool(cfg.get_value("stars", "conquered_%d" % n, false)),
			}
	# More potions than shelf space (e.g. from an older save): the extra becomes points.
	for kind in potions.keys():
		if potions[kind] > shelf_slots[kind]:
			score += (potions[kind] - shelf_slots[kind]) * POINTS_PER_POTION
			potions[kind] = shelf_slots[kind]
	_save_game()


func _save_game() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	for kind in potions.keys():
		cfg.set_value("potions", kind, potions[kind])
	cfg.set_value("progress", "score", score)
	for kind in shelf_slots:
		cfg.set_value("shelves", kind, shelf_slots[kind])
	for id in owned_upgrades:
		cfg.set_value("upgrades", id, true)
	cfg.set_value("upgrades", "familiar_on", familiar_on)
	for n in level_records:
		cfg.set_value("stars", "best_%d" % n, level_records[n].best)
		cfg.set_value("stars", "conquered_%d" % n, level_records[n].conquered)
	cfg.save(SAVE_PATH)


func _award_potions() -> void:
	var kinds := [PotionArt.WISDOM, PotionArt.VISION]
	for i in _potion_reward():
		var kind: String = kinds[randi() % 2]
		var fly := FlyingPotion.new()
		fly.liquid = PotionArt.COLORS[kind]
		fly.position = WORD_CENTER + Vector2(randf_range(-60, 60), 0)
		fly.scale = Vector2.ONE * 1.6
		add_child(fly)
		var tw := fly.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(0.25 + i * 0.18)
		tw.tween_property(fly, "position", fly.position + Vector2(0, -90), 0.3)
		# Count (and save) right away; the shelf / score only shows it once it lands.
		if potions[kind] < shelf_slots[kind]:
			potions[kind] += 1
			incoming[kind] = incoming.get(kind, 0) + 1
			var shelf: PotionShelf = shelves[kind]
			tw.tween_property(fly, "position", shelf.slot_global_position(potions[kind] - 1), 0.55)
			tw.parallel().tween_property(fly, "scale", Vector2.ONE, 0.55)
			tw.tween_callback(func() -> void:
				incoming[kind] -= 1
				_update_potion_ui()
				fly.queue_free())
		else:
			# Shelf is full: this potion turns into points.
			score += POINTS_PER_POTION
			score_incoming += POINTS_PER_POTION
			var target := score_label.global_position + score_label.size * 0.5
			tw.tween_property(fly, "position", target, 0.55)
			tw.parallel().tween_property(fly, "scale", Vector2.ONE * 0.6, 0.55)
			tw.tween_callback(func() -> void:
				score_incoming -= POINTS_PER_POTION
				_update_potion_ui()
				_pop_score()
				fly.queue_free())
	_save_game()
	_update_potion_ui()


## Points for the current level run: what you earned minus what you drank, never below 0.
func level_max() -> int:
	return GameData.WORDS_PER_LEVEL * WORD_POINTS


## Points for the word just brewed: 10, minus 5 if Vision was used, minus 5 if Wisdom was used.
func word_score() -> int:
	var pts := WORD_POINTS
	if vision_level > 0:
		pts -= HELP_PENALTY
	if wisdom_level > 0:
		pts -= HELP_PENALTY
	if familiar_helped or where_paid:
		pts -= HELP_PENALTY
	return maxi(0, pts)


func _update_level_stars() -> void:
	for i in level_stars.size():
		var n := i + 1
		if level_records.has(n):
			var rec: Dictionary = level_records[n]
			level_stars[i].set_record(true, int(rec.best), bool(rec.conquered))
		else:
			level_stars[i].set_record(false, 0, false)


func _pop_score() -> void:
	score_label.pivot_offset = score_label.size * 0.5
	var tw := score_label.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(score_label, "scale", Vector2.ONE * 1.35, 0.1)
	tw.tween_property(score_label, "scale", Vector2.ONE, 0.25)


func _update_potion_ui() -> void:
	if shelves.is_empty():
		return
	var cost := _potion_cost()
	for kind in shelves:
		var shelf := shelves[kind] as PotionShelf
		shelf.capacity = shelf_slots[kind]
		shelf.count = potions[kind] - incoming.get(kind, 0)
	score_label.text = "Score: %d" % (score - score_incoming)
	var steps := _reveal_steps()
	var wisdom: Button = potion_buttons[PotionArt.WISDOM]
	if wisdom_level >= steps:
		wisdom.text = "Wisdom\n(all known)"
		wisdom.disabled = false  # free to reopen the thought
	else:
		wisdom.text = "Wisdom %d/%d\ncosts %d" % [wisdom_level, steps, cost]
		wisdom.disabled = potions[PotionArt.WISDOM] < cost
	var vision: Button = potion_buttons[PotionArt.VISION]
	if vision_level >= steps:
		vision.text = "Vision\n(clearest)"
		vision.disabled = true
	else:
		vision.text = "Vision %d/%d\ncosts %d" % [vision_level, steps, cost]
		vision.disabled = potions[PotionArt.VISION] < cost
	if where_button:
		if where_paid:
			where_button.text = "Where?\n(paid)"
			where_button.disabled = false
		else:
			where_button.text = "Where?\ncosts 1 + 1"
			where_button.disabled = potions[PotionArt.WISDOM] < WHERE_COST \
				or potions[PotionArt.VISION] < WHERE_COST


func _engraving_text() -> String:
	if puzzle.is_empty():
		return ""
	if _word_filled():
		return "STIR THE POT!"
	var n: int = puzzle.missing.size()
	return "FIND %d LETTER%s" % [n, "" if n == 1 else "S"]


# ---------------------------------------------------------------- drawing the hut

func _draw() -> void:
	var time := Time.get_ticks_msec() / 1000.0
	# Wall
	draw_rect(Rect2(0, 0, 1280, 600), Color("4b3226"))
	for x in range(0, 1281, 80):
		draw_line(Vector2(x, 0), Vector2(x, 600), Color("3e291f"), 3.0)
	# Window with a moon
	var win := Rect2(70, 118, 190, 150)
	draw_rect(win.grow(10), Color("2c1c14"))
	draw_rect(win, Color("1d2a4d"))
	draw_circle(win.position + Vector2(130, 50), 26, Color("fff4c9"))
	draw_circle(win.position + Vector2(140, 44), 22, Color("1d2a4d"))
	for s in [Vector2(30, 30), Vector2(60, 115), Vector2(100, 75), Vector2(165, 130), Vector2(40, 70)]:
		draw_circle(win.position + s, 2.5, Color("fff4c9"))
	draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color("2c1c14"), 8.0)
	draw_line(Vector2(win.position.x, win.get_center().y), Vector2(win.end.x, win.get_center().y), Color("2c1c14"), 8.0)
	# Shelf with jars
	draw_rect(Rect2(1030, 150, 220, 12), Color("2c1c14"))
	draw_rect(Rect2(1045, 105, 34, 45), Color("7fb3a8"))
	draw_rect(Rect2(1095, 92, 30, 58), Color("c76b5a"))
	draw_circle(Vector2(1160, 128), 22, Color("9b7fc4"))
	draw_rect(Rect2(1195, 110, 36, 40), Color("d9b45a"))
	# Fire glow under the cauldron
	_ellipse(Vector2(640, 600), 380, 100, Color(1.0, 0.55, 0.2, 0.22))
	# Cauldron body (front) with a soft shine
	_ellipse(Vector2(640, 470), 335, 175, Color("26262e"))
	_ellipse(Vector2(520, 540), 120, 40, Color(1, 1, 1, 0.04))
	# Rim seen from above: a thick dark ring around a wide pool of soup
	_ellipse(BREW_CENTER, BREW_RADIUS.x + 32, BREW_RADIUS.y + 22, Color("3b3b47"))
	_ellipse(BREW_CENTER + Vector2(0, -6), BREW_RADIUS.x + 18, BREW_RADIUS.y + 10, Color("4a4a58"))
	_ellipse(BREW_CENTER, BREW_RADIUS.x, BREW_RADIUS.y, brew_color.darkened(0.35))  # inner wall shadow
	_ellipse(BREW_CENTER + Vector2(0, 8), BREW_RADIUS.x - 8, BREW_RADIUS.y - 10, brew_color)
	# Swirls in the soup (they spin with your stirring)
	var spin := swirl_angle + time * 0.25
	for k in 3:
		var a0 := spin + k * TAU / 3.0
		var pts := PackedVector2Array()
		for j in 14:
			var a := a0 + j * 0.13
			var r := 50.0 + j * 15.0
			pts.append(BREW_CENTER + Vector2(0, 8) + Vector2(cos(a) * r, sin(a) * r * 0.36))
		draw_polyline(pts, brew_color.lightened(0.28), 3.0, true)
	_draw_picture(time)
	# Golden engraving on the front of the cauldron
	_draw_engraving()
	_draw_familiar(time)
	# Table
	draw_rect(Rect2(0, 595, 1280, 125), Color("8a5a32"))
	draw_rect(Rect2(0, 595, 1280, 8), Color("a8743f"))
	draw_line(Vector2(0, 640), Vector2(1280, 640), Color("744a28"), 2.0)
	draw_line(Vector2(0, 690), Vector2(1280, 690), Color("744a28"), 2.0)


## The vague picture of the word, wobbling and blurry in the brew.
func _draw_picture(time: float) -> void:
	var pic: String = puzzle.get("picture", "")
	if pic == "" or picture_alpha <= 0.01:
		return
	var fs := 110
	var baseline := (emoji_font.get_ascent(fs) - emoji_font.get_descent(fs)) * 0.5
	var wobble := 1.0 - picture_alpha  # less wobble and blur as it becomes clear
	draw_set_transform(PICTURE_CENTER, sin(time * 0.9) * 0.08 * wobble,
		Vector2(1.0 + sin(time * 1.4) * 0.05 * wobble, 0.8 + sin(time * 1.1) * 0.05 * wobble))
	var clear := picture_alpha  # each Vision potion raises this; a correct word makes it 1
	var tint := brew_color.lightened(0.5).lerp(Color.WHITE, clear * clear)
	var blur := 16.0 * (1.0 - clear)
	# Several shifted, faint copies blur the picture while it is still a mystery.
	for i in 8:
		var a := TAU * i / 8.0
		var c := tint
		c.a = 0.3 * (1.0 - clear) * minf(1.0, clear * 5.0)
		draw_string(emoji_font, Vector2(-150, baseline) + Vector2(cos(a), sin(a)) * blur, pic, HORIZONTAL_ALIGNMENT_CENTER, 300, fs, c)
	var main_c := tint
	main_c.a = 0.2 + 0.8 * clear * clear
	draw_string(emoji_font, Vector2(-150, baseline), pic, HORIZONTAL_ALIGNMENT_CENTER, 300, fs, main_c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The owl familiar beside the cauldron, with a ring that fills up until it helps.
func _draw_familiar(time: float) -> void:
	if not _has_familiar():
		return
	var c := FAMILIAR_POS + Vector2(0, sin(time * 1.5) * 3.0)
	draw_circle(c, 36.0, Color(0, 0, 0, 0.25))
	draw_arc(c, 36.0, 0.0, TAU, 40, Color(1, 0.85, 0.4, 0.2), 4.0, true)
	var frac := familiar_time / FAMILIAR_INTERVAL
	if frac > 0.0:
		draw_arc(c, 36.0, -PI / 2, -PI / 2 + TAU * frac, 40, BREW_GOLD, 4.0, true)
	var fs := 40
	var baseline := (emoji_font.get_ascent(fs) - emoji_font.get_descent(fs)) * 0.5
	draw_string(emoji_font, c + Vector2(-40, baseline), "🦉", HORIZONTAL_ALIGNMENT_CENTER, 80, fs)


func _draw_engraving() -> void:
	var text := _engraving_text()
	if text == "":
		return
	var fs := 36
	var w := 600.0
	var pos := Vector2(640.0 - w * 0.5, ENGRAVING_Y + 12.0)
	var gold := Color("e8b84a")
	if text.begins_with("STIR"):
		gold = gold.lerp(Color("fff0b0"), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0))
	# Dark edge above and light edge below make it look carved into the metal.
	draw_string(engrave_font, pos + Vector2(0, -2), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(0, 0, 0, 0.7))
	draw_string(engrave_font, pos + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(1, 0.9, 0.6, 0.35))
	draw_string(engrave_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, gold)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


# ---------------------------------------------------------------- particles

func _make_soft_circle(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	return g


func _make_bubbles(tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = 18
	p.lifetime = 1.4
	p.position = BREW_CENTER
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(220, 70)
	p.direction = Vector2(0, -1)
	p.spread = 15.0
	p.gravity = Vector2(0, -10)
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	p.color = BREW_GREEN.lightened(0.35)
	p.color_ramp = _fade_ramp()
	add_child(p)
	return p


func _make_sparkles(tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 80
	p.lifetime = 1.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(250, 10)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 350)
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 380.0
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.5
	p.color = BREW_GOLD
	p.color_ramp = _fade_ramp()
	add_child(p)
	return p


func _make_smoke(tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = 40
	p.lifetime = 1.6
	p.position = BREW_CENTER
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(150, 10)
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.gravity = Vector2(0, -20)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = Color(0.55, 0.5, 0.6, 0.8)
	p.color_ramp = _fade_ramp()
	add_child(p)
	return p


func _burst(p: CPUParticles2D) -> void:
	p.restart()
	p.emitting = true


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	layer.add_child(root)

	# Difficulty picker
	var top := HBoxContainer.new()
	top.position = Vector2(16, 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 6)
	root.add_child(top)
	var lvl := _label("Difficulty:", 22)
	lvl.custom_minimum_size = Vector2(0, 46)
	lvl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lvl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(lvl)
	for i in range(1, GameData.LEVELS.size() + 1):
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 2)
		top.add_child(col)
		var b := _button(str(i), Vector2(46, 46))
		b.toggle_mode = true
		b.pressed.connect(_start_level.bind(i))
		col.add_child(b)
		level_buttons.append(b)
		var star := LevelStar.new()
		col.add_child(star)
		level_stars.append(star)
	_update_level_stars()

	progress_label = _label("", 24)
	progress_label.position = Vector2(1090, 18)
	root.add_child(progress_label)

	score_label = _label("", 24)
	score_label.position = Vector2(860, 18)
	score_label.add_theme_color_override("font_color", BREW_GOLD)
	root.add_child(score_label)

	var tip := _label("Stir the pot: swipe\nleft across the brew!", 18)
	tip.position = Vector2(40, 300)
	tip.modulate = Color(1, 1, 1, 0.75)
	root.add_child(tip)

	# Meaning hint (Wisdom potion): a floating thought
	thought = ThoughtCloud.new()
	root.add_child(thought)
	thought.setup(Vector2(640, 168))

	# Action buttons
	var side := VBoxContainer.new()
	side.position = Vector2(975, 220)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_constant_override("separation", 12)
	root.add_child(side)
	# Each potion: a shelf of little flask icons, then the button that drinks one.
	var potion_rows := [
		[PotionArt.WISDOM, "Drink to learn what the word means", _drink_wisdom],
		[PotionArt.VISION, "Drink to see the picture in the brew more clearly", _drink_vision],
	]
	for info in potion_rows:
		var kind: String = info[0]
		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 8)
		side.add_child(hbox)
		var shelf := PotionShelf.new()
		shelf.liquid = PotionArt.COLORS[kind]
		hbox.add_child(shelf)
		shelves[kind] = shelf
		var b := _button("", Vector2(160, 64))
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_color_override("font_color", PotionArt.COLORS[kind].lightened(0.55))
		b.tooltip_text = info[1]
		b.pressed.connect(info[2])
		hbox.add_child(b)
		potion_buttons[kind] = b
	var where_row := HBoxContainer.new()
	where_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	where_row.add_theme_constant_override("separation", 8)
	side.add_child(where_row)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(PotionShelf.PER_ROW * PotionShelf.STEP + 4, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	where_row.add_child(spacer)
	var where := _button("", Vector2(160, 64))
	where.add_theme_font_size_override("font_size", 19)
	where.tooltip_text = "Show where a missing letter goes.\nCosts 1 Wisdom + 1 Vision potion per word (counts as help)."
	where_button = where
	where.pressed.connect(_show_where_hint)
	where_row.add_child(where)
	var shop_row := HBoxContainer.new()
	shop_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_row.add_theme_constant_override("separation", 8)
	side.add_child(shop_row)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = spacer.custom_minimum_size
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_row.add_child(spacer2)
	var shop_button := _button("Shelves", Vector2(160, 52))
	shop_button.add_theme_font_size_override("font_size", 19)
	shop_button.add_theme_color_override("font_color", BREW_GOLD)
	shop_button.tooltip_text = "Spend score points on more potion slots"
	shop_button.pressed.connect(_open_shop)
	shop_row.add_child(shop_button)
	_build_shop(root)

	# Level complete popup
	complete_panel = PanelContainer.new()
	complete_panel.position = Vector2(390, 230)
	complete_panel.custom_minimum_size = Vector2(500, 0)
	complete_panel.visible = false
	root.add_child(complete_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	complete_panel.add_child(box)
	complete_label = _label("", 30)
	complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	complete_label.add_theme_color_override("font_color", Color("4a2c17"))
	box.add_child(complete_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var again := _button("Play again", Vector2(180, 54))
	again.pressed.connect(func() -> void: _start_level(level))
	buttons.add_child(again)
	next_level_button = _button("Next level", Vector2(180, 54))
	next_level_button.pressed.connect(func() -> void: _start_level(level + 1))
	buttons.add_child(next_level_button)


# ---------------------------------------------------------------- shelves menu

## Score points needed for the next slot on a shelf: 30, 60, 90, ... (more each time).
func _slot_price(kind: String) -> int:
	return 30 * (shelf_slots[kind] - START_SLOTS + 1)


## The spell book (upgrade menu) and the skill tree it shows.
const SKILL_TREE := [
	{"id": "root", "parent": "", "pos": Vector2(0, 0), "icon": "🍲"},
	{"id": "wisdom_shelf", "parent": "root", "pos": Vector2(-260, 120), "icon": "📘"},
	{"id": "vision_shelf", "parent": "root", "pos": Vector2(260, 120), "icon": "🔮"},
	{"id": "familiar", "parent": "root", "pos": Vector2(0, 250), "icon": "🦉"},
	{"id": "discount", "parent": "wisdom_shelf", "pos": Vector2(-470, 300), "icon": "💰"},
	{"id": "lucky", "parent": "vision_shelf", "pos": Vector2(470, 300), "icon": "🍀"},
]


func _build_shop(root: Control) -> void:
	shop_panel = SpellBook.new()
	shop_panel.game = self
	shop_panel.emoji_font = emoji_font
	root.add_child(shop_panel)


func _open_shop() -> void:
	if complete_panel.visible:
		return
	shop_panel.open_book()


func _update_shop() -> void:
	if shop_panel:
		shop_panel.refresh()


func _buy_slot(kind: String) -> bool:
	var price := _slot_price(kind)
	if shelf_slots[kind] >= MAX_SLOTS or score < price:
		return false
	score -= price
	shelf_slots[kind] += 1
	_save_game()
	_update_potion_ui()
	_update_shop()
	return true


## Sum of your best star on every level (max 100 per level, 1000 in total).
func total_stars() -> int:
	var total := 0
	for n in level_records:
		total += int(level_records[n].best)
	return total


func _upgrade_info(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}


func book_stats_text() -> String:
	return "Score: %d points      Stars from levels: %d / %d" % [score, total_stars(), GameData.LEVELS.size() * 100]


## Everything the spell book needs to draw and explain one spell.
func skill_info(id: String) -> Dictionary:
	var info := {"title": "", "desc": "", "status_text": "", "hint": "",
		"understood": false, "can_buy": false, "toggle": false}
	if id == "root":
		info.title = "Your cauldron"
		info.desc = "The heart of every spell. Earn stars on the levels to unlock spells, and score to learn them."
		info.understood = true
		info.status_text = "%d stars" % total_stars()
		info.hint = "Score: %d points" % score
	elif id == "wisdom_shelf" or id == "vision_shelf":
		var kind := PotionArt.WISDOM if id == "wisdom_shelf" else PotionArt.VISION
		var label := "Wisdom" if kind == PotionArt.WISDOM else "Vision"
		var price := _slot_price(kind)
		var maxed: bool = shelf_slots[kind] >= MAX_SLOTS
		info.title = "%s shelf" % label
		info.desc = "Makes room for one more %s potion on its shelf." % label
		info.understood = shelf_slots[kind] > START_SLOTS
		info.can_buy = not maxed and score >= price
		info.status_text = "%d / %d slots" % [shelf_slots[kind], MAX_SLOTS]
		if maxed:
			info.hint = "Full size!"
		elif info.can_buy:
			info.hint = "Hold to learn: %d points" % price
		else:
			info.hint = "Needs %d points (you have %d)" % [price, score]
	else:
		var u := _upgrade_info(id)
		var owned := owned_upgrades.has(id)
		var unlocked := total_stars() >= int(u.stars)
		info.title = u.name
		info.desc = String(u.desc).replace("\n", " ")
		info.understood = owned
		info.can_buy = not owned and unlocked and score >= int(u.price)
		info.toggle = owned and id == "familiar"
		if owned:
			if info.toggle:
				info.status_text = "owl ON" if familiar_on else "owl OFF"
				info.hint = "Learned. Click to switch the owl %s." % ("off" if familiar_on else "on")
			else:
				info.status_text = "learned"
				info.hint = "Learned."
		elif not unlocked:
			info.status_text = "needs %d stars" % u.stars
			info.hint = "Locked: needs %d stars (you have %d)" % [u.stars, total_stars()]
		else:
			info.status_text = "%d points" % u.price
			info.hint = ("Hold to learn: %d points" % u.price) if info.can_buy \
				else ("Needs %d points (you have %d)" % [u.price, score])
	return info


## Learn a spell (called when the mouse has been held on it long enough).
func skill_buy(id: String) -> bool:
	if id == "wisdom_shelf":
		return _buy_slot(PotionArt.WISDOM)
	if id == "vision_shelf":
		return _buy_slot(PotionArt.VISION)
	var u := _upgrade_info(id)
	if u.is_empty() or owned_upgrades.has(id) or total_stars() < int(u.stars) or score < int(u.price):
		return false
	score -= int(u.price)
	owned_upgrades[id] = true
	_save_game()
	_update_potion_ui()
	_update_shop()
	return true


## A click on a learned spell that can be switched (the owl).
func skill_click(id: String) -> void:
	if id == "familiar" and owned_upgrades.has(id):
		familiar_on = not familiar_on
		familiar_time = 0.0
		_save_game()
		_update_shop()


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	return b


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", _ui_box(Color("6b4226"), Color("c99a5b")))
	t.set_stylebox("hover", "Button", _ui_box(Color("7d5030"), Color("e8c27a")))
	t.set_stylebox("pressed", "Button", _ui_box(Color("d9a441"), Color("fff0c2")))
	t.set_stylebox("hover_pressed", "Button", _ui_box(Color("e0b052"), Color("fff0c2")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", _ui_box(Color("4a3226"), Color("6b5040")))
	t.set_color("font_disabled_color", "Button", Color(1, 0.95, 0.85, 0.35))
	t.set_color("font_color", "Button", Color("fff3d6"))
	t.set_color("font_hover_color", "Button", Color("ffffff"))
	t.set_color("font_pressed_color", "Button", Color("2b1a0e"))
	t.set_color("font_hover_pressed_color", "Button", Color("2b1a0e"))
	t.set_color("font_color", "Label", Color("fff3d6"))
	var parchment := _ui_box(Color("f3e2b8"), Color("8b5a2b"))
	parchment.set_content_margin_all(16)
	t.set_stylebox("panel", "PanelContainer", parchment)
	return t


func _ui_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	return sb


# ---------------------------------------------------------------- helper node

## Draws the "drop here" bar and the golden hint marker.
class Marker extends Node2D:
	const INSERT := 0
	const HINT_BOX := 1
	const HINT_BAR := 2

	var kind := HINT_BOX
	var color := Color.WHITE

	func _draw() -> void:
		var h := LetterTile.BUBBLE_RADIUS + 6.0
		if kind == INSERT:
			draw_line(Vector2(0, -h), Vector2(0, h), color, 6.0)
			return
		if kind == HINT_BOX:
			draw_arc(Vector2.ZERO, h, 0.0, TAU, 40, color, 5.0, true)
		else:
			draw_line(Vector2(0, -h), Vector2(0, h), color, 8.0)
		var tip := -h - 8.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-16, tip - 24), Vector2(16, tip - 24), Vector2(0, tip)
		]), color)


## A reward potion flying from the cauldron to its shelf.
class FlyingPotion extends Node2D:
	var liquid := Color.WHITE

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 16.0, Color(liquid, 0.25))
		PotionArt.draw_flask(self, Vector2.ZERO, 1.0, liquid)


## A wooden spoon that follows the mouse while you stir.
class Spoon extends Node2D:
	func _draw() -> void:
		var handle_end := Vector2(70, -170)
		draw_line(Vector2(0, -10), handle_end, Color("5a3a1e"), 14.0, true)
		draw_line(Vector2(0, -10), handle_end, Color("a8743f"), 9.0, true)
		draw_circle(Vector2.ZERO, 20.0, Color("5a3a1e"))
		draw_circle(Vector2(-2, -2), 16.0, Color("a8743f"))
