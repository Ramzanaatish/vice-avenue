extends Node

## Game state machine. Decides state, emits EventBus signals.
## AppRoot performs the actual scene swap (B-11).

enum State { MENU, LOADING, PLAYING, PAUSED, GAME_OVER }

var state: State = State.MENU
var current_mission_id: String = ""
var is_new_game: bool = false
# Step 6: which slot the world should load on Continue (0 = autosave).
var active_slot_id: int = 0
# Step 7 (Phase 14, S04): where Settings' Back button returns to.
# "menu" (opened from the Main Menu) or "world" (opened from the
# Pause Menu — the world is reloaded from autosave slot 0).
var settings_return_target: String = "menu"

func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_notify_state()

func get_state_name() -> String:
	return State.keys()[state]

func request_scene(scene_path: String) -> void:
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal("scene_change_requested", scene_path)

func start_new_game(slot_id: int) -> void:
	active_slot_id = slot_id
	is_new_game = true
	current_mission_id = "mission_001"
	set_state(State.LOADING)
	request_scene("res://scenes/world/world_root.tscn")

func continue_game(slot_id: int) -> void:
	active_slot_id = slot_id
	is_new_game = false
	set_state(State.LOADING)
	request_scene("res://scenes/world/world_root.tscn")

func quit_to_menu() -> void:
	current_mission_id = ""
	set_state(State.MENU)
	request_scene("res://scenes/frontend/main_menu.tscn")

func _notify_state() -> void:
	if not is_inside_tree():
		return
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal("game_state_changed", get_state_name())
