extends CanvasLayer

## S15 — Game Over / Death (Step 6, Slice C).
## Shown when the player dies (health 0) or is arrested (wanted
## fail state). Offers Retry from the last checkpoint (the
## autosave slot), Load a manual slot, or Quit to the Main Menu.
## Never deletes progress. Headers are original wording.
## The tree is paused while this is open; this layer runs
## always so its buttons work.

signal retry_pressed
signal load_pressed
signal quit_pressed

var _cause := "damage"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Overlay/VBox/RetryButton.pressed.connect(func() -> void: UiFeedback.press($Overlay/VBox/RetryButton); retry_pressed.emit())
	$Overlay/VBox/LoadButton.pressed.connect(func() -> void: UiFeedback.press($Overlay/VBox/LoadButton); load_pressed.emit())
	$Overlay/VBox/QuitButton.pressed.connect(func() -> void: UiFeedback.press($Overlay/VBox/QuitButton); quit_pressed.emit())
	visible = false

func is_open() -> bool:
	return visible

func get_cause() -> String:
	return _cause

func show_game_over(cause: String) -> void:
	_cause = cause
	match cause:
		"arrested":
			$Overlay/VBox/HeaderLabel.text = "IN CUSTODY"
			$Overlay/VBox/CauseLabel.text = "Arrested by the police."
		"police":
			$Overlay/VBox/HeaderLabel.text = "DOWN AND OUT"
			$Overlay/VBox/CauseLabel.text = "Killed by the police."
		_:
			$Overlay/VBox/HeaderLabel.text = "DOWN AND OUT"
			$Overlay/VBox/CauseLabel.text = "Killed in the streets."
	var slots: Array = SaveManager.list_slots()
	var autosave: Dictionary = slots[0]
	$Overlay/VBox/RetryButton.disabled = not bool(autosave.get("exists", false))
	if bool(autosave.get("exists", false)):
		$Overlay/VBox/AutosaveLabel.text = "Last autosave: " + str(autosave.get("saved_at", ""))
	else:
		$Overlay/VBox/AutosaveLabel.text = "No autosave yet — Retry is unavailable."
	visible = true
	# Step 7 (Phase 14): the overlay fades in instead of popping.
	$Overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property($Overlay, "modulate:a", 1.0, 0.2)

func hide_game_over() -> void:
	visible = false
