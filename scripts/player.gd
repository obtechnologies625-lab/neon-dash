extends CharacterBody2D
## The runner.
##
## IMPORTANT: the player never moves horizontally. `run_speed` only controls how
## fast the *world* scrolls past (main.gd moves obstacles and the backdrop) and
## how hard the legs pump. The runner stays pinned to its lane, otherwise it
## would simply run off the right edge of the screen.
##
## All art is drawn procedurally via _draw(); there are no image assets.

signal died
signal jumped(is_double: bool)
signal landed
signal slid

const GRAVITY := 2600.0
const FALL_GRAVITY := 3400.0
const MAX_FALL_SPEED := 1500.0
const JUMP_VELOCITY := -900.0
const DOUBLE_JUMP_VELOCITY := -760.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
const SLIDE_DURATION := 0.45
const DEATH_BOUNCE := Vector2(-260.0, -520.0)

const BODY := Color("6bf5f0")
const BODY_DEEP := Color("1c7f96")
const BODY_EDGE := Color("0b0a1c")
const EYE := Color("ffffff")
const SCARF := Color("ff5f7e")
const CORE := Color("fff27a")
const DUST := Color("8fd8ff")

@onready var _stand_shape: CollisionShape2D = $StandShape
@onready var _slide_shape: CollisionShape2D = $SlideShape

## Horizontal scroll speed of the world. The runner does NOT use this to move.
var run_speed := 340.0
## How far the world has scrolled; streams the motion trail behind the runner.
var world_scroll := 0.0
var alive := true

## False while a menu is open, so keys used to navigate it don't jump or slide.
var input_enabled := true

var _coyote := 0.0
var _buffer := 0.0
var _slide_timer := 0.0
var _jumps_left := 2
var _sliding := false
var _was_on_floor := true
var _phase := 0.0
var _squash := Vector2.ONE
var _blink := 0.0
var _trail: Array[Dictionary] = []
var _particles_enabled := true
var _touch_start_pos := Vector2.ZERO
var _touch_start_time := 0.0


func _input(event: InputEvent) -> void:
	if not input_enabled or not alive:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start_pos = event.position
			_touch_start_time = Time.get_ticks_msec() / 1000.0
		else:
			var dy: float = event.position.y - _touch_start_pos.y
			var dx: float = absf(event.position.x - _touch_start_pos.x)
			var dt := maxf((Time.get_ticks_msec() / 1000.0) - _touch_start_time, 0.001)

			if dy > 24.0 and dy / dt > 0.6 and is_on_floor():
				_slide_timer = SLIDE_DURATION
			elif dy < 20.0 and dx < 40.0 and dt < 0.35:
				_buffer = JUMP_BUFFER


func _ready() -> void:
	floor_snap_length = 8.0
	_set_sliding(false)


func set_particles_enabled(enabled: bool) -> void:
	_particles_enabled = enabled


func reset(to: Vector2) -> void:
	alive = true
	position = to
	velocity = Vector2.ZERO
	_phase = 0.0
	_jumps_left = 2
	_coyote = 0.0
	_buffer = 0.0
	_slide_timer = 0.0
	_squash = Vector2.ONE
	_trail.clear()
	_set_sliding(false)
	modulate = Color.WHITE
	rotation = 0.0
	visible = true


func is_sliding() -> bool:
	return _sliding


func kill() -> void:
	if not alive:
		return

	alive = false
	_set_sliding(false)
	velocity = DEATH_BOUNCE
	_squash = Vector2(1.35, 0.7)
	if _particles_enabled:
		GFX.dust(get_parent(), position, BODY, 22, 1.6)
	died.emit()


func _physics_process(delta: float) -> void:
	if not alive:
		_process_death(delta)
		return

	# Legs pump faster as the world scrolls quicker.
	var intensity := clampf(run_speed / 520.0, 0.35, 2.2)
	_phase += delta * 13.0 * intensity
	_blink = maxf(_blink - delta, 0.0)

	# --- The runner is anchored: no horizontal movement at all. ---
	velocity.x = 0.0

	if input_enabled and Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = COYOTE_TIME
		_jumps_left = 2
	else:
		_coyote = maxf(_coyote - delta, 0.0)

	_process_slide(delta)

	if _buffer > 0.0:
		if _coyote > 0.0:
			_do_jump(JUMP_VELOCITY, 1.0, false)
			# A ground jump spends the first jump, leaving exactly one air jump.
			_jumps_left = 1
			_buffer = 0.0
			_coyote = 0.0
		elif _jumps_left > 0:
			_jumps_left -= 1
			_do_jump(DOUBLE_JUMP_VELOCITY, 0.82, true)
			_buffer = 0.0

	# Variable jump height: release early to hop, hold to go higher.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45

	var gravity := GRAVITY if velocity.y < 0.0 else FALL_GRAVITY
	if _sliding and on_floor:
		gravity *= 0.35
	velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)

	move_and_slide()
	# Re-query after moving so a landing is detected on the frame it happens.
	_update_squash(delta, is_on_floor())
	_update_trail(delta)


func _process_slide(delta: float) -> void:
	var was_sliding := _sliding

	if input_enabled and is_on_floor() and Input.is_action_pressed("slide"):
		_slide_timer = SLIDE_DURATION

	_slide_timer = maxf(_slide_timer - delta, 0.0)
	_set_sliding(_slide_timer > 0.0)

	if _sliding and not was_sliding:
		slid.emit()
		if _particles_enabled:
			GFX.dust(get_parent(), position + Vector2(0.0, 22.0), DUST, 10, 0.8)


func _do_jump(power: float, squash: float, is_double: bool) -> void:
	velocity.y = power
	_squash = Vector2(1.0 / squash, squash)
	_blink = 0.12

	if _particles_enabled:
		GFX.dust(get_parent(), position + Vector2(0.0, 24.0), DUST, 14 if not is_double else 18, 1.0)
		GFX.ring(get_parent(), position + Vector2(0.0, 24.0), BODY, 40.0 if not is_double else 54.0)

	jumped.emit(is_double)


func _update_squash(delta: float, on_floor: bool) -> void:
	if on_floor and not _was_on_floor:
		_squash = Vector2(1.4, 0.62)
		landed.emit()
		if _particles_enabled:
			GFX.dust(get_parent(), position + Vector2(0.0, 26.0), DUST, 16, 1.2)
			GFX.ring(get_parent(), position + Vector2(0.0, 26.0), DUST, 34.0)

	_was_on_floor = on_floor

	if _sliding:
		_squash = _squash.lerp(Vector2(1.25, 0.72), delta * 14.0)
	else:
		_squash = _squash.lerp(Vector2.ONE, delta * 9.0)


func _update_trail(delta: float) -> void:
	# Motion trail: a pose history that streams behind the runner as the world
	# scrolls, instead of stacking up at the runner's fixed lane x.
	if run_speed > 120.0 and not _sliding:
		_trail.append({"y": position.y, "scroll": world_scroll})
		if _trail.size() > 9:
			_trail.remove_at(0)
	else:
		_trail.clear()


func _process_death(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
	velocity.y = minf(velocity.y + GRAVITY * 0.85 * delta, MAX_FALL_SPEED)
	move_and_slide()
	_squash = _squash.lerp(Vector2.ONE, delta * 5.0)
	_trail.clear()


func _set_sliding(on: bool) -> void:
	if on == _sliding:
		return

	_sliding = on
	_stand_shape.disabled = on
	_slide_shape.disabled = not on


# --- Procedural drawing ---------------------------------------------------

func _draw() -> void:
	_draw_trail()

	# Squash/stretch is applied around the runner's centre.
	draw_set_transform(Vector2.ZERO, 0.0, _squash)

	_draw_scarf()
	_draw_legs()
	_draw_body()
	_draw_speed_lines()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Faded copies of the runner trailing behind, implying motion.
func _draw_trail() -> void:
	for i in _trail.size():
		var t := float(i + 1) / float(_trail.size())
		var alpha := 0.05 + t * 0.16
		var behind := world_scroll - float(_trail[i]["scroll"])
		var offset := Vector2(-behind, float(_trail[i]["y"]) - position.y)
		GFX.glow_circle(self, offset, 20.0 - i, Color(BODY.r, BODY.g, BODY.b, alpha), 2)
		draw_circle(offset, 15.0 - i * 0.8, Color(BODY.r, BODY.g, BODY.b, alpha * 0.5))


func _draw_scarf() -> void:
	# Tapered ribbon trailing behind, wobbling as the runner moves.
	for i in 5:
		var t := float(i) / 4.0
		var wobble := sin(_phase * 0.9 - t * 1.5) * (3.0 + t * 5.0)
		var lift := -18.0 + t * 4.0
		var anchor := Vector2(-9.0 - t * 10.0, lift + wobble)
		var tip := anchor + Vector2(-11.0, 7.0 + wobble * 0.4)

		var color := SCARF
		color.a = 0.92 - t * 0.6
		draw_colored_polygon(
			PackedVector2Array([Vector2(-3.0, -21.0), anchor, tip]),
			color
		)


func _draw_legs() -> void:
	if _sliding:
		# Tucked legs while sliding.
		GFX.neon_rect(self, Rect2(-22.0, 15.0, 18.0, 11.0), 5.0, BODY_DEEP)
		GFX.neon_rect(self, Rect2(4.0, 15.0, 18.0, 11.0), 5.0, BODY_DEEP)
		return

	# Classic two-leg run cycle: one leg forward while the other is back.
	var airborne := not is_on_floor()
	var swing_a := 0.0 if airborne else sin(_phase) * 11.0
	var swing_b := 0.0 if airborne else sin(_phase + PI) * 11.0
	var knee_a := 4.0 if swing_a > 0.0 else 0.0
	var knee_b := 4.0 if swing_b > 0.0 else 0.0

	GFX.neon_rect(self, Rect2(-15.0 + swing_a * 0.5, 9.0, 9.0, 17.0 - knee_a), 4.5, BODY_DEEP)
	GFX.neon_rect(self, Rect2(6.0 + swing_b * 0.5, 9.0, 9.0, 17.0 - knee_b), 4.5, BODY_DEEP)


func _draw_body() -> void:
	# Torso: dark shell with a bright inner plate.
	GFX.neon_rect(self, Rect2(-16.0, -7.0, 32.0, 27.0), 10.0, BODY_EDGE)
	GFX.neon_rect(self, Rect2(-13.0, -4.0, 26.0, 21.0), 8.0, BODY)

	# Glowing core on the chest.
	var pulse := 0.75 + 0.25 * sin(_phase * 1.5)
	GFX.glow_circle(self, Vector2(0.0, 7.0), 9.0, Color(CORE.r, CORE.g, CORE.b, pulse), 3)
	draw_circle(Vector2(0.0, 7.0), 3.2, Color(CORE.r, CORE.g, CORE.b, 0.55 + 0.45 * pulse))

	# Head.
	draw_circle(Vector2(0.0, -16.0), 12.5, BODY_EDGE)
	draw_circle(Vector2(0.0, -17.0), 10.0, BODY)

	# Visor.
	GFX.neon_rect(self, Rect2(-9.5, -23.0, 19.0, 11.0), 5.5, BODY_EDGE)

	# Eyes — they blink just after a jump and every few seconds.
	var blinking := _blink > 0.0 or fmod(_phase, 7.0) < 0.15
	var eye_h := 1.6 if blinking else 4.0
	GFX.neon_rect(self, Rect2(-7.0, -19.0 - eye_h * 0.5, 5.5, eye_h), 1.5, EYE)
	GFX.neon_rect(self, Rect2(1.5, -19.0 - eye_h * 0.5, 5.5, eye_h), 1.5, EYE)


func _draw_speed_lines() -> void:
	# Streaks behind the runner once the world is scrolling quickly.
	var k := clampf((run_speed - 320.0) / 500.0, 0.0, 1.0)
	if k <= 0.02:
		return

	for i in 4:
		var y := -20.0 + float(i) * 12.0
		var length := 16.0 + k * 22.0
		var x := -26.0 - float(i) * 4.0
		draw_line(
			Vector2(x, y),
			Vector2(x - length, y),
			Color(0.6, 0.95, 1.0, k * 0.35),
			2.0
		)