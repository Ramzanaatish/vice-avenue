extends Node

## Slice B self-test (Step 5). Run it with:
##   godot --headless --path . res://tests/test_slice_b.tscn
## Drives the full Mission 04 loop with the real input actions:
## briefing -> accept -> pickup -> enter car -> drive -> drop-off
## -> return -> reward -> results -> save/load validation.

var _world: Node3D
var _player: CharacterBody3D
var _car: VehicleBody3D
var _phase := 0
var _timer := 0.0
var _car_start := Vector3.ZERO
var _saw_interact: bool = false
var _failures: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var packed: PackedScene = load("res://scenes/world/world_root.tscn")
	_world = packed.instantiate()
	add_child(_world)
	_player = _world.get_node("Dynamic/Player")
	_car = _world.get_node("Dynamic/Car")
	print("TEST Slice B: world loaded, car at ", _car.global_position)

func _process(delta: float) -> void:
	_timer += delta
	match _phase:
		0:
			# Briefing auto-opens ~1.0 s after the world settles.
			if _timer > 1.5:
				if MissionManager.get_state("mission_004") != "AVAILABLE":
					_failures.append("mission_004 not AVAILABLE (state %s)" % MissionManager.get_state("mission_004"))
				var briefing = _world.get_node_or_null("MissionBriefing")
				if briefing == null:
					_failures.append("briefing did not auto-open")
					_finish()
					return
				var accept = briefing.get_node("BriefingPanel/VBox/Buttons/AcceptButton")
				accept.emit_signal("pressed")
				_phase = 1
				_timer = 0.0
		1:
			if _timer > 0.3:
				if MissionManager.get_state("mission_004") != "ACTIVE":
					_failures.append("mission not ACTIVE after Accept (state %s)" % MissionManager.get_state("mission_004"))
				var current := MissionManager.get_current_objective("mission_004")
				if str(current.get("id", "")) != "pickup":
					_failures.append("current objective is not pickup")
				var label = _world.get_node("HUD/SafeArea/ObjectiveLabel")
				if not str(label.text).contains("Pick up"):
					_failures.append("HUD objective wrong: " + str(label.text))
				# Walk to the pickup beacon (Hamza's workshop).
				_player.global_position = Vector3(-10, 0, 12)
				_phase = 2
				_timer = 0.0
		2:
			if _timer > 0.5:
				if not InventoryManager.has_item("package"):
					_failures.append("package not in inventory after pickup")
				var current := MissionManager.get_current_objective("mission_004")
				if str(current.get("id", "")) != "drive":
					_failures.append("current objective is not drive (is %s)" % str(current.get("id", "")))
				# Walk up to the car, then hold E until we are driving.
				_player.global_position = Vector3(3, 0, 16)
				_phase = 3
				_timer = 0.0
		3:
			# Observe first: the Interact button must appear BEFORE
			# any press (pressing enters the car at once, which hides
			# the button again in the same frame).
			var interact_button = _world.get_node("HUD/SafeArea/InteractButton")
			if interact_button.visible:
				_saw_interact = true
			if _timer > 0.3:
				if not _saw_interact:
					_failures.append("Interact button not shown near the car")
				_phase = 4
				_timer = 0.0
		4:
			Input.action_press("interact")
			if _timer > 0.3:
				var vm = _world.get_node("VehicleManager")
				if not bool(vm.driving):
					_failures.append("did not enter the car")
				Input.action_release("interact")
				if _player.visible:
					_failures.append("player still visible while driving")
				var accel = _world.get_node("HUD/SafeArea/AccelButton")
				if not accel.visible:
					_failures.append("Accel button not shown in vehicle mode")
				_car_start = _car.global_position
				Input.action_press("accelerate", 1.0)
				_phase = 5
				_timer = 0.0
		5:
			if _timer > 1.5:
				Input.action_release("accelerate")
				var moved := _car.global_position - _car_start
				var horiz := Vector2(moved.x, moved.z).length()
				print("TEST Slice B: car moved ", moved, " (horizontal ", snappedf(horiz, 0.1), " m)")
				if horiz < 2.0:
					_failures.append("car did not drive (horizontal %s m)" % str(snappedf(horiz, 0.1)))
				if absf(_car.global_position.y) > 0.5:
					_failures.append("car fell through the ground (y = %s)" % str(snappedf(_car.global_position.y, 0.1)))
				# Drive the car into the drop-off beacon.
				_car.global_position = Vector3(0, 0, -48)
				_phase = 6
				_timer = 0.0
		6:
			if _timer > 0.5:
				var current := MissionManager.get_current_objective("mission_004")
				if str(current.get("id", "")) != "return":
					_failures.append("current objective is not return (is %s)" % str(current.get("id", "")))
				_phase = 7
				_timer = 0.0
		7:
			Input.action_press("interact")
			if _timer > 0.3:
				Input.action_release("interact")
				var vm = _world.get_node("VehicleManager")
				if bool(vm.driving):
					_failures.append("did not exit the car")
				if not _player.visible:
					_failures.append("player still hidden after exiting")
				# Return to Hamza on foot.
				_player.global_position = Vector3(-10, 0, 12)
				_phase = 8
				_timer = 0.0
		8:
			if _timer > 0.5:
				if MissionManager.get_state("mission_004") != "SUCCESS":
					_failures.append("mission not SUCCESS after return (state %s)" % MissionManager.get_state("mission_004"))
				if EconomyManager.cash != 5250:
					_failures.append("reward wrong: cash is Rs %d, expected Rs 5250" % EconomyManager.cash)
				if InventoryManager.has_item("package"):
					_failures.append("package still in inventory after delivery")
				var results = _world.get_node_or_null("MissionResults")
				if results == null:
					_failures.append("results screen did not open")
					_finish()
					return
				var header = results.get_node("ResultsPanel/VBox/HeaderLabel")
				if header.text != "MISSION COMPLETE":
					_failures.append("results header wrong: " + str(header.text))
				var continue_button = results.get_node("ResultsPanel/VBox/Buttons/ContinueButton")
				continue_button.emit_signal("pressed")
				_phase = 9
				_timer = 0.0
		9:
			if _timer > 0.3:
				if _world.get_node_or_null("MissionResults") != null:
					_failures.append("results screen still open after Continue")
				if get_tree().paused:
					_failures.append("tree still paused after results closed")
				# Save/load validation: mission state must survive.
				var data: Dictionary = _world.collect_save_data()
				var saved: Dictionary = SaveManager.save_game(1, data)
				if not bool(saved.get("ok", false)):
					_failures.append("save failed: " + str(saved.get("error", "?")))
				else:
					var loaded: Dictionary = SaveManager.load_game(1)
					if not bool(loaded.get("ok", false)):
						_failures.append("load failed: " + str(loaded.get("error", "?")))
					else:
						var loaded_data: Dictionary = loaded["data"]
						var completed: Array = loaded_data["progress"]["completed_missions"]
						if "mission_004" not in completed:
							_failures.append("save lost the completed mission")
						if int(loaded_data["player"]["cash"]) != 5250:
							_failures.append("save lost the reward (cash %s)" % str(loaded_data["player"]["cash"]))
						var vehicles: Array = loaded_data["vehicles"]
						if vehicles.is_empty() or int(vehicles[0].get("condition", -1)) != 100:
							_failures.append("save lost the vehicle condition")
				_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("TEST Slice B: PASS")
	else:
		print("TEST Slice B: FAIL — ", "; ".join(_failures))
	get_tree().quit()
