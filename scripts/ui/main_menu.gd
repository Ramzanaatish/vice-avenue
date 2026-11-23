extends Control

## S03 — Main Menu (Step 3).
## Continue (only if a save exists), New Game (-> S05),
## Settings (-> S04), Credits (-> S16, later step), Exit.
## Shows the latest save summary + version + Offline.

const WORLD_SCENE := "res://scenes/world/world_root.tscn"
const CREDITS_SCENE := "res://scenes/frontend/credits.tscn"

var _latest_slot := -1

func _ready() -> void:
	$VersionLabel.text = "v" + VersionManager.get_game_version()
	$OfflineLabel.text = "Offline"
	$Center/MenuBox/ContinueButton.pressed.connect(_on_continue_pressed)
	$Center/MenuBox/NewGameButton.pressed.connect(_on_new_game_pressed)
	$Center/MenuBox/SettingsButton.pressed.connect(_on_settings_pressed)
	$Center/MenuBox/CreditsButton.pressed.connect(_on_credits_pressed)
	$Center/MenuBox/ExitButton.pressed.connect(_on_exit_pressed)
	$ExitConfirm.confirmed.connect(_on_exit_confirmed)
	_refresh()
	print("Main Menu shown.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		$ExitConfirm.popup_centered()

func _refresh() -> void:
	var slots: Array = SaveManager.list_slots()
	_latest_slot = -1
	var latest_at := ""
	for info in slots:
		if bool(info.get("exists", false)) and str(info.get("saved_at", "")) > latest_at:
			latest_at = str(info.get("saved_at", ""))
			_latest_slot = int(info.get("slot", -1))
	$Center/MenuBox/ContinueButton.disabled = _latest_slot < 0
	if _latest_slot >= 0:
		var info: Dictionary = {}
		for s in slots:
			if int(s.get("slot", -1)) == _latest_slot:
				info = s
		$SaveSummary.text = "Latest save: Slot %d — %s — Rs %d — %s" % [_latest_slot, str(info.get("chapter", "?")), int(info.get("money", 0)), str(info.get("saved_at", ""))]
	else:
		$SaveSummary.text = "No saves yet."

func _on_continue_pressed() -> void:
	UiFeedback.press($Center/MenuBox/ContinueButton)
	if _latest_slot < 0:
		return
	var loaded: Dictionary = SaveManager.load_slot(_latest_slot)
	if not bool(loaded.get("ok", false)):
		$SaveSummary.text = "Load failed: " + str(loaded.get("error", "?"))
		return
	# v1.1.2: ResourceLoader.exists, not the FileAccess existence
	# check — the .tscn is remapped in an exported build (see
	# app_root.gd).
	if not ResourceLoader.exists(WORLD_SCENE, "PackedScene"):
		$SaveSummary.text = "Save loaded OK (Slot %d). World scene arrives in Slice A (Step 4)." % _latest_slot
		return
	GameManager.continue_game(_latest_slot)

func _on_new_game_pressed() -> void:
	UiFeedback.press($Center/MenuBox/NewGameButton)
	GameManager.request_scene("res://scenes/frontend/save_slots.tscn")

func _on_settings_pressed() -> void:
	UiFeedback.press($Center/MenuBox/SettingsButton)
	GameManager.request_scene("res://scenes/frontend/settings.tscn")

func _on_credits_pressed() -> void:
	UiFeedback.press($Center/MenuBox/CreditsButton)
	# v1.1.2: ResourceLoader.exists, not the FileAccess existence
	# check — the .tscn is remapped in an exported build (see
	# app_root.gd).
	if not ResourceLoader.exists(CREDITS_SCENE, "PackedScene"):
		$SaveSummary.text = "Credits scene is not built yet (later step)."
		return
	GameManager.request_scene(CREDITS_SCENE)

func _on_exit_pressed() -> void:
	UiFeedback.press($Center/MenuBox/ExitButton)
	$ExitConfirm.popup_centered()

func _on_exit_confirmed() -> void:
	get_tree().quit()
