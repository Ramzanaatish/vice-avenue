extends CanvasLayer

## S13 — mission briefing. Shows title, story, objectives and
## rewards BEFORE the player accepts. Accept -> the mission
## becomes ACTIVE (or retries a FAILED one); Decline -> the
## mission stays available and the panel closes.

signal accepted
signal declined

var _mission_id: String = ""

func show_mission(mission_id: String) -> void:
	_mission_id = mission_id
	var mission := MissionManager.get_mission(mission_id)
	$BriefingPanel/VBox/TitleLabel.text = str(mission.get("title", mission_id))
	$BriefingPanel/VBox/DescLabel.text = str(mission.get("description", ""))
	for child in $BriefingPanel/VBox/ObjectivesList.get_children():
		child.queue_free()
	for objective in mission.get("objectives", []):
		var row := Label.new()
		row.text = "• " + str(objective.get("text", ""))
		$BriefingPanel/VBox/ObjectivesList.add_child(row)
	var money := int(mission.get("rewards", {}).get("money", 0))
	if money > 0:
		$BriefingPanel/VBox/RewardLabel.text = "Reward: +Rs %d" % money
	else:
		$BriefingPanel/VBox/RewardLabel.text = "Reward: —"
	$BriefingPanel/VBox/StartLabel.text = "Start: " + str(mission.get("start_location", ""))

func _ready() -> void:
	$BriefingPanel/VBox/Buttons/AcceptButton.pressed.connect(_on_accept_pressed)
	$BriefingPanel/VBox/Buttons/DeclineButton.pressed.connect(_on_decline_pressed)

func _on_accept_pressed() -> void:
	UiFeedback.press($BriefingPanel/VBox/Buttons/AcceptButton)
	var state := MissionManager.get_state(_mission_id)
	if state == "FAILED":
		MissionManager.retry_mission(_mission_id)
	elif state == "AVAILABLE":
		MissionManager.accept_mission(_mission_id)
		MissionManager.start_mission(_mission_id)
	GameManager.current_mission_id = _mission_id
	accepted.emit()

func _on_decline_pressed() -> void:
	UiFeedback.press($BriefingPanel/VBox/Buttons/DeclineButton)
	declined.emit()
