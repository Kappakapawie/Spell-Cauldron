class_name GapSlot
extends Node2D

## A visible empty spot in the word (easy levels): an empty, dashed bubble.
## Holds one LetterTile once the player drops a letter on it.

var index := -1             ## position of the missing letter in the word
var tile: LetterTile = null
var glow := false

var _phase := randf() * TAU


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if tile:
		return  # the placed letter draws its own bubble
	LetterTile.draw_bubble(self, LetterTile.bob_offset(_phase), LetterTile.BUBBLE_RADIUS, true, glow)
