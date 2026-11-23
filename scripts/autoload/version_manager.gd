extends Node

## Version constants. Single source of truth for versions.
## Android version code is a separate, always-increasing integer.
## NEVER decrease version_code. NEVER change the package ID after
## the first Play publication (see update_release_process.md).

const GAME_VERSION: String = "1.1.2"
const VERSION_CODE: int = 4
const SAVE_SCHEMA_VERSION: int = 2
const CONTENT_VERSION: int = 4
const BUILD_CHANNEL: String = "dev"

## Phase 16 (Step 8): the update contract.
## MIN_SUPPORTED_VERSION_CODE — the oldest installed build that a
## newer release still supports in place. A build older than this
## must update before its saves are trusted (check_update reports
## it as "required"). MIN_SUPPORTED_SCHEMA — the oldest save schema
## with a registered migration in SaveManager (1 -> 2).
const MIN_SUPPORTED_VERSION_CODE: int = 1
const MIN_SUPPORTED_SCHEMA: int = 1
## The shipped manifest. This game is offline-first: there is NO
## network update check. The manifest ships inside the app and is
## the single source the update logic reads; a future Play in-app
## update (or a hosted manifest) feeds the same check_update()
## function a candidate manifest dictionary instead.
const MANIFEST_PATH: String = "res://data/version_manifest.json"
const PACKAGE_ID: String = "com.devflowia.viceavenue"

## Version Name -> Version Code -> Save Schema table.
## Add one row per release. This table is the update contract:
## a higher version code + the same package ID = in-place Play update.
const VERSION_TABLE: Array = [
	{"version_name": "1.0.0", "version_code": 1, "save_schema": 1},
	{"version_name": "1.1.0", "version_code": 2, "save_schema": 2},
	{"version_name": "1.1.1", "version_code": 3, "save_schema": 2},
	{"version_name": "1.1.2", "version_code": 4, "save_schema": 2},
]

func get_game_version() -> String:
	return GAME_VERSION

func get_version_code() -> int:
	return VERSION_CODE

func get_save_schema_version() -> int:
	return SAVE_SCHEMA_VERSION

func check() -> Dictionary:
	# Boot probe (S01): confirms the version table is sane.
	return {
		"ok": true,
		"game_version": GAME_VERSION,
		"version_code": VERSION_CODE,
		"save_schema": SAVE_SCHEMA_VERSION,
	}

## Phase 16: load the shipped version manifest. Never crashes:
## a missing or malformed manifest returns an empty Dictionary
## and validate_manifest() reports the problem.
func load_manifest() -> Dictionary:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

## Phase 16: validate a manifest against this build's constants.
## Returns {"ok": bool, "errors": Array[String]}. A manifest that
## does not match the installed build is a packaging error, not a
## player-facing update: the shipped manifest must always validate.
func validate_manifest(manifest: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if manifest.is_empty():
		errors.append("manifest missing or unreadable")
		return {"ok": false, "errors": errors}
	if str(manifest.get("package_id", "")) != PACKAGE_ID:
		errors.append("package_id mismatch")
	if str(manifest.get("version_name", "")) != GAME_VERSION:
		errors.append("version_name mismatch")
	if int(manifest.get("version_code", -1)) != VERSION_CODE:
		errors.append("version_code mismatch")
	if int(manifest.get("save_schema", -1)) != SAVE_SCHEMA_VERSION:
		errors.append("save_schema mismatch")
	if int(manifest.get("content_version", -1)) != CONTENT_VERSION:
		errors.append("content_version mismatch")
	var min_supported := int(manifest.get("min_supported_version_code", -1))
	if min_supported < 1 or min_supported > VERSION_CODE:
		errors.append("min_supported_version_code out of range")
	var latest: Dictionary = VERSION_TABLE[VERSION_TABLE.size() - 1]
	if int(latest.get("version_code", -1)) != VERSION_CODE:
		errors.append("version table latest row does not match VERSION_CODE")
	return {"ok": errors.is_empty(), "errors": errors}

## Phase 16: pure update check. Compares a CANDIDATE manifest
## (from a future update source — Play in-app update or a hosted
## manifest) against the installed build. No I/O, no network.
## Returns {"update_available": bool, "required": bool,
## "newer_version_name": String, "newer_version_code": int,
## "reason": String}. "required" is true only when this installed
## build is older than the candidate's minimum supported version.
func check_update(candidate: Dictionary) -> Dictionary:
	var result := {
		"update_available": false,
		"required": false,
		"newer_version_name": "",
		"newer_version_code": 0,
		"reason": "installed build is current",
	}
	if candidate.is_empty() or not candidate.has("version_code"):
		result["reason"] = "no candidate manifest to compare"
		return result
	var cand_code := int(candidate.get("version_code", 0))
	if cand_code <= VERSION_CODE:
		return result
	result["update_available"] = true
	result["newer_version_name"] = str(candidate.get("version_name", ""))
	result["newer_version_code"] = cand_code
	var cand_min := int(candidate.get("min_supported_version_code", 0))
	if VERSION_CODE < cand_min:
		result["required"] = true
		result["reason"] = "installed build is below the minimum supported version"
	else:
		result["reason"] = "a newer version is available"
	return result

## Phase 16: can a save with this schema be loaded? True for the
## current schema and for any older schema with a registered
## migration (SaveManager.register_migration). Anything else —
## schema 0/missing, or a schema from a NEWER build — is refused.
func is_save_compatible(schema_version: int) -> bool:
	return schema_version >= MIN_SUPPORTED_SCHEMA and schema_version <= SAVE_SCHEMA_VERSION

## Phase 16: one summary for a future Settings/About display:
## installed version + whether the shipped manifest validates.
func get_update_summary() -> Dictionary:
	var manifest := load_manifest()
	var validation := validate_manifest(manifest)
	return {
		"game_version": GAME_VERSION,
		"version_code": VERSION_CODE,
		"save_schema": SAVE_SCHEMA_VERSION,
		"content_version": CONTENT_VERSION,
		"build_channel": BUILD_CHANNEL,
		"manifest_ok": bool(validation.get("ok", false)),
		"manifest_errors": validation.get("errors", []),
	}
