class_name LevelStar
extends Control

## A star with a number in it: your best result for a recipe book (picker, HUD, end screen),
## or all your stars together.
## Solid glowing gold = conquered (a perfect run).

var played := false
var best := 0.0
var conquered := false
var radius := 21.0
var show_empty := false    ## draw a faint outline for a book that was never finished
var on_parchment := false  ## darker lines and number for light backgrounds


func _init() -> void:
	custom_minimum_size = Vector2(46, 42)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_record(p_played: bool, p_best: float, p_conquered: bool) -> void:
	played = p_played
	best = p_best
	conquered = p_conquered
	queue_redraw()


func _process(_delta: float) -> void:
	if conquered:
		queue_redraw()  # gentle shimmer


func _draw() -> void:
	if not played and not show_empty:
		return
	var c := size * 0.5
	var r := radius
	if not played:
		var line_pts := _points(c, r)
		line_pts.append(line_pts[0])
		draw_polyline(line_pts, Color(1.0, 0.9, 0.7, 0.3), maxf(1.5, r / 14.0), true)
		return
	var ink := Color("4a2c17")
	var edge := Color("b8842a")
	var fill := Color("ffd45c")
	if conquered:
		var shimmer := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0)
		draw_circle(c, r + 3.0, Color(1.0, 0.85, 0.3, 0.12 + 0.12 * shimmer))
		if not on_parchment:
			edge = Color("fff0b0")
	else:
		fill = Color(1.0, 0.82, 0.35, 0.45 if on_parchment else 0.15)
		if not on_parchment:
			edge = Color(1.0, 0.85, 0.4, 0.8)
			ink = Color("fff3d6")
	draw_star(self, c, r, best, fill, edge, ink)


static func _points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rad := r if i % 2 == 0 else r * 0.55
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts


## The star symbol, for anything that shows a number of stars.
static func draw_star(ci: CanvasItem, c: Vector2, r: float, value: float, fill := Color("ffd45c"),
		edge := Color("b8842a"), ink := Color("4a2c17")) -> void:
	var pts := _points(c, r)
	ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	ci.draw_polyline(pts, edge, maxf(1.5, r / 14.0), true)
	var font := ThemeDB.fallback_font
	var text := MenuKit.points_text(value)
	var fs := roundi((13 if text.length() < 4 else (10 if text.length() == 4 else 8)) * r / 21.0)
	var baseline := c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5 + 1.0
	ci.draw_string(font, Vector2(c.x - r, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, ink)
