class_name StartChoice
extends Control

## Go on with the saved game, or start a new one. Asked before the title screen when the game is started with
## "-- --ask-reset" ("Play Spell Cauldron (choose reset).bat"); the title's Reset game button opens "are you sure?" at once.

signal new_game_pressed

var _title: Label
var _note: Label
var _first: Button
var _second: Button
var _status := ""
var _only_ask := false  ## opened with the title's button: there is no first page
var _asking := false  ## "are you sure?" is shown


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var panel := PanelContainer.new()
	panel.position = Vector2(400, 215)
	panel.custom_minimum_size = Vector2(480, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_title = MenuKit.label("", 32, MenuKit.INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_note = MenuKit.label("", 18, Color("8a5a1a"))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.custom_minimum_size = Vector2(0, 60)
	box.add_child(_note)
	# "Yes" is not where "Reset" was, so a double click never resets anything.
	_first = MenuKit.button("", Vector2(0, 60), _on_first)
	box.add_child(_first)
	_second = MenuKit.button("", Vector2(0, 60), _on_second)
	box.add_child(_second)


func open(stars: float, knowledge: int) -> void:
	_status = "%s star%s and %d knowledge" % [MenuKit.points_text(stars), "" if stars == 1.0 else "s", knowledge]
	_only_ask = false
	visible = true
	get_tree().paused = true
	_show_page(false)


## Only "are you sure?".
func ask() -> void:
	_only_ask = true
	visible = true
	get_tree().paused = true
	_show_page(true)


func close() -> void:
	visible = false
	get_tree().paused = false


## The save could not be put aside, so nothing was reset.
func show_problem(text: String) -> void:
	_show_page(_only_ask)
	_note.text = text


func _show_page(asking: bool) -> void:
	_asking = asking
	if asking:
		_title.text = "Really start over?"
		_note.text = "All stars, knowledge, potions and spells are reset.\nYour old save is kept as a backup file."
		_first.text = "Yes, start over"
		_second.text = "No, keep my game"
	else:
		_title.text = "Welcome back!"
		_note.text = "Your game has %s." % _status
		_first.text = "Continue"
		_second.text = "Reset the game"


func _on_first() -> void:
	if _asking:
		new_game_pressed.emit()
	else:
		close()


func _on_second() -> void:
	if _only_ask:
		close()
	else:
		_show_page(not _asking)


## Esc keeps the game.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if _asking and not _only_ask:
			_show_page(false)
		else:
			close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(ScreenLayout.rect(), Color(0, 0, 0, 0.55))


## Also beside the 1280 x 720 on a wider screen: nothing behind it can be touched.
func _has_point(point: Vector2) -> bool:
	return ScreenLayout.rect().has_point(point)
