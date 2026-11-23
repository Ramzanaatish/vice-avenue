extends Node

## Creates the audio buses if missing and routes playback.
## Buses: Music, SFX, Dialogue, Ambience.
## Step 7 (Phase 15): named SFX from res://audio/*.wav —
## all clips are synthesized in-house (see step7/gen_audio.py),
## no downloads, no licensed assets. Playback is skipped while
## muted (the buses are also silenced by SettingsManager).

const BUSES: Array[String] = ["Music", "SFX", "Dialogue", "Ambience"]

# name -> [path, bus]
const SOUNDS := {
	"ui_click": ["res://audio/ui_click.wav", "SFX"],
	"dialogue_blip": ["res://audio/dialogue_blip.wav", "Dialogue"],
	"hit_thud": ["res://audio/hit_thud.wav", "SFX"],
	"wanted_sting": ["res://audio/wanted_sting.wav", "SFX"],
	"mission_jingle": ["res://audio/mission_jingle.wav", "Music"],
	"death_sting": ["res://audio/death_sting.wav", "SFX"],
}

var _music_player: AudioStreamPlayer = null
var _cache: Dictionary = {}

func _ready() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus(AudioServer.get_bus_count())
			AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, bus)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

func is_muted() -> bool:
	var settings = get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_method("get_value"):
		return bool(settings.get_value("audio/muted"))
	return false

func get_sound_names() -> Array:
	return SOUNDS.keys()

func get_stream(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var entry: Array = SOUNDS.get(sound_name, [])
	if entry.is_empty():
		return null
	var stream: AudioStream = load(entry[0])
	if stream != null:
		_cache[sound_name] = stream
	return stream

func play_named(sound_name: String, volume_db: float = 0.0) -> void:
	if is_muted():
		return
	var entry: Array = SOUNDS.get(sound_name, [])
	if entry.is_empty():
		return
	var stream := get_stream(sound_name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = str(entry[1])
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_ui_click() -> void:
	play_named("ui_click")

func play_dialogue_blip() -> void:
	play_named("dialogue_blip")

func play_hit() -> void:
	play_named("hit_thud")

func play_wanted_sting() -> void:
	play_named("wanted_sting")

func play_mission_jingle() -> void:
	play_named("mission_jingle")

func play_death_sting() -> void:
	play_named("death_sting")

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or is_muted():
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_music(stream: AudioStream) -> void:
	if stream == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()
