extends Node3D

## S20 — NPC Manager (Step 6, Slice C). Scene-owned (child of
## WorldRoot). Spawns NPCs from data/npcs/*.json, owns the
## talk-target query and the respawn-on-load reset. NPC runtime
## state is NOT saved (S20) — reset_npcs() rebuilds them from
## their routines, which is also what a fresh load does.

const NPCS_PATH := "res://data/npcs/npcs_old_quarter.json"
const NPC_SCENE := "res://scenes/npc/npc.tscn"
const TALK_DISTANCE := 2.5

var npcs: Array = []
var _data: Dictionary = {}

func _ready() -> void:
	_load_data()
	spawn_all()

func _load_data() -> void:
	if not FileAccess.file_exists(NPCS_PATH):
		print("NPCManager: NPC data missing.")
		_data = {"npcs": []}
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(NPCS_PATH))
	if parsed is Dictionary:
		_data = parsed

func spawn_all() -> void:
	var root = get_parent()
	var dynamic = root.get_node_or_null("Dynamic")
	if dynamic == null:
		return
	var container = dynamic.get_node_or_null("NPCs")
	if container == null:
		container = Node3D.new()
		container.name = "NPCs"
		dynamic.add_child(container)
	var packed: PackedScene = load(NPC_SCENE)
	for entry in _data.get("npcs", []):
		var npc = packed.instantiate()
		container.add_child(npc)
		var pos: Dictionary = entry.get("position", {"x": 0, "z": 0})
		npc.global_position = Vector3(float(pos.get("x", 0.0)), 0.0, float(pos.get("z", 0.0)))
		npc.setup(entry)
		npcs.append(npc)
	print("NPCManager: spawned ", npcs.size(), " NPCs.")

func reset_npcs() -> void:
	for npc in npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	npcs.clear()
	spawn_all()

func get_npc(npc_id: String):
	for npc in npcs:
		if is_instance_valid(npc) and str(npc.npc_id) == npc_id:
			return npc
	return null

func get_nearest_talkable(from_pos: Vector3):
	var best = null
	var best_dist := TALK_DISTANCE
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		if bool(npc.is_dead):
			continue
		if str(npc.get_state()) == "Flee":
			continue
		if str(npc.dialogue_id) == "":
			continue
		var dist: float = npc.global_position.distance_to(from_pos)
		if dist < best_dist:
			best = npc
			best_dist = dist
	return best

func set_talking(npc, talking: bool) -> void:
	if npc != null and is_instance_valid(npc):
		npc.set_talk(talking)

func alive_count() -> int:
	var count := 0
	for npc in npcs:
		if is_instance_valid(npc) and not bool(npc.is_dead):
			count += 1
	return count
