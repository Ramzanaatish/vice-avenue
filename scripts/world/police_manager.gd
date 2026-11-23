extends Node3D

## S21 — Police Manager (Step 6, Slice C). Scene-owned (child
## of WorldRoot). Owns the wanted level, heat, response
## selection and dispatch (B-11); officers only run their own
## state. Wanted tiers for Slice C: 0 none, 1 investigate,
## 2 pursuit — tiers 3-5 (roadblocks, high intensity) arrive
## in later phases and are never spawned here. Active police
## are capped per tier from data/police_tuning.json.
## Wanted level + heat are part of the save (player block, S21);
## officer state is NOT saved (respawned by dispatch on load).

const TUNING_PATH := "res://data/police_tuning.json"
const OFFICER_SCENE := "res://scenes/police/police_officer.tscn"

var wanted_level := 0
var heat := 0.0
var officers: Array = []

var _tuning: Dictionary = {}
var _time_since_hostile := 999.0
var _arrest_emitted := false
## Cached officer PackedScene (Step 7). The scene is loaded ONCE
## and reused for every dispatch: reloading it after the last
## officer was freed gave each new officer fresh sub-resources,
## and freeing such an officer logged a headless-dummy
## "Parameter material is null" engine error. Keeping one cached
## scene also avoids a disk load per dispatch.
var _officer_scene: PackedScene = null

func _ready() -> void:
	_load_tuning()
	_officer_scene = load(OFFICER_SCENE)
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.hostile_act_committed.connect(_on_hostile_act)

func _load_tuning() -> void:
	if not FileAccess.file_exists(TUNING_PATH):
		print("PoliceManager: tuning missing, using defaults.")
		_tuning = {"heat_decay_per_sec": 3.0, "heat_grace_sec": 8.0, "heat_per_attack_npc": 30, "heat_per_attack_police": 40, "heat_per_call_police": 20, "max_active": {"1": 1, "2": 2}, "wanted_thresholds": {"1": 25, "2": 50}}
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TUNING_PATH))
	if parsed is Dictionary:
		_tuning = parsed

func _process(delta: float) -> void:
	_time_since_hostile += delta
	if heat > 0.0 and _time_since_hostile > float(_tuning.get("heat_grace_sec", 8.0)):
		heat = maxf(0.0, heat - float(_tuning.get("heat_decay_per_sec", 3.0)) * delta)
		_update_wanted()

func _on_hostile_act(kind: String, _position: Vector3) -> void:
	match kind:
		"attack_npc":
			add_heat(int(_tuning.get("heat_per_attack_npc", 30)))
		"attack_police":
			add_heat(int(_tuning.get("heat_per_attack_police", 40)))
		"call_police":
			add_heat(int(_tuning.get("heat_per_call_police", 20)))

func add_heat(amount: int) -> void:
	heat = minf(100.0, heat + float(amount))
	_time_since_hostile = 0.0
	_update_wanted()

func set_heat(value: float) -> void:
	# Public API: missions and tests set heat directly.
	heat = clampf(value, 0.0, 100.0)
	_time_since_hostile = 0.0
	_update_wanted()

func set_wanted_level(level: int) -> void:
	# Public API: jump straight to a tier (missions, tests).
	# Heat is set to the tier's threshold so decay behaves
	# normally from there.
	var thresholds: Dictionary = _tuning.get("wanted_thresholds", {"1": 25, "2": 50})
	heat = float(thresholds.get(str(clampi(level, 0, 2)), 0))
	if level <= 0:
		heat = 0.0
	_time_since_hostile = 0.0
	_update_wanted()

func _level_for_heat(value: float) -> int:
	var thresholds: Dictionary = _tuning.get("wanted_thresholds", {"1": 25, "2": 50})
	if value >= float(thresholds.get("2", 50)):
		return 2
	if value >= float(thresholds.get("1", 25)):
		return 1
	return 0

func _update_wanted() -> void:
	var new_level := _level_for_heat(heat)
	if new_level == wanted_level:
		return
	var old_level := wanted_level
	wanted_level = new_level
	if new_level > old_level:
		# Step 7 (Phase 15): rising heat stings once per tier.
		var audio = get_node_or_null("/root/AudioManager")
		if audio != null and audio.has_method("play_wanted_sting"):
			audio.play_wanted_sting()
	if new_level == 0 and old_level > 0:
		_arrest_emitted = false
		var bus = get_node_or_null("/root/EventBus")
		if bus != null:
			bus.emit_signal("notification_requested", "You escaped.")
	var bus2 = get_node_or_null("/root/EventBus")
	if bus2 != null:
		bus2.emit_signal("wanted_changed", wanted_level)
	_sync_dispatch()

func _cap_for_level(level: int) -> int:
	var caps: Dictionary = _tuning.get("max_active", {"1": 1, "2": 2})
	return int(caps.get(str(level), 0))

func _sync_dispatch() -> void:
	_prune_officers()
	var cap := _cap_for_level(wanted_level)
	while officers.size() < cap:
		_spawn_officer()
	while officers.size() > cap:
		var extra = officers[officers.size() - 1]
		recall_officer(extra)

func _prune_officers() -> void:
	var alive: Array = []
	for officer in officers:
		if is_instance_valid(officer):
			alive.append(officer)
	officers = alive

func _spawn_officer() -> void:
	var root = get_parent()
	var player = root.get_node_or_null("Dynamic/Player")
	if player == null:
		return
	var dynamic = root.get_node_or_null("Dynamic")
	if dynamic == null:
		return
	var container = dynamic.get_node_or_null("Police")
	if container == null:
		container = Node3D.new()
		container.name = "Police"
		dynamic.add_child(container)
	var spot := _pick_spawn_spot(player.global_position)
	if spot == Vector3.INF:
		return
	if _officer_scene == null:
		_officer_scene = load(OFFICER_SCENE)
	var officer = _officer_scene.instantiate()
	container.add_child(officer)
	officer.global_position = spot
	var start_state := "Investigate"
	if wanted_level >= 2:
		start_state = "Pursue"
	officer.setup(_tuning, self, player, start_state, player.global_position)
	officers.append(officer)
	print("PoliceManager: dispatched officer (level ", wanted_level, ", active ", officers.size(), ").")

func _pick_spawn_spot(player_pos: Vector3) -> Vector3:
	# Street-grid spawn points (roads only, no buildings).
	var candidates: Array = [
		Vector3(0, 0, -30), Vector3(0, 0, 30), Vector3(-30, 0, 0), Vector3(30, 0, 0),
		Vector3(0, 0, -45), Vector3(0, 0, 45), Vector3(-45, 0, 0), Vector3(45, 0, 0),
		Vector3(-8, 0, -30), Vector3(8, 0, 30), Vector3(-30, 0, 8), Vector3(30, 0, -8),
	]
	var min_dist := float(_tuning.get("spawn_min_distance", 15.0))
	var max_dist := float(_tuning.get("spawn_max_distance", 40.0))
	var fallback := Vector3.INF
	for spot in candidates:
		var dist: float = spot.distance_to(player_pos)
		if dist < min_dist or dist > max_dist:
			if dist >= min_dist and fallback == Vector3.INF:
				fallback = spot
			continue
		# Never spawn on top of a live officer: two capsules
		# at the same spot make the physics solver launch
		# both of them skyward (caught headless, Step 6).
		if _spot_occupied(spot):
			continue
		return spot
	if fallback != Vector3.INF:
		return fallback
	return candidates[0] + Vector3(2.5, 0, 0)

func _spot_occupied(spot: Vector3) -> bool:
	for officer in officers:
		if is_instance_valid(officer) and officer.global_position.distance_to(spot) < 3.0:
			return true
	return false

func recall_officer(officer) -> void:
	if officer == null:
		return
	officers.erase(officer)
	if is_instance_valid(officer):
		officer.queue_free()
	print("PoliceManager: officer recalled (active ", officers.size(), ").")

func arrest_player() -> void:
	if _arrest_emitted:
		return
	_arrest_emitted = true
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal("player_died", "arrested")

func get_active_count() -> int:
	_prune_officers()
	return officers.size()

func reset() -> void:
	heat = 0.0
	_time_since_hostile = 999.0
	_arrest_emitted = false
	for officer in officers:
		if is_instance_valid(officer):
			officer.queue_free()
	officers.clear()
	if wanted_level != 0:
		wanted_level = 0
		var bus = get_node_or_null("/root/EventBus")
		if bus != null:
			bus.emit_signal("wanted_changed", 0)
