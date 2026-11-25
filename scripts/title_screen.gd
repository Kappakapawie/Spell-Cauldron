class_name TitleScreen
extends Control

## The title screen: the game's name floats in bubbles over the witch's hut.
## The hut and cauldron behind it are drawn by main.gd, which also lets you
## stir the cauldron here to start (so the first thing you learn is stirring).

signal play_pressed
signal book_pressed
signal quit_pressed
signal reset_pressed


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # stirring must reach the cauldron
	_add_word("SPELL", Vector2(640, 72), 1.2, 8.0)
	_add_word("CAULDRON", Vector2(640, 180), 1.05, 20.0)
	var reset := MenuKit.button("Reset game", Vector2(ScreenLayout.pick(150, 170), 46), reset_pressed.emit)
	reset.position = Vector2(16 - ScreenLayout.edge(), 12)
	add_child(reset)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 24)
	bar.position = Vector2(0, 627)
	bar.size = Vector2(1280, 64)
	add_child(bar)
	bar.add_child(MenuKit.button("Spell book", Vector2(200, 60), book_pressed.emit))
	var play := MenuKit.button("Play", Vector2(260, 60), play_pressed.emit)
	play.add_theme_font_size_override("font_size", 30)
	play.add_theme_color_override("font_color", MenuKit.GOLD)
	bar.add_child(play)
	var quit := MenuKit.button("Quit", Vector2(200, 60), quit_pressed.emit)
	quit.visible = not OS.has_feature("web")  # a browser tab is closed by the browser
	bar.add_child(quit)


## Letters on a gentle arch: golden like the ones you place yourself.
func _add_word(word: String, center: Vector2, scl: float, arch: float) -> void:
	var step := (LetterTile.BUBBLE_RADIUS * 2.0 + 6.0) * scl
	var mid := (word.length() - 1) * 0.5
	for i in word.length():
		var t := LetterTile.new(word[i], true)
		t.in_word = true
		t.show_kind = false
		var off := (i - mid) / mid
		t.position = center + Vector2((i - mid) * step, off * off * arch)
		t.scale = Vector2.ONE * scl
		add_child(t)
