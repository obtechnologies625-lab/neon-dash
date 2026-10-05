extends Node
## Autoload: registers every input action in code.
##
## Doing it in GDScript (instead of by hand in project.godot) means the controls
## are defined in one readable place and can be re-tuned easily.

var _touch_start_y := 0.0
var _touch_start_pos := Vector2.ZERO
var _touch_start_time := 0.0


const ACTIONS := {
	"jump": [KEY_SPACE, KEY_W, KEY_UP, KEY_ENTER],
	"slide": [KEY_S, KEY_DOWN, KEY_CTRL, KEY_SHIFT],
	"restart": [KEY_R],
	"pause": [KEY_ESCAPE, KEY_P],
	"settings": [KEY_O],
}


func _enter_tree() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)

		for keycode in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)

		# Left click / tap also jumps, so the game is playable on touch screens.
		if action == "jump":
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			InputMap.action_add_event(action, click)