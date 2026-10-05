extends Node2D
## Parallax night-city backdrop, drawn procedurally.
##
## Layers move at different fractions of `scroll`, which main.gd feeds every
## frame. Nothing here collides with the player; it only sets the mood.

const VIEW_WIDTH := 960.0
const VIEW_HEIGHT := 540.0
const GROUND_Y := 430.0

const SKY_TOP := Color("150e33")
const SKY_BOTTOM := Color("4a1f6b")
const MOON := Color("fff3d0")
const CLOUD := Color(0.72, 0.52, 0.86, 0.30)
const BUILDING_FAR := Color("241a45")
const BUILDING_NEAR := Color("1b1334")
const WINDOW := Color(1.0, 0.86, 0.45, 0.75)

var scroll := 0.0

var _time := 0.0
var _clouds: Array[Dictionary] = []
var _stars: Array[Dictionary] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260910

	for i in 26:
		_stars.append({
			"pos": Vector2(rng.randf_range(0.0, VIEW_WIDTH), rng.randf_range(10.0, 300.0)),
			"radius": rng.randf_range(0.7, 1.9),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.6, 2.0),
		})

	for i in 6:
		_clouds.append({
			"offset": rng.randf_range(0.0, VIEW_WIDTH),
			"y": rng.randf_range(40.0, 220.0),
			"scale": rng.randf_range(0.7, 1.5),
			"parallax": rng.randf_range(0.04, 0.12),
		})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_stars()
	_draw_moon()
	_draw_clouds()
	_draw_buildings(0.08, 288.0, 58.0, BUILDING_FAR, 0.45, 4)
	_draw_buildings(0.18, 336.0, 44.0, BUILDING_NEAR, 0.8, 5)
	_draw_ground_haze()


## A soft band of light where the city meets the ground, adding depth.
func _draw_ground_haze() -> void:
	for i in 8:
		var t := float(i) / 8.0
		draw_rect(
			Rect2(0.0, GROUND_Y - 70.0 + t * 70.0, VIEW_WIDTH, 12.0),
			Color(0.35, 0.22, 0.55, 0.05)
		)


func _draw_sky() -> void:
	var bands := 30
	var band_height := VIEW_HEIGHT / float(bands)

	for i in bands:
		var t := float(i) / float(bands - 1)
		var color := SKY_TOP.lerp(SKY_BOTTOM, t)
		draw_rect(Rect2(0.0, float(i) * band_height, VIEW_WIDTH, band_height + 1.0), color)


func _draw_stars() -> void:
	for star in _stars:
		var pos: Vector2 = star["pos"]
		var twinkle := 0.55 + 0.45 * sin(_time * star["speed"] + star["phase"])
		var wrapped := Vector2(fposmod(pos.x - scroll * 0.05, VIEW_WIDTH), pos.y)
		draw_circle(wrapped, star["radius"], Color(1.0, 1.0, 1.0, twinkle * 0.8))


func _draw_moon() -> void:
	var moon := Vector2(770.0, 110.0)

	# Wide bloom, then tighter rings, for a soft halo.
	GFX.glow_circle(self, moon, 92.0, Color(1.0, 0.95, 0.8, 0.55), 6)

	draw_circle(moon, 44.0, MOON)

	# Craters, clipped visually by drawing them slightly darker than the disc.
	var crater := Color(0.85, 0.78, 0.62, 0.55)
	draw_circle(moon + Vector2(-14.0, -10.0), 8.0, crater)
	draw_circle(moon + Vector2(12.0, 8.0), 6.0, crater)
	draw_circle(moon + Vector2(-6.0, 20.0), 5.0, crater)
	draw_circle(moon + Vector2(20.0, -16.0), 3.5, crater)

	# Rim light on the lower-right edge.
	draw_arc(moon, 43.0, -0.6, 1.4, 18, Color(1.0, 1.0, 0.92, 0.5), 2.0)


func _draw_clouds() -> void:
	for cloud in _clouds:
		var x := fposmod(cloud["offset"] - scroll * cloud["parallax"], VIEW_WIDTH + 220.0) - 110.0
		var y: float = cloud["y"]
		var s: float = cloud["scale"]

		draw_circle(Vector2(x, y), 30.0 * s, CLOUD)
		draw_circle(Vector2(x + 28.0 * s, y + 6.0 * s), 22.0 * s, CLOUD)
		draw_circle(Vector2(x - 28.0 * s, y + 8.0 * s), 18.0 * s, CLOUD)


func _draw_buildings(parallax: float, base_y: float, width: float, color: Color, lit: float, columns: int) -> void:
	var spacing := width + 12.0
	var first := int(floor((scroll * parallax) / spacing))

	for i in range(first - 1, first + columns + 2):
		var seed_value := float(absi(i) * 7919 % 1000) / 1000.0
		var height := 70.0 + seed_value * 150.0
		var x := float(i) * spacing - scroll * parallax

		draw_rect(Rect2(x, base_y - height, width, height + 40.0), color)

		# Rooftop antenna on the taller towers.
		if height > 140.0:
			GFX.neon_line(self, Vector2(x + width * 0.5, base_y - height),
				Vector2(x + width * 0.5, base_y - height - 18.0),
				Color(0.45, 0.6, 0.95, 0.5), 1.5)

		# Deterministic window pattern per building index.
		if lit <= 0.0:
			continue

		for row in range(4):
			for col in range(2):
				var key := (absi(i) * 31 + row * 7 + col * 13) % 5
				if key > 2:
					continue

				var wx := x + 9.0 + float(col) * (width * 0.42)
				var wy := base_y - height + 14.0 + float(row) * 24.0
				var flicker := 0.75 + 0.25 * sin(_time * 1.5 + float(key) * 2.1 + float(i))
				var lit_color := WINDOW
				lit_color.a = WINDOW.a * lit * flicker
				draw_rect(Rect2(wx, wy, 7.0, 11.0), lit_color)