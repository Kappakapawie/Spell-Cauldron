class_name PotionShelf
extends Control

## Shows how many potions of one kind you have, as little flask icons,
## plus faint empty slots for the room that is left on the shelf.

const PER_ROW := 5
const STEP := 22.0

var liquid := Color.WHITE
var count := 0:
	set(value):
		count = value
		queue_redraw()
var capacity := 3:
	set(value):
		capacity = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(PER_ROW * STEP + 4, 60) * ScreenLayout.icons()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Where the potion with this index sits (used for the "fly to shelf" animation).
func slot_global_position(index: int) -> Vector2:
	return global_position + _slot(clampi(index, 0, capacity - 1))


func _slot(i: int) -> Vector2:
	var row := i / PER_ROW
	var col := i % PER_ROW
	var zoom := ScreenLayout.icons()
	var in_row := mini(PER_ROW, capacity - row * PER_ROW)  # in the middle, under its icon
	return Vector2(size.x * 0.5 + (col - (in_row - 1) * 0.5) * STEP * zoom, (20 + row * 28) * zoom)


func _draw() -> void:
	var zoom := ScreenLayout.icons()
	for i in capacity:
		if i < count:
			PotionArt.draw_flask(self, _slot(i), zoom, liquid)
		else:
			# Empty slot: a faint outline of a flask.
			var c := _slot(i)
			draw_arc(c, 9.5 * zoom, 0.0, TAU, 20, Color(1, 0.95, 0.85, 0.22), 1.5, true)
			draw_rect(Rect2(c + Vector2(-3, -15) * zoom, Vector2(6, 6) * zoom), Color(1, 0.95, 0.85, 0.22), false, 1.0)
