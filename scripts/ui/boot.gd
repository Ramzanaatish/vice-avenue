extends Control

## S01 — Boot / Splash (Step 3).
## Shows the working title while settings load and the save
## schema version is probed. Advances to S03 after a 1.2 s
## minimum display; any tap skips AFTER that minimum.

const MIN_DISPLAY := 1.2

var _elapsed := 0.0
var _advanced := false

func _ready() -> void:
	SettingsManager.load_settings()
	var check: Dictionary = VersionManager.check()
	$VersionLabel.text = "v" + str(check.get("game_version", "?"))
	print("Boot shown (version ", check.get("game_version", "?"), ", schema ", check.get("save_schema", "?"), ").")

func _process(delta: float) -> void:
	if _advanced:
		return
	_elapsed += delta
	$LoadingBar.value = clampf(_elapsed / MIN_DISPLAY * 100.0, 0.0, 100.0)
	if _elapsed >= MIN_DISPLAY:
		_advance()

func _input(event: InputEvent) -> void:
	if _advanced or _elapsed < MIN_DISPLAY:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_advance()

func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	print("Boot: advancing to Main Menu.")
	GameManager.request_scene("res://scenes/frontend/main_menu.tscn")
