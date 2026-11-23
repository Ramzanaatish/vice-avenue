extends Node3D

## S17 — World Root, Old Quarter (Step 6, Slice C).
## Greybox district: ground, streets, modular building boxes,
## spawn point. Owns the pause overlay (S06), the vehicle
## manager (S19), the mission controller (M04), the NPC manager
## (S20), the police manager (S21), and the dialogue (S12),
## map (S08) and game-over (S15) overlays; wires the HUD.
## The world sets the game state to PLAYING once it is ready.
## Save/load: collect_save_data() writes the full state
## (position + facing + wanted + mission + inventory + vehicle);
## apply_save_data() restores it on Continue and on S15 Retry.
## The interact prompt is arbitrated here (one writer): talk to
## an NPC beats entering the car.

const DISTRICT_PATH := "res://data/maps/district_old_quarter.json"

var _district: Dictionary = {}
var _inventory_open = null
var _dialogue = null
var _dialogue_npc = null
var _map_open = null
var _game_over = null

func _ready() -> void:
	_load_district()
	var player = $Dynamic/Player
	if GameManager.is_new_game:
		player.global_position = _spawn_point()
	else:
		var loaded: Dictionary = SaveManager.load_game(GameManager.active_slot_id)
		if bool(loaded.get("ok", false)):
			apply_save_data(loaded["data"])
		else:
			player.global_position = _spawn_point()
			print("World Root: load failed (", str(loaded.get("error", "?")), ") — starting at spawn.")
	$HUD/SafeArea/Minimap.set_district(_district)
	$HUD/SafeArea/Minimap.set_player(player)
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.game_state_changed.connect(_on_game_state_changed)
		bus.player_died.connect(_on_player_died)
	GameManager.set_state(GameManager.State.PLAYING)
	print("World Root ready (Old Quarter, ", _district.get("buildings", []).size(), " buildings, spawn ", player.global_position, ").")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# The inventory handles its own back press.
		if _inventory_open != null:
			return
		if GameManager.get_state_name() == "PLAYING":
			GameManager.set_state(GameManager.State.PAUSED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		if GameManager.get_state_name() == "PLAYING" and _inventory_open == null:
			show_inventory(false)
	elif event.is_action_pressed("open_map"):
		if GameManager.get_state_name() == "PLAYING" and _map_open == null:
			show_map(false)

func _physics_process(_delta: float) -> void:
	# Interact arbitration (one writer for the HUD button):
	# talking to a nearby NPC wins over entering the car.
	if GameManager.get_state_name() != "PLAYING":
		return
	if _dialogue != null or _map_open != null or _game_over != null:
		return
	var player = $Dynamic/Player
	var vm = $VehicleManager
	# Input.action_press() sets action state but never produces
	# an _unhandled_input event, so the open actions are also
	# checked here (real keys still arrive via _unhandled_input;
	# both paths are guarded against double-opening).
	if Input.is_action_just_pressed("open_map") and _map_open == null:
		show_map(false)
		return
	if Input.is_action_just_pressed("open_inventory") and _inventory_open == null:
		show_inventory(false)
		return
	if bool(vm.driving):
		$HUD.set_interact_visible(false, "")
		if Input.is_action_just_pressed("interact"):
			vm.exit_vehicle()
		return
	var npc = $NPCManager.get_nearest_talkable(player.global_position)
	if npc != null:
		$HUD.set_interact_visible(true, "Talk to " + str(npc.display_name))
		if Input.is_action_just_pressed("interact"):
			_open_dialogue(npc)
	elif vm.is_near_car():
		$HUD.set_interact_visible(true, "E — Enter Car")
		if Input.is_action_just_pressed("interact"):
			vm.enter_vehicle()
	else:
		$HUD.set_interact_visible(false, "")

func _on_game_state_changed(new_state: String) -> void:
	if new_state == "PAUSED":
		$PauseMenu.visible = true
		if $PauseMenu.has_method("refresh"):
			$PauseMenu.refresh()
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif new_state == "PLAYING":
		$PauseMenu.visible = false
		get_tree().paused = false

func show_inventory(from_pause: bool) -> void:
	if _inventory_open != null:
		return
	var scene: PackedScene = load("res://scenes/frontend/inventory.tscn")
	_inventory_open = scene.instantiate()
	_inventory_open.from_pause = from_pause
	_inventory_open.closed.connect(_on_inventory_closed)
	add_child(_inventory_open)
	if not from_pause:
		get_tree().paused = true

func _on_inventory_closed() -> void:
	if _inventory_open != null:
		_inventory_open.queue_free()
		_inventory_open = null
	if GameManager.get_state_name() == "PLAYING":
		get_tree().paused = false

func show_map(from_pause: bool) -> void:
	if _map_open != null:
		return
	var scene: PackedScene = load("res://scenes/frontend/map.tscn")
	_map_open = scene.instantiate()
	_map_open.closed.connect(_on_map_closed)
	add_child(_map_open)
	var mission_pos := Vector3.ZERO
	var mission_label := ""
	var has_mission := false
	var active := MissionManager.get_active_mission()
	if active != "":
		var mission := MissionManager.get_mission(active)
		var current := MissionManager.get_current_objective(active)
		var oid := str(current.get("id", ""))
		var locations: Dictionary = mission.get("locations", {})
		var loc: Dictionary = locations.get(oid, {})
		if not loc.is_empty():
			mission_pos = Vector3(float(loc.get("x", 0.0)), 0.0, float(loc.get("z", 0.0)))
			mission_label = str(current.get("text", ""))
			has_mission = true
	_map_open.show_map(_district, $Dynamic/Player, mission_pos, mission_label, has_mission)
	if not from_pause:
		get_tree().paused = true

func _on_map_closed() -> void:
	if _map_open != null:
		_map_open.queue_free()
		_map_open = null
	if GameManager.get_state_name() == "PLAYING":
		get_tree().paused = false

func _open_dialogue(npc) -> void:
	if _dialogue != null:
		return
	var scene: PackedScene = load("res://scenes/frontend/dialogue.tscn")
	_dialogue = scene.instantiate()
	_dialogue.closed.connect(_on_dialogue_closed)
	_dialogue.mission_offered.connect(_on_mission_offered)
	add_child(_dialogue)
	_dialogue_npc = npc
	$NPCManager.set_talking(npc, true)
	if not _dialogue.show_dialogue(str(npc.dialogue_id)):
		_on_dialogue_closed()
		return
	get_tree().paused = true

func _on_dialogue_closed() -> void:
	if _dialogue_npc != null:
		$NPCManager.set_talking(_dialogue_npc, false)
		_dialogue_npc = null
	if _dialogue != null:
		_dialogue.queue_free()
		_dialogue = null
	if GameManager.get_state_name() == "PLAYING":
		get_tree().paused = false

func _on_mission_offered(mission_id: String) -> void:
	# The dialogue closed itself (and unpaused) before emitting.
	var mc = $MissionController
	if mc != null and mc.has_method("offer_mission"):
		mc.offer_mission(mission_id)

func _on_player_died(cause: String) -> void:
	if _game_over != null:
		return
	GameManager.set_state(GameManager.State.GAME_OVER)
	var scene: PackedScene = load("res://scenes/frontend/game_over.tscn")
	_game_over = scene.instantiate()
	_game_over.retry_pressed.connect(_on_game_over_retry)
	_game_over.load_pressed.connect(_on_game_over_load)
	_game_over.quit_pressed.connect(_on_game_over_quit)
	add_child(_game_over)
	_game_over.show_game_over(cause)
	get_tree().paused = true

func _close_game_over() -> void:
	if _game_over != null:
		_game_over.queue_free()
		_game_over = null

func _on_game_over_retry() -> void:
	var restored: Dictionary = SaveManager.restore_checkpoint()
	if not bool(restored.get("ok", false)):
		var bus = get_node_or_null("/root/EventBus")
		if bus != null:
			bus.emit_signal("notification_requested", "Retry failed: " + str(restored.get("error", "?")))
		return
	_close_game_over()
	apply_save_data(restored["data"])
	GameManager.set_state(GameManager.State.PLAYING)
	get_tree().paused = false

func _on_game_over_load() -> void:
	_close_game_over()
	get_tree().paused = false
	GameManager.set_state(GameManager.State.MENU)
	GameManager.request_scene("res://scenes/frontend/save_slots.tscn")

func _on_game_over_quit() -> void:
	_close_game_over()
	get_tree().paused = false
	GameManager.quit_to_menu()

func collect_save_data() -> Dictionary:
	# A save taken mid-conversation closes the dialogue cleanly
	# (S12): dialogue state is never stored in the save.
	if _dialogue != null:
		_on_dialogue_closed()
	var data: Dictionary = SaveManager.new_game_data()
	var player = $Dynamic/Player
	data["player"]["position"] = [player.global_position.x, player.global_position.y, player.global_position.z]
	data["player"]["rotation_y"] = player.get_facing_yaw()
	data["player"]["health"] = player.health
	data["player"]["cash"] = EconomyManager.cash
	data["player"]["wanted_level"] = $PoliceManager.wanted_level
	data["player"]["heat"] = $PoliceManager.heat
	var active := MissionManager.get_active_mission()
	if active != "":
		data["progress"]["current_mission"] = active
		data["progress"]["objective_index"] = int(MissionManager.current_objective_index.get(active, 0))
	else:
		data["progress"]["current_mission"] = GameManager.current_mission_id
		data["progress"]["objective_index"] = 0
	var completed: Array = []
	for mission_id in MissionManager.mission_states:
		if MissionManager.mission_states[mission_id] == "SUCCESS":
			completed.append(str(mission_id))
	data["progress"]["completed_missions"] = completed
	var inventory: Array = []
	for item_id in InventoryManager.items:
		inventory.append({"id": str(item_id), "qty": int(InventoryManager.items[item_id])})
	data["inventory"] = inventory
	var vehicles: Array = []
	var car = $Dynamic.get_node_or_null("Car")
	if car != null:
		vehicles.append({"id": "car_01", "condition": int(car.get("condition"))})
	data["vehicles"] = vehicles
	data["world_flags"] = MissionManager.story_flags.duplicate()
	return data

func apply_save_data(data: Dictionary) -> void:
	# Full restore (Step 6): position + facing + health + cash +
	# wanted + inventory + vehicles + mission state + story flags.
	# NPCs respawn from their routines (S20: runtime NPC state
	# is never saved); police respawn from the restored wanted
	# level via dispatch.
	var player = $Dynamic/Player
	var p: Dictionary = data.get("player", {})
	var pos: Array = p.get("position", [0.0, 0.0, 8.0])
	player.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	player.set_facing(float(p.get("rotation_y", 0.0)))
	player.health = maxi(1, clampi(int(p.get("health", 100)), 0, 100))
	player.is_dead = false
	EventBus.emit_signal("health_changed", player.health, 100)
	EconomyManager.set_cash(int(p.get("cash", 250)))
	var inv: Dictionary = {}
	for entry in data.get("inventory", []):
		inv[str(entry.get("id", ""))] = int(entry.get("qty", 0))
	InventoryManager.set_items(inv)
	MissionManager.story_flags = (data.get("world_flags", {}) as Dictionary).duplicate()
	MissionManager.restore_progress(data.get("progress", {}))
	GameManager.current_mission_id = str(data.get("progress", {}).get("current_mission", "mission_001"))
	var vehicles: Array = data.get("vehicles", [])
	var car = $Dynamic.get_node_or_null("Car")
	if car != null and not vehicles.is_empty():
		car.set("condition", int(vehicles[0].get("condition", 100)))
	$NPCManager.reset_npcs()
	$PoliceManager.reset()
	$PoliceManager.set_heat(float(p.get("heat", 0.0)))
	print("World Root: save applied (pos ", player.global_position, ", health ", player.health, ", wanted ", $PoliceManager.wanted_level, ").")

func _load_district() -> void:
	if not FileAccess.file_exists(DISTRICT_PATH):
		print("World Root: district JSON missing, using defaults.")
		_district = {"bounds": {"min_x": -60, "max_x": 60, "min_z": -60, "max_z": 60}, "buildings": []}
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DISTRICT_PATH))
	if parsed is Dictionary:
		_district = parsed

func _spawn_point() -> Vector3:
	var s: Dictionary = _district.get("spawn", {"x": 0, "y": 0, "z": 8})
	return Vector3(float(s.get("x", 0)), float(s.get("y", 0)), float(s.get("z", 8)))
