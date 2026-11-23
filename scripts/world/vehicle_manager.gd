extends Node

## S19 enter/exit + vehicle mode. Scene-owned (child of WorldRoot).
## Proximity: player within 3.5 m of the car. Enter/exit via the
## interact action (E) or the HUD Interact button (same action).
## While driving, the player's body is hidden and frozen and the
## car's chase camera takes over.

const ENTER_DISTANCE := 3.5

var player = null
var car = null
var hud = null
var driving: bool = false

var _near_car: bool = false

func _ready() -> void:
	var root = get_parent()
	player = root.get_node("Dynamic/Player")
	car = root.get_node("Dynamic/Car")
	hud = root.get_node("HUD")

func _physics_process(_delta: float) -> void:
	# Step 6: input is arbitrated by WorldRoot (one owner for
	# the interact action); this manager only tracks proximity.
	# Enter/exit are called by WorldRoot.
	if player == null or car == null:
		return
	_near_car = player.global_position.distance_to(car.global_position) < ENTER_DISTANCE

func is_near_car() -> bool:
	return _near_car

func enter_vehicle() -> void:
	if driving or player == null or car == null:
		return
	if int(car.get("condition")) <= 0:
		_notify("The car is wrecked — it needs a workshop repair.")
		return
	driving = true
	car.driven = true
	player.visible = false
	player.set_physics_process(false)
	var shape = player.get_node_or_null("CollisionShape3D")
	if shape != null:
		shape.set_deferred("disabled", true)
	var player_cam = player.get_node_or_null("SpringArm3D/Camera3D")
	if player_cam != null:
		player_cam.current = false
	var car_cam = car.get_node_or_null("CameraRig/Camera3D")
	if car_cam != null:
		car_cam.current = true
	if hud != null:
		hud.set_interact_visible(false, "")
		hud.set_vehicle_mode(true, car)
	_notify("Driving — W/S to drive, A/D to steer, Space handbrake, E to exit.")

func exit_vehicle() -> void:
	if not driving or player == null or car == null:
		return
	driving = false
	car.driven = false
	var exit_point = car.get_node_or_null("ExitPoint")
	if exit_point != null:
		player.global_position = exit_point.global_position
	player.visible = true
	player.set_physics_process(true)
	var shape = player.get_node_or_null("CollisionShape3D")
	if shape != null:
		shape.set_deferred("disabled", false)
	var car_cam = car.get_node_or_null("CameraRig/Camera3D")
	if car_cam != null:
		car_cam.current = false
	var player_cam = player.get_node_or_null("SpringArm3D/Camera3D")
	if player_cam != null:
		player_cam.current = true
	if hud != null:
		hud.set_vehicle_mode(false, null)
	_notify("You got out of the car.")

func _notify(text: String) -> void:
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal("notification_requested", text)
