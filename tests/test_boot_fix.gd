extends Node

## v1.1.2 boot-fix regression test. Run it with:
##   godot --headless --path . res://tests/test_boot_fix.tscn
## The v1.1.1 build stranded the game on the boot screen on real
## phones: AppRoot's scene gate used FileAccess.file_exists() on a
## res:// .tscn path, which returns FALSE in an exported build
## (scenes are compiled to .scn + .remap, so the literal .tscn is
## not in the PCK) while returning TRUE headless (the .tscn files
## exist on disk). The gate therefore never fired headless and the
## bug shipped — boot bar full, v1.1.1 shown, menu never appeared.
## Checks:
## - every scene the game can switch to exists via
##   ResourceLoader.exists (the API that resolves remaps);
## - no scene-existence check in the switching files still uses
##   FileAccess.file_exists (static guard, same style as the
##   Step 7 police scene-cache guard in test_step8.gd);
## - the shipped version is 1.1.2 / code 4, save schema stays 2.
## The end-to-end proof is the exported-PCK boot run (see
## step8/check_pck_boot.sh): in a PCK, FileAccess.file_exists on a
## .tscn returns false, so only this test + that run together
## close the hole.
## (-s scripts cannot see autoloads, so the test runs as a scene.)

var _failures: Array = []

const SCENES: Array = [
	"res://scenes/frontend/boot.tscn",
	"res://scenes/frontend/main_menu.tscn",
	"res://scenes/frontend/settings.tscn",
	"res://scenes/frontend/save_slots.tscn",
	"res://scenes/frontend/credits.tscn",
	"res://scenes/frontend/pause_menu.tscn",
	"res://scenes/frontend/map.tscn",
	"res://scenes/frontend/dialogue.tscn",
	"res://scenes/frontend/hud.tscn",
	"res://scenes/frontend/game_over.tscn",
	"res://scenes/world/world_root.tscn",
]

const SCENE_GATE_FILES: Array = [
	"res://scripts/core/app_root.gd",
	"res://scripts/ui/main_menu.gd",
	"res://scripts/ui/save_slots.gd",
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check_scenes_exist()
	_check_no_fileaccess_scene_gate()
	_check_version()
	_finish()

func _check_scenes_exist() -> void:
	for path in SCENES:
		_expect(ResourceLoader.exists(path, "PackedScene"), "scene exists via ResourceLoader: " + path)

func _check_no_fileaccess_scene_gate() -> void:
	for path in SCENE_GATE_FILES:
		var f := FileAccess.open(path, FileAccess.READ)
		_expect(f != null, "can read gate file: " + path)
		if f == null:
			continue
		var text := f.get_as_text()
		f.close()
		_expect(not text.contains("FileAccess.file_exists"), "no FileAccess.file_exists gate left in " + path)
		_expect(text.contains("ResourceLoader.exists"), "ResourceLoader.exists gate present in " + path)

func _check_version() -> void:
	_expect(VersionManager.GAME_VERSION == "1.1.2", "version is 1.1.2")
	_expect(VersionManager.VERSION_CODE == 4, "version code is 4")
	_expect(VersionManager.SAVE_SCHEMA_VERSION == 2, "save schema stays 2")

func _expect(cond: bool, label: String) -> void:
	if cond:
		print("TEST boot_fix: OK ", label)
	else:
		_failures.append(label)
		print("TEST boot_fix: FAIL ", label)

func _finish() -> void:
	if _failures.is_empty():
		print("TEST boot_fix: PASS")
	else:
		print("TEST boot_fix: FAIL — ", "; ".join(_failures))
	get_tree().quit()
