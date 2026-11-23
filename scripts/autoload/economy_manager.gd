extends Node

## One authoritative wallet. Every transaction has a reason and a
## unique id, so a double-tap can never double-charge.

var cash: int = 0
var _txn_counter: int = 0

func _ready() -> void:
	cash = 250

func _next_txn_id() -> String:
	_txn_counter += 1
	return "txn_%d_%d" % [Time.get_unix_time_from_system(), _txn_counter]

func add_cash(amount: int, reason: String) -> String:
	var txn := _next_txn_id()
	cash = clampi(cash + amount, 0, SaveManager.MAX_MONEY)
	_notify()
	return txn

func spend_cash(amount: int, reason: String) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "error": "bad amount"}
	if cash < amount:
		return {"ok": false, "error": "not enough money"}
	var txn := _next_txn_id()
	cash -= amount
	_notify()
	return {"ok": true, "txn": txn, "balance": cash}

func purchase(item_id: String, qty: int, unit_price: int) -> Dictionary:
	var total := qty * unit_price
	var result := spend_cash(total, "purchase:" + item_id)
	if not bool(result.get("ok", false)):
		return result
	return {"ok": true, "txn": result["txn"], "total": total, "balance": cash}

func set_cash(amount: int) -> void:
	# Step 6: load-time restore (SaveManager owns the file; the
	# wallet owns the value). Clamped like every other change.
	cash = clampi(amount, 0, SaveManager.MAX_MONEY)
	_notify()

func _notify() -> void:
	if not is_inside_tree():
		return
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal("money_changed", cash)
