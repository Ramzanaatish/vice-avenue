extends Node

## AppRoot — the main scene (Step 3).
## Owns scene switching (B-11): it hosts the current frontend /
## world scene as a CHILD (it never replaces itself, so the
## switching logic survives every swap), listens to GameManager's
## state signal (via EventBus.game_state_changed) and to
## EventBus.scene_change_requested, and performs the swap.
## GameManager decides the state; AppRoot only swaps.
## On boot it shows S01 Boot / Splash, which advances to S03.

const BOOT_SCENE := "res://scenes/frontend/boot.tscn"

var _current_scene: Node = null

func _ready() -> void:
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.scene_change_requested.connect(_on_scene_change_requested)
		bus.game_state_changed.connect(_on_game_state_changed)
	_boot_check()
	_show_scene(BOOT_SCENE)

func _on_scene_change_requested(scene_path: String) -> void:
	if not FileAccess.file_exists(scene_path):
		print("AppRoot: scene not built yet: ", scene_path, " — staying on current scene.")
		return
	_show_scene(scene_path)

func _on_game_state_changed(new_state: String) -> void:
	print("AppRoot: game state -> ", new_state)

func _show_scene(scene_path: String) -> void:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("AppRoot: cannot load scene: " + scene_path)
		return
	if _current_scene != null:
		_current_scene.queue_free()
		_current_scene = null
	_current_scene = packed.instantiate()
	add_child(_current_scene)
	print("AppRoot: showing scene: ", scene_path)

func _boot_check() -> void:
	# Read-only boot check (Step 3). No writes: the save/load
	# round-trip lives in tests/test_save_manager.tscn, and the
	# real save UI is S05. A boot check must never overwrite a
	# player's slot.
	print("Vice Avenue Step 6 booted.")
	for autoload_name in ["EventBus", "VersionManager", "AudioManager", "SettingsManager", "SaveManager", "GameManager", "MissionManager", "EconomyManager", "InventoryManager", "SecurityManager"]:
		var ok := get_node_or_null("/root/" + autoload_name) != null
		print("  autoload ", autoload_name, ": ", "OK" if ok else "MISSING")
	var slots: Array = SaveManager.list_slots()
	var found := 0
	for info in slots:
		if bool(info.get("exists", false)):
			found += 1
	print("  save slots with data: ", found, " of ", slots.size())
	print("  settings music_volume: ", SettingsManager.get_value("audio/music_volume"))
	print("  game state: ", GameManager.get_state_name())
