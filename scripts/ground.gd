extends StaticBody2D
## The scrolling ground plane. Also provides the collision the player runs on.
##
## Drawn in LOCAL space: the node sits on the ground line, so local y = 0 is the
## surface the player stands on and everything below it is solid fill.

const VIEW_HALF := 520.0
const DEPTH := 240.0
const DASH_SPACING := 46.0

const SURFACE := Color("2a1d4d")
const SURFACE_TOP := Color("6bf5f0")
const DASH := Color(0.45, 0.75, 0.95, 0.35)
const GLOW := Color(0.42, 0.96, 0.94, 0.16)

var scroll := 0.0

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Glow spilling up from the surface.
	for i in 6:
		var t := float(i) / 6.0
		draw_rect(Rect2(-VIEW_HALF, -34.0 + t * 34.0, VIEW_HALF * 2.0, 34.0),
			Color(GLOW.r, GLOW.g, GLOW.b, GLOW.a * (1.0 - t) * 0.8))

	draw_rect(Rect2(-VIEW_HALF, 0.0, VIEW_HALF * 2.0, DEPTH), SURFACE)

	# Bright cap and a thin dark seam so the surface reads crisply.
	draw_rect(Rect2(-VIEW_HALF, 0.0, VIEW_HALF * 2.0, 5.0), SURFACE_TOP)
	draw_rect(Rect2(-VIEW_HALF, 5.0, VIEW_HALF * 2.0, 3.0), Color(0.06, 0.04, 0.14, 0.6))

	# Perspective grid receding into the floor.
	for i in 5:
		var y := 26.0 + float(i) * float(i) * 13.0
		draw_rect(Rect2(-VIEW_HALF, y, VIEW_HALF * 2.0, 1.5),
			Color(0.45, 0.85, 0.95, 0.10 - float(i) * 0.015))

	# Moving tick marks sell the speed.
	var offset := fposmod(scroll, DASH_SPACING)
	var dashes := int(VIEW_HALF * 2.0 / DASH_SPACING) + 3
	var index := int(floor((scroll - offset) / DASH_SPACING))

	for i in range(-1, dashes):
		var x := float(i) * DASH_SPACING - offset
		var seed_value := float(absi(index + i) * 6151 % 100) / 100.0
		if seed_value < 0.35:
			continue

		draw_rect(Rect2(x, 22.0, 4.0, 14.0 + seed_value * 30.0), DASH)

	# Occasional glowing stud.
	if fmod(_time * 0.6, 4.0) < 0.08:
		GFX.glow_circle(self, Vector2(fposmod(scroll * 0.5, VIEW_HALF * 2.0) - VIEW_HALF, 62.0),
			9.0, SURFACE_TOP, 2)