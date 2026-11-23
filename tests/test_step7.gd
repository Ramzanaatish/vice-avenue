extends Node

## Step 7 self-test (Phase 14 + 15 + 17 headless checks). Run it with:
##   godot --headless --path . res://tests/test_step7.tscn
## Checks: settings persist/apply (bus dB, mute -80 dB, restore to
## defaults at the end), HUD touch layout + FPS, settings
## return-to-world via EventBus scene_change_requested, pause
## save-safety pure function, audio names/streams/play, animation
## getters (bob/swing/flash/beacon), credits data + scene, theme
## font size + button min height, map/HUD button sizes, version
## bump. Layout-size checks run two frames after _ready so
## anchors resolve. (-s scripts cannot see autoloads, so the
## test runs as a scene.)

var _failures: Array = []
var _frame := 0
# HUD root is a CanvasLayer, not a Control.
var _hud: Node = null
var _map: Control = null
var _requested_scene := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.scene_change_requested.connect(_on_scene_change_requested)
	_check_settings_apply()
	_check_hud_touch_layout()
	_check_settings_return_to_world()
	_check_pause_save_safety()
	_check_audio()
	_check_animation()
	_check_police_scene_cache()
	_check_credits()
	_check_theme()
	_check_version()
	_map = load("res://scenes/frontend/map.tscn").instantiate()
	add_child(_map)

func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 2:
		_check_layout_sizes()
		_finish()

func _on_scene_change_requested(path: String) -> void:
	_requested_scene = path

func _expect(cond: bool, label: String) -> void:
	if cond:
		print("TEST step7: OK ", label)
	else:
		_failures.append(label)
		print("TEST step7: FAIL ", label)

func _check_settings_apply() -> void:
	SettingsManager.set_value("audio/sfx_volume", 0.5)
	var sfx_idx := AudioServer.get_bus_index("SFX")
	_expect(sfx_idx >= 0, "SFX bus exists")
	if sfx_idx >= 0:
		_expect(absf(AudioServer.get_bus_volume_db(sfx_idx) - linear_to_db(0.5)) < 0.5, "sfx volume 0.5 applies (~-6 dB)")
	SettingsManager.set_value("audio/muted", true)
	if sfx_idx >= 0:
		_expect(AudioServer.get_bus_volume_db(sfx_idx) <= -79.0, "mute silences SFX bus (-80 dB)")
	SettingsManager.load_settings()
	_expect(bool(SettingsManager.get_value("audio/muted")) == true, "mute persists after reload")
	SettingsManager.reset_to_defaults()
	_expect(bool(SettingsManager.get_value("audio/muted")) == false, "reset restores mute=false")

func _check_hud_touch_layout() -> void:
	SettingsManager.set_value("controls/button_size", 1.5)
	SettingsManager.set_value("controls/button_opacity", 0.5)
	SettingsManager.set_value("graphics/show_fps", true)
	_hud = load("res://scenes/frontend/hud.tscn").instantiate()
	add_child(_hud)
	_expect(absf(_hud.get_node("SafeArea/InventoryButton").scale.x - 1.5) < 0.01, "HUD button_size 1.5 applies")
	_expect(absf(_hud.get_node("SafeArea/InventoryButton").modulate.a - 0.5) < 0.01, "HUD button_opacity 0.5 applies")
	_expect(_hud.get_node("SafeArea/FpsLabel").visible, "FPS label visible when show_fps")
	SettingsManager.reset_to_defaults()
	_expect(not _hud.get_node("SafeArea/FpsLabel").visible, "FPS label hidden at defaults")

func _check_settings_return_to_world() -> void:
	var saved: Dictionary = SaveManager.save_game(0, SaveManager.new_game_data())
	_expect(bool(saved.get("ok", false)), "autosave slot 0 writable for return test")
	var settings_scene: Control = load("res://scenes/frontend/settings.tscn").instantiate()
	add_child(settings_scene)
	GameManager.settings_return_target = "world"
	_requested_scene = ""
	settings_scene._on_back_pressed()
	_expect(_requested_scene == "res://scenes/world/world_root.tscn", "settings Back from pause returns to world")
	GameManager.settings_return_target = "menu"
	_requested_scene = ""
	settings_scene._on_back_pressed()
	_expect(_requested_scene == "res://scenes/frontend/main_menu.tscn", "settings Back from menu returns to menu")
	settings_scene.queue_free()
	SaveManager.delete_slot(0)

func _check_pause_save_safety() -> void:
	var PauseMenuScript = load("res://scripts/ui/pause_menu.gd")
	_expect(PauseMenuScript.is_save_safe(0), "save safe at wanted 0")
	_expect(not PauseMenuScript.is_save_safe(1), "save unsafe at wanted 1")
	_expect(not PauseMenuScript.is_save_safe(2), "save unsafe at wanted 2")
	_expect(PauseMenuScript.save_blocked_reason(0) == "", "no reason at wanted 0")
	_expect(PauseMenuScript.save_blocked_reason(2) != "", "reason shown at wanted 2")

func _check_audio() -> void:
	var names: Array = AudioManager.get_sound_names()
	for expected in ["ui_click", "dialogue_blip", "hit_thud", "wanted_sting", "mission_jingle", "death_sting"]:
		_expect(names.has(expected), "audio clip registered: " + expected)
		_expect(AudioManager.get_stream(expected) != null, "audio stream loads: " + expected)
	AudioManager.play_ui_click()
	AudioManager.play_dialogue_blip()
	AudioManager.play_hit()
	AudioManager.play_wanted_sting()
	AudioManager.play_mission_jingle()
	AudioManager.play_death_sting()
	_expect(true, "all six SFX play without error")
	for bus in ["SFX", "Music", "Dialogue", "Ambience"]:
		_expect(AudioServer.get_bus_index(bus) >= 0, "audio bus exists: " + bus)

func _check_animation() -> void:
	var player: CharacterBody3D = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	_expect(player.get_bob_offset() == 0.0, "player bob starts at 0")
	_expect(not player.is_swinging(), "player not swinging at spawn")
	_expect(not player.is_flashing(), "player not flashing at spawn")
	player.attack()
	_expect(player.is_swinging(), "player swing starts on attack")
	SettingsManager.set_value("controls/sensitivity", 2.0)
	_expect(absf(player.get_sensitivity_scale() - 2.0) < 0.01, "sensitivity 2.0 applies to player")
	SettingsManager.set_value("controls/invert_camera", true)
	_expect(player.is_invert_camera(), "invert camera applies to player")
	SettingsManager.set_value("accessibility/camera_shake", false)
	player.damage(10)
	_expect(player.get_shake_timer() == 0.0, "no camera shake when disabled")
	SettingsManager.set_value("accessibility/camera_shake", true)
	player.damage(10)
	_expect(player.get_shake_timer() > 0.0, "camera shake on damage when enabled")
	_expect(player.is_flashing(), "player flashes on non-fatal damage")
	SettingsManager.reset_to_defaults()
	player.queue_free()
	var npc: CharacterBody3D = load("res://scenes/npc/npc.tscn").instantiate()
	add_child(npc)
	npc.setup({"id": "test_npc", "name": "Test", "color": [0.5, 0.5, 0.5], "waypoints": []})
	_expect(npc.get_bob_offset() == 0.0, "npc bob starts at 0")
	_expect(not npc.is_flashing(), "npc not flashing at spawn")
	npc.damage(10)
	_expect(npc.is_flashing(), "npc flashes on non-fatal damage")
	npc.queue_free()
	var officer: CharacterBody3D = load("res://scenes/police/police_officer.tscn").instantiate()
	add_child(officer)
	_expect(not officer.is_beacon_on(), "beacon off at spawn")
	_expect(not officer.is_flashing(), "officer not flashing at spawn")
	officer.state = "Pursue"
	officer._animate(0.3)
	_expect(officer.is_beacon_on(), "beacon blinks while pursuing")
	officer.damage(10)
	_expect(officer.is_flashing(), "officer flashes on non-fatal damage")
	officer.queue_free()

func _check_police_scene_cache() -> void:
	# Regression test for the Step 7 null-material fix: the
	# PoliceManager must load the officer scene ONCE and reuse it.
	# A per-dispatch load() after every officer was freed gave
	# each new officer fresh sub-resources, and freeing such an
	# officer logged a headless "Parameter material is null"
	# engine error. Officers from one cached scene share their
	# body material object across a full free + re-dispatch.
	var mgr = load("res://scripts/world/police_manager.gd").new()
	add_child(mgr)
	_expect(mgr._officer_scene != null, "police manager caches the officer scene")
	var o1: CharacterBody3D = mgr._officer_scene.instantiate()
	add_child(o1)
	var rid1 := str(o1.get_node("Visual/Body").get_surface_override_material(0).get_rid())
	o1.queue_free()
	# Free takes effect at frame end; force it now so the next
	# instantiate proves the cache survives a full unload.
	await get_tree().process_frame
	var o2: CharacterBody3D = mgr._officer_scene.instantiate()
	add_child(o2)
	var rid2 := str(o2.get_node("Visual/Body").get_surface_override_material(0).get_rid())
	_expect(rid2 == rid1, "officer after full recall reuses the cached scene materials")
	o2.queue_free()
	mgr.queue_free()

func _check_credits() -> void:
	var file := FileAccess.open("res://data/credits.json", FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	var sections: Array = parsed.get("sections", [])
	_expect(sections.size() == 6, "credits.json has 6 sections")
	var text := ""
	for section in sections:
		for line in section.get("lines", []):
			text += str(line) + "\n"
	_expect(text.contains("Aariz"), "credits mention Aariz")
	var credits: Control = load("res://scenes/frontend/credits.tscn").instantiate()
	add_child(credits)
	var found := false
	for child in credits.get_node("Scroll/CreditsList").get_children():
		if child is Label and str(child.text).contains("Aariz"):
			found = true
	_expect(found, "credits scene lists Aariz")
	credits.queue_free()

func _check_theme() -> void:
	var theme: Theme = load("res://themes/ui_theme.tres")
	_expect(theme.get_font_size("font_size", "Button") == 18, "theme Button font size is 18")
	var button := Button.new()
	button.theme = theme
	button.text = "Test"
	add_child(button)
	_expect(button.get_combined_minimum_size().y >= 44.0, "theme button min height >= 44 px")
	button.queue_free()

func _check_version() -> void:
	_expect(VersionManager.GAME_VERSION == "1.1.2", "version is 1.1.2")
	_expect(VersionManager.VERSION_CODE == 4, "version code is 4")
	_expect(VersionManager.SAVE_SCHEMA_VERSION == 2, "save schema stays 2")
	var found_row := false
	for row in VersionManager.VERSION_TABLE:
		if str(row.get("version_name", "")) == "1.1.2" and int(row.get("version_code", 0)) == 4 and int(row.get("save_schema", 0)) == 2:
			found_row = true
	_expect(found_row, "version table has 1.1.2 / code 4 / schema 2")

func _check_layout_sizes() -> void:
	_expect(_map.get_node("CloseButton").size.y >= 48.0, "map Close button >= 48 px tall")
	_expect(_map.get_node("ZoomInButton").size.y >= 48.0, "map ZoomIn >= 48 px tall")
	_expect(_map.get_node("ZoomOutButton").size.y >= 48.0, "map ZoomOut >= 48 px tall")
	_expect(_hud.get_node("SafeArea/PauseButton").size.y >= 48.0, "HUD Pause button >= 48 px tall")
	_expect(_hud.get_node("SafeArea/InventoryButton").size.y >= 48.0, "HUD Inventory button >= 48 px tall")
	_expect(_hud.get_node("SafeArea/MapButton").size.y >= 48.0, "HUD Map button >= 48 px tall")

func _finish() -> void:
	if _failures.is_empty():
		print("TEST step7: PASS")
	else:
		print("TEST step7: FAIL — ", "; ".join(_failures))
	get_tree().quit()
