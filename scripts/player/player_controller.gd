extends CharacterBody3D

## S18 — Player controller (Step 4, Slice A).
## Third-person, camera-relative movement. Tuning comes from
## data/player_tuning.json (never hardcoded). Input is collected
## only through Input actions, so keyboard, touch (S07) and
## future controllers share one action map.

const TUNING_PATH := "res://data/player_tuning.json"
# Step 6 (Slice C): basic melee combat. Damageables (NPCs, police)
# join the "damageable" group; the attack hits the nearest one
# in front of the player. Tuning lives here only until the
# weapon data file arrives (Phase 7); it is a plain constant,
# not a hardcoded story line.
const ATTACK_RANGE := 2.4
const ATTACK_ARC_DEGREES := 60.0
const ATTACK_DAMAGE := 34
const ATTACK_COOLDOWN := 0.45

var health := 100
var is_dead := false
var walk_speed := 5.0
var sprint_speed := 8.0
var accel := 12.0
var jump_velocity := 7.0
var gravity := 20.0
var mouse_sensitivity := 0.0025

var _cam_yaw := 0.0
var _cam_pitch := -0.35
var _attack_timer := 0.0

# Step 7 (Phase 15): procedural animation — walk bob + lean,
# attack lunge, hit flash, camera shake. No new assets: the
# greybox body is a capsule, so the motion sells the movement.
# Step 7 (Phase 14): camera sensitivity / invert come from S04
# (before this step the sliders existed but nothing read them).
const SWING_TIME := 0.18
const BOB_AMPLITUDE := 0.045
var _sensitivity_scale := 1.0
var _invert_camera := false
var _bob_phase := 0.0
var _bob_offset := 0.0
var _swing_timer := 0.0
var _flash_timer := 0.0
var _shake_timer := 0.0
var _shake_strength := 0.0
var _body_mat: Material = null
var _flash_mat: StandardMaterial3D = null
var _spring_base := Vector3.ZERO

func get_bob_offset() -> float:
	return _bob_offset

func is_swinging() -> bool:
	return _swing_timer > 0.0

func is_flashing() -> bool:
	return _flash_timer > 0.0

func get_sensitivity_scale() -> float:
	return _sensitivity_scale

func is_invert_camera() -> bool:
	return _invert_camera

func get_shake_timer() -> float:
	return _shake_timer

func _ready() -> void:
	add_to_group("player")
	_load_tuning()
	$SpringArm3D.rotation = Vector3(_cam_pitch, 0, 0)
	_spring_base = $SpringArm3D.position
	_body_mat = $Visual/Body.get_surface_override_material(0)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.albedo_color = Color(1, 1, 1, 1)
	_flash_mat.emission_enabled = true
	_flash_mat.emission = Color(1, 1, 1, 1)
	_flash_mat.emission_energy_multiplier = 0.6
	_apply_control_settings()
	var settings = get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_signal("settings_applied"):
		settings.settings_applied.connect(_apply_control_settings)
	print("Player ready (walk ", walk_speed, ", sprint ", sprint_speed, ").")

func _apply_control_settings() -> void:
	var settings = get_node_or_null("/root/SettingsManager")
	if settings == null:
		return
	_sensitivity_scale = clampf(float(settings.get_value("controls/sensitivity")), 0.5, 2.0)
	_invert_camera = bool(settings.get_value("controls/invert_camera"))

func _load_tuning() -> void:
	if not FileAccess.file_exists(TUNING_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TUNING_PATH))
	if parsed is Dictionary:
		walk_speed = float(parsed.get("walk_speed", walk_speed))
		sprint_speed = float(parsed.get("sprint_speed", sprint_speed))
		accel = float(parsed.get("accel", accel))
		jump_velocity = float(parsed.get("jump_velocity", jump_velocity))
		gravity = float(parsed.get("gravity", gravity))
		mouse_sensitivity = float(parsed.get("mouse_sensitivity", mouse_sensitivity))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)
	elif event is InputEventScreenDrag:
		_rotate_camera(event.relative * 2.0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _rotate_camera(relative: Vector2) -> void:
	var sens := mouse_sensitivity * _sensitivity_scale
	_cam_yaw -= relative.x * sens
	if _invert_camera:
		_cam_pitch = clampf(_cam_pitch + relative.y * sens, -1.2, 0.4)
	else:
		_cam_pitch = clampf(_cam_pitch - relative.y * sens, -1.2, 0.4)
	$SpringArm3D.rotation = Vector3(_cam_pitch, _cam_yaw, 0)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if Input.is_action_just_pressed("attack"):
		attack()
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3.ZERO
	if input_dir.length() > 0.01:
		dir = (Basis(Vector3.UP, _cam_yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	move_and_slide()
	if dir.length() > 0.01:
		var target_yaw := atan2(dir.x, dir.z)
		$Visual.rotation.y = lerp_angle($Visual.rotation.y, target_yaw, 10.0 * delta)
	_animate(delta, dir)

func _animate(delta: float, move_dir: Vector3) -> void:
	# Walk bob + lean (procedural, greybox-safe).
	var h_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and h_speed > 0.5:
		_bob_phase += delta * h_speed * 1.6
		_bob_offset = sin(_bob_phase) * BOB_AMPLITUDE
	else:
		_bob_offset = move_toward(_bob_offset, 0.0, delta * 0.2)
	# Attack lunge: forward along the facing, sine arc.
	var lunge := 0.0
	if _swing_timer > 0.0:
		_swing_timer = maxf(0.0, _swing_timer - delta)
		lunge = sin((SWING_TIME - _swing_timer) / SWING_TIME * PI) * 0.18
	var forward: Vector3 = Basis(Vector3.UP, $Visual.rotation.y).z
	$Visual.position = forward * lunge + Vector3(0, _bob_offset, 0)
	$Visual.rotation.x = clampf(h_speed * 0.012, 0.0, 0.08) if move_dir.length() > 0.01 else 0.0
	# Hit flash restore.
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		if _flash_timer <= 0.0:
			_restore_body_material()
	# Camera shake decay.
	if _shake_timer > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		var s := _shake_strength * (_shake_timer / 0.25)
		$SpringArm3D.position = _spring_base + Vector3(randf_range(-s, s), randf_range(-s, s), 0.0)
	else:
		$SpringArm3D.position = _spring_base

func _flash_body() -> void:
	if _body_mat == null or _flash_mat == null:
		return
	$Visual/Body.set_surface_override_material(0, _flash_mat)
	_flash_timer = 0.15

func _restore_body_material() -> void:
	if _body_mat == null:
		return
	$Visual/Body.set_surface_override_material(0, _body_mat)
	_flash_timer = 0.0

func attack() -> void:
	if is_dead or _attack_timer > 0.0:
		return
	_attack_timer = ATTACK_COOLDOWN
	_swing_timer = SWING_TIME
	var best: Node3D = null
	var best_dist := ATTACK_RANGE
	# Facing: rotation.y = atan2(dir.x, dir.z) in _physics_process,
	# so the facing vector is (sin(yaw), 0, cos(yaw)) = Basis.z.
	var forward: Vector3 = Basis(Vector3.UP, $Visual.rotation.y).z
	for target in get_tree().get_nodes_in_group("damageable"):
		if not (target is Node3D):
			continue
		if bool(target.get("is_dead")):
			continue
		var to_target: Vector3 = (target as Node3D).global_position - global_position
		to_target.y = 0.0
		var dist := to_target.length()
		if dist > ATTACK_RANGE or dist < 0.05:
			continue
		var angle := rad_to_deg(forward.angle_to(to_target.normalized()))
		if angle > ATTACK_ARC_DEGREES:
			continue
		if dist < best_dist:
			best = target
			best_dist = dist
	if best != null:
		best.damage(ATTACK_DAMAGE, "player")
		var audio = get_node_or_null("/root/AudioManager")
		if audio != null and audio.has_method("play_hit"):
			audio.play_hit()
		print("Player attacked ", best.name, " (", ATTACK_DAMAGE, " dmg).")

func get_facing_yaw() -> float:
	return $Visual.rotation.y

func set_facing(yaw: float) -> void:
	$Visual.rotation.y = yaw

func heal() -> void:
	health = 100
	is_dead = false
	EventBus.emit_signal("health_changed", health, 100)

func damage(amount: int, cause: String = "damage") -> void:
	if health <= 0 or is_dead:
		return
	health = maxi(0, health - amount)
	EventBus.emit_signal("health_changed", health, 100)
	if health <= 0:
		is_dead = true
		_restore_body_material()
		var audio = get_node_or_null("/root/AudioManager")
		if audio != null and audio.has_method("play_death_sting"):
			audio.play_death_sting()
		EventBus.emit_signal("player_died", cause)
		print("Player died (", cause, ").")
		return
	_flash_body()
	var settings = get_node_or_null("/root/SettingsManager")
	if settings != null and bool(settings.get_value("accessibility/camera_shake")):
		_shake_timer = 0.25
		_shake_strength = 0.12
