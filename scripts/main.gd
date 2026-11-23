extends Node2D

## Spell Cauldron - rough prototype.
## Everything is drawn with simple shapes so we can test how the game feels
## before spending time on art.

const BREW_GREEN := Color("63c56f")
const BREW_GOLD := Color("ffd45c")
const BREW_MURKY := Color("6b4f7a")

const WORD_CENTER := Vector2(640, 250)
const WORD_MAX_WIDTH := 860.0
const WORD_STEP := LetterTile.SIZE + 10.0
const TABLE_Y := 645.0
const TABLE_STEP := 86.0
const DROP_RADIUS := 64.0
const BREW_CENTER := Vector2(640, 336)
const STIR_TURNS := 0.9  ## how many full circles you need to draw to stir

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
var stir_last_angle := 0.0
var stir_total := 0.0
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

var message_label: Label
var progress_label: Label
var meaning_panel: PanelContainer
var meaning_label: Label
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
	_build_ui()
	_start_level(1)


# ---------------------------------------------------------------- levels & words

func _start_level(n: int) -> void:
	level = n
	for i in level_buttons.size():
		level_buttons[i].set_pressed_no_signal(i + 1 == level)
	var settings: Dictionary = GameData.LEVELS[level - 1]
	session_words = _pick_words(settings)
	word_number = 0
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
	stirring = false
	if swirl_tween:
		swirl_tween.kill()
	for c in pieces.get_children():
		c.queue_free()
	row.clear()
	tiles.clear()
	hint_count = 0
	hint_marker.visible = false
	insert_marker.visible = false
	meaning_panel.visible = false
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
	var plural := "letter" if missing.size() == 1 else "letters"
	if gaps_visible:
		_say("Drag the missing %s into the word, then stir!" % plural)
	else:
		_say("%d %s missing... but where? Drop them into the word, then stir!" % [missing.size(), plural])


func _next_word() -> void:
	word_number += 1
	if word_number >= GameData.WORDS_PER_LEVEL:
		_show_level_complete()
	else:
		_start_word()


func _show_level_complete() -> void:
	busy = true
	complete_label.text = "Level %d complete!\nYou brewed all %d words." % [level, GameData.WORDS_PER_LEVEL]
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
	if busy or complete_panel.visible:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var p := get_global_mouse_position()
		var t := _tile_at(p)
		if t:
			_begin_drag(t, p)
			get_viewport().set_input_as_handled()
		elif _in_cauldron(p):
			stirring = true
			stir_last_angle = (p - BREW_CENTER).angle()
			stir_total = 0.0


func _input(event: InputEvent) -> void:
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
			stirring = false


func _tile_at(p: Vector2) -> LetterTile:
	for i in range(tiles.size() - 1, -1, -1):
		if tiles[i].contains_point(p):
			return tiles[i]
	return null


func _in_cauldron(p: Vector2) -> bool:
	var d := p - Vector2(640, 380)
	return pow(d.x / 270.0, 2) + pow(d.y / 190.0, 2) <= 1.0


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


func _send_home(t: LetterTile) -> void:
	t.in_word = false
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


func _stir_motion(p: Vector2) -> void:
	if p.distance_to(BREW_CENTER) < 30.0:
		return  # too close to the middle, the angle jumps around
	var a := (p - BREW_CENTER).angle()
	var d := wrapf(a - stir_last_angle, -PI, PI)
	stir_last_angle = a
	stir_total += d
	swirl_angle += d
	if absf(stir_total) >= TAU * STIR_TURNS:
		stirring = false
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
		_say("Place the missing letters first, then stir again.")
		busy = false
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
		var orbit := BREW_CENTER + Vector2(cos(a) * 180.0, sin(a) * 40.0 - 50.0)
		var pos := homes[i].lerp(orbit, w)
		row[i].position = pos
		var slot := row[i] as GapSlot
		if slot and slot.tile:
			slot.tile.position = pos
	swirl_angle = start_angle + t * TAU * 1.5


func _brew_success() -> void:
	_say("Well brewed!  %s" % puzzle.word)
	sparkles.position = WORD_CENTER
	_burst(sparkles)
	var tw := create_tween()
	tw.tween_property(self, "brew_color", BREW_GOLD, 0.3)
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
	_say("The brew fizzled... try again!")
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
			_say("All the letters look right. Stir the cauldron!")
			return
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
	hint_count += 1

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


func _toggle_meaning() -> void:
	if complete_panel.visible:
		return
	meaning_label.text = puzzle.meaning
	meaning_panel.visible = not meaning_panel.visible


func _say(text: String) -> void:
	message_label.text = text


# ---------------------------------------------------------------- drawing the hut

func _draw() -> void:
	# Wall
	draw_rect(Rect2(0, 0, 1280, 560), Color("4b3226"))
	for x in range(0, 1281, 80):
		draw_line(Vector2(x, 0), Vector2(x, 560), Color("3e291f"), 3.0)
	# Window with a moon
	var win := Rect2(70, 90, 190, 160)
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
	_ellipse(Vector2(640, 560), 340, 95, Color(1.0, 0.55, 0.2, 0.22))
	# Cauldron body, rim and brew
	_ellipse(Vector2(640, 450), 260, 175, Color("26262e"))
	_ellipse(Vector2(555, 420), 110, 70, Color(1, 1, 1, 0.05))
	_ellipse(BREW_CENTER + Vector2(0, -4), 240, 58, Color("3b3b47"))
	_ellipse(BREW_CENTER, 212, 42, brew_color)
	for k in 3:
		var a0 := swirl_angle + k * TAU / 3.0
		var pts := PackedVector2Array()
		for j in 12:
			var a := a0 + j * 0.14
			var r := 60.0 + j * 9.0
			pts.append(BREW_CENTER + Vector2(cos(a) * r, sin(a) * r * 0.2))
		draw_polyline(pts, brew_color.lightened(0.3), 3.0, true)
	# Table
	draw_rect(Rect2(0, 560, 1280, 160), Color("8a5a32"))
	draw_rect(Rect2(0, 560, 1280, 8), Color("a8743f"))
	draw_line(Vector2(0, 610), Vector2(1280, 610), Color("744a28"), 2.0)
	draw_line(Vector2(0, 668), Vector2(1280, 668), Color("744a28"), 2.0)


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
	p.emission_rect_extents = Vector2(170, 12)
	p.direction = Vector2(0, -1)
	p.spread = 15.0
	p.gravity = Vector2(0, -30)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 40.0
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
	top.add_child(lvl)
	for i in range(1, GameData.LEVELS.size() + 1):
		var b := _button(str(i), Vector2(46, 46))
		b.toggle_mode = true
		b.pressed.connect(_start_level.bind(i))
		top.add_child(b)
		level_buttons.append(b)

	progress_label = _label("", 24)
	progress_label.position = Vector2(1090, 18)
	root.add_child(progress_label)

	message_label = _label("", 24)
	message_label.position = Vector2(140, 168)
	message_label.size = Vector2(1000, 40)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_constant_override("outline_size", 8)
	message_label.add_theme_color_override("font_outline_color", Color("2c1c14"))
	root.add_child(message_label)

	var tip := _label("Tip: draw a circle on the\ncauldron to stir it!", 18)
	tip.position = Vector2(60, 300)
	tip.modulate = Color(1, 1, 1, 0.75)
	root.add_child(tip)

	# Meaning hint (parchment)
	meaning_panel = PanelContainer.new()
	meaning_panel.position = Vector2(340, 70)
	meaning_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meaning_panel.visible = false
	root.add_child(meaning_panel)
	meaning_label = _label("", 22)
	meaning_label.custom_minimum_size = Vector2(580, 0)
	meaning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meaning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meaning_label.add_theme_color_override("font_color", Color("4a2c17"))
	meaning_panel.add_child(meaning_label)

	# Action buttons
	var side := VBoxContainer.new()
	side.position = Vector2(1070, 250)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_constant_override("separation", 12)
	root.add_child(side)
	var stir := _button("Stir!", Vector2(180, 70))
	stir.add_theme_font_size_override("font_size", 30)
	stir.pressed.connect(_stir)
	side.add_child(stir)
	var where := _button("Where?", Vector2(180, 54))
	where.tooltip_text = "Show where a missing letter goes"
	where.pressed.connect(_show_where_hint)
	side.add_child(where)
	var meaning := _button("Meaning?", Vector2(180, 54))
	meaning.tooltip_text = "Show what the word means"
	meaning.pressed.connect(_toggle_meaning)
	side.add_child(meaning)

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
		var h := LetterTile.SIZE * 0.5 + 8.0
		if kind == INSERT:
			draw_line(Vector2(0, -h), Vector2(0, h), color, 6.0)
			return
		if kind == HINT_BOX:
			draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), color, false, 5.0)
		else:
			draw_line(Vector2(0, -h), Vector2(0, h), color, 8.0)
		var tip := -h - 8.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-16, tip - 24), Vector2(16, tip - 24), Vector2(0, tip)
		]), color)
