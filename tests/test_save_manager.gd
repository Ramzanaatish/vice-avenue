extends Node

## Save/load self-test (Step 3). Run it with:
##   godot --headless --path . res://tests/test_save_manager.tscn
## (-s scripts cannot see autoloads, so the test runs as a scene.)

func _ready() -> void:
	var failures: Array = []
	var data: Dictionary = SaveManager.new_game_data()
	var saved: Dictionary = SaveManager.save_game(1, data)
	if not bool(saved.get("ok", false)):
		failures.append("save failed: " + str(saved.get("error", "?")))
	else:
		var loaded: Dictionary = SaveManager.load_game(1)
		if not bool(loaded.get("ok", false)):
			failures.append("load failed: " + str(loaded.get("error", "?")))
		else:
			var p: Dictionary = loaded["data"]["player"]
			if int(p.get("cash", -1)) != 250:
				failures.append("cash mismatch: " + str(p.get("cash")))
			if int(p.get("health", -1)) != 100:
				failures.append("health mismatch: " + str(p.get("health")))
			if str(loaded["data"]["progress"].get("current_mission", "")) != "mission_001":
				failures.append("mission mismatch")
		var slots: Array = SaveManager.list_slots()
		if not bool(slots[1].get("exists", false)):
			failures.append("slot 1 not listed after save")
	# --- Step 6: schema migration 1 -> 2 ---
	# A schema-1 file (no rotation_y / wanted_level / heat) must
	# load and come back as schema 2 with the new fields defaulted.
	var old_data: Dictionary = SaveManager.new_game_data()
	old_data["schema_version"] = 1
	(old_data["player"] as Dictionary).erase("rotation_y")
	(old_data["player"] as Dictionary).erase("wanted_level")
	(old_data["player"] as Dictionary).erase("heat")
	var canonical := JSON.stringify(JSON.parse_string(JSON.stringify(old_data)))
	old_data["checksum"] = str(canonical.hash())
	var old_file := FileAccess.open(SaveManager.slot_path(1), FileAccess.WRITE)
	old_file.store_string(JSON.stringify(old_data))
	old_file.close()
	var migrated: Dictionary = SaveManager.load_game(1)
	if not bool(migrated.get("ok", false)):
		failures.append("migration 1->2 failed: " + str(migrated.get("error", "?")))
	else:
		if int(migrated["data"].get("schema_version", -1)) != 2:
			failures.append("migrated save still schema " + str(migrated["data"].get("schema_version")))
		var mp: Dictionary = migrated["data"]["player"]
		if not mp.has("rotation_y") or not mp.has("wanted_level") or not mp.has("heat"):
			failures.append("migration did not add the Slice C player fields")
		elif int(mp.get("wanted_level", -1)) != 0 or float(mp.get("heat", -1.0)) != 0.0 or float(mp.get("rotation_y", -1.0)) != 0.0:
			failures.append("migration defaults wrong: " + str(mp))
	# --- Step 6: kill-during-save (atomic write) ---
	# Re-save a good slot first (this also creates the .bak).
	var good: Dictionary = SaveManager.save_game(1, SaveManager.new_game_data())
	if not bool(good.get("ok", false)):
		failures.append("re-save before kill test failed: " + str(good.get("error", "?")))
	else:
		# A partial .tmp file (kill mid-write) must never be read
		# as the save; the intact slot must still load.
		var tmp := FileAccess.open(SaveManager.slot_path(1) + ".tmp", FileAccess.WRITE)
		tmp.store_string("{\"schema_version\": 2, \"player\": {\"health\":")
		tmp.close()
		var after_kill: Dictionary = SaveManager.load_game(1)
		if not bool(after_kill.get("ok", false)):
			failures.append("kill-during-save broke the slot: " + str(after_kill.get("error", "?")))
		# Corrupt the slot itself: the .bak backup must recover it,
		# migrated to the current schema.
		var corrupt := FileAccess.open(SaveManager.slot_path(1), FileAccess.WRITE)
		corrupt.store_string("this is not json")
		corrupt.close()
		var recovered: Dictionary = SaveManager.load_game(1)
		if not bool(recovered.get("ok", false)):
			failures.append("backup recovery failed: " + str(recovered.get("error", "?")))
		elif str(recovered.get("recovered_from", "")) != "backup":
			failures.append("corrupt slot did not recover from backup")
		elif int(recovered["data"].get("schema_version", -1)) != 2:
			failures.append("recovered backup is not schema 2")
		DirAccess.remove_absolute(SaveManager.slot_path(1) + ".tmp")
	# --- Step 6: restore_checkpoint() reads the autosave slot ---
	var auto: Dictionary = SaveManager.save_game(0, SaveManager.new_game_data())
	if not bool(auto.get("ok", false)):
		failures.append("autosave failed: " + str(auto.get("error", "?")))
	else:
		var checkpoint: Dictionary = SaveManager.restore_checkpoint()
		if not bool(checkpoint.get("ok", false)):
			failures.append("restore_checkpoint failed: " + str(checkpoint.get("error", "?")))
	SaveManager.delete_slot(0)
	SaveManager.delete_slot(1)
	var after: Array = SaveManager.list_slots()
	if bool(after[1].get("exists", false)):
		failures.append("slot 1 still listed after delete")
	if failures.is_empty():
		print("TEST save/load: PASS")
	else:
		print("TEST save/load: FAIL — ", "; ".join(failures))
	get_tree().quit()
