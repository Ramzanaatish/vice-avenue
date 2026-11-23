extends Node

## Settings live in ConfigFile user://settings.cfg (never in saves).

signal settings_applied

const SETTINGS_PATH := "user://settings.cfg"

const DEFAULTS := {
	"graphics/quality": "Medium",
	"graphics/shadows": false,
	"graphics/resolution_scale": 1.0,
	"graphics/show_fps": false,
	"audio/music_volume": 0.8,
	"audio/sfx_volume": 0.8,
	"audio/dialogue_volume": 0.8,
	"audio/ambience_volume": 0.8,
	"audio/muted": false,
	"controls/sensitivity": 1.0,
	"controls/invert_camera": false,
	"controls/button_size": 1.0,
	"controls/button_opacity": 0.85,
	"accessibility/subtitles": true,
	"accessibility/camera_shake": true,
}

var _settings: Dictionary = {}

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	_settings = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for section in cfg.get_sections():
			for key in cfg.get_section_keys(section):
				_settings[section + "/" + key] = cfg.get_value(section, key)
	apply_settings()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for full_key in _settings.keys():
		var parts: PackedStringArray = full_key.split("/")
		if parts.size() == 2:
			cfg.set_value(parts[0], parts[1], _settings[full_key])
	cfg.save(SETTINGS_PATH)

func reset_to_defaults() -> void:
	# S04 "Reset to defaults". Applies + saves immediately.
	_settings = DEFAULTS.duplicate(true)
	apply_settings()
	save_settings()

func get_value(key: String):
	return _settings.get(key, DEFAULTS.get(key))

func set_value(key: String, value) -> void:
	_settings[key] = value
	apply_settings()
	save_settings()

func apply_settings() -> void:
	for bus in ["Music", "SFX", "Dialogue", "Ambience"]:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			var vol: float = clampf(float(get_value("audio/" + bus.to_lower() + "_volume")), 0.0, 1.0)
			if bool(get_value("audio/muted")):
				vol = 0.0
			if vol <= 0.001:
				AudioServer.set_bus_volume_db(idx, -80.0)
			else:
				AudioServer.set_bus_volume_db(idx, linear_to_db(vol))
	if is_inside_tree():
		var scale: float = clampf(float(get_value("graphics/resolution_scale")), 0.5, 1.0)
		# FSR scaling only exists on the Forward+ renderer; on
		# GL Compatibility (this project) it only logs a warning,
		# so use bilinear there.
		var method: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility"))
		if method == "forward_plus":
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		else:
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		get_viewport().scaling_3d_scale = scale
	settings_applied.emit()
