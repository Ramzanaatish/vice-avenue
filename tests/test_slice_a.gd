extends Node

## Slice A self-test (Step 4). Run it with:
##   godot --headless --path . res://tests/test_slice_a.tscn
## Drives the real input actions and checks the player moves,
## pause freezes the tree, and the HUD updates.

var _world: Node3D
var _player: CharacterBody3D
var _phase := 0
var _timer := 0.0
var _start_pos := Vector3.ZERO
var _failures: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var packed: PackedScene = load("res://scenes/world/world_root.tscn")
	_world = packed.instantiate()
	add_child(_world)
	_player = _world.get_node("Dynamic/Player")
	_start_pos = _player.global_position
	print("TEST Slice A: world loaded, player at ", _start_pos)

func _process(delta: float) -> void:
	_timer += delta
	match _phase:
		0:
			if _timer > 0.5:
				Input.action_press("move_forward", 1.0)
				_phase = 1
				_timer = 0.0
		1:
			if _timer > 1.0:
				Input.action_release("move_forward")
				var moved := _player.global_position - _start_pos
				var horiz := Vector2(moved.x, moved.z).length()
				print("TEST Slice A: moved ", moved, " (horizontal ", snappedf(horiz, 0.1), " m)")
				if horiz < 2.0:
					_failures.append("player did not move (horizontal %s m)" % str(snappedf(horiz, 0.1)))
				if absf(_player.global_position.y) > 0.5:
					_failures.append("player fell through the ground (y = %s)" % str(snappedf(_player.global_position.y, 0.1)))
				var money_label = _world.get_node("HUD/SafeArea/MoneyLabel")
				if money_label.text != "Rs 250":
					_failures.append("HUD money label wrong: " + money_label.text)
				_player.damage(10)
				_phase = 2
				_timer = 0.0
		2:
			if _timer > 0.3:
				var bar = _world.get_node("HUD/SafeArea/HealthBar")
				print("TEST Slice A: health bar value ", bar.value)
				if int(bar.value) != 90:
					_failures.append("HUD health bar did not update (value %s)" % str(bar.value))
				GameManager.set_state(GameManager.State.PAUSED)
				_phase = 3
				_timer = 0.0
		3:
			if _timer > 0.3:
				if not get_tree().paused:
					_failures.append("tree not paused after PAUSED state")
				if not _world.get_node("PauseMenu").visible:
					_failures.append("pause overlay not visible")
				GameManager.set_state(GameManager.State.PLAYING)
				_phase = 4
				_timer = 0.0
		4:
			if _timer > 0.3:
				if get_tree().paused:
					_failures.append("tree still paused after resume")
				_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("TEST Slice A: PASS")
	else:
		print("TEST Slice A: FAIL — ", "; ".join(_failures))
	get_tree().quit()
