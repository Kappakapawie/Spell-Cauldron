class_name PotionArt
extends RefCounted

## Shared drawing + data for potions.

const WISDOM := "wisdom"   ## tells you what the word means
const VISION := "vision"   ## shows the picture in the brew, a bit clearer each time

const COLORS := {
	WISDOM: Color("6f8cff"),
	VISION: Color("e46bd0"),
}


## A small round flask with a cork. `s` = scale (1.0 is about 20 px tall).
static func draw_flask(ci: CanvasItem, c: Vector2, s: float, liquid: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-3, -15) * s, Vector2(6, 8) * s), Color(0.85, 0.9, 1.0, 0.85))
	ci.draw_rect(Rect2(c + Vector2(-4, -19) * s, Vector2(8, 5) * s), Color("8b5a2b"))
	ci.draw_circle(c, 9.5 * s, Color(0.85, 0.9, 1.0, 0.55))
	ci.draw_circle(c + Vector2(0, 1) * s, 7.5 * s, liquid)
	ci.draw_circle(c + Vector2(-3, -3) * s, 2.0 * s, Color(1, 1, 1, 0.75))
