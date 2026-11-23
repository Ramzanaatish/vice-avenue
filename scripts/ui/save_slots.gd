extends Control

## S05 — Save Slots (Step 3).
## 3 cards: Autosave (slot 0), Slot 1, Slot 2. Load continues,
## Load on an empty manual slot starts a New Game there,
## Delete asks first. Autosave can never be overwritten by hand.

const WORLD_SCENE := "res://scenes/world/world_root.tscn"
const SLOT_NAMES := ["Autosave", "Slot 1", "Slot 2"]

var _delete_slot := -1

func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	$DeleteConfirm.confirmed.connect(_on_delete_confirmed)
	for i in 3:
		var card = $Slots.get_node("SlotCard%d" % i)
		card.get_node("VBox/LoadButton").pressed.connect(_on_load_pressed.bind(i))
		card.get_node("VBox/DeleteButton").pressed.connect(_on_delete_pressed.bind(i))
	_refresh()
	print("Save Slots shown.")

func _refresh() -> void:
	var slots: Array = SaveManager.list_slots()
	for i in 3:
		var card = $Slots.get_node("SlotCard%d" % i)
		var info: Dictionary = slots[i]
		card.get_node("VBox/SlotName").text = SLOT_NAMES[i]
		var load_btn: Button = card.get_node("VBox/LoadButton")
		var del_btn: Button = card.get_node("VBox/DeleteButton")
		if bool(info.get("exists", false)):
			card.get_node("VBox/SlotInfo").text = "%s — Rs %d — %s" % [str(info.get("chapter", "?")), int(info.get("money", 0)), str(info.get("saved_at", ""))]
			load_btn.text = "Load"
			load_btn.disabled = false
			del_btn.disabled = false
		else:
			card.get_node("VBox/SlotInfo").text = "Empty"
			if i == 0:
				load_btn.text = "Load"
				load_btn.disabled = true
			else:
				load_btn.text = "New Game"
				load_btn.disabled = false
			del_btn.disabled = true
	$StatusLabel.text = ""

func _on_load_pressed(slot_id: int) -> void:
	UiFeedback.press($Slots.get_node("SlotCard%d" % slot_id).get_node("VBox/LoadButton"))
	var slots: Array = SaveManager.list_slots()
	var exists := bool(slots[slot_id].get("exists", false))
	if exists:
		var loaded: Dictionary = SaveManager.load_slot(slot_id)
		if not bool(loaded.get("ok", false)):
			$StatusLabel.text = "Load failed: " + str(loaded.get("error", "?"))
			return
		_enter_world(slot_id, false)
	else:
		if slot_id == 0:
			return
		var saved: Dictionary = SaveManager.save_game(slot_id, SaveManager.new_game_data())
		if not bool(saved.get("ok", false)):
			$StatusLabel.text = "New Game failed: " + str(saved.get("error", "?"))
			return
		_enter_world(slot_id, true)

func _enter_world(slot_id: int, is_new: bool) -> void:
	# v1.1.2: ResourceLoader.exists, not the FileAccess existence
	# check — the .tscn is remapped in an exported build (see
	# app_root.gd).
	if not ResourceLoader.exists(WORLD_SCENE, "PackedScene"):
		if is_new:
			$StatusLabel.text = "New game saved to Slot %d. " % slot_id
		else:
			$StatusLabel.text = "Save loaded (Slot %d). " % slot_id
		$StatusLabel.text += "World scene arrives in Slice A (Step 4)."
		_refresh_keep_status()
		return
	if is_new:
		GameManager.start_new_game(slot_id)
	else:
		GameManager.continue_game(slot_id)

func _refresh_keep_status() -> void:
	var status: String = $StatusLabel.text
	_refresh()
	$StatusLabel.text = status

func _on_delete_pressed(slot_id: int) -> void:
	UiFeedback.press($Slots.get_node("SlotCard%d" % slot_id).get_node("VBox/DeleteButton"))
	_delete_slot = slot_id
	$DeleteConfirm.dialog_text = "Delete %s? This cannot be undone." % SLOT_NAMES[slot_id]
	$DeleteConfirm.popup_centered()

func _on_delete_confirmed() -> void:
	if _delete_slot >= 0:
		SaveManager.delete_slot(_delete_slot)
		_delete_slot = -1
	_refresh()

func _on_back_pressed() -> void:
	UiFeedback.press($BackButton)
	GameManager.request_scene("res://scenes/frontend/main_menu.tscn")
