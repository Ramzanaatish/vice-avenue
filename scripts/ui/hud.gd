extends CanvasLayer

## S07 — HUD (Step 5).
## Listens ONLY to EventBus (B-11). Stores no game data.
## Jump/Sprint buttons drive Input actions; Interact/Attack/Aim
## arrive with their phases (S12 dialogue, Phase 7 combat).
## Vehicle mode (Step 5): the right cluster swaps to
## Accel/Brake/Handbrake, the joystick steers, and the minimap
## follows the car.

var _notify_tween: Tween = null
var _vehicle = null

# Step 7 (Phase 14): touch controls actually honour the S04
# settings (button size / opacity / FPS display). Before this
# step the sliders existed but nothing in the game read them.
const TOUCH_NODES: Array[String] = [
	"SprintButton", "JumpButton", "AttackButton", "InteractButton",
	"AccelButton", "BrakeButton", "HandbrakeButton",
	"InventoryButton", "MapButton", "MoveJoystick",
]

func _ready() -> void:
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.health_changed.connect(_on_health_changed)
		bus.money_changed.connect(_on_money_changed)
		bus.wanted_changed.connect(_on_wanted_changed)
		bus.notification_requested.connect(_on_notification_requested)
	var settings = get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_signal("settings_applied"):
		settings.settings_applied.connect(_apply_touch_layout)
		settings.settings_applied.connect(_apply_fps_visibility)
	$SafeArea/HealthBar.max_value = 100
	$SafeArea/HealthBar.value = 100
	$SafeArea/MoneyLabel.text = "Rs " + str(EconomyManager.cash)
	$SafeArea/WantedLabel.text = "Wanted: 0"
	$SafeArea/ObjectiveLabel.text = "Slice B: Drive the car, finish the favour."
	_apply_touch_layout()
	_apply_fps_visibility()
	$SafeArea/PauseButton.pressed.connect(_on_pause_pressed)
	$SafeArea/JumpButton.pressed.connect(_on_jump_pressed)
	$SafeArea/JumpButton.button_up.connect(_on_jump_released)
	$SafeArea/SprintButton.button_down.connect(_on_sprint_down)
	$SafeArea/SprintButton.button_up.connect(_on_sprint_up)
	$SafeArea/InteractButton.pressed.connect(_on_interact_pressed)
	$SafeArea/InteractButton.button_up.connect(_on_interact_released)
	$SafeArea/AccelButton.button_down.connect(func() -> void: Input.action_press("accelerate"))
	$SafeArea/AccelButton.button_up.connect(func() -> void: Input.action_release("accelerate"))
	$SafeArea/BrakeButton.button_down.connect(func() -> void: Input.action_press("brake"))
	$SafeArea/BrakeButton.button_up.connect(func() -> void: Input.action_release("brake"))
	$SafeArea/HandbrakeButton.button_down.connect(func() -> void: Input.action_press("handbrake"))
	$SafeArea/HandbrakeButton.button_up.connect(func() -> void: Input.action_release("handbrake"))
	$SafeArea/InventoryButton.pressed.connect(_on_inventory_pressed)
	$SafeArea/AttackButton.button_down.connect(_on_attack_down)
	$SafeArea/AttackButton.button_up.connect(_on_attack_up)
	$SafeArea/MapButton.pressed.connect(_on_map_pressed)
	print("HUD ready.")

func _process(_delta: float) -> void:
	if _vehicle != null:
		$SafeArea/SpeedLabel.text = "%d km/h" % int(_vehicle.get_speed_kmh())
	if $SafeArea/FpsLabel.visible:
		$SafeArea/FpsLabel.text = "%d FPS" % Engine.get_frames_per_second()

func _apply_touch_layout() -> void:
	var settings = get_node_or_null("/root/SettingsManager")
	if settings == null:
		return
	var size_factor := clampf(float(settings.get_value("controls/button_size")), 0.5, 1.5)
	var opacity := clampf(float(settings.get_value("controls/button_opacity")), 0.3, 1.0)
	for node_name in TOUCH_NODES:
		var node := $SafeArea.get_node_or_null(node_name)
		if node == null:
			continue
		node.pivot_offset = node.size * 0.5
		node.scale = Vector2(size_factor, size_factor)
		node.modulate.a = opacity

func _apply_fps_visibility() -> void:
	var settings = get_node_or_null("/root/SettingsManager")
	if settings == null:
		return
	$SafeArea/FpsLabel.visible = bool(settings.get_value("graphics/show_fps"))

func set_objective(text: String) -> void:
	$SafeArea/ObjectiveLabel.text = text

func set_interact_visible(visible: bool, text: String) -> void:
	$SafeArea/InteractButton.visible = visible
	if text != "":
		$SafeArea/InteractButton.text = text

func set_vehicle_mode(driving: bool, car) -> void:
	_vehicle = car if driving else null
	$SafeArea/JumpButton.visible = not driving
	$SafeArea/SprintButton.visible = not driving
	$SafeArea/AttackButton.visible = not driving
	$SafeArea/AccelButton.visible = driving
	$SafeArea/BrakeButton.visible = driving
	$SafeArea/HandbrakeButton.visible = driving
	$SafeArea/SpeedLabel.visible = driving
	$SafeArea/MoveJoystick.vehicle_mode = driving
	var minimap = $SafeArea/Minimap
	if driving:
		minimap.set_player(car)
	else:
		var player = get_parent().get_node_or_null("Dynamic/Player")
		if player != null:
			minimap.set_player(player)

func _on_health_changed(current: int, maximum: int) -> void:
	$SafeArea/HealthBar.max_value = maximum
	$SafeArea/HealthBar.value = current

func _on_money_changed(new_amount: int) -> void:
	$SafeArea/MoneyLabel.text = "Rs " + str(new_amount)

func _on_wanted_changed(level: int) -> void:
	$SafeArea/WantedLabel.text = "Wanted: " + str(level)
	# Step 7: wanted is red while the police are after the player.
	if level > 0:
		$SafeArea/WantedLabel.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3, 1.0))
	else:
		$SafeArea/WantedLabel.remove_theme_color_override("font_color")

func _on_notification_requested(text: String) -> void:
	var label := $SafeArea/NotificationLabel
	label.text = text
	label.modulate.a = 1.0
	if _notify_tween != null:
		_notify_tween.kill()
	_notify_tween = create_tween()
	_notify_tween.tween_interval(2.0)
	_notify_tween.tween_property(label, "modulate:a", 0.0, 1.0)

func _on_pause_pressed() -> void:
	UiFeedback.press($SafeArea/PauseButton)
	GameManager.set_state(GameManager.State.PAUSED)

func _on_jump_pressed() -> void:
	Input.action_press("jump")

func _on_jump_released() -> void:
	Input.action_release("jump")

func _on_sprint_down() -> void:
	Input.action_press("sprint")

func _on_sprint_up() -> void:
	Input.action_release("sprint")

func _on_interact_pressed() -> void:
	UiFeedback.press($SafeArea/InteractButton)
	Input.action_press("interact")

func _on_interact_released() -> void:
	Input.action_release("interact")

func _on_inventory_pressed() -> void:
	UiFeedback.press($SafeArea/InventoryButton)
	get_parent().show_inventory(false)

func _on_attack_down() -> void:
	Input.action_press("attack")

func _on_attack_up() -> void:
	Input.action_release("attack")

func _on_map_pressed() -> void:
	UiFeedback.press($SafeArea/MapButton)
	get_parent().show_map(false)
