extends Node
## Autoload: stores the best score and lifetime coin total on disk.
##
## Uses ConfigFile, which writes to user://. On the web build that maps to the
## browser's IndexedDB, so a high score survives a page reload.

const SAVE_PATH := "user://neon_dash_save.cfg"

var best_score: int = 0
var total_coins: int = 0

var _config := ConfigFile.new()


func _ready() -> void:
	load_state()


func load_state() -> void:
	if _config.load(SAVE_PATH) != OK:
		best_score = 0
		total_coins = 0
		return

	best_score = int(_config.get_value("progress", "best_score", 0))
	total_coins = int(_config.get_value("progress", "total_coins", 0))


func submit(score: int, coins: int) -> bool:
	## Banks a finished run. Returns true when it beat the previous record.
	var beat_record := score > best_score

	best_score = maxi(best_score, score)
	total_coins += coins

	_config.set_value("progress", "best_score", best_score)
	_config.set_value("progress", "total_coins", total_coins)
	_config.save(SAVE_PATH)

	return beat_record