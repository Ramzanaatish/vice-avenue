extends CanvasLayer

## S12 — Dialogue / Interaction (Step 6, Slice C).
## Data-driven: every line comes from data/dialogue/<npc_id>.json
## (lines, choices, conditions, flag effects, mission offers).
## NO dialogue text lives in this script (S12 test: grep check).
## Choices may set story flags through MissionManager or offer
## a mission (mission_offered signal -> the world opens the
## S13 briefing). The tree is paused while dialogue is open;
## this layer runs always so its buttons work.

signal closed
signal mission_offered(mission_id: String)

const DIALOGUE_DIR := "res://data/dialogue/"

var npc_id := ""
var _data: Dictionary = {}
var _lines: Dictionary = {}
var _current_line := ""
var _open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$DialogueBox/VBox/ContinueButton.pressed.connect(_on_continue_pressed)
	$DialogueBox.visible = false
	$ChoicesLayer.visible = false

func is_open() -> bool:
	return _open

func get_current_line_id() -> String:
	return _current_line

func show_dialogue(p_npc_id: String) -> bool:
	npc_id = p_npc_id
	var path := DIALOGUE_DIR + npc_id + ".json"
	if not FileAccess.file_exists(path):
		print("Dialogue: no data for ", npc_id)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		print("Dialogue: bad data for ", npc_id)
		return false
	_data = parsed
	_lines.clear()
	for line in _data.get("lines", []):
		_lines[str(line.get("id", ""))] = line
	_open = true
	$DialogueBox.visible = true
	# Step 7 (Phase 14): the box fades in instead of popping.
	$DialogueBox.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property($DialogueBox, "modulate:a", 1.0, 0.15)
	_show_line("start")
	return true

func close_dialogue() -> void:
	if not _open:
		return
	_open = false
	$DialogueBox.visible = false
	$ChoicesLayer.visible = false
	closed.emit()

func _show_line(line_id: String) -> void:
	if line_id == "" or not _lines.has(line_id):
		close_dialogue()
		return
	var line: Dictionary = _lines[line_id]
	if not _requires_met(line):
		var skip_to := str(line.get("skip_to", ""))
		if skip_to != "":
			_show_line(skip_to)
		else:
			close_dialogue()
		return
	_current_line = line_id
	var flag := str(line.get("set_flag", ""))
	if flag != "":
		MissionManager.set_flag(flag, true)
	$DialogueBox/VBox/SpeakerLabel.text = str(line.get("speaker", ""))
	$DialogueBox/VBox/DialogueText.text = str(line.get("text", ""))
	var audio = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_dialogue_blip"):
		audio.play_dialogue_blip()
	var choices: Array = line.get("choices", [])
	for child in $ChoicesLayer.get_children():
		child.queue_free()
	if choices.is_empty():
		$ChoicesLayer.visible = false
		$DialogueBox/VBox/ContinueButton.visible = true
	else:
		$DialogueBox/VBox/ContinueButton.visible = false
		$ChoicesLayer.visible = true
		for choice in choices:
			var button := Button.new()
			button.text = str(choice.get("text", ""))
			button.custom_minimum_size = Vector2(420, 48)
			button.pressed.connect(_on_choice_pressed.bind(choice, button))
			$ChoicesLayer.add_child(button)

func _requires_met(line: Dictionary) -> bool:
	var req: Dictionary = line.get("requires", {})
	if req.is_empty():
		return true
	if req.has("mission"):
		var mission_id := str(req.get("mission", ""))
		var wanted_state := str(req.get("state", ""))
		return MissionManager.get_state(mission_id) == wanted_state
	if req.has("flag"):
		var flag := str(req.get("flag", ""))
		return MissionManager.get_flag(flag) == bool(req.get("value", true))
	return true

func _on_continue_pressed() -> void:
	if not _open:
		return
	UiFeedback.press($DialogueBox/VBox/ContinueButton)
	var line: Dictionary = _lines.get(_current_line, {})
	_show_line(str(line.get("next", "")))

func _on_choice_pressed(choice: Dictionary, button: Button) -> void:
	if not _open:
		return
	UiFeedback.press(button)
	var flag := str(choice.get("set_flag", ""))
	if flag != "":
		MissionManager.set_flag(flag, true)
	var mission_offer := str(choice.get("mission_offer", ""))
	var next_id := str(choice.get("next", ""))
	if mission_offer != "":
		var offered := mission_offer
		close_dialogue()
		mission_offered.emit(offered)
		return
	_show_line(next_id)

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("interact"):
		var choices_visible: bool = $ChoicesLayer.visible
		if not choices_visible:
			_on_continue_pressed()
			get_viewport().set_input_as_handled()
