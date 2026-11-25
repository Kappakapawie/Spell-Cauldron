class_name PocketFrog
extends Node2D

## The little frog beside the cauldron while you play: click it, pay the potions, and it
## swallows the theme together with the word you are on, and coughs up something new.
## main.gd decides what; this only shows it. It sits in a circle like the other pets; (0, 0) is its middle.

const SIZE := 0.185
const RADIUS := 36.0

var cost: Array[Color] = []
var affordable := false
var left := 1               ## how often it can still be fed in this book
var awake := true          ## false while nothing can be fed to it (a word is being brewed)
var _frog: ThemeFrog.Frog
var _tongue: ThemeFrog.Tongue
var _dust: Array[CPUParticles2D] = []
var _refuse := 0.0
var _move: Tween           ## what is flying into its mouth now
var _run := 0              ## goes up when it is interrupted, so old animations stop


func _init() -> void:
	_frog = ThemeFrog.Frog.new()
	_frog.scale = Vector2.ONE * SIZE
	add_child(_frog)
	_tongue = ThemeFrog.Tongue.new()
	_tongue.from = Vector2.ZERO
	_tongue.thickness = 0.32
	add_child(_tongue)
	var tex := ThemeFrog.soft_dot()
	for color in ThemeFrog.DUST:
		var p := ThemeFrog.make_dust(tex, color)
		p.position = Vector2.ZERO
		p.scale = Vector2.ONE * 0.6
		add_child(p)
		_dust.append(p)


func is_at(global_p: Vector2) -> bool:
	return visible and global_p.distance_to(global_position) <= (RADIUS + 4.0) * scale.x


func refuse() -> void:
	_refuse = 0.45


## Stops whatever it was doing.
func calm() -> void:
	_run += 1
	if _move:
		_move.kill()
	_frog.calm()
	_tongue.out = false
	for p in _dust:
		p.emitting = false


func _process(delta: float) -> void:
	_refuse = maxf(0.0, _refuse - delta)
	_frog.position.x = sin(_refuse * 45.0) * 14.0 * _refuse
	if is_visible_in_tree():
		queue_redraw()


## Letters fly into its mouth, then the tongue fetches the theme's name; gulp.
func eat(letters: Array[Node2D], label: Control) -> void:
	var run := _run
	await _frog.open_mouth(0.15)
	if run != _run:
		return
	var fly := create_tween().set_parallel()
	_move = fly
	fly.tween_interval(0.3)
	for i in letters.size():
		if not is_instance_valid(letters[i]):
			continue
		var node := letters[i]
		fly.tween_property(node, "global_position", global_position, 0.32).set_delay(i * 0.025) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.tween_property(node, "scale", Vector2.ONE * 0.05, 0.32).set_delay(i * 0.025).set_ease(Tween.EASE_IN)
	await fly.finished
	if run != _run:
		return
	for i in letters.size():
		if is_instance_valid(letters[i]):
			letters[i].visible = false
	var middle := label.global_position + label.size * 0.5
	_tongue.out = true
	_tongue.tip = Vector2.ZERO
	var tw := create_tween().set_trans(Tween.TRANS_QUAD)
	_move = tw
	tw.tween_property(_tongue, "tip", to_local(middle), 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.07)
	tw.tween_property(_tongue, "tip", Vector2.ZERO, 0.28).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(label, "position", global_position - label.size * 0.5, 0.28).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(label, "scale", Vector2.ONE * 0.1, 0.28).set_ease(Tween.EASE_IN)
	await tw.finished
	if run != _run:
		return
	_tongue.out = false
	label.visible = false
	await _frog.gulp()


## A shudder and a cloud of magic dust; whatever comes up is shown by main.gd.
func cough() -> void:
	var run := _run
	await _frog.shudder()
	if run != _run:
		return
	for p in _dust:
		p.restart()
		p.emitting = true
	_frog.kick()


func done() -> void:
	_frog.close_mouth()


func _draw() -> void:
	var ready := affordable and awake
	var hover := is_at(get_global_mouse_position()) and not ScreenLayout.phone
	draw_circle(Vector2.ZERO, RADIUS, Color(1, 0.85, 0.4, 0.22) if hover and ready else Color(0, 0, 0, 0.25))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color("f2c14e") if affordable else Color(1, 0.85, 0.4, 0.2), 4.0, true)
	_frog.modulate = Color.WHITE if affordable or not awake else Color(1, 1, 1, 0.4)
	if (hover or (ScreenLayout.phone and left == 0)) and awake:
		draw_string(ThemeDB.fallback_font, Vector2(-80, RADIUS + 42), "click to feed" if affordable else ("full until the next book" if left == 0 else "too few potions"),
			HORIZONTAL_ALIGNMENT_CENTER, 160, 13, Color(1, 0.95, 0.85, 0.65))
	# How many meals are left, in a small badge.
	var badge := Vector2(RADIUS - 5, -RADIUS + 7)
	draw_circle(badge, 12.0, Color("f2c14e") if left > 0 else Color(0.45, 0.42, 0.38))
	draw_string(ThemeDB.fallback_font, badge + Vector2(-12, 6), str(left), HORIZONTAL_ALIGNMENT_CENTER, 24, 16, Color("4a2c17"))
	if left == 0:
		return
	var step := 16.0
	for i in cost.size():
		var c := Vector2((i - (cost.size() - 1) * 0.5) * step, RADIUS + 18)
		var col := cost[i]
		if not affordable:
			col.a = 0.35
		draw_rect(Rect2(c + Vector2(-2.5, -11), Vector2(5, 6)), col.lightened(0.3))
		draw_rect(Rect2(c + Vector2(-3, -13), Vector2(6, 3)), Color(0.55, 0.36, 0.2, col.a))
		draw_circle(c, 6.0, col)
