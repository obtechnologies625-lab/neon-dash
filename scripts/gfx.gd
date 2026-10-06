extends Node
## Shared procedural-art helpers.
##
## This project ships no image files: every visual is generated at runtime from
## polygons, circles and small generated textures. Keeping the maths here stops
## it being copy-pasted across player/obstacle/coin.
##
## All draw_* helpers take the CanvasItem as the first argument and must be
## called from inside that node's own _draw().

## Polygon points for a rounded rectangle, ready for draw_colored_polygon().
static func rounded_rect(rect: Rect2, radius: float, steps: int = 4) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)

	var corners := [
		[Vector2(rect.position.x + r, rect.position.y + r), PI, PI * 1.5],
		[Vector2(rect.end.x - r, rect.position.y + r), PI * 1.5, TAU],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0, PI * 0.5],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5, PI],
	]

	for corner in corners:
		var centre: Vector2 = corner[0]
		for i in steps + 1:
			var angle := lerpf(corner[1], corner[2], float(i) / float(steps))
			points.append(centre + Vector2(cos(angle), sin(angle)) * r)

	return points


## Filled rounded rectangle with a soft outer glow.
static func neon_rect(
	ci: CanvasItem, rect: Rect2, radius: float, color: Color, glow: float = 0.0
) -> void:
	if glow > 0.0:
		for i in 3:
			var t := float(i) / 3.0
			var grown := rect.grow(glow * (1.0 - t * 0.6))
			ci.draw_colored_polygon(
				rounded_rect(grown, radius + glow * 0.5),
				Color(color.r, color.g, color.b, 0.13)
			)
	ci.draw_colored_polygon(rounded_rect(rect, radius), color)


## A line drawn in three passes so it reads as glowing neon.
static func neon_line(
	ci: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float
) -> void:
	ci.draw_line(from, to, Color(color.r, color.g, color.b, 0.16), width * 3.5)
	ci.draw_line(from, to, Color(color.r, color.g, color.b, 0.42), width * 2.0)
	ci.draw_line(from, to, color, width)


## Soft round bloom behind an object.
static func glow_circle(
	ci: CanvasItem, center: Vector2, radius: float, color: Color, layers: int = 4
) -> void:
	for i in layers:
		var t := float(i) / float(layers)
		ci.draw_circle(
			center,
			radius * (1.0 - t * 0.72),
			Color(color.r, color.g, color.b, color.a * 0.15)
		)


## Soft radial dot, used as the texture for particle systems.
static func soft_dot(size: int = 24) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5

	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
			var a := clampf(1.0 - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))

	return ImageTexture.create_from_image(image)


## Spawns a short-lived dust puff and cleans it up automatically.
static func dust(
	parent: Node, at: Vector2, color: Color, amount: int = 12, force: float = 1.0
) -> CPUParticles2D:
	var puff := CPUParticles2D.new()
	puff.texture = soft_dot(16)
	puff.amount = amount
	puff.one_shot = true
	puff.emitting = true
	puff.lifetime = 0.5
	puff.explosiveness = 1.0
	puff.direction = Vector2(0.0, -1.0)
	puff.spread = 75.0
	puff.initial_velocity_min = 40.0 * force
	puff.initial_velocity_max = 160.0 * force
	puff.gravity = Vector2(0.0, 300.0)
	puff.damping_min = 30.0
	puff.damping_max = 80.0
	puff.scale_amount_min = 0.12
	puff.scale_amount_max = 0.4
	puff.color = color
	puff.position = at

	parent.add_child(puff)

	if parent.is_inside_tree():
		parent.get_tree().create_timer(1.4).timeout.connect(puff.queue_free)

	return puff


## Spawns an expanding shockwave ring that fades and frees itself.
static func ring(parent: Node, at: Vector2, color: Color, max_radius: float = 46.0) -> Node:
	var ring = Node2D.new()
	ring.set_script(preload("res://scripts/ring.gd"))
	ring.position = at
	ring.color = color
	ring.max_radius = max_radius
	parent.add_child(ring)
	return ring