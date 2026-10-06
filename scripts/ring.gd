extends Node2D
## Expanding shockwave ring that fades out and frees itself.

var color := Color("6bf5f0")
var max_radius := 46.0
var squash := 0.45
var life := 0.38
var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / life, 0.0, 1.0)
	var ease_out := 1.0 - (1.0 - t) * (1.0 - t)
	var r := 6.0 + ease_out * max_radius
	var a := (1.0 - t) * 0.85

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(color.r, color.g, color.b, a * 0.3), 6.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(color.r, color.g, color.b, a), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
