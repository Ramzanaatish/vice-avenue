extends Node

## Items are data (data/items/items.json). Capacity enforced here.

const DEFAULT_CAPACITY := 40

var items: Dictionary = {}
var capacity: int = DEFAULT_CAPACITY

func add_item(item_id: String, qty: int = 1) -> bool:
	if count_items() + qty > capacity:
		return false
	items[item_id] = int(items.get(item_id, 0)) + qty
	_notify()
	return true

func remove_item(item_id: String, qty: int = 1) -> bool:
	var have := int(items.get(item_id, 0))
	if have < qty:
		return false
	have -= qty
	if have <= 0:
		items.erase(item_id)
	else:
		items[item_id] = have
	_notify()
	return true

func count_items() -> int:
	var total := 0
	for v in items.values():
		total += int(v)
	return total

func has_item(item_id: String) -> bool:
	return int(items.get(item_id, 0)) > 0

func set_items(new_items: Dictionary) -> void:
	# Step 6: load-time restore. Replaces the whole inventory
	# (the save is authoritative); capacity still applies.
	items.clear()
	for item_id in new_items:
		var qty := int(new_items[item_id])
		if qty > 0:
			items[str(item_id)] = qty
	_notify()

func _notify() -> void:
	if not is_inside_tree():
		return
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal("inventory_changed")
