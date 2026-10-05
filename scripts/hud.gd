extends Control
## All on-screen text: score bar, title card, and the game-over card.
##
## The UI is assembled in _ready() instead of in the scene file, so the whole
## interface can be read and tweaked from one place.

## Emitted whenever the player changes an option in the settings menu.
signal settings_changed

enum Row { DIFFICULTY, SCREEN_SHAKE, PARTICLES, SHOW_FPS, MASTER_VOLUME, SFX_VOLUME, RESET }

const ROW_COUNT := 7
const FONT_TITLE := 62
const FONT_BIG := 34
const FONT_MED := 20
const FONT_SMALL := 16

const TEXT_COLOR := Color("f2f0ff")
const ACCENT := Color("6bf5f0")
const GOLD := Color("ffd34d")
const DIM := Color(0.72, 0.70, 0.88, 1.0)

var _score_value: Label
var _best_value: Label
var _coin_value: Label
var _speed_value: Label

var _title_card: Control
var _title_hint: Label
var _over_card: Control
var _over_score: Label
var _over_best: Label
var _over_coins: Label
var _over_record: Label

var _banner: Label
var _banner_time := 0.0

var _fps_label: Label
var _settings_card: Control
var _settings_rows: Array[Label] = []
var _settings_index := 0
var _reset_armed := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_score_bar()
	_build_title_card()
	_build_game_over_card()
	_build_banner()
	_build_fps_label()
	_build_settings_card()


# --- Construction --------------------------------------------------------

func _panel(color: Color = Color(0.05, 0.03, 0.12, 0.82)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_stylebox(color))
	return panel


func _make_stylebox(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_color = Color(0.42, 0.96, 0.94, 0.35)
	style.set_border_width_all(2)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style


func _label(text: String, size: int, color: Color = TEXT_COLOR) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, float(height))
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _centered_card() -> PanelContainer:
	var card := _panel()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 190.0
	card.offset_right = -190.0
	card.offset_top = 130.0
	card.offset_bottom = -140.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	return card


func _build_score_bar() -> void:
	var bar := _panel(Color(0.05, 0.03, 0.12, 0.55))
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 16.0
	bar.offset_right = -16.0
	bar.offset_top = 12.0
	bar.offset_bottom = 78.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	_score_value = _label("0", FONT_BIG, ACCENT)
	_best_value = _label("BEST 0", FONT_MED, GOLD)
	_coin_value = _label("COINS 0", FONT_MED, TEXT_COLOR)
	_speed_value = _label("", FONT_SMALL, DIM)

	var score_box := VBoxContainer.new()
	score_box.add_child(_label("SCORE", FONT_SMALL, DIM))
	score_box.add_child(_score_value)

	var best_box := VBoxContainer.new()
	best_box.add_child(_label("BEST", FONT_SMALL, DIM))
	best_box.add_child(_best_value)

	var coin_box := VBoxContainer.new()
	coin_box.add_child(_label("COINS", FONT_SMALL, DIM))
	coin_box.add_child(_coin_value)

	var speed_box := VBoxContainer.new()
	speed_box.add_child(_label("SPEED", FONT_SMALL, DIM))
	speed_box.add_child(_speed_value)

	for child in [score_box, best_box, coin_box, speed_box]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(child)


func _build_title_card() -> void:
	_title_card = _centered_card()

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	_title_card.add_child(box)

	var title := _label("NEON DASH", FONT_TITLE, ACCENT)
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)

	box.add_child(_label("an endless runner", FONT_MED, DIM))
	box.add_child(_spacer(18))

	var controls := _label(
		"SPACE / W / UP  —  jump (twice for a double jump)\nS / DOWN / CTRL  —  slide\nESC  —  pause     R  —  restart     O  —  settings",
		FONT_MED,
		TEXT_COLOR
	)
	box.add_child(controls)

	box.add_child(_spacer(22))
	_title_hint = _label("press SPACE to start", FONT_BIG, GOLD)
	box.add_child(_title_hint)


func _build_game_over_card() -> void:
	_over_card = _centered_card()
	_over_card.visible = false

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	_over_card.add_child(box)

	var title := _label("CRASHED", FONT_TITLE, Color("ff5470"))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)

	box.add_child(_spacer(10))
	_over_score = _label("SCORE 0", FONT_BIG, ACCENT)
	box.add_child(_over_score)

	_over_best = _label("BEST 0", FONT_MED, GOLD)
	box.add_child(_over_best)

	_over_coins = _label("COINS 0", FONT_MED, TEXT_COLOR)
	box.add_child(_over_coins)

	_over_record = _label("NEW RECORD!", FONT_MED, Color("8dff9f"))
	_over_record.visible = false
	box.add_child(_over_record)

	box.add_child(_spacer(18))
	box.add_child(_label("press R or SPACE to run again   ·   O for settings", FONT_MED, DIM))


# --- Runtime API ---------------------------------------------------------

func show_title() -> void:
	_title_card.visible = true
	_over_card.visible = false
	_banner.text = ""
	_banner.modulate.a = 0.0
	_best_value.text = "BEST %d" % HighScore.best_score
	_coin_value.text = "COINS %d" % HighScore.total_coins


func hide_cards() -> void:
	_title_card.visible = false
	_over_card.visible = false


func show_game_over(score: int, coins: int, is_record: bool) -> void:
	_title_card.visible = false
	_over_card.visible = true

	_over_score.text = "SCORE %d" % score
	_over_best.text = "BEST %d" % HighScore.best_score
	_over_coins.text = "COINS %d" % coins
	_over_record.visible = is_record


func set_paused(paused: bool) -> void:
	_over_card.visible = paused
	if paused:
		_over_score.text = "PAUSED"
		_over_best.text = "ESC resume   ·   O settings"
		_over_coins.text = ""
		_over_record.visible = false


func update_hud(score: int, coins: int, speed: float) -> void:
	_score_value.text = str(score)
	_best_value.text = "BEST %d" % HighScore.best_score
	_coin_value.text = "COINS %d" % coins
	_speed_value.text = "%.1fx" % speed


## Shows a short, fading message (used for milestones like "SPEED UP").
func flash(text: String, color: Color = ACCENT) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	_banner_time = 1.8


func _process(delta: float) -> void:
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time / 0.6, 0.0, 1.0)

	if _title_hint != null and _title_card.visible:
		_title_hint.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() / 260.0)

	_fps_label.visible = GameSettings.show_fps
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


# --- Settings menu -------------------------------------------------------

func is_settings_open() -> bool:
	return _settings_card.visible


func open_settings() -> void:
	_settings_index = 0
	_reset_armed = false
	_settings_card.visible = true
	_refresh_settings()


func close_settings() -> void:
	_settings_card.visible = false
	_reset_armed = false


## Handles one input event while the menu is open (called from main.gd).
func settings_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		_move_selection(1)
	elif event.is_action_pressed("ui_up"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_left", true):
		_adjust(-1)
	elif event.is_action_pressed("ui_right", true):
		_adjust(1)
	elif event.is_action_pressed("ui_accept"):
		_activate()


func _move_selection(step: int) -> void:
	_settings_index = posmod(_settings_index + step, ROW_COUNT)
	_reset_armed = false
	_refresh_settings()


## Left / right: step a value down or up.
func _adjust(direction: int) -> void:
	match _settings_index:
		Row.DIFFICULTY:
			GameSettings.set_difficulty(GameSettings.difficulty + direction)
		Row.SCREEN_SHAKE:
			GameSettings.screen_shake = not GameSettings.screen_shake
		Row.PARTICLES:
			GameSettings.particles = not GameSettings.particles
		Row.SHOW_FPS:
			GameSettings.show_fps = not GameSettings.show_fps
		Row.MASTER_VOLUME:
			GameSettings.master_volume = _stepped(GameSettings.master_volume, direction)
			SoundFx.apply_master_volume()
		Row.SFX_VOLUME:
			GameSettings.sfx_volume = _stepped(GameSettings.sfx_volume, direction)
		_:
			return

	_commit_settings()


## Enter / space: cycle or toggle the row, or confirm the reset.
func _activate() -> void:
	match _settings_index:
		Row.DIFFICULTY:
			GameSettings.set_difficulty(posmod(GameSettings.difficulty + 1, 3))
			_commit_settings()
		Row.SCREEN_SHAKE, Row.PARTICLES, Row.SHOW_FPS:
			_adjust(1)
		Row.RESET:
			if _reset_armed:
				_reset_armed = false
				GameSettings.reset_progress()
				_best_value.text = "BEST %d" % HighScore.best_score
				_coin_value.text = "COINS 0"
				SoundFx.play(SoundFx.crash)
			else:
				_reset_armed = true
			_refresh_settings()


func _stepped(value: float, direction: int) -> float:
	return clampf(snappedf(value + 0.1 * float(direction), 0.1), 0.0, 1.0)


func _commit_settings() -> void:
	GameSettings.save_settings()
	SoundFx.play(SoundFx.click)
	settings_changed.emit()
	_refresh_settings()


func _row_text(row: int) -> String:
	match row:
		Row.DIFFICULTY:
			return "DIFFICULTY      ◄ %s ►" % GameSettings.difficulty_name().to_upper()
		Row.SCREEN_SHAKE:
			return "SCREEN SHAKE      %s" % _on_off(GameSettings.screen_shake)
		Row.PARTICLES:
			return "PARTICLES      %s" % _on_off(GameSettings.particles)
		Row.SHOW_FPS:
			return "SHOW FPS      %s" % _on_off(GameSettings.show_fps)
		Row.MASTER_VOLUME:
			return "MASTER VOLUME      %s" % _meter(GameSettings.master_volume)
		Row.SFX_VOLUME:
			return "EFFECTS VOLUME      %s" % _meter(GameSettings.sfx_volume)
		_:
			return "press ENTER again to ERASE best score" if _reset_armed else "RESET BEST SCORE"


func _on_off(value: bool) -> String:
	return "ON" if value else "OFF"


func _meter(value: float) -> String:
	var filled := roundi(value * 10.0)
	return "%s%s  %d%%" % ["■".repeat(filled), "□".repeat(10 - filled), roundi(value * 100.0)]


func _refresh_settings() -> void:
	for i in _settings_rows.size():
		var selected := i == _settings_index
		var row := _settings_rows[i]
		row.text = ("►  %s  ◄" if selected else "%s") % _row_text(i)

		var color := TEXT_COLOR
		if selected:
			color = Color("ff5470") if (i == Row.RESET and _reset_armed) else GOLD
		elif i == Row.RESET:
			color = DIM
		row.add_theme_color_override("font_color", color)


func _build_fps_label() -> void:
	_fps_label = _label("", FONT_SMALL, DIM)
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -130.0
	_fps_label.offset_right = -22.0
	_fps_label.offset_top = 84.0
	_fps_label.offset_bottom = 106.0
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.visible = false
	add_child(_fps_label)


func _build_settings_card() -> void:
	# Near-opaque so the title / game-over card underneath doesn't show through.
	_settings_card = _panel(Color(0.05, 0.03, 0.12, 0.97))
	_settings_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_card.offset_left = 150.0
	_settings_card.offset_right = -150.0
	_settings_card.offset_top = 56.0
	_settings_card.offset_bottom = -56.0
	_settings_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_card.visible = false
	add_child(_settings_card)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	_settings_card.add_child(box)

	box.add_child(_label("SETTINGS", FONT_BIG, ACCENT))
	box.add_child(_spacer(6))

	for i in ROW_COUNT:
		var row := _label("", FONT_MED)
		_settings_rows.append(row)
		box.add_child(row)

	box.add_child(_spacer(8))
	box.add_child(_label("UP / DOWN  select     LEFT / RIGHT  change\nENTER  toggle     O or ESC  close", FONT_SMALL, DIM))


func _build_banner() -> void:
	_banner = _label("", FONT_BIG, ACCENT)
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 96.0
	_banner.offset_bottom = 146.0
	_banner.modulate.a = 0.0
	add_child(_banner)