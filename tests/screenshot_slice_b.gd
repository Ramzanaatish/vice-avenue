extends Node

## Temporary screenshot driver (Step 5, NOT shipped): captures the
## world greybox with the car (05) and the M04 briefing (06).
## Under Xvfb the engine runs at a few FPS, so a 0.5 s timer can
## already be past the briefing's 1.0 s auto-open — the driver
## therefore locks the mission for the world shot, then re-opens
## the briefing through the real workshop-beacon path.
## Run it with:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . res://tests/screenshot_slice_b.tscn

var _world: Node3D = null
var _timer := 0.0
var _phase := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var packed: PackedScene = load("res://scenes/world/world_root.tscn")
	_world = packed.instantiate()
	add_child(_world)
	# Suppress the auto-briefing so the world shot is clean.
	MissionManager.mission_states["mission_004"] = "LOCKED"

func _process(delta: float) -> void:
	_timer += delta
	match _phase:
		0:
			# First frame: capture the world before anything opens.
			# Park the view south of the car so the car is in frame
			# (it sits at (5, 0, 16), behind the default spawn view).
			var player = _world.get_node("Dynamic/Player")
			player.global_position = Vector3(5, 0, 24)
			_shot("05_world.png")
			_phase = 1
			_timer = 0.0
		1:
			if _timer > 0.5:
				# Re-open the briefing the real way: unlock the
				# mission and walk into the workshop beacon.
				MissionManager.unlock_mission("mission_004")
				var player2 = _world.get_node("Dynamic/Player")
				player2.global_position = Vector3(-10, 0, 12)
				_phase = 2
				_timer = 0.0
		2:
			if _world.get_node_or_null("MissionBriefing") != null or _timer > 2.0:
				_shot("06_briefing.png")
				_phase = 3
				_timer = 0.0
		3:
			# The shot above awaits one frame before saving, so
			# wait a beat before quitting or the file never lands.
			if _timer > 0.5:
				print("SCREENSHOTS SLICE B DONE")
				get_tree().quit()

func _shot(file_name: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var dir := OS.get_user_data_dir() + "/screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir + "/" + file_name
	var err := img.save_png(path)
	print("SCREENSHOT ", file_name, " -> ", path, " err=", err)
