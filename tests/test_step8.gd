extends Node

## Step 8 self-test (Phase 16 update/version system + Phase 17
## headless slice review). Run it with:
##   godot --headless --path . res://tests/test_step8.tscn
## Checks: shipped version manifest loads + validates against the
## build constants; validate_manifest rejects bad manifests;
## check_update logic (same / newer / required / older / empty);
## save-schema compatibility (1 migrates, 2 current, 0 and 3
## refused); update summary; version table strictly increasing
## with latest row == constants; export_presets.cfg consistency
## (both presets: same package id, code 4, name 1.1.2; AAB preset
## is a Gradle AAB build); Step 7 police scene-cache fix still in
## place (officer scene loaded once, never per dispatch).
## (-s scripts cannot see autoloads, so the test runs as a scene.)

var _failures: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check_manifest()
	_check_validate_rejects_bad()
	_check_update()
	_check_save_compat()
	_check_update_summary()
	_check_version_table_and_presets()
	_check_police_scene_cache()
	_finish()

func _expect(cond: bool, label: String) -> void:
	if cond:
		print("TEST step8: OK ", label)
	else:
		_failures.append(label)
		print("TEST step8: FAIL ", label)

func _check_manifest() -> void:
	var manifest := VersionManager.load_manifest()
	_expect(not manifest.is_empty(), "shipped version manifest loads")
	_expect(str(manifest.get("package_id", "")) == "com.devflowia.viceavenue", "manifest package_id matches")
	_expect(str(manifest.get("version_name", "")) == "1.1.2", "manifest version_name is 1.1.2")
	_expect(int(manifest.get("version_code", -1)) == 4, "manifest version_code is 4")
	_expect(int(manifest.get("save_schema", -1)) == 2, "manifest save_schema is 2")
	_expect(int(manifest.get("content_version", -1)) == 4, "manifest content_version is 4")
	_expect(int(manifest.get("min_supported_version_code", -1)) == 1, "manifest min_supported_version_code is 1")
	var validation := VersionManager.validate_manifest(manifest)
	_expect(bool(validation.get("ok", false)), "shipped manifest validates against build constants")

func _check_validate_rejects_bad() -> void:
	var good := VersionManager.load_manifest()
	var wrong_code := good.duplicate()
	wrong_code["version_code"] = 5
	_expect(not bool(VersionManager.validate_manifest(wrong_code).get("ok", true)), "validate rejects wrong version_code")
	var wrong_pkg := good.duplicate()
	wrong_pkg["package_id"] = "com.example.other"
	_expect(not bool(VersionManager.validate_manifest(wrong_pkg).get("ok", true)), "validate rejects wrong package_id")
	var wrong_schema := good.duplicate()
	wrong_schema["save_schema"] = 3
	_expect(not bool(VersionManager.validate_manifest(wrong_schema).get("ok", true)), "validate rejects wrong save_schema")
	var bad_min := good.duplicate()
	bad_min["min_supported_version_code"] = 99
	_expect(not bool(VersionManager.validate_manifest(bad_min).get("ok", true)), "validate rejects min_supported above version_code")
	_expect(not bool(VersionManager.validate_manifest({}).get("ok", true)), "validate rejects empty manifest")

func _check_update() -> void:
	var same := VersionManager.load_manifest()
	var r_same := VersionManager.check_update(same)
	_expect(not bool(r_same.get("update_available", true)), "same manifest: no update available")
	var newer := {"version_name": "1.2.0", "version_code": 5, "min_supported_version_code": 1}
	var r_newer := VersionManager.check_update(newer)
	_expect(bool(r_newer.get("update_available", false)), "newer code 5: update available")
	_expect(not bool(r_newer.get("required", true)), "newer code 5 with min 1: update optional")
	_expect(str(r_newer.get("newer_version_name", "")) == "1.2.0", "newer manifest name reported")
	_expect(int(r_newer.get("newer_version_code", 0)) == 5, "newer manifest code reported")
	var required := {"version_name": "2.0.0", "version_code": 6, "min_supported_version_code": 5}
	var r_req := VersionManager.check_update(required)
	_expect(bool(r_req.get("update_available", false)), "newer code 6: update available")
	_expect(bool(r_req.get("required", false)), "installed code 4 below min 5: update required")
	var older := {"version_name": "1.1.0", "version_code": 2, "min_supported_version_code": 1}
	_expect(not bool(VersionManager.check_update(older).get("update_available", true)), "older code 2: no update available")
	_expect(not bool(VersionManager.check_update({}).get("update_available", true)), "empty candidate: no update available")

func _check_save_compat() -> void:
	_expect(VersionManager.is_save_compatible(1), "save schema 1 compatible (migration 1->2 exists)")
	_expect(VersionManager.is_save_compatible(2), "save schema 2 compatible (current)")
	_expect(not VersionManager.is_save_compatible(0), "save schema 0 refused")
	_expect(not VersionManager.is_save_compatible(3), "save schema 3 (newer build) refused")

func _check_update_summary() -> void:
	var summary := VersionManager.get_update_summary()
	_expect(str(summary.get("game_version", "")) == "1.1.2", "summary version is 1.1.2")
	_expect(int(summary.get("version_code", -1)) == 4, "summary code is 4")
	_expect(int(summary.get("save_schema", -1)) == 2, "summary save schema is 2")
	_expect(bool(summary.get("manifest_ok", false)), "summary manifest_ok is true")

func _check_version_table_and_presets() -> void:
	var prev_code := 0
	var increasing := true
	for row in VersionManager.VERSION_TABLE:
		var code := int(row.get("version_code", 0))
		if code <= prev_code:
			increasing = false
		prev_code = code
	_expect(increasing, "version table codes strictly increase")
	var latest = VersionManager.VERSION_TABLE[VersionManager.VERSION_TABLE.size() - 1]
	_expect(str(latest.get("version_name", "")) == "1.1.2" and int(latest.get("version_code", 0)) == 4 and int(latest.get("save_schema", 0)) == 2, "version table latest row is 1.1.2 / code 4 / schema 2")
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	_expect(err == OK, "export_presets.cfg loads")
	if err == OK:
		_expect(int(cfg.get_value("preset.0.options", "version/code", -1)) == 4, "debug preset version/code is 4")
		_expect(str(cfg.get_value("preset.0.options", "version/name", "")) == "1.1.2", "debug preset version/name is 1.1.2")
		_expect(str(cfg.get_value("preset.0.options", "package/unique_name", "")) == "com.devflowia.viceavenue", "debug preset package id matches")
		_expect(cfg.has_section("preset.1"), "AAB preset (preset.1) exists")
		_expect(str(cfg.get_value("preset.1.options", "package/unique_name", "")) == "com.devflowia.viceavenue", "AAB preset package id matches")
		_expect(int(cfg.get_value("preset.1.options", "version/code", -1)) == 4, "AAB preset version/code is 4")
		_expect(str(cfg.get_value("preset.1.options", "version/name", "")) == "1.1.2", "AAB preset version/name is 1.1.2")
		_expect(bool(cfg.get_value("preset.1.options", "gradle_build/use_gradle_build", false)), "AAB preset uses Gradle build")
		_expect(int(cfg.get_value("preset.1.options", "gradle_build/export_format", 0)) == 1, "AAB preset export_format is AAB (1)")
		_expect(str(cfg.get_value("preset.1.options", "gradle_build/min_sdk", "")) == "24", "AAB preset min_sdk is 24")
		_expect(str(cfg.get_value("preset.1.options", "gradle_build/target_sdk", "")) == "36", "AAB preset target_sdk is 36")
		_expect(str(cfg.get_value("preset.1", "export_path", "")).ends_with(".aab"), "AAB preset export path ends .aab")
		# Step 8 fix: Godot 4.7 option names are gradle_build/*,
		# launcher_icons/*, architectures/* — the old Godot 3
		# slash forms (gradle/build/*, launcher/icon/*,
		# variant/architecture/*) are silently ignored.
		_expect(not cfg.has_section_key("preset.1.options", "gradle/build/export_format"), "no stale gradle/build/* key in AAB preset")
		_expect(not cfg.has_section_key("preset.1.options", "launcher/icon/main_192x192"), "no stale launcher/icon/* key in AAB preset")
		_expect(not cfg.has_section_key("preset.1.options", "variant/architecture/arm64-v8a"), "no stale variant/architecture/* key in AAB preset")

func _check_police_scene_cache() -> void:
	# Step 7 fix must survive: the officer PackedScene is loaded
	# once (ready + guarded lazy fallback), never per dispatch.
	var file := FileAccess.open("res://scripts/world/police_manager.gd", FileAccess.READ)
	_expect(file != null, "police_manager.gd readable")
	if file == null:
		return
	var text := file.get_as_text()
	_expect(text.contains("_officer_scene = load(OFFICER_SCENE)"), "police manager caches officer scene once")
	_expect(text.count("load(OFFICER_SCENE") == 2, "officer scene load appears exactly twice (ready + guarded fallback)")
	_expect(text.contains("if _officer_scene == null:"), "officer scene load is guarded by null check")

func _finish() -> void:
	if _failures.is_empty():
		print("TEST step8: PASS")
	else:
		print("TEST step8: FAIL — ", "; ".join(_failures))
	get_tree().quit()
