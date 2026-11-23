class_name PotionShelf
extends Control

## Shows how many potions of one kind you have, as little flask icons.

const PER_ROW := 5
const STEP := 22.0
const MAX_SHOWN := 10

var liquid := Color.WHITE
var count := 0:
	set(value):
		count = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(PER_ROW * STEP + 4, 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Where the next potion would appear (used for the "fly to shelf" animation).
func slot_global_position(index: int) -> Vector2:
	return global_position + _slot(mini(index, MAX_SHOWN - 1))


func _slot(i: int) -> Vector2:
	var row := i / PER_ROW
	var col := i % PER_ROW
	return Vector2(size.x - STEP * 0.5 - col * STEP, 18 + row * 28)


func _draw() -> void:
	var shown := mini(count, MAX_SHOWN)
	var extra := count - shown
	if extra > 0:
		shown -= 1  # make room for the "+N" label
	for i in shown:
		PotionArt.draw_flask(self, _slot(i), 1.0, liquid)
	if extra > 0:
		var font := ThemeDB.fallback_font
		var p := _slot(shown) + Vector2(-11, 6)
		draw_string(font, p, "+%d" % (extra + 1), HORIZONTAL_ALIGNMENT_CENTER, 22, 14, Color("fff3d6"))
