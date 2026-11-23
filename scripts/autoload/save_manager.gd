extends Node

## Owns ALL save/load. Nothing else writes save files.
## Rules (B-13, locked): user:// only, atomic write (temp ->
## verify -> rename), rolling .bak backup, schema_version +
## game_version + checksum in every save, validation on load,
## chained migrations, downgrade protection.

signal save_completed(slot_id: int)
signal save_failed(slot_id: int, reason: String)

const SAVE_DIR := "user://saves/"
const AUTOSAVE_SLOT := 0
const MANUAL_SLOTS: Array[int] = [1, 2]
const MAX_MONEY := 999999999
const MAX_HEALTH := 100

var _migrations: Dictionary = {}

func _ready() -> void:
	_ensure_dirs()
	# Step 6 (Slice C): schema 1 -> 2 adds the player fields the
	# full restore needs (facing, wanted level, heat). Registered
	# here because SaveManager owns ALL save/load (B-13).
	register_migration(1, 2, _migrate_1_to_2)

func _migrate_1_to_2(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	var player: Dictionary = result.get("player", {})
	if not player.has("rotation_y"):
		player["rotation_y"] = 0.0
	if not player.has("wanted_level"):
		player["wanted_level"] = 0
	if not player.has("heat"):
		player["heat"] = 0.0
	result["player"] = player
	return result

func _ensure_dirs() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func slot_path(slot_id: int) -> String:
	return SAVE_DIR + "slot_%02d.json" % slot_id

func backup_path(slot_id: int) -> String:
	return slot_path(slot_id) + ".bak"

func register_migration(from_schema: int, to_schema: int, step: Callable) -> void:
	_migrations[Vector2i(from_schema, to_schema)] = step

func new_game_data() -> Dictionary:
	return {
		"schema_version": VersionManager.SAVE_SCHEMA_VERSION,
		"game_version": VersionManager.GAME_VERSION,
		"save_slot": "slot_01",
		"player": {"position": [0.0, 0.0, 0.0], "rotation_y": 0.0, "health": 100, "cash": 250, "wanted_level": 0, "heat": 0.0},
		"progress": {"current_mission": "mission_001", "completed_missions": [], "unlocks": []},
		"inventory": [],
		"vehicles": [],
		"world_flags": {},
		"saved_at": Time.get_datetime_string_from_system(true, false),
	}

func checksum_of(payload: String) -> String:
	return str(payload.hash())

func _canonical_json(data: Dictionary) -> String:
	# Godot's JSON parser returns every number as float, so a
	# checksum over the raw dict never verifies after a save/load
	# round-trip (250 becomes 250.0). Canonicalise by round-
	# tripping through the parser first; the result is identical
	# at save time and at load time.
	var parsed = JSON.parse_string(JSON.stringify(data))
	return JSON.stringify(parsed)

func _is_whole_number(value) -> bool:
	# JSON round-trips every number as float (250 -> 250.0).
	return (value is int) or (value is float and value == float(int(value)))

func validate_data(data: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	if not data.has("schema_version") or not _is_whole_number(data["schema_version"]):
		errors.append("missing schema_version")
	if not data.has("player") or not (data["player"] is Dictionary):
		errors.append("missing player block")
	else:
		var health = data["player"].get("health", -1)
		if not _is_whole_number(health) or int(health) < 0 or int(health) > MAX_HEALTH:
			errors.append("health out of range")
		var cash = data["player"].get("cash", -1)
		if not _is_whole_number(cash) or int(cash) < 0 or int(cash) > MAX_MONEY:
			errors.append("cash out of range")
		var wanted = data["player"].get("wanted_level", 0)
		if not _is_whole_number(wanted) or int(wanted) < 0 or int(wanted) > 5:
			errors.append("wanted_level out of range")
		var heat = data["player"].get("heat", 0.0)
		if not (heat is float or heat is int) or float(heat) < 0.0 or float(heat) > 100.0:
			errors.append("heat out of range")
	if not data.has("progress") or not (data["progress"] is Dictionary):
		errors.append("missing progress block")
	return {"ok": errors.is_empty(), "errors": errors}

func migrate_data(data: Dictionary, from_schema: int, to_schema: int) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	var current := from_schema
	while current < to_schema:
		var key := Vector2i(current, current + 1)
		if not _migrations.has(key):
			return {"ok": false, "error": "no migration %d -> %d" % [current, current + 1]}
		var migrated = (_migrations[key] as Callable).call(result)
		if not (migrated is Dictionary):
			return {"ok": false, "error": "migration %d -> %d returned bad data" % [current, current + 1]}
		result = migrated
		current += 1
	result["schema_version"] = to_schema
	return {"ok": true, "data": result}

func save_game(slot_id: int, data: Dictionary) -> Dictionary:
	_ensure_dirs()
	var payload: Dictionary = data.duplicate(true)
	payload["schema_version"] = VersionManager.SAVE_SCHEMA_VERSION
	payload["game_version"] = VersionManager.GAME_VERSION
	payload["saved_at"] = Time.get_datetime_string_from_system(true, false)
	payload["checksum"] = checksum_of(_canonical_json(payload))
	var json_text := JSON.stringify(payload)
	var path := slot_path(slot_id)
	var tmp_path := path + ".tmp"
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, backup_path(slot_id))
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return _fail(slot_id, "cannot open temp file")
	file.store_string(json_text)
	file.close()
	var check := FileAccess.open(tmp_path, FileAccess.READ)
	if check == null:
		return _fail(slot_id, "cannot verify temp file")
	var verify_text := check.get_as_text()
	check.close()
	if not (JSON.parse_string(verify_text) is Dictionary):
		return _fail(slot_id, "temp file failed verification")
	if DirAccess.rename_absolute(tmp_path, path) != OK:
		return _fail(slot_id, "rename failed")
	save_completed.emit(slot_id)
	_notify_bus("save_completed", [slot_id])
	return {"ok": true, "path": path}

func load_slot(slot_id: int) -> Dictionary:
	# Spec name (S03/S05) for load_game.
	return load_game(slot_id)

func restore_checkpoint() -> Dictionary:
	# S15 Retry: the checkpoint IS the autosave slot (slot 0).
	# Returns the same shape as load_game (ok/data or ok/error).
	return load_game(AUTOSAVE_SLOT)

func load_game(slot_id: int) -> Dictionary:
	_ensure_dirs()
	var path := slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "no save in slot %d" % slot_id}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return _try_backup(slot_id, "save is not valid JSON")
	var data: Dictionary = parsed
	if data.has("checksum"):
		var stored: String = str(data["checksum"])
		var copy: Dictionary = data.duplicate(true)
		copy.erase("checksum")
		if checksum_of(_canonical_json(copy)) != stored:
			return _try_backup(slot_id, "checksum mismatch (file changed or corrupt)")
	var schema: int = int(data.get("schema_version", -1))
	if schema > VersionManager.SAVE_SCHEMA_VERSION:
		return {"ok": false, "error": "save is from a newer game version; update the game first", "downgrade": true}
	if schema < VersionManager.SAVE_SCHEMA_VERSION:
		var migrated := migrate_data(data, schema, VersionManager.SAVE_SCHEMA_VERSION)
		if not bool(migrated.get("ok", false)):
			return _try_backup(slot_id, str(migrated.get("error", "migration failed")))
		data = migrated["data"]
	var check := validate_data(data)
	if not bool(check.get("ok", false)):
		return _try_backup(slot_id, "validation failed: " + ", ".join(check["errors"]))
	return {"ok": true, "data": data}

func list_slots() -> Array:
	var result: Array = []
	for slot_id in [AUTOSAVE_SLOT, MANUAL_SLOTS[0], MANUAL_SLOTS[1]]:
		var info := {"slot": slot_id, "exists": false}
		var path := slot_path(slot_id)
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				info["exists"] = true
				info["chapter"] = str(parsed.get("progress", {}).get("current_mission", ""))
				info["money"] = int(parsed.get("player", {}).get("cash", 0))
				info["saved_at"] = str(parsed.get("saved_at", ""))
		result.append(info)
	return result

func delete_slot(slot_id: int) -> bool:
	var path := slot_path(slot_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if FileAccess.file_exists(backup_path(slot_id)):
		DirAccess.remove_absolute(backup_path(slot_id))
	return true

func _try_backup(slot_id: int, reason: String) -> Dictionary:
	var bpath := backup_path(slot_id)
	if FileAccess.file_exists(bpath):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(bpath))
		if parsed is Dictionary:
			var data: Dictionary = parsed
			# Step 6: a backup written by an older schema migrates
			# like a normal load — a recovered save must never
			# come back with missing fields.
			var schema: int = int(data.get("schema_version", -1))
			if schema > 0 and schema < VersionManager.SAVE_SCHEMA_VERSION:
				var migrated := migrate_data(data, schema, VersionManager.SAVE_SCHEMA_VERSION)
				if bool(migrated.get("ok", false)):
					data = migrated["data"]
			var check := validate_data(data)
			if bool(check.get("ok", false)):
				return {"ok": true, "data": data, "recovered_from": "backup", "note": reason}
	return {"ok": false, "error": reason}

func _fail(slot_id: int, reason: String) -> Dictionary:
	save_failed.emit(slot_id, reason)
	_notify_bus("save_failed", [slot_id, reason])
	return {"ok": false, "error": reason}

func _notify_bus(signal_name: String, args: Array) -> void:
	if not is_inside_tree():
		return
	var bus = get_node_or_null("/root/EventBus")
	if bus == null:
		return
	if signal_name == "save_completed":
		bus.emit_signal("save_completed", args[0])
	elif signal_name == "save_failed":
		bus.emit_signal("save_failed", args[0], args[1])
