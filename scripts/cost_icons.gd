class_name CostIcons
extends Control

## A row of tiny, simple potion icons showing what a button costs
## (blue = Wisdom, pink = Vision). Sits in the lower half of its button.

var colors: Array[Color] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_costs(new_colors: Array[Color]) -> void:
	colors = new_colors
	queue_redraw()


func _draw() -> void:
	if colors.is_empty():
		return
	var zoom := ScreenLayout.icons()
	var step := 16.0 * zoom
	var start := size.x * 0.5 - step * (colors.size() - 1) * 0.5
	for i in colors.size():
		var c := Vector2(start + i * step, size.y * 0.5 + 3)
		var col := colors[i]
		if get_parent() is Button and (get_parent() as Button).disabled:
			col.a = 0.35
		# Just a round belly, a little neck and a cork: an icon, not a drawing.
		draw_rect(Rect2(c + Vector2(-2.5, -11) * zoom, Vector2(5, 6) * zoom), col.lightened(0.3))
		draw_rect(Rect2(c + Vector2(-3, -13) * zoom, Vector2(6, 3) * zoom), Color(0.55, 0.36, 0.2, col.a))
		draw_circle(c, 6.0 * zoom, col)
