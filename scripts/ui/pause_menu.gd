extends CanvasLayer

## S06 — Pause Menu (Step 4).
## Overlay child of the World Root. The tree is paused while
## this is visible; this layer runs always (process_mode set
## in the scene) so its buttons work.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/VBox/ResumeButton.pressed.connect(_on_resume_pressed)
	$Panel/VBox/MapButton.pressed.connect(_on_map_pressed)
	$Panel/VBox/InventoryButton.pressed.connect(_on_inventory_pressed)
	$Panel/VBox/SettingsButton.pressed.connect(_on_settings_pressed)
	$Panel/VBox/SaveButton.pressed.connect(_on_save_pressed)
	$Panel/VBox/QuitButton.pressed.connect(_on_quit_pressed)
	$Panel/VBox/ObjectiveLabel.text = "Objective: Drive the car, finish the favour."
	$Panel/VBox/AutosaveLabel.text = "Autosave: not saved yet"

## Step 7 (Phase 14, S06): saving is unsafe mid-pursuit — the
## button is disabled and the reason is shown (blueprint B-13).
## Pure function so the headless test can check it directly.
static func is_save_safe(wanted_level: int) -> bool:
	return wanted_level <= 0

static func save_blocked_reason(wanted_level: int) -> String:
	if wanted_level <= 0:
		return ""
	return "Save unavailable — the police are after you."

func _current_wanted() -> int:
	var world = get_parent()
	if world != null and world.has_node("PoliceManager"):
		return int(world.get_node("PoliceManager").wanted_level)
	return 0

## Called by the world whenever the pause menu opens: refresh the
## objective, the autosave status and the save-button safety.
func refresh() -> void:
	var wanted := _current_wanted()
	$Panel/VBox/SaveButton.disabled = not is_save_safe(wanted)
	if not is_save_safe(wanted):
		$Panel/VBox/AutosaveLabel.text = save_blocked_reason(wanted)
	else:
		var slots: Array = SaveManager.list_slots()
		if not slots.is_empty() and bool(slots[0].get("exists", false)):
			$Panel/VBox/AutosaveLabel.text = "Autosaved " + str(slots[0].get("saved_at", ""))
		else:
			$Panel/VBox/AutosaveLabel.text = "Autosave: not saved yet"
	var active: String = MissionManager.get_active_mission()
	if active != "":
		var current: Dictionary = MissionManager.get_current_objective(active)
		var objective := str(current.get("text", ""))
		if objective != "":
			$Panel/VBox/ObjectiveLabel.text = "Objective: " + objective

func _save_to_autosave() -> bool:
	var world = get_parent()
	if world == null or not world.has_method("collect_save_data"):
		return false
	var saved: Dictionary = SaveManager.save_game(0, world.collect_save_data())
	return bool(saved.get("ok", false))

func _on_resume_pressed() -> void:
	UiFeedback.press($Panel/VBox/ResumeButton)
	GameManager.set_state(GameManager.State.PLAYING)

func _on_map_pressed() -> void:
	UiFeedback.press($Panel/VBox/MapButton)
	get_parent().show_map(true)

func _on_inventory_pressed() -> void:
	UiFeedback.press($Panel/VBox/InventoryButton)
	get_parent().show_inventory(true)

func _on_settings_pressed() -> void:
	UiFeedback.press($Panel/VBox/SettingsButton)
	# Step 7 (Phase 14, S04): Back in Settings returns to the
	# calling scene. The world is a full scene swap, so autosave
	# slot 0 first and come back through it; if the save fails
	# we fall back to the Main Menu instead of a broken world.
	if _save_to_autosave():
		GameManager.settings_return_target = "world"
	else:
		GameManager.settings_return_target = "menu"
	get_tree().paused = false
	GameManager.set_state(GameManager.State.MENU)
	GameManager.request_scene("res://scenes/frontend/settings.tscn")

func _on_save_pressed() -> void:
	UiFeedback.press($Panel/VBox/SaveButton)
	if not is_save_safe(_current_wanted()):
		$Panel/VBox/AutosaveLabel.text = save_blocked_reason(_current_wanted())
		return
	if _save_to_autosave():
		$Panel/VBox/AutosaveLabel.text = "Autosaved " + Time.get_time_string_from_system()
	else:
		$Panel/VBox/AutosaveLabel.text = "Save failed: no world data."

func _on_quit_pressed() -> void:
	UiFeedback.press($Panel/VBox/QuitButton)
	get_tree().paused = false
	GameManager.quit_to_menu()
