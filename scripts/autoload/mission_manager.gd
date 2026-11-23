extends Node

## Mission state machine. Missions are DATA (data/missions/*.json),
## never hardcoded. States: LOCKED -> AVAILABLE -> ACCEPTED ->
## ACTIVE -> OBJECTIVE_COMPLETE -> SUCCESS / FAILED -> REWARDED.

const MISSIONS_DIR := "res://data/missions/"

var missions: Dictionary = {}
var mission_states: Dictionary = {}
var story_flags: Dictionary = {}
var current_objective_index: Dictionary = {}

func _ready() -> void:
	load_missions()

func load_missions() -> void:
	missions.clear()
	mission_states.clear()
	var dir := DirAccess.open(MISSIONS_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json") or file_name == "index.json":
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS_DIR + file_name))
		if parsed is Dictionary and parsed.has("mission_id"):
			missions[parsed["mission_id"]] = parsed
			mission_states[parsed["mission_id"]] = "LOCKED"
	if missions.has("mission_001"):
		mission_states["mission_001"] = "AVAILABLE"

func get_mission(mission_id: String) -> Dictionary:
	return missions.get(mission_id, {})

func get_state(mission_id: String) -> String:
	return str(mission_states.get(mission_id, "LOCKED"))

func unlock_mission(mission_id: String) -> void:
	if get_state(mission_id) == "LOCKED":
		mission_states[mission_id] = "AVAILABLE"
		_notify(mission_id)

func get_active_mission() -> String:
	for mission_id in mission_states:
		if mission_states[mission_id] == "ACTIVE":
			return str(mission_id)
	return ""

func get_current_objective(mission_id: String) -> Dictionary:
	var mission := get_mission(mission_id)
	var objectives: Array = mission.get("objectives", [])
	var idx := int(current_objective_index.get(mission_id, 0))
	if idx < 0 or idx >= objectives.size():
		return {}
	return objectives[idx]

func accept_mission(mission_id: String) -> bool:
	if get_state(mission_id) != "AVAILABLE":
		return false
	mission_states[mission_id] = "ACCEPTED"
	current_objective_index[mission_id] = 0
	_notify(mission_id)
	return true

func start_mission(mission_id: String) -> bool:
	if get_state(mission_id) not in ["ACCEPTED", "AVAILABLE"]:
		return false
	mission_states[mission_id] = "ACTIVE"
	current_objective_index[mission_id] = 0
	_notify(mission_id)
	return true

func complete_objective(mission_id: String, objective_id: String) -> void:
	var mission := get_mission(mission_id)
	var objectives: Array = mission.get("objectives", [])
	if objectives.is_empty():
		return
	var idx := int(current_objective_index.get(mission_id, 0))
	if idx >= objectives.size():
		return
	# Out-of-order completions are ignored.
	if str(objectives[idx].get("id", "")) != objective_id:
		return
	idx += 1
	current_objective_index[mission_id] = idx
	if idx >= objectives.size():
		mission_states[mission_id] = "OBJECTIVE_COMPLETE"
		complete_mission(mission_id)
	_notify(mission_id)

func complete_mission(mission_id: String) -> bool:
	if get_state(mission_id) not in ["ACTIVE", "OBJECTIVE_COMPLETE"]:
		return false
	mission_states[mission_id] = "SUCCESS"
	var mission := get_mission(mission_id)
	for flag in mission.get("flags_set", []):
		story_flags[str(flag)] = true
	var audio = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_mission_jingle"):
		audio.play_mission_jingle()
	_notify(mission_id)
	return true

func fail_mission(mission_id: String) -> void:
	mission_states[mission_id] = "FAILED"
	_notify(mission_id)

func retry_mission(mission_id: String) -> bool:
	if get_state(mission_id) != "FAILED":
		return false
	mission_states[mission_id] = "ACTIVE"
	current_objective_index[mission_id] = 0
	_notify(mission_id)
	return true

func set_flag(flag: String, value: bool) -> void:
	story_flags[flag] = value

func restore_progress(progress: Dictionary) -> void:
	# Step 6: load-time restore of mission state. Completed
	# missions come back as SUCCESS, the saved current mission
	# as ACTIVE at its saved objective index; everything else
	# keeps the state load_missions() gave it (mission_001
	# AVAILABLE, the rest LOCKED until unlocked in play).
	# Notifies for the current mission so the world (beacons,
	# HUD objective) updates from the restored state.
	var completed: Array = progress.get("completed_missions", [])
	var current: String = str(progress.get("current_mission", ""))
	for mission_id in mission_states:
		if str(mission_id) in completed:
			mission_states[mission_id] = "SUCCESS"
		elif str(mission_id) == current:
			mission_states[mission_id] = "ACTIVE"
	current_objective_index.clear()
	if current != "" and missions.has(current):
		var objectives: Array = (missions[current] as Dictionary).get("objectives", [])
		var max_idx := maxi(0, objectives.size() - 1)
		current_objective_index[current] = clampi(int(progress.get("objective_index", 0)), 0, max_idx)
	if current != "":
		_notify(current)

func get_flag(flag: String) -> bool:
	return bool(story_flags.get(flag, false))

func evaluate_ending() -> String:
	# Evaluated at the start of Mission 30 (B-08).
	var evidence := get_flag("evidence_preserved")
	var published := get_flag("zoya_published")
	var revenge := get_flag("revenge_taken")
	var family_safe := get_flag("family_safe")
	if evidence and published and not revenge:
		return "A"
	if revenge:
		return "B"
	if not published and family_safe:
		return "C"
	return "C"

func _notify(mission_id: String) -> void:
	if not is_inside_tree():
		return
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal("mission_state_changed", mission_id, get_state(mission_id))
