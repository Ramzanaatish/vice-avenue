extends Node

## Version constants. Single source of truth for versions.
## Android version code is a separate, always-increasing integer.
## NEVER decrease version_code. NEVER change the package ID after
## the first Play publication (see update_release_process.md).

const GAME_VERSION: String = "1.1.1"
const VERSION_CODE: int = 3
const SAVE_SCHEMA_VERSION: int = 2
const CONTENT_VERSION: int = 3
const BUILD_CHANNEL: String = "dev"

## Version Name -> Version Code -> Save Schema table.
## Add one row per release. This table is the update contract:
## a higher version code + the same package ID = in-place Play update.
const VERSION_TABLE: Array = [
	{"version_name": "1.0.0", "version_code": 1, "save_schema": 1},
	{"version_name": "1.1.0", "version_code": 2, "save_schema": 2},
	{"version_name": "1.1.1", "version_code": 3, "save_schema": 2},
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
