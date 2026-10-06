extends Node2D
## Foreground railing that whips past faster than the play field, adding depth.
## Kept below the runner's feet so it never blocks gameplay.

const VIEW_WIDTH := 960.0

var scroll := 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rail_y := 508.0

	draw_rect(Rect2(0.0, rail_y, VIEW_WIDTH, 32.0), Color(0.04, 0.03, 0.10, 0.9))
	GFX.neon_line(self, Vector2(0.0, rail_y), Vector2(VIEW_WIDTH, rail_y), Color(1.0, 0.45, 0.75, 0.5), 2.0)

	var spacing := 210.0
	var parallax := 1.35
	var first := int(floor((scroll * parallax) / spacing))

	for i in range(first - 1, first + 7):
		var x := float(i) * spacing - scroll * parallax
		draw_rect(Rect2(x, rail_y - 34.0, 8.0, 34.0), Color(0.05, 0.04, 0.13, 0.9))
		GFX.glow_circle(self, Vector2(x + 4.0, rail_y - 38.0), 9.0, Color(1.0, 0.45, 0.75, 0.45), 3)
		draw_circle(Vector2(x + 4.0, rail_y - 38.0), 3.5, Color(1.0, 0.78, 0.92, 0.9))
