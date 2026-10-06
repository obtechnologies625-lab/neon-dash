extends Node2D
## Neon Dash — game loop, spawning and difficulty.
##
## The player sits at a fixed x position; the world scrolls past instead.
## Obstacles and coins are spawned off-screen to the right and freed once they
## leave on the left, so the node count stays small enough for the web build.

enum State { TITLE, PLAYING, GAME_OVER }

const GROUND_Y := 430.0
const PLAYER_START := Vector2(210.0, 404.0)
const SPAWN_X := 1040.0

const BASE_SPEED := 340.0
const MAX_SPEED := 820.0
const SPEED_RAMP := 15.0
const SCORE_PER_PIXEL := 0.09
const COIN_SCORE := 25

const OBSTACLE_SCENE := preload("res://scenes/obstacle.tscn")
const COIN_SCENE := preload("res://scenes/coin.tscn")

enum Kind { SPIKE, DOUBLE_SPIKE, PILLAR, LOW_BAR, DRONE, LASER, GATE }

@onready var _world = $World
@onready var _ground = $Ground
@onready var _entities = $Entities
@onready var _player = $Entities/Player
@onready var _hud = $UI/HUD
@onready var _camera = $Camera2D
@onready var _fg = $Foreground
@onready var _splash = $SplashLayer/Splash

var _state: int = State.TITLE
var _elapsed := 0.0
var _distance := 0.0
var _score := 0
var _coins := 0
var _scroll := 0.0
var _speed := BASE_SPEED
var _spawn_timer := 1.2
var _shake := 0.0
var _next_milestone := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()

	# Children inherit ALWAYS from this node. Main must keep running while the
	# tree is paused (to hear the unpause key), but the world itself must freeze.
	for node in [_world, _ground, _entities]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE

	_player.died.connect(_on_player_died)
	_player.jumped.connect(_on_player_jumped)
	_player.slid.connect(_on_player_slid)
	_hud.settings_changed.connect(_apply_settings)
	_player.reset(PLAYER_START)
	_hud.show_title()
	_apply_settings()

	# The boot splash owns the screen (and the keyboard) until it finishes.
	_player.input_enabled = false
	_splash.finished.connect(_on_splash_done)


func _unhandled_input(event: InputEvent) -> void:
	if _splash.is_active():
		return

	# While the settings menu is open it owns the keyboard.
	if _hud.is_settings_open():
		if event.is_action_pressed("settings") or event.is_action_pressed("pause"):
			_set_settings_open(false)
		else:
			_hud.settings_input(event)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("settings"):
		# Not mid-run: only from the title, the game-over card, or while paused.
		if _state != State.PLAYING or get_tree().paused:
			_set_settings_open(true)
		return

	if event.is_action_pressed("pause"):
		_toggle_pause()
		return

	if event.is_action_pressed("restart"):
		if _state != State.TITLE:
			_start_run()
		return

	if event.is_action_pressed("jump"):
		if _state == State.TITLE or _state == State.GAME_OVER:
			_start_run()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	match _state:
		State.TITLE:
			_process_attract(delta)
		State.PLAYING:
			_process_run(delta)
		State.GAME_OVER:
			_process_death_recovery(delta)

	_sync_entity_speed()
	_update_camera(delta)


## Title screen: slow idle scroll so the background is alive.
func _process_attract(delta: float) -> void:
	_speed = lerpf(_speed, 150.0, delta * 2.0)
	_advance_scroll(delta)


func _process_run(delta: float) -> void:
	_elapsed += delta

	# Difficulty ramps smoothly toward a hard cap.
	var target := minf(BASE_SPEED + SPEED_RAMP * _elapsed, MAX_SPEED) * GameSettings.speed_scale()
	_speed = lerpf(_speed, target, delta * 1.5)

	_distance += _speed * delta
	_score = int(_distance * SCORE_PER_PIXEL)

	_advance_scroll(delta)
	_update_spawning(delta)
	_update_milestones()

	_hud.update_hud(_score, _coins, _speed / BASE_SPEED)

	SoundFx.update_music_fade(delta)


## After a crash everything coasts to a stop.
func _process_death_recovery(delta: float) -> void:
	_speed = move_toward(_speed, 0.0, 900.0 * delta)
	_advance_scroll(delta)
	SoundFx.update_music_fade(delta)


func _advance_scroll(delta: float) -> void:
	_scroll += _speed * delta
	_world.scroll = _scroll
	_ground.scroll = _scroll
	_fg.scroll = _scroll

	# On the title screen the runner waits at the start line.
	_player.run_speed = 0.0 if _state == State.TITLE else _speed


## Entities spawned before a speed change need the new speed too.
func _sync_entity_speed() -> void:
	for child in _entities.get_children():
		if child is Area2D:
			child.scroll_speed = _speed


func _update_camera(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 2.2, 0.0)
		_camera.offset = Vector2(
			randf_range(-1.0, 1.0) * _shake * 13.0,
			randf_range(-1.0, 1.0) * _shake * 13.0
		)
	else:
		_camera.offset = _camera.offset.lerp(Vector2.ZERO, delta * 9.0)


# --- Spawning ------------------------------------------------------------

func _update_spawning(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return

	# Gap shrinks as the run gets harder, but never below a fair window.
	var interval := maxf(1.35 - _elapsed * 0.022, 0.72)
	_spawn_timer = interval * randf_range(0.88, 1.15)
	_spawn_wave()


func _spawn_wave() -> void:
	# A wave is one obstacle, sometimes trailed by coins as a reward.
	var kind := _pick_kind()
	_spawn_obstacle(kind, SPAWN_X)

	# A laser sweeps a long stretch of ground, so it gets no low coins (they
	# would sit inside the beam) and no chained follow-up hazard.
	var is_laser := kind == Kind.LASER

	# Coins go to the LEFT of the obstacle (smaller x = reached later), so they
	# reward a clean jump or slide rather than leading into the hazard.
	if randf() < 0.65:
		var start := SPAWN_X - randf_range(70.0, 100.0)
		if is_laser or randf() < 0.5:
			# High arc: collect these mid-jump.
			var height := randf_range(104.0, 150.0)
			_spawn_coin(start, height)
			for i in 2:
				_spawn_coin(start - 46.0 * float(i + 1), height - 26.0 * float(i + 1))
		else:
			# Low line: grab them while still running or while sliding.
			_spawn_coin(start, randf_range(30.0, 48.0))
			_spawn_coin(start - 46.0, randf_range(30.0, 48.0))
			_spawn_coin(start - 92.0, randf_range(30.0, 48.0))

	# Occasionally chain a second, clearly separated obstacle further left.
	if not is_laser and _elapsed > 8.0 and randf() < 0.26:
		_spawn_obstacle(_pick_kind(), SPAWN_X - randf_range(250.0, 360.0))


func _pick_kind() -> int:
	# Unlock trickier hazards gradually so the run has a learning curve.
	var pool: Array[int] = [Kind.SPIKE]

	if _elapsed > 6.0:
		pool.append(Kind.DOUBLE_SPIKE)
		pool.append(Kind.PILLAR)
	if _elapsed > 14.0:
		pool.append(Kind.LOW_BAR)
	if _elapsed > 22.0:
		pool.append(Kind.DRONE)
		pool.append(Kind.PILLAR)
	if _elapsed > 26.0:
		pool.append(Kind.GATE)
	if _elapsed > 34.0:
		pool.append(Kind.LASER)

	return pool[randi() % pool.size()]


func _spawn_obstacle(kind: int, x: float) -> void:
	var obstacle = OBSTACLE_SCENE.instantiate()
	_entities.add_child(obstacle)
	obstacle.configure(kind, GROUND_Y, _speed)
	obstacle.position.x = x
	obstacle.hit_player.connect(_on_obstacle_hit)


func _spawn_coin(x: float, height: float) -> void:
	var coin = COIN_SCENE.instantiate()
	_entities.add_child(coin)
	coin.configure(GROUND_Y, height, _speed)
	coin.position.x = x
	coin.collected.connect(_on_coin_collected)


func _update_milestones() -> void:
	var level := int(_elapsed / 30.0) + 1
	if level > _next_milestone:
		_next_milestone = level
		_hud.flash("SPEED UP", Color("8dff9f"))
		SoundFx.play(SoundFx.milestone)


# --- Events --------------------------------------------------------------

func _on_coin_collected() -> void:
	_coins += 1
	_score += COIN_SCORE
	SoundFx.play(SoundFx.coin)


func _on_player_jumped(is_double: bool) -> void:
	SoundFx.play(SoundFx.double_jump if is_double else SoundFx.jump)


func _on_player_slid() -> void:
	SoundFx.play(SoundFx.slide)


func _on_obstacle_hit() -> void:
	if _state != State.PLAYING:
		return

	_state = State.GAME_OVER
	_shake = 1.0 if GameSettings.screen_shake else 0.0
	SoundFx.play(SoundFx.crash)
	SoundFx.stop_music()
	_player.kill()


func _on_splash_done() -> void:
	_player.input_enabled = true


## Pushes the current GameSettings onto the things that cache them.
func _apply_settings() -> void:
	_player.set_particles_enabled(GameSettings.particles)


func _set_settings_open(open: bool) -> void:
	if open:
		_hud.open_settings()
	else:
		_hud.close_settings()

	# Menu keys (arrows, space, enter) must not also make the runner jump.
	_player.input_enabled = not open


func _on_player_died() -> void:
	var is_record := HighScore.submit(_score, _coins)
	_hud.show_game_over(_score, _coins, is_record)


func _toggle_pause() -> void:
	if _state != State.PLAYING:
		return

	var paused := not get_tree().paused
	get_tree().paused = paused
	_hud.set_paused(paused)


# --- Flow ----------------------------------------------------------------

func _start_run() -> void:
	get_tree().paused = false
	_hud.set_paused(false)

	for child in _entities.get_children():
		if child is Area2D:
			child.queue_free()

	_state = State.PLAYING
	_elapsed = 0.0
	_distance = 0.0
	_score = 0
	_coins = 0
	_speed = BASE_SPEED
	_spawn_timer = 0.9
	_next_milestone = 1
	_shake = 0.0
	_camera.offset = Vector2.ZERO

	_player.reset(PLAYER_START)
	_hud.hide_cards()
	_hud.update_hud(0, 0, 1.0)
	SoundFx.play_music()


func _notification(what: int) -> void:
	# Auto-pause when the window loses focus mid-run.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _state == State.PLAYING:
		if not get_tree().paused:
			get_tree().paused = true
			_hud.set_paused(true)