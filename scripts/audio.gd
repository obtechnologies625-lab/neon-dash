extends Node
## Autoload (registered as `SoundFx`): procedurally synthesised sound effects.
##
## No `class_name` here on purpose: Godot refuses an autoload whose name matches
## a global class.
##
## The project ships no audio files either — every blip is generated as a short
## 16-bit waveform at startup, which keeps the build tiny and avoids licensing
## any samples.

const VOICES := 8

var jump: AudioStreamWAV
var double_jump: AudioStreamWAV
var coin: AudioStreamWAV
var slide: AudioStreamWAV
var crash: AudioStreamWAV
var milestone: AudioStreamWAV
var click: AudioStreamWAV

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_player: AudioStreamPlayer
var _music_fade := 0.0


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

	jump = _sweep(420.0, 880.0, 0.11, 0.32)
	double_jump = _sweep(660.0, 1320.0, 0.13, 0.30)
	coin = _sweep(980.0, 1560.0, 0.09, 0.26)
	slide = _noise(0.16, 0.20)
	crash = _sweep(340.0, 70.0, 0.45, 0.38, true)
	milestone = _chord([660.0, 880.0, 1320.0], 0.30, 0.26)
	click = _sweep(1200.0, 1400.0, 0.05, 0.18)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

	apply_master_volume()


## Plays one of the generated effects. Silently does nothing when muted.
func play(stream: AudioStreamWAV, pitch: float = 1.0) -> void:
	if stream == null or GameSettings.sfx_volume <= 0.001:
		return

	var player := _players[_next]
	_next = (_next + 1) % _players.size()

	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = linear_to_db(GameSettings.sfx_volume)
	player.play()


## Converts a 0..1 volume into decibels for the whole sound bus.
func apply_master_volume() -> void:
	# linear_to_db(0) is -inf, so clamp to a tiny value that is effectively silent.
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(GameSettings.master_volume, 0.0001)))


## Starts a short procedural backing loop that fades in over `fade` seconds.
func play_music(fade: float = 1.2) -> void:
	if _music_player.playing:
		_music_fade = maxf(_music_fade, fade)
		return

	_music_player.stream = _generate_music_loop()
	_music_player.volume_db = -80.0 if fade > 0.0 else linear_to_db(0.35)
	_music_player.play()
	_music_fade = fade


## Fades out the backing loop and stops it.
func stop_music(fade: float = 0.6) -> void:
	_music_fade = -fade


## Call from _process(delta) in the owner scene to apply music fade in/out.
func update_music_fade(delta: float) -> void:
	if _music_fade > 0.0:
		_music_fade = maxf(_music_fade - delta, 0.0)
		var target := linear_to_db(0.35)
		_music_player.volume_db = move_toward(_music_player.volume_db, target, 80.0 * delta)
	elif _music_fade < 0.0:
		_music_fade = minf(_music_fade + delta, 0.0)
		var target := -80.0
		_music_player.volume_db = move_toward(_music_player.volume_db, target, 80.0 * delta)
		if _music_player.volume_db <= -70.0 and _music_player.playing:
			_music_player.stop()


# --- Synthesis -----------------------------------------------------------

## A tone that glides from f0 to f1, with a short attack and decay envelope.
static func _sweep(
	f0: float, f1: float, duration: float, amp: float, square: bool = false
) -> AudioStreamWAV:
	var rate := 22050
	var count := maxi(int(rate * duration), 1)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0

	for i in count:
		var t := float(i) / float(count)
		phase += TAU * lerpf(f0, f1, t) / float(rate)

		var sample := sin(phase)
		if square:
			sample = 1.0 if sample > 0.0 else -1.0

		var envelope := clampf(t / 0.02, 0.0, 1.0) * clampf((1.0 - t) / 0.3, 0.0, 1.0)
		bytes.encode_s16(i * 2, int(clampf(sample * amp * envelope, -1.0, 1.0) * 32767.0))

	return _to_stream(bytes, rate)


## Filtered noise, used for the slide / whoosh sounds.
static func _noise(duration: float, amp: float) -> AudioStreamWAV:
	var rate := 22050
	var count := maxi(int(rate * duration), 1)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var previous := 0.0

	for i in count:
		var t := float(i) / float(count)
		# Low-pass the white noise for a softer, rounder whoosh.
		previous = lerpf(previous, rng.randf_range(-1.0, 1.0), 0.22)

		var envelope := clampf(t / 0.05, 0.0, 1.0) * clampf((1.0 - t) / 0.4, 0.0, 1.0)
		bytes.encode_s16(i * 2, int(clampf(previous * amp * envelope, -1.0, 1.0) * 32767.0))

	return _to_stream(bytes, rate)


## Several tones at once, for the "speed up" fanfare.
static func _chord(freqs: Array, duration: float, amp: float) -> AudioStreamWAV:
	var rate := 22050
	var count := maxi(int(rate * duration), 1)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in count:
		var t := float(i) / float(count)
		var value := 0.0

		for f in freqs:
			# t runs 0..1 across the clip, so scale by duration to get real Hz.
			value += sin(TAU * float(f) * t * duration)

		value /= float(freqs.size())
		var envelope := clampf(t / 0.03, 0.0, 1.0) * clampf((1.0 - t) / 0.35, 0.0, 1.0)
		bytes.encode_s16(i * 2, int(clampf(value * amp * envelope, -1.0, 1.0) * 32767.0))

	return _to_stream(bytes, rate)


static func _to_stream(bytes: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream


## Very short procedural backing loop: bass + hi-hats + chord stab.
static func _generate_music_loop() -> AudioStreamWAV:
	var rate := 22050
	var bpm := 110.0
	var beat := 60.0 / bpm
	var bars := 2
	var beats := bars * 4
	var samples := maxi(int(rate * beat * beats), 1)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)

	var bass: Array[float] = [55.0, 55.0, 73.42, 73.42]
	var chord: Array[float] = [220.0, 261.63, 329.63, 0.0]

	for i in samples:
		var t := float(i) / float(rate)
		var beat_t := fmod(t, beat)
		var bar := int(fmod(t / beat, 4.0))
		var val := 0.0

		# Bass
		var bf := bass[bar]
		if bf > 0.0:
			val += sin(TAU * bf * t) * 0.35

		# Chord on beats 2 and 4 (off-beat stab)
		var chord_t := fmod(t - beat * 0.5, beat)
		if chord_t >= 0.0 and chord_t < 0.18:
			var amp := 1.0 - chord_t / 0.18
			for f in chord:
				if f > 0.0:
					val += sin(TAU * f * t) * 0.12 * amp

		# Hi-hat every 8th note
		var eighth := fmod(t, beat * 0.5)
		if eighth < 0.04:
			val += (randf() * 2.0 - 1.0) * 0.18

		var envelope := clampf(beat_t / 0.02, 0.0, 1.0) * clampf((beat - beat_t) / 0.12, 0.0, 1.0)
		var sample := clampf(val * envelope, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 24000.0))

	var stream := _to_stream(bytes, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream