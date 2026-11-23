extends Node

## Scene-load smoke test (Step 4 fix): instantiates every scene
## in the project, one frame each. A script with a latent parse
## error (e.g. `:=` over a Variant) fails at LOAD time, which
## headless --import does NOT report and F5 never reaches (it
## only loads Boot + Main Menu). Run it with:
##   godot --headless --path . res://tests/test_all_scenes.tscn

const SCENES := [
	"res://scenes/frontend/boot.tscn",
	"res://scenes/frontend/main_menu.tscn",
	"res://scenes/frontend/settings.tscn",
	"res://scenes/frontend/save_slots.tscn",
	"res://scenes/frontend/credits.tscn",
	"res://scenes/frontend/pause_menu.tscn",
	"res://scenes/frontend/hud.tscn",
	"res://scenes/frontend/mission_briefing.tscn",
	"res://scenes/frontend/mission_results.tscn",
	"res://scenes/frontend/inventory.tscn",
	"res://scenes/frontend/dialogue.tscn",
	"res://scenes/frontend/map.tscn",
	"res://scenes/frontend/game_over.tscn",
	"res://scenes/player/player.tscn",
	"res://scenes/npc/npc.tscn",
	"res://scenes/police/police_officer.tscn",
	"res://scenes/vehicles/car.tscn",
	"res://scenes/world/world_root.tscn",
]

var _idx := 0
var _failures: Array = []
var _current: Node = null
# Step 7 (Phase 17): per-scene load timing + node counts — the
# headless-measurable half of the performance doc. Real FPS /
# draw calls / memory still need the phone (blueprint O-03).
var _load_start_ms := 0
var _timings: Array = []

func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

func _ready() -> void:
	# ALWAYS: a loaded scene may pause the tree itself (the world
	# auto-shows the mission briefing, which pauses) — the test
	# must keep running so it can free the scene and finish.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_next()

func _process(_delta: float) -> void:
	# One frame per scene so _ready runs, then move on.
	if _current != null:
		var elapsed_ms := Time.get_ticks_msec() - _load_start_ms
		var nodes := _count_nodes(_current)
		_timings.append("%s: %d ms, %d nodes" % [SCENES[_idx], elapsed_ms, nodes])
		_current.queue_free()
		_current = null
		_idx += 1
		_load_next()

func _load_next() -> void:
	if _idx >= SCENES.size():
		_finish()
		return
	var path: String = SCENES[_idx]
	_load_start_ms = Time.get_ticks_msec()
	var packed: PackedScene = load(path)
	if packed == null:
		_failures.append(path + " did not load")
		print("TEST all scenes: FAIL to load ", path)
		_idx += 1
		_load_next()
		return
	_current = packed.instantiate()
	if _current == null:
		_failures.append(path + " did not instantiate")
		_idx += 1
		_load_next()
		return
	add_child(_current)
	print("TEST all scenes: LOAD OK ", path)

func _finish() -> void:
	for line in _timings:
		print("TEST all scenes: TIMING ", line)
	if _failures.is_empty():
		print("TEST all scenes: PASS (", SCENES.size(), " scenes)")
	else:
		print("TEST all scenes: FAIL — ", "; ".join(_failures))
	get_tree().quit()
