extends CanvasLayer

## S14 — mission results. Shows success or failure with the
## objective checklist and the reward breakdown. Rewards are
## already granted by MissionManager/EconomyManager before this
## screen opens — it only displays them, so closing it can
## never lose or duplicate a reward.

signal continue_pressed
signal retry_pressed
signal quit_pressed

func show_result(mission_id: String, success: bool, checklist: Array, rewards: Array, flag_note: String) -> void:
	var mission := MissionManager.get_mission(mission_id)
	if success:
		$ResultsPanel/VBox/HeaderLabel.text = "MISSION COMPLETE"
	else:
		$ResultsPanel/VBox/HeaderLabel.text = "MISSION FAILED"
	$ResultsPanel/VBox/TitleLabel.text = str(mission.get("title", mission_id))
	for child in $ResultsPanel/VBox/Checklist.get_children():
		child.queue_free()
	for entry in checklist:
		var row := Label.new()
		var mark := "✓ " if bool(entry.get("done", false)) else "✗ "
		row.text = mark + str(entry.get("text", ""))
		$ResultsPanel/VBox/Checklist.add_child(row)
	for child in $ResultsPanel/VBox/RewardsList.get_children():
		child.queue_free()
	for reward in rewards:
		var row := Label.new()
		row.text = str(reward)
		$ResultsPanel/VBox/RewardsList.add_child(row)
	$ResultsPanel/VBox/FlagNote.text = flag_note
	$ResultsPanel/VBox/Buttons/ContinueButton.visible = success
	$ResultsPanel/VBox/Buttons/RetryButton.visible = not success
	$ResultsPanel/VBox/Buttons/QuitButton.visible = not success

func _ready() -> void:
	$ResultsPanel/VBox/Buttons/ContinueButton.pressed.connect(func() -> void: UiFeedback.press($ResultsPanel/VBox/Buttons/ContinueButton); continue_pressed.emit())
	$ResultsPanel/VBox/Buttons/RetryButton.pressed.connect(func() -> void: UiFeedback.press($ResultsPanel/VBox/Buttons/RetryButton); retry_pressed.emit())
	$ResultsPanel/VBox/Buttons/QuitButton.pressed.connect(func() -> void: UiFeedback.press($ResultsPanel/VBox/Buttons/QuitButton); quit_pressed.emit())
