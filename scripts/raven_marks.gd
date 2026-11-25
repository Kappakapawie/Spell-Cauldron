class_name RavenMarks
extends Node2D

## The raven's marks: a small raven above the word, over the space where a letter belongs.
## A red raven = a vowel goes there, a black one = a consonant.

const SIZE := Vector2(54, 46)

## Every mark: {"at": Vector2 (its feet), "vowel": bool, "age": seconds since it appeared, "size": 0 to 1}
var marks: Array[Dictionary] = []
var mark_scale := 1.0


func _draw() -> void:
	for m in marks:
		var pop := minf(1.0, m.age / 0.25)
		var side: Vector2 = SIZE * mark_scale * m.size * (0.4 + 0.6 * pop) * (1.0 + 0.3 * sin(pop * PI))
		var bird := MenuKit.drawing("@raven_red" if m.vowel else "@raven_black")
		draw_texture_rect(bird, Rect2(m.at - Vector2(side.x * 0.5, side.y - 4.0), side), false)
