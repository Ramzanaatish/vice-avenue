extends VehicleBody3D

## S19 — one drivable car. Tuning is DATA (data/vehicles/car_01.json).
## Reads the vehicle actions (accelerate/brake/steer_left/steer_right/
## handbrake) only while `driven` is true. Damage reduces engine
## force; condition 0 = cannot drive (needs a workshop repair, S22).

const TUNING_PATH := "res://data/vehicles/car_01.json"

var condition: int = 100
var driven: bool = false
var tuning: Dictionary = {}

var _steer_target: float = 0.0

func _ready() -> void:
	_load_tuning()
	mass = float(tuning.get("mass", 1200.0))
	print("Car ready (", str(tuning.get("name", "car")), ", condition ", condition, ").")

func _load_tuning() -> void:
	if not FileAccess.file_exists(TUNING_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TUNING_PATH))
	if parsed is Dictionary:
		tuning = parsed

func _physics_process(delta: float) -> void:
	if not driven:
		engine_force = 0.0
		brake = float(tuning.get("brake_force", 12000.0))
		steering = move_toward(steering, 0.0, 0.02)
		return
	var max_speed := float(tuning.get("max_speed", 28.0))
	var speed := linear_velocity.length()
	var accel := Input.get_action_strength("accelerate")
	var brake_input := Input.get_action_strength("brake")
	var steer_input := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	_steer_target = steer_input * float(tuning.get("max_steer", 0.55))
	steering = move_toward(steering, _steer_target, float(tuning.get("steer_speed", 2.5)) * delta)
	var health_factor := float(condition) / 100.0
	if Input.is_action_pressed("handbrake"):
		engine_force = 0.0
		brake = float(tuning.get("handbrake_force", 20000.0))
	elif condition <= 0:
		engine_force = 0.0
		brake = float(tuning.get("brake_force", 12000.0))
	else:
		engine_force = accel * float(tuning.get("engine_force", 9000.0)) * health_factor
		if speed > max_speed:
			engine_force = 0.0
		brake = brake_input * float(tuning.get("brake_force", 12000.0))

func damage(amount: int) -> void:
	condition = maxi(0, condition - amount)
	if condition <= 0:
		var bus = get_node_or_null("/root/EventBus")
		if bus != null:
			bus.emit_signal("notification_requested", "The car is wrecked — it needs a workshop repair.")

func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6
