extends Control
## Boot splash: flashes the VANES-AI logo and the OB Technologies credit line
## as the game opens, then hands over to the title screen. Any key skips it.

signal finished

const TOTAL := 2.6
const FADE := 0.35
const BLINK_END := 1.44
const BLINK_CYCLE := 0.36
const BLINK_ON := 0.22

const LOGO := Color("6bf5f0")
const PINK := Color("ff5f7e")
const BG := Color(0.02, 0.01, 0.06)

var _t := 0.0
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()


func is_active() -> bool:
	return not _done


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t >= TOTAL:
		_finish()
		return
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event.pressed and (
		event is InputEventKey
		or event is InputEventMouseButton
		or event is InputEventScreenTouch
	):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	_done = true
	visible = false
	finished.emit()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var fade := 1.0
	if _t > TOTAL - FADE:
		fade = (TOTAL - _t) / FADE
	fade = clampf(fade, 0.0, 1.0)

	# Three hard flashes while the game boots, then a steady glow.
	var flash := 1.0
	if _t < BLINK_END:
		flash = 1.0 if fmod(_t, BLINK_CYCLE) < BLINK_ON else 0.15

	var a := fade * flash
	draw_rect(Rect2(Vector2.ZERO, vp), Color(BG.r, BG.g, BG.b, fade))

	var c := vp * 0.5
	var mark := c + Vector2(0.0, -78.0)

	GFX.glow_circle(self, mark, 74.0, Color(LOGO.r, LOGO.g, LOGO.b, 0.5 * a), 5)
	draw_colored_polygon(
		PackedVector2Array([
			mark + Vector2(0.0, -46.0),
			mark + Vector2(40.0, 0.0),
			mark + Vector2(0.0, 46.0),
			mark + Vector2(-40.0, 0.0),
		]),
		Color(LOGO.r, LOGO.g, LOGO.b, 0.9 * a)
	)
	draw_colored_polygon(
		PackedVector2Array([
			mark + Vector2(0.0, -24.0),
			mark + Vector2(20.0, 0.0),
			mark + Vector2(0.0, 24.0),
			mark + Vector2(-20.0, 0.0),
		]),
		Color(BG.r, BG.g, BG.b, fade)
	)
	GFX.neon_line(self, mark + Vector2(-12.0, -12.0), mark + Vector2(0.0, 14.0), Color(PINK.r, PINK.g, PINK.b, a), 5.0)
	GFX.neon_line(self, mark + Vector2(12.0, -12.0), mark + Vector2(0.0, 14.0), Color(PINK.r, PINK.g, PINK.b, a), 5.0)

	var font := ThemeDB.fallback_font
	draw_string(font, c + Vector2(-300.0, 66.0), "V A N E S - A I", HORIZONTAL_ALIGNMENT_CENTER, 600.0, 54, Color(1.0, 1.0, 1.0, a))
	draw_string(font, c + Vector2(-300.0, 102.0), "made by OB TECHNOLOGIES", HORIZONTAL_ALIGNMENT_CENTER, 600.0, 22, Color(PINK.r, PINK.g, PINK.b, a))
	draw_string(font, c + Vector2(-300.0, 156.0), "presents", HORIZONTAL_ALIGNMENT_CENTER, 600.0, 16, Color(1.0, 1.0, 1.0, 0.55 * fade))
