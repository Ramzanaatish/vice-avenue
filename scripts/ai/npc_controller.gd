extends CharacterBody3D

## S20 — NPC pedestrian (Step 6, Slice C).
## Finite-state machine: Idle, Walk, Talk, Flee, Dead.
## Waypoint walking on the street grid (no navmesh in the
## greybox — waypoints come from data/npcs/*.json and stay on
## the roads). NPC runtime state is NOT saved (S20): on load
## the NPCManager respawns NPCs from their routines.
## Attacking an NPC raises wanted heat through the EventBus
## (hostile_act_committed) — the NPC never touches the
## PoliceManager directly (B-11).

const WALK_SPEED := 2.0
const FLEE_SPEED := 5.5
const FLEE_TIME := 3.0
const CALL_POLICE_DELAY := 2.0
const IDLE_MIN := 2.0
const IDLE_MAX := 4.0
const GRAVITY := 20.0

var npc_id := ""
var display_name := ""
var dialogue_id := ""
var archetype := "civilian"
var health := 100
var max_health := 100
var is_dead := false

var _state := "Idle"
var _waypoints: Array = []
var _waypoint_index := 0
var _idle_timer := 0.0
var _flee_timer := 0.0
var _flee_from := Vector3.ZERO
var _call_police_timer := -1.0
var _called_police := false

# Step 7 (Phase 15): procedural walk bob + hit flash (greybox
# capsule + sphere head, no new assets). The flash re-caches
# the current body material at hit time, because set_body_color
# replaces the override per NPC at spawn.
const BOB_AMPLITUDE := 0.04
var _bob_phase := 0.0
var _bob_offset := 0.0
var _flash_timer := 0.0
var _body_mat: Material = null
var _flash_mat: StandardMaterial3D = null
var _bob_base := Vector3.ZERO

func get_bob_offset() -> float:
	return _bob_offset

func is_flashing() -> bool:
	return _flash_timer > 0.0

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("npc")
	_bob_base = $Visual.position
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.albedo_color = Color(1, 1, 1, 1)
	_flash_mat.emission_enabled = true
	_flash_mat.emission = Color(1, 1, 1, 1)
	_flash_mat.emission_energy_multiplier = 0.6

func setup(data: Dictionary) -> void:
	npc_id = str(data.get("id", "npc"))
	display_name = str(data.get("name", "Civilian"))
	dialogue_id = str(data.get("dialogue", ""))
	archetype = str(data.get("archetype", "civilian"))
	max_health = int(data.get("health", 100))
	health = max_health
	var color: Array = data.get("color", [0.5, 0.5, 0.5])
	set_body_color(Color(float(color[0]), float(color[1]), float(color[2])))
	_waypoints = data.get("waypoints", [])
	if _waypoints.is_empty():
		_state = "Idle"
	else:
		_state = "Walk"
		_waypoint_index = 0

func set_body_color(color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var body = get_node_or_null("Visual/Body")
	if body != null:
		body.set_surface_override_material(0, mat)

func _get_body_mesh() -> MeshInstance3D:
	return $Visual/Body

func _flash_body() -> void:
	if _flash_mat == null:
		return
	if _flash_timer > 0.0:
		_flash_timer = 0.15
		return
	_body_mat = _get_body_mesh().get_surface_override_material(0)
	_get_body_mesh().set_surface_override_material(0, _flash_mat)
	_flash_timer = 0.15

func _restore_body_material() -> void:
	if _body_mat == null:
		return
	_get_body_mesh().set_surface_override_material(0, _body_mat)
	_flash_timer = 0.0

func set_talk(talking: bool) -> void:
	if is_dead:
		return
	if talking:
		_state = "Talk"
		velocity = Vector3.ZERO
	elif _state == "Talk":
		_state = "Idle" if _waypoints.is_empty() else "Walk"
		_idle_timer = 0.0

func get_state() -> String:
	return _state

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_animate(delta)
	if _call_police_timer > 0.0:
		_call_police_timer -= delta
		if _call_police_timer <= 0.0 and not _called_police:
			_called_police = true
			var bus = get_node_or_null("/root/EventBus")
			if bus != null:
				bus.emit_signal("hostile_act_committed", "call_police", global_position)
				bus.emit_signal("notification_requested", "Someone called the police!")
	if _state == "Talk" or _state == "Idle":
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity = Vector3.ZERO
		if _state == "Idle" and not _waypoints.is_empty():
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_state = "Walk"
		move_and_slide()
		return
	var target := Vector3.ZERO
	var speed := WALK_SPEED
	if _state == "Walk":
		target = _current_waypoint()
		if global_position.distance_to(target) < 1.0:
			_waypoint_index = (_waypoint_index + 1) % _waypoints.size()
			_state = "Idle"
			_idle_timer = randf_range(IDLE_MIN, IDLE_MAX)
			velocity = Vector3.ZERO
			move_and_slide()
			return
	elif _state == "Flee":
		_flee_timer -= delta
		var away: Vector3 = global_position - _flee_from
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3(0, 0, 1)
		target = global_position + away.normalized() * 10.0
		speed = FLEE_SPEED
		if _flee_timer <= 0.0:
			_state = "Idle"
			_idle_timer = randf_range(IDLE_MIN, IDLE_MAX)
			velocity = Vector3.ZERO
			move_and_slide()
			return
	var dir: Vector3 = target - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		var target_yaw := atan2(dir.x, dir.z)
		$Visual.rotation.y = lerp_angle($Visual.rotation.y, target_yaw, 8.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _animate(delta: float) -> void:
	var moving := _state == "Walk" or _state == "Flee"
	var h_speed := Vector2(velocity.x, velocity.z).length()
	if moving and h_speed > 0.5:
		_bob_phase += delta * h_speed * 1.8
		_bob_offset = sin(_bob_phase) * BOB_AMPLITUDE
	else:
		_bob_offset = move_toward(_bob_offset, 0.0, delta * 0.2)
	$Visual.position = _bob_base + Vector3(0, _bob_offset, 0)
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		if _flash_timer <= 0.0:
			_restore_body_material()

func _current_waypoint() -> Vector3:
	if _waypoints.is_empty():
		return global_position
	var wp: Dictionary = _waypoints[_waypoint_index]
	return Vector3(float(wp.get("x", 0.0)), 0.0, float(wp.get("z", 0.0)))

func damage(amount: int, source: String = "player") -> void:
	if is_dead:
		return
	health = maxi(0, health - amount)
	if source == "player":
		var bus = get_node_or_null("/root/EventBus")
		if bus != null:
			bus.emit_signal("hostile_act_committed", "attack_npc", global_position)
	if health <= 0:
		_die()
		return
	_flash_body()
	# Survive a hit: run away from the attacker (the player).
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player is Node3D:
		_flee_from = (player as Node3D).global_position
	else:
		_flee_from = global_position + Vector3(0, 0, 1)
	_state = "Flee"
	_flee_timer = FLEE_TIME
	if not _called_police:
		_call_police_timer = CALL_POLICE_DELAY

func _die() -> void:
	is_dead = true
	_state = "Dead"
	velocity = Vector3.ZERO
	_restore_body_material()
	_bob_offset = 0.0
	$Visual.position = Vector3.ZERO
	var shape = get_node_or_null("CollisionShape3D")
	if shape != null:
		shape.set_deferred("disabled", true)
	# Fall flat on the ground (greybox death pose).
	$Visual.rotation = Vector3(PI / 2.0, $Visual.rotation.y, 0.0)
	print("NPC ", npc_id, " died.")
