extends Node

## Global signals only. No logic, no state. (B-11)
## Managers communicate through these signals or narrow public
## methods. No scene reads another manager's internals directly.

signal health_changed(current: int, maximum: int)
signal money_changed(new_amount: int)
signal wanted_changed(level: int)
signal hostile_act_committed(kind: String, position: Vector3)
signal mission_state_changed(mission_id: String, new_state: String)
signal notification_requested(text: String)
signal save_completed(slot_id: int)
signal save_failed(slot_id: int, reason: String)
signal player_died(cause: String)
signal game_state_changed(new_state: String)
signal settings_changed
signal inventory_changed
signal loading_progress(value: float)
signal scene_change_requested(scene_path: String)
