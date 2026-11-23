extends CharacterBody3D

## S21 — Police officer (Step 6, Slice C).
## States: Investigate, Pursue, Arrest, Search. (Patrol and
## Follow arrive with the full police loop, Phase 9.)
## The officer only runs its own state; the PoliceManager owns
## the wanted level, response selection and dispatch (B-11).
## Movement is direct steering on the street grid (no navmesh
## in the greybox); the officer slides along buildings.

const GRAVITY := 20.0

var health := 100
var max_health := 100
var is_dead := false

var state := "Investigate"
var last_known := Vector3.ZERO
var target_player: Node3D = null

var _config: Dictionary = {}
var _catch_timer := 0.0
var _attack_timer := 0.0
var _search_timer := 0.0
var _lose_timer := 0.0
var _manager = null

# Step 7 (Phase 15): procedural walk bob + hit flash + pursuit
# beacon (alternating red/blue spheres above the cap, visible
# only while Pursue). The flash re-caches the body material at
# hit time — the uniform is a shared scene sub-resource, so the
# override is swapped, never mutated.
const BOB_AMPLITUDE := 0.04
const BEACON_BLINK := 0.25
var _bob_phase := 0.0
var _bob_offset := 0.0
var _flash_timer := 0.0
var _body_mat: Material = null
var _flash_mat: StandardMaterial3D = null
var _bob_base := Vector3.ZERO
var _beacon_timer := 0.0
var _beacon_red_on := false

func get_bob_offset() -> float:
	return _bob_offset

func is_flashing() -> bool:
	return _flash_timer > 0.0

func is_beacon_on() -> bool:
	return state == "Pursue" and ($Visual/BeaconRed.visible or $Visual/BeaconBlue.visible)

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("police")
	_bob_base = $Visual.position
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.albedo_color = Color(1, 1, 1, 1)
	_flash_mat.emission_enabled = true
	_flash_mat.emission = Color(1, 1, 1, 1)
	_flash_mat.emission_energy_multiplier = 0.6
	$Visual/BeaconRed.visible = false
	$Visual/BeaconBlue.visible = false

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

func setup(config: Dictionary, manager, player: Node3D, start_state: String, known_pos: Vector3) -> void:
	_config = config
	_manager = manager
	target_player = player
	state = start_state
	last_known = known_pos
	_search_timer = float(config.get("search_time", 5.0))

func get_state() -> String:
	return state

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_animate(delta)
	_attack_timer = maxf(0.0, _attack_timer - delta)
	match state:
		"Investigate":
			_move_toward(last_known, float(_config.get("investigate_speed", 3.5)), delta)
			if global_position.distance_to(last_known) < 1.5:
				state = "Search"
				_search_timer = float(_config.get("search_time", 5.0))
		"Pursue":
			if target_player == null or not is_instance_valid(target_player):
				state = "Search"
				_search_timer = float(_config.get("search_time", 5.0))
				return
			if not target_player.visible:
				# The player is in a vehicle (hidden body): the
				# officer cannot see or catch them on foot.
				state = "Search"
				_search_timer = float(_config.get("search_time", 5.0))
				return
			var player_pos: Vector3 = target_player.global_position
			last_known = player_pos
			var dist := global_position.distance_to(player_pos)
			if dist > float(_config.get("lose_distance", 30.0)):
				_lose_timer += delta
				if _lose_timer >= float(_config.get("lose_time", 5.0)):
					_lose_timer = 0.0
					state = "Search"
					_search_timer = float(_config.get("search_time", 5.0))
					return
			else:
				_lose_timer = 0.0
			_move_toward(player_pos, float(_config.get("pursue_speed", 6.5)), delta)
			if dist <= float(_config.get("arrest_range", 1.8)):
				_catch_timer += delta
				if _catch_timer >= float(_config.get("arrest_time", 1.5)):
					state = "Arrest"
					if _manager != null and _manager.has_method("arrest_player"):
						_manager.arrest_player()
			else:
				_catch_timer = maxf(0.0, _catch_timer - delta)
				if dist <= float(_config.get("attack_range", 2.2)) and _attack_timer <= 0.0:
					_attack_timer = float(_config.get("attack_cooldown", 1.2))
					if target_player.has_method("damage"):
						target_player.damage(int(_config.get("attack_damage", 12)), "police")
		"Search":
			_search_timer -= delta
			velocity.x = 0.0
			velocity.z = 0.0
			if not is_on_floor():
				velocity.y -= GRAVITY * delta
			else:
				velocity.y = 0.0
			move_and_slide()
			if _search_timer <= 0.0:
				if target_player != null and is_instance_valid(target_player) and global_position.distance_to(target_player.global_position) < 18.0:
					state = "Pursue"
				elif _manager != null and _manager.has_method("recall_officer"):
					_manager.recall_officer(self)
		"Arrest":
			velocity = Vector3.ZERO
			move_and_slide()

func _animate(delta: float) -> void:
	var moving := state == "Pursue" or state == "Investigate"
	var h_speed := Vector2(velocity.x, velocity.z).length()
	if moving and h_speed > 0.5:
		_bob_phase += delta * h_speed * 1.8
		_bob_offset = sin(_bob_phase) * BOB_AMPLITUDE
	else:
		_bob_offset = move_toward(_bob_offset, 0.0, delta * 0.2)
	$Visual.position = _bob_base + Vector3(0, _bob_offset, 0)
	# Pursuit beacon: alternate red/blue while chasing, dark otherwise.
	if state == "Pursue":
		_beacon_timer += delta
		if _beacon_timer >= BEACON_BLINK:
			_beacon_timer = 0.0
			_beacon_red_on = not _beacon_red_on
			$Visual/BeaconRed.visible = _beacon_red_on
			$Visual/BeaconBlue.visible = not _beacon_red_on
	else:
		$Visual/BeaconRed.visible = false
		$Visual/BeaconBlue.visible = false
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		if _flash_timer <= 0.0:
			_restore_body_material()

func _move_toward(target: Vector3, speed: float, delta: float) -> void:
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

func damage(amount: int, source: String = "player") -> void:
	if is_dead:
		return
	health = maxi(0, health - amount)
	if source == "player":
		var bus = get_node_or_null("/root/EventBus")
		if bus != null:
			bus.emit_signal("hostile_act_committed", "attack_police", global_position)
	if health <= 0:
		_die()
		return
	_flash_body()
	# Hit officers fight back: they saw the attacker.
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player is Node3D:
		last_known = (player as Node3D).global_position
		target_player = player
		state = "Pursue"

func _die() -> void:
	is_dead = true
	state = "Dead"
	velocity = Vector3.ZERO
	_restore_body_material()
	_bob_offset = 0.0
	$Visual.position = Vector3.ZERO
	$Visual/BeaconRed.visible = false
	$Visual/BeaconBlue.visible = false
	var shape = get_node_or_null("CollisionShape3D")
	if shape != null:
		shape.set_deferred("disabled", true)
	$Visual.rotation = Vector3(PI / 2.0, $Visual.rotation.y, 0.0)
	print("Police officer died.")
