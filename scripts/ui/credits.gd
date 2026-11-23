extends Control

## S16 — Credits (Step 7, Phase 14).
## Reads data/credits.json and lists every section in a
## scrollable column. Back returns to the Main Menu.

const CREDITS_PATH := "res://data/credits.json"
const MAIN_MENU := "res://scenes/frontend/main_menu.tscn"

func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	_load_credits()

func _load_credits() -> void:
	var data := _load_credits_data()
	var list: VBoxContainer = $Scroll/CreditsList
	for section in data.get("sections", []):
		var heading := Label.new()
		heading.text = str(section.get("heading", ""))
		heading.add_theme_font_size_override("font_size", 24)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(heading)
		for line in section.get("lines", []):
			var label := Label.new()
			label.text = str(line)
			label.add_theme_font_size_override("font_size", 18)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			list.add_child(label)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		list.add_child(spacer)

func _load_credits_data() -> Dictionary:
	if not FileAccess.file_exists(CREDITS_PATH):
		return {"sections": []}
	var file := FileAccess.open(CREDITS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {"sections": []}

func _on_back_pressed() -> void:
	UiFeedback.press($BackButton)
	GameManager.request_scene(MAIN_MENU)
