extends Node

## Temporary screenshot driver (NOT shipped): renders each
## frontend scene in turn and saves viewport PNGs to user://.

const OUT_DIR := "user://screenshots"
const SHOTS := [
	["res://scenes/frontend/boot.tscn", "01_boot.png", 0.6],
	["res://scenes/frontend/main_menu.tscn", "02_main_menu.png", 0.5],
	["res://scenes/frontend/settings.tscn", "03_settings.png", 0.5],
	["res://scenes/frontend/save_slots.tscn", "04_save_slots.png", 0.5],
]

var _idx := 0
var _current: Node = null
var _timer := 0.0
var _wait := 0.0
var _capturing := false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	# Seed one save so the menu shows Continue enabled and
	# Slot 1 shows real data.
	SaveManager.save_game(1, SaveManager.new_game_data())
	_show_next()

func _process(delta: float) -> void:
	if _capturing:
		return
	_timer += delta
	if _timer >= _wait:
		_capture()

func _show_next() -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	if _idx >= SHOTS.size():
		print("SCREENSHOTS DONE")
		get_tree().quit()
		return
	var entry = SHOTS[_idx]
	var packed: PackedScene = load(entry[0])
	_current = packed.instantiate()
	add_child(_current)
	_wait = entry[2]
	_timer = 0.0

func _capture() -> void:
	_capturing = true
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path: String = OUT_DIR + "/" + str(SHOTS[_idx][1])
	var err := img.save_png(path)
	print("SCREENSHOT ", SHOTS[_idx][1], " -> ", path, " err=", err)
	_capturing = false
	_idx += 1
	_show_next()
