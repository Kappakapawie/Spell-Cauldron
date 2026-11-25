class_name PauseMenu
extends Control

## Shown over a level with the Menu button or Esc. The whole game stands still meanwhile.

signal restart_pressed
signal levels_pressed
signal title_pressed

var _note: Label


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var panel := PanelContainer.new()
	panel.position = Vector2(440, 150)
	panel.custom_minimum_size = Vector2(400, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := MenuKit.label("Taking a break", 32, MenuKit.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_note = MenuKit.label("", 18, Color("8a5a1a"))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.custom_minimum_size = Vector2(0, 60)  # room for two lines, so the buttons never shift
	box.add_child(_note)
	box.add_child(MenuKit.button("Keep brewing", Vector2(0, 56), close))
	box.add_child(MenuKit.button("Start these recipes over", Vector2(0, 56), restart_pressed.emit))
	box.add_child(MenuKit.button("Choose other recipes", Vector2(0, 56), levels_pressed.emit))
	box.add_child(MenuKit.button("Title screen", Vector2(0, 56), title_pressed.emit))


func open(words_brewed: int) -> void:
	if words_brewed > 0:
		_note.text = "%d level%s brewed. If you leave now,\nthese recipes start over next time." \
			% [words_brewed, "" if words_brewed == 1 else "s"]
	else:
		_note.text = "No levels brewed yet, so nothing is lost."
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	if is_inside_tree():
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(ScreenLayout.rect(), Color(0, 0, 0, 0.55))


## Also beside the 1280 x 720 on a wider screen: nothing behind it can be touched.
func _has_point(point: Vector2) -> bool:
	return ScreenLayout.rect().has_point(point)
