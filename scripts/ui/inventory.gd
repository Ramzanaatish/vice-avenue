extends Control

## S09 — inventory. Displays InventoryManager only; it never
## creates items. Categories filter the grid; Drop removes one;
## Use/Equip are disabled until a usable/equippable item exists.

signal closed

const ITEMS_PATH := "res://data/items/items.json"

var from_pause: bool = false

var _defs: Dictionary = {}
var _category: String = "All"
var _selected: String = ""

func _ready() -> void:
	_load_defs()
	$Panel/VBox/TopBar/CloseButton.pressed.connect(_on_close_pressed)
	for category in ["All", "Weapons", "Items", "Consumables"]:
		var button: Button = $Panel/VBox/HBox/Categories.get_node(category + "Button")
		button.pressed.connect(_on_category_pressed.bind(category, button))
	$Panel/VBox/HBox/Detail/Buttons/UseButton.pressed.connect(_on_use_pressed)
	$Panel/VBox/HBox/Detail/Buttons/EquipButton.pressed.connect(_on_equip_pressed)
	$Panel/VBox/HBox/Detail/Buttons/DropButton.pressed.connect(_on_drop_pressed)
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.connect("inventory_changed", _refresh)
		bus.connect("money_changed", _refresh_money)
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_close_pressed()

func _load_defs() -> void:
	if not FileAccess.file_exists(ITEMS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	if parsed is Dictionary:
		_defs = parsed

func _refresh() -> void:
	_refresh_grid()
	_refresh_detail()
	_refresh_money(0)

func _refresh_money(_amount: int) -> void:
	$Panel/VBox/BottomBar/MoneyLabel.text = "Rs %d" % EconomyManager.cash
	$Panel/VBox/BottomBar/CapacityLabel.text = "%d / %d" % [InventoryManager.count_items(), InventoryManager.capacity]

func _refresh_grid() -> void:
	var grid = $Panel/VBox/HBox/Grid
	for child in grid.get_children():
		child.queue_free()
	var shown := 0
	for item_id in InventoryManager.items:
		var def: Dictionary = _defs.get(item_id, {})
		var category := str(def.get("category", "Items"))
		if _category != "All" and category != _category:
			continue
		var slot := Button.new()
		var qty := int(InventoryManager.items[item_id])
		slot.text = "%s x%d" % [str(def.get("name", item_id)), qty]
		slot.pressed.connect(_on_slot_pressed.bind(item_id, slot))
		grid.add_child(slot)
		shown += 1
	if shown == 0:
		var empty := Label.new()
		empty.text = "Inventory is empty."
		grid.add_child(empty)

func _refresh_detail() -> void:
	var detail = $Panel/VBox/HBox/Detail
	if _selected == "" or not InventoryManager.has_item(_selected):
		detail.get_node("NameLabel").text = "No item selected"
		detail.get_node("DescLabel").text = ""
		detail.get_node("StatsLabel").text = ""
		detail.get_node("Buttons/UseButton").disabled = true
		detail.get_node("Buttons/EquipButton").disabled = true
		detail.get_node("Buttons/DropButton").disabled = true
		return
	var def: Dictionary = _defs.get(_selected, {})
	detail.get_node("NameLabel").text = str(def.get("name", _selected))
	detail.get_node("DescLabel").text = str(def.get("description", ""))
	detail.get_node("StatsLabel").text = "x%d — %s" % [int(InventoryManager.items[_selected]), str(def.get("category", "Items"))]
	detail.get_node("Buttons/UseButton").disabled = true
	detail.get_node("Buttons/EquipButton").disabled = true
	detail.get_node("Buttons/DropButton").disabled = false

func _on_slot_pressed(item_id: String, button: Button) -> void:
	UiFeedback.press(button)
	_selected = item_id
	_refresh_detail()

func _on_category_pressed(category: String, button: Button) -> void:
	UiFeedback.press(button)
	_category = category
	_refresh_grid()

func _on_use_pressed() -> void:
	UiFeedback.press($Panel/VBox/HBox/Detail/Buttons/UseButton)
	# No usable consumable exists yet (Phase 10 adds medkits).
	pass

func _on_equip_pressed() -> void:
	UiFeedback.press($Panel/VBox/HBox/Detail/Buttons/EquipButton)
	# No weapon exists yet (Phase 11 adds weapons).
	pass

func _on_drop_pressed() -> void:
	UiFeedback.press($Panel/VBox/HBox/Detail/Buttons/DropButton)
	if _selected != "":
		InventoryManager.remove_item(_selected, 1)

func _on_close_pressed() -> void:
	UiFeedback.press($Panel/VBox/TopBar/CloseButton)
	closed.emit()
