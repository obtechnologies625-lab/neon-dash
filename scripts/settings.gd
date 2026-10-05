extends Node
## Autoload (registered as `GameSettings`): player preferences, persisted to disk.
##
## No `class_name` here on purpose: Godot refuses an autoload whose name matches
## a global class.
##
## Separate from HighScore on purpose: wiping your options should never cost you
## your record. Settings live in their own file so `reset_progress()` can clear
## the save without touching the controls you picked.

const SAVE_PATH := "user://neon_dash_settings.cfg"

enum Difficulty { EASY, NORMAL, HARD }

const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard"]

var difficulty: int = Difficulty.NORMAL
var screen_shake := true
var particles := true
var show_fps := false
var master_volume := 0.8
var sfx_volume := 0.9

var _config := ConfigFile.new()


func _ready() -> void:
	load_settings()


## Multiplies the world's scroll speed; also widens the scoring gap.
func speed_scale() -> float:
	match difficulty:
		Difficulty.EASY:
			return 0.78
		Difficulty.HARD:
			return 1.28
		_:
			return 1.0


func difficulty_name() -> String:
	return DIFFICULTY_NAMES[clampi(difficulty, 0, DIFFICULTY_NAMES.size() - 1)]


func set_difficulty(value: int) -> void:
	difficulty = clampi(value, 0, Difficulty.HARD)
	save_settings()


func load_settings() -> void:
	if _config.load(SAVE_PATH) != OK:
		return

	difficulty = int(_config.get_value("options", "difficulty", Difficulty.NORMAL))
	screen_shake = bool(_config.get_value("options", "screen_shake", true))
	particles = bool(_config.get_value("options", "particles", true))
	show_fps = bool(_config.get_value("options", "show_fps", false))
	master_volume = float(_config.get_value("audio", "master_volume", 0.8))
	sfx_volume = float(_config.get_value("audio", "sfx_volume", 0.9))


func save_settings() -> void:
	_config.set_value("options", "difficulty", difficulty)
	_config.set_value("options", "screen_shake", screen_shake)
	_config.set_value("options", "particles", particles)
	_config.set_value("options", "show_fps", show_fps)
	_config.set_value("audio", "master_volume", master_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	_config.save(SAVE_PATH)


## Clears the best score / coin totals, leaving preferences untouched.
func reset_progress() -> void:
	var save_file := HighScore.SAVE_PATH
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file))
	HighScore.load_state()