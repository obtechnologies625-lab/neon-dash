extends Area2D
## A collectible that scrolls in from the right.

signal collected

const FILL := Color("ffd34d")
const CORE := Color("fff3c4")
const RIM := Color("b8860b")

@onready var _shape: CollisionShape2D = $Shape

var scroll_speed := 340.0

var _spin := 0.0
var _taken := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func configure(ground_y: float, height: float, speed: float) -> void:
	scroll_speed = speed
	position.y = ground_y - height
	_spin = randf() * TAU


func _physics_process(delta: float) -> void:
	position.x -= scroll_speed * delta
	_spin += delta * 3.4

	if position.x < -100.0:
		queue_free()
		return

	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _taken or not (body.get_script() != null and body.get_script().get_path() == "res://scripts/player.gd"):
		return

	_taken = true
	collected.emit()

	# Pop-and-fade before removing itself.
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 2.1, 0.24)
	tween.tween_property(self, "modulate:a", 0.0, 0.24)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	# Squash horizontally to fake a spinning coin.
	var width := absf(cos(_spin)) * 10.0 + 2.0
	var height := 13.0

	GFX.glow_circle(self, Vector2.ZERO, 18.0, Color(FILL.r, FILL.g, FILL.b, 0.5), 3)
	GFX.neon_rect(self, Rect2(-width, -height, width * 2.0, height * 2.0), height, FILL, 3.0)
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 20, RIM, 2.0)

	if width > 5.0:
		GFX.neon_rect(
			self, Rect2(-width * 0.3, -height * 0.45, width * 0.6, height * 0.9), 3.0, CORE
		)

	# A sparkle sweeping across the face as it turns.
	var sweep := fmod(_spin, TAU) / TAU
	if sweep < 0.25:
		var x := lerpf(-width, width, sweep / 0.25)
		GFX.neon_line(self, Vector2(x, -height * 0.7), Vector2(x, height * 0.7),
			Color(1.0, 1.0, 1.0, 0.7), 1.5)