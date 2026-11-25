class_name CatPaw
extends Node2D

## The cat familiar's paw: it swipes down between two letters, or taps beside the word, then fades away.

const FUR := Color("e6a052")
const FUR_DARK := Color("b87333")
const PAD := Color("f2b6b0")

var claws_out := true


## Swipes through `spot`. `on_hit` is called when the paw passes between the letters.
func swipe(spot: Vector2, on_hit: Callable) -> void:
	position = spot + Vector2(34, -78)
	rotation = 0.5
	modulate.a = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(self, "position", spot + Vector2(40, -92), 0.2)  # wind up
	tw.tween_property(self, "position", spot, 0.1).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "rotation", 0.0, 0.1)
	tw.tween_callback(on_hit)
	tw.tween_property(self, "position", spot + Vector2(-24, 66), 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "rotation", -0.4, 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


## Pats twice beside the word, claws in. `on_hit` is called at the first pat.
func tap(spot: Vector2, on_hit: Callable) -> void:
	claws_out = false
	position = spot + Vector2(0, -80)
	modulate.a = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_property(self, "position", spot, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(on_hit)
	tw.tween_property(self, "scale", Vector2(1.12, 0.88), 0.06)
	tw.tween_property(self, "scale", Vector2.ONE, 0.06)
	tw.tween_property(self, "position", spot + Vector2(0, -34), 0.14)
	tw.tween_property(self, "position", spot, 0.1).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(1.12, 0.88), 0.06)
	tw.tween_property(self, "scale", Vector2.ONE, 0.06)
	tw.tween_property(self, "position", spot + Vector2(0, -60), 0.25)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _draw() -> void:
	# The arm fades out upwards, so the paw seems to reach in from nowhere.
	for i in 12:
		draw_circle(Vector2(i * 4.0, -14.0 - i * 9.0), 20.0, Color(FUR, 1.0 - i / 12.0))
	draw_circle(Vector2.ZERO, 27.0, FUR_DARK)
	draw_circle(Vector2.ZERO, 25.0, FUR)
	for x in [-18.0, -6.0, 6.0, 18.0]:
		var toe := Vector2(x, 20.0 - absf(x) * 0.35)
		if claws_out:
			draw_line(toe, toe + Vector2(0, 17), Color("fff6e0"), 3.0, true)
		draw_circle(toe, 8.5, FUR_DARK)
		draw_circle(toe, 7.5, FUR)
		draw_circle(toe + Vector2(0, 2), 3.5, PAD)
	draw_circle(Vector2(0, 0), 9.0, PAD)


## What stays behind where the cat opened a space: a see-through paw print.
class ClawMarks extends Node2D:
	const INK := Color(1.0, 0.95, 0.8, 0.42)

	var print_scale := 1.0  ## smaller in long words, like the letters
	var spots: Array[Vector2] = []:
		set(value):
			spots = value
			queue_redraw()

	func _draw() -> void:
		for s in spots:
			draw_set_transform(s, 0.0, Vector2.ONE * print_scale)
			# One big pad and four toes that never overlap, so the print is evenly see-through.
			var pad := PackedVector2Array()
			for i in 32:
				var a := i * TAU / 32.0
				pad.append(Vector2(0, 11) + Vector2(cos(a) * 16.0, sin(a) * (12.0 if sin(a) > 0.0 else 14.0)))
			draw_colored_polygon(pad, INK)
			for toe in [Vector2(-22, -5), Vector2(-9, -16), Vector2(9, -16), Vector2(22, -5)]:
				draw_circle(toe, 7.0, INK)
		draw_set_transform(Vector2.ZERO)
