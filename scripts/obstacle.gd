extends Area2D
## A hazard that scrolls in from the right. Reports a hit through `hit_player`.
##
## Every kind gets its own silhouette, colour and collision shape so it can be
## recognised at a glance, and each animates slightly so the scene feels alive.

signal hit_player

enum Kind {
	SPIKE,        ## Jump over it.
	DOUBLE_SPIKE, ## Wider spike, still a jump.
	PILLAR,       ## Tall block, jump it.
	LOW_BAR,      ## Duck under it.
	DRONE,        ## Hovering, weaves up and down.
	LASER,        ## Emitter tower; the beam fires on a cycle.
	GATE,         ## Wall with a window: jump or slide to fit through.
}

## Half the laser beam's length either side of its tower, in pixels.
const BEAM_HALF := 180.0

const METAL := Color("2b2148")
const METAL_HI := Color("4a3870")
const DANGER := Color("ff4f6d")
const WARN := Color("ffb03a")
const CYAN := Color("6bf5f0")
const EYE := Color("ffe066")

@onready var _shape: CollisionShape2D = $Shape
@onready var _beam: CollisionShape2D = $BeamShape

var scroll_speed := 340.0
var kind: int = Kind.SPIKE

var _phase := 0.0
var _base_y := 0.0
var _time := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Sets up the obstacle's type, height and matching collision shape.
func configure(new_kind: int, ground_y: float, speed: float) -> void:
	kind = new_kind
	scroll_speed = speed
	_base_y = ground_y
	position.y = ground_y
	_phase = randf() * TAU
	_time = randf() * 2.0
	_configure_shape()


func _configure_shape() -> void:
	var box := RectangleShape2D.new()
	var ball := CircleShape2D.new()
	var slab := RectangleShape2D.new()

	match kind:
		Kind.SPIKE:
			box.size = Vector2(32.0, 36.0)
			_shape.shape = box
			_shape.position = Vector2(0.0, -18.0)
		Kind.DOUBLE_SPIKE:
			box.size = Vector2(58.0, 36.0)
			_shape.shape = box
			_shape.position = Vector2(0.0, -18.0)
		Kind.PILLAR:
			box.size = Vector2(40.0, 86.0)
			_shape.shape = box
			_shape.position = Vector2(0.0, -43.0)
		Kind.LOW_BAR:
			# Low enough to clip a standing runner, but a slide clears it.
			box.size = Vector2(130.0, 26.0)
			_shape.shape = box
			_shape.position = Vector2(0.0, -51.0)
		Kind.DRONE:
			ball.radius = 17.0
			_shape.shape = ball
			_shape.position = Vector2(0.0, -50.0)
		Kind.LASER:
			# The tower is harmless (its collider is switched off below); only
			# the separate beam collider kills, so a slide can pass the tower.
			box.size = Vector2(26.0, 34.0)
			_shape.shape = box
			_shape.position = Vector2(0.0, -17.0)
		Kind.GATE:
			# A thick lintel above slide height: duck under it, or clear it
			# with a full jump.
			slab.size = Vector2(96.0, 70.0)
			_shape.shape = slab
			_shape.position = Vector2(0.0, -69.0)

	_shape.set_deferred("disabled", kind == Kind.LASER)

	# The beam collider only exists for the laser, and starts retracted.
	_beam.shape = null
	_beam.disabled = true
	if kind == Kind.LASER:
		var beam := RectangleShape2D.new()
		# Spans chest height: a standing runner is hit, a slide passes under.
		beam.size = Vector2(BEAM_HALF * 2.0, 30.0)
		_beam.shape = beam
		_beam.position = Vector2(0.0, -45.0)


func _physics_process(delta: float) -> void:
	_time += delta
	position.x -= scroll_speed * delta

	if kind == Kind.DRONE:
		_phase += delta * 2.6
		position.y = _base_y - 50.0 + sin(_phase) * 12.0

	# The laser beam is only lethal while it is extended.
	if kind == Kind.LASER:
		_beam.set_deferred("disabled", not beam_active())

	# A laser's beam reaches BEAM_HALF past its tower, so keep it until it is
	# fully off screen.
	var despawn_x := -180.0 - (BEAM_HALF if kind == Kind.LASER else 0.0)
	if position.x < despawn_x:
		queue_free()
		return

	queue_redraw()


## True while the laser's beam is extended.
func beam_active() -> bool:
	return fmod(_time, 2.4) < 1.15


func _on_body_entered(body: Node2D) -> void:
	if body.get_script() != null and body.get_script().get_path() == "res://scripts/player.gd":
		hit_player.emit()


# --- Procedural drawing ---------------------------------------------------

func _draw() -> void:
	match kind:
		Kind.SPIKE:
			_draw_spike(0.0, 1.0)
		Kind.DOUBLE_SPIKE:
			_draw_spike(-14.0, 1.0)
			_draw_spike(14.0, 1.0)
		Kind.PILLAR:
			_draw_pillar()
		Kind.LOW_BAR:
			_draw_low_bar()
		Kind.DRONE:
			_draw_drone()
		Kind.LASER:
			_draw_laser()
		Kind.GATE:
			_draw_gate()


## A single spike with a hot glowing edge and a reflective highlight.
func _draw_spike(offset_x: float, scale: float) -> void:
	GFX.glow_circle(self, Vector2(offset_x, -16.0 * scale), 26.0 * scale,
		Color(DANGER.r, DANGER.g, DANGER.b, 0.45), 3)

	var points := PackedVector2Array([
		Vector2(offset_x - 17.0 * scale, 0.0),
		Vector2(offset_x, -36.0 * scale),
		Vector2(offset_x + 17.0 * scale, 0.0),
	])

	draw_colored_polygon(points, METAL)
	GFX.neon_line(self, points[0], points[1], DANGER, 2.5)
	GFX.neon_line(self, points[1], points[2], DANGER, 2.5)
	GFX.neon_line(self, points[2], points[0], DANGER, 2.5)

	# Bright inner edge catching the light.
	GFX.neon_line(self,
		Vector2(offset_x - 1.0, -28.0 * scale),
		Vector2(offset_x - 6.0, -6.0 * scale),
		Color(1.0, 0.75, 0.82, 0.8), 2.0)


func _draw_pillar() -> void:
	GFX.glow_circle(self, Vector2(0.0, -43.0), 52.0, Color(DANGER.r, DANGER.g, DANGER.b, 0.3), 3)

	GFX.neon_rect(self, Rect2(-21.0, -86.0, 42.0, 86.0), 6.0, METAL)
	GFX.neon_rect(self, Rect2(-15.0, -80.0, 30.0, 74.0), 4.0, METAL_HI)

	# Diagonal hazard stripes.
	for i in 5:
		var y := -76.0 + float(i) * 16.0
		GFX.neon_line(self, Vector2(-13.0, y), Vector2(13.0, y + 11.0),
			Color(DANGER.r, DANGER.g, DANGER.b, 0.65), 3.5)

	# Cap light.
	var blink := 0.5 + 0.5 * sin(_time * 6.0)
	draw_circle(Vector2(0.0, -84.0), 3.5, Color(DANGER.r, DANGER.g, DANGER.b, 0.4 + blink * 0.6))


func _draw_low_bar() -> void:
	GFX.glow_circle(self, Vector2(0.0, -51.0), 62.0, Color(WARN.r, WARN.g, WARN.b, 0.28), 3)

	# Support posts down to the ground.
	GFX.neon_rect(self, Rect2(-60.0, -64.0, 9.0, 64.0), 3.0, METAL)
	GFX.neon_rect(self, Rect2(51.0, -64.0, 9.0, 64.0), 3.0, METAL)

	GFX.neon_rect(self, Rect2(-65.0, -64.0, 130.0, 26.0), 5.0, METAL)

	for i in 5:
		var x := -58.0 + float(i) * 26.0
		GFX.neon_line(self, Vector2(x, -62.0), Vector2(x + 12.0, -42.0),
			Color(WARN.r, WARN.g, WARN.b, 0.8), 4.0)

	_draw_duck_hint(Vector2(0.0, -74.0))


func _draw_gate() -> void:
	GFX.glow_circle(self, Vector2(0.0, -62.0), 70.0, Color(DANGER.r, DANGER.g, DANGER.b, 0.26), 3)

	# Short posts either side of a low window. They are decoration only; the
	# lethal collider is the heavy lintel above (y -104..-34).
	GFX.neon_rect(self, Rect2(-48.0, -34.0, 14.0, 34.0), 3.0, METAL)
	GFX.neon_rect(self, Rect2(34.0, -34.0, 14.0, 34.0), 3.0, METAL)

	# The lintel: duck under it, or jump clean over it.
	GFX.neon_rect(self, Rect2(-48.0, -104.0, 96.0, 70.0), 5.0, METAL)
	GFX.neon_rect(self, Rect2(-42.0, -98.0, 84.0, 58.0), 4.0, METAL_HI)

	for i in 5:
		var x := -38.0 + float(i) * 18.0
		GFX.neon_line(self, Vector2(x, -44.0), Vector2(x + 10.0, -60.0),
			Color(DANGER.r, DANGER.g, DANGER.b, 0.75), 3.5)

	_draw_duck_hint(Vector2(0.0, -116.0))


## A bobbing hover drone with spinning rotor and a thruster flame.
func _draw_drone() -> void:
	GFX.glow_circle(self, Vector2(0.0, 6.0), 26.0, Color(EYE.r, EYE.g, EYE.b, 0.35), 3)

	# Rotor blur.
	for i in 2:
		var half := 26.0 - float(i) * 6.0
		draw_line(Vector2(-half, -16.0), Vector2(half, -16.0),
			Color(0.8, 0.9, 1.0, 0.35 - float(i) * 0.1), 2.5)
	draw_line(Vector2(0.0, -16.0), Vector2(0.0, -10.0), METAL_HI, 3.0)

	draw_circle(Vector2.ZERO, 17.0, METAL)
	draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 26, DANGER, 2.5)

	# Scanning eye that tracks left.
	var eye := 0.6 + 0.4 * sin(_time * 4.0)
	draw_circle(Vector2(-4.0, 2.0), 6.0, Color(EYE.r, EYE.g, EYE.b, eye))

	# Thruster.
	var flame := 8.0 + sin(_time * 22.0) * 2.5
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-5.0, 16.0),
			Vector2(5.0, 16.0),
			Vector2(0.0, 16.0 + flame),
		]),
		Color(1.0, 0.55, 0.3, 0.85)
	)


## An emitter tower that charges up, then fires a beam at chest height.
func _draw_laser() -> void:
	var firing := beam_active()
	# Charge builds during the 1.25s the beam is retracted.
	var charge := 1.0 if firing else clampf(1.0 - fmod(_time, 2.4) / 1.25, 0.0, 1.0)
	var beam_y := -45.0

	# Emitter housing.
	GFX.neon_rect(self, Rect2(-15.0, -34.0, 30.0, 34.0), 5.0, METAL)
	GFX.neon_rect(self, Rect2(-9.0, -30.0, 18.0, 24.0), 3.0, METAL_HI)
	GFX.glow_circle(self, Vector2(0.0, -34.0), 12.0,
		Color(WARN.r, WARN.g, WARN.b, 0.35 + charge * 0.5), 3)
	draw_circle(Vector2(0.0, -34.0), 4.0,
		Color(WARN.r, WARN.g, WARN.b, 0.4 + charge * 0.6))

	if not firing:
		# Telegraph: a thin dotted guide line so the player can read the timing.
		for i in 6:
			var x := -BEAM_HALF + float(i) * 62.0
			GFX.neon_line(self, Vector2(x, beam_y), Vector2(x + 18.0, beam_y),
				Color(WARN.r, WARN.g, WARN.b, 0.12 + charge * 0.3), 1.5)
		return

	# The live beam.
	var half := BEAM_HALF
	GFX.neon_rect(self, Rect2(-half, beam_y - 5.0, half * 2.0, 10.0), 5.0,
		Color(1.0, 0.45, 0.55, 0.95))
	GFX.neon_line(self, Vector2(-half, beam_y), Vector2(half, beam_y),
		Color(1.0, 0.85, 0.9, 0.9), 2.0)


## Small down-arrow telling the player to duck.
func _draw_duck_hint(at: Vector2) -> void:
	var hint := Color(1.0, 0.75, 0.55, 0.85)
	var bob := sin(_time * 4.0) * 2.0
	GFX.neon_line(self, at + Vector2(0.0, bob), at + Vector2(0.0, bob + 14.0), hint, 3.0)
	GFX.neon_line(self, at + Vector2(0.0, bob), at + Vector2(-7.0, bob + 8.0), hint, 3.0)
	GFX.neon_line(self, at + Vector2(0.0, bob), at + Vector2(7.0, bob + 8.0), hint, 3.0)