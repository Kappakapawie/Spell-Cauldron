class_name ThemeFrog
extends Control

## Shown when a recipe book is opened. A frog coughs up the book's theme in a puff of magic dust.
## Click a theme to brew the book with it. Or feed the frog potions: it swallows what is there
## and coughs up something else.

signal start_pressed(theme: String)
signal reroll_pressed
signal back_pressed

const MOUTH := Vector2(640, 452)   ## where things go in and come out
const CARD_Y := 212.0
const CARD_STEP := 300.0
const DUST := [Color("ffd45c"), Color("e46bd0"), Color("8fe3ff"), Color("b78bff"), Color("9df28a")]

var busy := false            ## the frog is eating or coughing
var cards: Array[ThemeCard] = []
var emoji_font: Font
var reroll_button: Button
var cost_icons: CostIcons
var can_reroll := false
var _frog: Frog
var _tongue: Tongue
var _card_layer: Control
var _dust: Array[CPUParticles2D] = []
var _title: Label
var _hint: Label
var _stock: Stock
var _run := 0                ## goes up when the screen opens or closes, so old animations stop


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title = _centered(40, MenuKit.CREAM, 28)
	_hint = _centered(22, Color("e8c27a"), 86)
	_frog = Frog.new()
	_frog.position = MOUTH
	add_child(_frog)
	_card_layer = Control.new()
	_card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card_layer)
	_tongue = Tongue.new()
	add_child(_tongue)
	var tex := soft_dot()
	for color in DUST:
		var p := make_dust(tex, color)
		add_child(p)
		_dust.append(p)
	var back := MenuKit.button("Back", Vector2(160, 56), back_pressed.emit)
	back.position = Vector2(70 - ScreenLayout.edge(), 644)
	add_child(back)
	reroll_button = MenuKit.button("Feed the frog\n ", Vector2(230, 72), reroll_pressed.emit)
	reroll_button.position = Vector2(525, 630)
	reroll_button.add_theme_font_size_override("font_size", 20)
	reroll_button.tooltip_text = "The frog swallows this and coughs up something new."
	add_child(reroll_button)
	cost_icons = CostIcons.new()
	cost_icons.position = Vector2(0, 36)
	cost_icons.size = Vector2(230, 36)
	reroll_button.add_child(cost_icons)
	_stock = Stock.new()
	_stock.position = Vector2(1040 + ScreenLayout.edge(), 640)
	add_child(_stock)


func _centered(font_size: int, color: Color, y: float) -> Label:
	var l := MenuKit.label("", font_size, color)
	l.position = Vector2(0, y)
	l.size = Vector2(1280, font_size + 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


## Opens for a book; the frog coughs up the themes on offer.
func open(book: int, themes: Array) -> void:
	_run += 1
	visible = true
	_reset()
	_title.text = "Brew recipes %d" % book
	_cough(themes, _run)


func close() -> void:
	_run += 1
	visible = false
	_reset()


## The frog swallows what is on offer and coughs up the new themes.
func swap(themes: Array) -> void:
	if busy:
		return
	var run := _run
	_set_busy(true)
	_hint.text = "Gulp..."
	var old := cards.duplicate()
	cards.clear()
	await _frog.open_mouth(0.18)
	for card: ThemeCard in old:
		if run != _run:
			return
		await _swallow(card)
	if run != _run:
		return
	await _frog.gulp()
	if run != _run:
		return
	_cough(themes, run)


## How often it can still be fed in this book.
func show_left(left: int) -> void:
	reroll_button.text = "Feed the frog (%d left)\n " % left if left > 0 else "The frog is full\nuntil the next book"
	cost_icons.visible = left > 0


func set_potions(wisdom: int, vision: int, cost: Array[Color], affordable: bool, unlocked: bool) -> void:
	reroll_button.visible = unlocked  # only with the Hungry frog spell
	_stock.visible = unlocked
	_stock.wisdom = wisdom
	_stock.vision = vision
	_stock.queue_redraw()
	can_reroll = affordable
	cost_icons.set_costs(cost)
	_update_buttons()


func _reset() -> void:
	busy = false
	for c in _card_layer.get_children():
		c.queue_free()
	cards.clear()
	_tongue.out = false
	_frog.calm()
	for p in _dust:
		p.emitting = false


func _set_busy(b: bool) -> void:
	busy = b
	_update_buttons()


func _update_buttons() -> void:
	reroll_button.disabled = busy or not can_reroll
	for c in cards:
		c.disabled = busy
		c.queue_redraw()
	cost_icons.queue_redraw()


## The tongue shoots out, sticks to the card and pulls it in.
func _swallow(card: ThemeCard) -> void:
	var middle := card.position + card.size * 0.5
	_tongue.out = true
	_tongue.tip = MOUTH
	var tw := create_tween()
	tw.tween_property(_tongue, "tip", middle, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.07)
	tw.tween_property(_tongue, "tip", MOUTH, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "position", MOUTH - card.size * 0.5, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "scale", Vector2(0.08, 0.08), 0.22).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "rotation", randf_range(-0.8, 0.8), 0.22)
	await tw.finished
	_tongue.out = false
	if is_instance_valid(card):  # gone already if the screen was left meanwhile
		card.queue_free()


## A shudder, a cloud of magic dust, and out come the themes.
func _cough(themes: Array, run: int) -> void:
	_set_busy(true)
	_hint.text = "Hrrk..."
	await _frog.shudder()
	if run != _run:
		return
	for i in themes.size():
		_puff()
		_frog.kick()
		var card := ThemeCard.new(themes[i], emoji_font)
		var home := Vector2(640 + (i - (themes.size() - 1) * 0.5) * CARD_STEP, CARD_Y) - card.size * 0.5
		card.position = MOUTH - card.size * 0.5
		card.scale = Vector2(0.08, 0.08)
		card.rotation = randf_range(-1.2, 1.2)
		card.disabled = true  # until the frog is done
		card.pressed.connect(_choose.bind(card))
		_card_layer.add_child(card)
		cards.append(card)
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "position", home, 0.5)
		tw.tween_property(card, "scale", Vector2.ONE, 0.5)
		tw.tween_property(card, "rotation", 0.0, 0.5)
		await get_tree().create_timer(0.28).timeout
		if run != _run:
			return
	_frog.close_mouth()
	await get_tree().create_timer(0.35).timeout
	if run != _run:
		return
	_set_busy(false)
	_hint.text = ScreenLayout.say("Click the theme to start brewing" if themes.size() == 1 else "Click the theme you want to brew")


func _choose(card: ThemeCard) -> void:
	if not busy:
		start_pressed.emit(card.theme_name)


func _puff() -> void:
	for p in _dust:
		p.restart()
		p.emitting = true


static func make_dust(tex: Texture2D, color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 42
	p.lifetime = 2.0
	p.position = MOUTH
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 16.0
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.gravity = Vector2(0, 45)
	p.damping_min = 120.0
	p.damping_max = 260.0
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 640.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 1.2
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	return p


static func soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 24
	t.height = 24
	return t


func _draw() -> void:
	var all := ScreenLayout.rect()
	draw_rect(all, Color("4b3226"))
	for x in range(-800, 2081, 80):
		if x >= all.position.x and x <= all.end.x:
			draw_line(Vector2(x, all.position.y), Vector2(x, all.end.y), Color("3e291f"), 3.0)
	draw_rect(Rect2(all.position.x, 596, all.size.x, all.end.y - 596), Color("8a5a32"))
	draw_rect(Rect2(all.position.x, 596, all.size.x, 6), Color("a8743f"))


## Also beside the 1280 x 720 on a wider screen: nothing behind it can be touched.
func _has_point(point: Vector2) -> bool:
	return ScreenLayout.rect().has_point(point)


## A piece of parchment with a theme on it.
class ThemeCard extends Button:
	var theme_name := ""
	var _icon := ""
	var _font: Font

	func _init(p_name: String = "", font: Font = null) -> void:
		theme_name = p_name
		_font = font
		_icon = GameData.THEME_ICONS.get(p_name, "📜")
		size = Vector2(264, 150)
		pivot_offset = size * 0.5
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var lit := is_hovered() and not disabled
		if lit:
			for i in 3:
				var glow := StyleBoxFlat.new()
				glow.bg_color = Color(1.0, 0.85, 0.35, 0.16)
				glow.set_corner_radius_all(18)
				draw_style_box(glow, r.grow(5.0 + i * 5.0))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("fff0c8") if lit else Color("f3e2b8")
		sb.border_color = Color("e3a92f") if lit else Color("8b5a2b")
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(14)
		draw_style_box(sb, r)
		var font := _font if _font else ThemeDB.fallback_font
		draw_string(font, Vector2(0, 80), _icon, HORIZONTAL_ALIGNMENT_CENTER, size.x, 54, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(8, 124), theme_name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 23, MenuKit.INK)


## The frog's tongue, drawn over the cards it catches.
class Tongue extends Node2D:
	var from := MOUTH + Vector2(0, 8)
	var thickness := 1.0
	var tip := MOUTH:
		set(value):
			tip = value
			queue_redraw()
	var out := false:
		set(value):
			out = value
			queue_redraw()

	func _draw() -> void:
		if not out:
			return
		draw_line(from, tip, Color("b8485c"), 18.0 * thickness, true)
		draw_line(from, tip, Color("e06a7d"), 12.0 * thickness, true)
		draw_circle(tip, 17.0 * thickness, Color("b8485c"))
		draw_circle(tip, 14.0 * thickness, Color("e06a7d"))


## How many potions you have to pay with.
class Stock extends Control:
	var wisdom := 0
	var vision := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(0, 38), "You have", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, MenuKit.CREAM)
		PotionArt.draw_flask(self, Vector2(104, 34), 1.1, PotionArt.COLORS[PotionArt.WISDOM])
		draw_string(font, Vector2(118, 40), str(wisdom), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, MenuKit.CREAM)
		PotionArt.draw_flask(self, Vector2(164, 34), 1.1, PotionArt.COLORS[PotionArt.VISION])
		draw_string(font, Vector2(178, 40), str(vision), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, MenuKit.CREAM)


## The frog itself. (0, 0) is the middle of its mouth.
class Frog extends Node2D:
	const SKIN := Color("6cae4c")
	const DARK := Color("4d8538")
	const BELLY := Color("d9e6a5")
	var mouth := 0.0       ## 0 = shut, 1 = wide open
	var bulge := 0.0       ## something is going down the throat
	var squash := 0.0      ## pressed flat (+) or stretched up (-)
	var sway := 0.0        ## shuddering to the side
	var surprise := 0.0    ## big eyes
	var _tw: Tween

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _tween() -> Tween:
		if _tw:
			_tw.kill()
		_tw = create_tween().set_trans(Tween.TRANS_SINE)
		return _tw

	func calm() -> void:
		if _tw:
			_tw.kill()
		mouth = 0.0
		bulge = 0.0
		squash = 0.0
		sway = 0.0
		surprise = 0.0

	func open_mouth(time: float) -> void:
		var tw := _tween()
		tw.tween_property(self, "mouth", 1.0, time)
		await tw.finished

	func close_mouth() -> void:
		var tw := _tween()
		tw.tween_property(self, "mouth", 0.0, 0.3)
		tw.parallel().tween_property(self, "surprise", 0.0, 0.5)
		tw.parallel().tween_property(self, "squash", 0.0, 0.3)

	## Mouth shut, a lump goes down, and the frog looks surprised.
	func gulp() -> void:
		var tw := _tween()
		tw.tween_property(self, "mouth", 0.0, 0.1)
		tw.tween_property(self, "bulge", 1.0, 0.18)
		tw.parallel().tween_property(self, "squash", 0.12, 0.18)
		tw.tween_property(self, "bulge", 0.0, 0.3)
		tw.parallel().tween_property(self, "squash", -0.05, 0.3)
		tw.tween_property(self, "squash", 0.0, 0.15)
		tw.tween_interval(0.25)
		await tw.finished

	## Something wants to come up again.
	func shudder() -> void:
		var tw := _tween()
		tw.tween_property(self, "surprise", 1.0, 0.15)
		for i in 5:
			tw.tween_property(self, "sway", 7.0 if i % 2 == 0 else -7.0, 0.06)
			tw.parallel().tween_property(self, "bulge", 0.5 if i % 2 == 0 else 0.0, 0.06)
		tw.tween_property(self, "sway", 0.0, 0.05)
		tw.tween_property(self, "squash", 0.16, 0.14)
		tw.tween_property(self, "mouth", 1.0, 0.08)
		tw.parallel().tween_property(self, "bulge", 0.0, 0.08)
		await tw.finished

	## The jolt of a cough.
	func kick() -> void:
		var tw := _tween()
		mouth = 1.0
		tw.tween_property(self, "squash", -0.12, 0.07)
		tw.tween_property(self, "squash", 0.05, 0.14)

	func _ellipse(c: Vector2, r: Vector2, color: Color) -> void:
		var pts := PackedVector2Array()
		for i in 40:
			pts.append(c + Vector2(cos(i * TAU / 40.0), sin(i * TAU / 40.0)) * r)
		draw_colored_polygon(pts, color)

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var breath := 0.012 * sin(t * 2.2)
		var sq := squash + breath
		# Squash from the feet (y = 150) up.
		draw_set_transform(Vector2(sway, 150.0 * sq), 0.0, Vector2(1.0 + sq * 0.7, 1.0 - sq))
		_ellipse(Vector2(0, 150), Vector2(190, 14), Color(0, 0, 0, 0.25))
		# Back legs, body, belly
		for side in [-1.0, 1.0]:
			_ellipse(Vector2(side * 118, 108), Vector2(56, 44), DARK)
			_ellipse(Vector2(side * 140, 144), Vector2(44, 11), DARK)
		_ellipse(Vector2(0, 84), Vector2(116, 70), SKIN)
		_ellipse(Vector2(0, 96), Vector2(82, 54), BELLY)
		# Front feet
		for side in [-1.0, 1.0]:
			_ellipse(Vector2(side * 70, 122), Vector2(20, 30), SKIN)
			for toe in [-14.0, 0.0, 14.0]:
				_ellipse(Vector2(side * 70 + toe, 148), Vector2(10, 7), SKIN)
		# Throat
		_ellipse(Vector2(0, 46 + 20 * bulge), Vector2(84 + 22 * bulge, 34 + 16 * bulge), BELLY)
		# Eyes, then the head over their lower halves
		for side in [-1.0, 1.0]:
			var eye := Vector2(side * 74, -54)
			draw_circle(eye, 34.0, SKIN)
			var blink := fmod(t + 1.3, 4.0) < 0.13 and surprise < 0.5
			if blink:
				draw_line(eye + Vector2(-18, 2), eye + Vector2(18, 2), DARK, 5.0, true)
			else:
				var big := 23.0 + 4.0 * surprise
				draw_circle(eye + Vector2(0, -3), big, Color("fff7d8"))
				_ellipse(eye + Vector2(-side * 3, -3), Vector2(13 - 4 * surprise, 10 - 3 * surprise), Color("2b2016"))
				draw_circle(eye + Vector2(-side * 3 + 4, -8), 3.5, Color.WHITE)
		_ellipse(Vector2(0, 0), Vector2(130, 56), SKIN)
		for side in [-1.0, 1.0]:
			_ellipse(Vector2(side * 14, -30), Vector2(4, 3), DARK)
			_ellipse(Vector2(side * 96, 4), Vector2(15, 9), Color(0.95, 0.55, 0.5, 0.35))
		for spot in [Vector2(-34, -40), Vector2(40, -38), Vector2(6, -46)]:
			_ellipse(spot, Vector2(8, 4), DARK.lightened(0.12))
		# Mouth
		if mouth > 0.05:
			_ellipse(Vector2(0, 8), Vector2(60 + 18 * (1.0 - mouth), 6 + 32 * mouth), DARK)
			_ellipse(Vector2(0, 8), Vector2(55 + 18 * (1.0 - mouth), 3 + 30 * mouth), Color("4a1a24"))
			_ellipse(Vector2(0, 8 + 18 * mouth), Vector2(34, 10 * mouth), Color("e06a7d"))
		else:
			draw_arc(Vector2(0, -92), 130.0, PI * 0.5 - 0.72, PI * 0.5 + 0.72, 32, DARK.darkened(0.25), 4.5, true)
		# A little witch's hat
		var hat := Color("3b2d55")
		_ellipse(Vector2(0, -54), Vector2(42, 9), hat)
		draw_colored_polygon(PackedVector2Array([Vector2(-27, -56), Vector2(27, -56), Vector2(14, -98), Vector2(23, -124),
			Vector2(-3, -106)]), hat)
		draw_colored_polygon(PackedVector2Array([Vector2(-27, -56), Vector2(27, -56), Vector2(24, -67), Vector2(-22, -67)]),
			Color("d9a441"))
		draw_set_transform(Vector2.ZERO)
