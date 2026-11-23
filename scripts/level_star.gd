class_name LevelStar
extends Control

## Small star under a level button showing your best points for that level.
## Solid glowing gold = conquered (a perfect run: every reward potion became points).

var played := false
var best := 0
var conquered := false


func _init() -> void:
	custom_minimum_size = Vector2(46, 42)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_record(p_played: bool, p_best: int, p_conquered: bool) -> void:
	played = p_played
	best = p_best
	conquered = p_conquered
	tooltip_text = "Conquered!" if conquered else ""
	queue_redraw()


func _process(_delta: float) -> void:
	if conquered:
		queue_redraw()  # gentle shimmer


func _draw() -> void:
	if not played:
		return
	var c := size * 0.5
	var r := 21.0
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rad := r if i % 2 == 0 else r * 0.55
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	var font := ThemeDB.fallback_font
	var fs := 13 if best < 100 else 11
	var baseline := c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5 + 1.0
	if conquered:
		var shimmer := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0)
		draw_circle(c, r + 3.0, Color(1.0, 0.85, 0.3, 0.12 + 0.12 * shimmer))
		draw_colored_polygon(pts, Color("ffd45c"))
		pts.append(pts[0])
		draw_polyline(pts, Color("fff0b0"), 1.5, true)
		draw_string(font, Vector2(0, baseline), str(best), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color("4a2c17"))
	else:
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.4, 0.15))
		pts.append(pts[0])
		draw_polyline(pts, Color(1.0, 0.85, 0.4, 0.8), 1.5, true)
		draw_string(font, Vector2(0, baseline), str(best), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color("fff3d6"))
