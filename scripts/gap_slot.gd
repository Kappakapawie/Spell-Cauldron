class_name GapSlot
extends Node2D

## A visible empty spot in the word (easy levels). Holds one LetterTile.

var index := -1             ## position of the missing letter in the word
var tile: LetterTile = null
var glow := false:
	set(value):
		glow = value
		queue_redraw()


func _draw() -> void:
	var half := LetterTile.SIZE * 0.5
	var rect := Rect2(-half, -half, LetterTile.SIZE, LetterTile.SIZE)
	draw_rect(rect, Color(1, 0.95, 0.8, 0.35 if glow else 0.12), true)
	var c := Color(1, 0.95, 0.8, 1.0 if glow else 0.75)
	var pts: Array[Vector2] = [
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half), Vector2(-half, -half)
	]
	for i in 4:
		draw_dashed_line(pts[i], pts[i + 1], c, 3.0, 9.0)
