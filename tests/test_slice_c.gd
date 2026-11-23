extends Node

## Slice C self-test (Step 6). Run it with:
##   godot --headless --path . res://tests/test_slice_c.tscn
## Drives the full Slice C loop with the real input actions:
## briefing decline -> NPC talk (Hamza mission offer) -> dialogue
## closes cleanly on save -> combat kill -> wanted + pursuit ->
## decay -> save/load position restore -> map -> death -> S15
## retry -> arrest -> S15 (arrested) -> quit to menu.
## Also checks the S12 rule: no dialogue text in any script.

var _world: Node3D
var _player: CharacterBody3D
var _phase := -1
var _timer := 0.0
var _failures: Array = []
var _decay_deadline := 0.0
var _heal_timer := 0.0
var _arrest_deadline := 0.0
var _arrest_glue_timer := 0.0
var _saved_pos := Vector3.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Clean slate: a stale autosave would change the world's
	# entry state (mission already done, no auto-briefing).
	SaveManager.delete_slot(0)
	SaveManager.delete_slot(1)
	_check_dialogue_texts()
	var packed: PackedScene = load("res://scenes/world/world_root.tscn")
	_world = packed.instantiate()
	add_child(_world)
	_player = _world.get_node("Dynamic/Player")
	_phase = 0
	_timer = 0.0
	print("TEST Slice C: world loaded.")

func _check_dialogue_texts() -> void:
	var texts: Array = []
	var dir := DirAccess.open("res://data/dialogue/")
	if dir != null:
		for file_name in dir.get_files():
			if not file_name.ends_with(".json"):
				continue
			var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + file_name))
			if parsed is Dictionary:
				for line in parsed.get("lines", []):
					texts.append(str(line.get("text", "")))
					for choice in line.get("choices", []):
						texts.append(str(choice.get("text", "")))
	var scripts: Array = []
	_collect_gd_files("res://scripts", scripts)
	for text in texts:
		if text == "":
			continue
		for path in scripts:
			if FileAccess.get_file_as_string(path).contains(text):
				_failures.append("S12: dialogue text found in script " + path)
				return

func _collect_gd_files(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for entry in dir.get_files():
		if entry.ends_with(".gd"):
			out.append(path + "/" + entry)
	for sub in dir.get_directories():
		_collect_gd_files(path + "/" + sub, out)

func _process(delta: float) -> void:
	_timer += delta
	match _phase:
		0:
			# Briefing auto-opens ~1.0 s after the world settles.
			if _timer > 1.5:
				var briefing = _world.get_node_or_null("MissionBriefing")
				if briefing == null:
					_failures.append("briefing did not auto-open")
					_finish()
					return
				briefing.get_node("BriefingPanel/VBox/Buttons/DeclineButton").emit_signal("pressed")
				_phase = 1
				_timer = 0.0
		1:
			if _timer > 0.3:
				if MissionManager.get_state("mission_004") != "AVAILABLE":
					_failures.append("mission not AVAILABLE after Decline (state %s)" % MissionManager.get_state("mission_004"))
				if get_tree().paused:
					_failures.append("tree still paused after Decline")
				var npc_manager = _world.get_node("NPCManager")
				if npc_manager.npcs.size() != 4:
					_failures.append("expected 4 NPCs, got %d" % npc_manager.npcs.size())
				if npc_manager.alive_count() != 4:
					_failures.append("not all NPCs alive at start")
				# Walk up to Hamza at the workshop.
				_player.global_position = Vector3(-8.5, 0, 12)
				_phase = 2
				_timer = 0.0
		2:
			if _timer > 0.3:
				var button = _world.get_node("HUD/SafeArea/InteractButton")
				if not button.visible:
					_failures.append("Talk prompt not shown near Hamza")
				elif not str(button.text).contains("Hamza"):
					_failures.append("Talk prompt wrong: " + str(button.text))
				Input.action_press("interact")
				_phase = 3
				_timer = 0.0
		3:
			if _timer > 0.3:
				Input.action_release("interact")
				var dialogue = _world.get("_dialogue")
				if dialogue == null:
					_failures.append("dialogue did not open")
					_finish()
					return
				if str(dialogue.get_current_line_id()) != "start":
					_failures.append("dialogue did not start at 'start' (is %s)" % str(dialogue.get_current_line_id()))
				_press_continue(dialogue)
				_phase = 4
				_timer = 0.0
		4:
			if _timer > 0.25:
				var dialogue = _world.get("_dialogue")
				if dialogue == null:
					_failures.append("dialogue closed early (phase 4)")
					_finish()
					return
				if str(dialogue.get_current_line_id()) != "branch_offer":
					_failures.append("expected branch_offer, got %s" % str(dialogue.get_current_line_id()))
				_press_continue(dialogue)
				_phase = 5
				_timer = 0.0
		5:
			if _timer > 0.25:
				var dialogue = _world.get("_dialogue")
				if dialogue == null:
					_failures.append("dialogue closed early (phase 5)")
					_finish()
					return
				if str(dialogue.get_current_line_id()) != "offer":
					_failures.append("expected offer line, got %s" % str(dialogue.get_current_line_id()))
				var choices = dialogue.get_node("ChoicesLayer").get_children()
				if choices.size() != 2:
					_failures.append("expected 2 choices, got %d" % choices.size())
					_finish()
					return
				choices[0].emit_signal("pressed")
				_phase = 6
				_timer = 0.0
		6:
			if _timer > 0.25:
				var dialogue = _world.get("_dialogue")
				if dialogue == null:
					_failures.append("dialogue closed early (phase 6)")
					_finish()
					return
				if str(dialogue.get_current_line_id()) != "offer_detail":
					_failures.append("expected offer_detail, got %s" % str(dialogue.get_current_line_id()))
				var choices = dialogue.get_node("ChoicesLayer").get_children()
				if choices.size() != 2:
					_failures.append("expected 2 choices at offer_detail, got %d" % choices.size())
					_finish()
					return
				choices[0].emit_signal("pressed")
				_phase = 7
				_timer = 0.0
		7:
			# Mission-offer choice: dialogue closes, briefing opens.
			if _timer > 0.3:
				if _world.get("_dialogue") != null:
					_failures.append("dialogue still open after mission offer")
					_finish()
					return
				var briefing = _world.get_node_or_null("MissionBriefing")
				if briefing == null:
					_failures.append("briefing did not open from mission offer")
					_finish()
					return
				briefing.get_node("BriefingPanel/VBox/Buttons/AcceptButton").emit_signal("pressed")
				_phase = 8
				_timer = 0.0
		8:
			if _timer > 0.3:
				if MissionManager.get_state("mission_004") != "ACTIVE":
					_failures.append("mission not ACTIVE after Accept (state %s)" % MissionManager.get_state("mission_004"))
				if get_tree().paused:
					_failures.append("tree still paused after briefing Accept")
				# Talk to Sana, then save mid-conversation: the
				# dialogue must close cleanly (S12).
				var sana = _world.get_node("NPCManager").get_npc("civilian_02")
				_player.global_position = sana.global_position + Vector3(1.5, 0, 0)
				_phase = 9
				_timer = 0.0
		9:
			if _timer > 0.3:
				Input.action_press("interact")
				_phase = 10
				_timer = 0.0
		10:
			if _timer > 0.3:
				Input.action_release("interact")
				if _world.get("_dialogue") == null:
					_failures.append("dialogue did not open for Sana")
					_finish()
					return
				var data: Dictionary = _world.collect_save_data()
				if _world.get("_dialogue") != null:
					_failures.append("dialogue did not close cleanly on save")
				if not (data.get("player", {}) as Dictionary).has("rotation_y"):
					_failures.append("save data has no rotation_y")
				# Combat: kill Rafiq (3 melee hits; he flees, so
				# re-approach before each hit).
				_phase = 11
				_timer = 0.0
				_attack_count = 0
		11:
			# Attack presses must span frames: press, then
			# release on the next tick (same-frame press+release
			# never reaches the physics check).
			if _attack_pressed:
				if _timer > 0.2:
					Input.action_release("attack")
					_attack_pressed = false
					_timer = 0.0
					if _attack_count >= 3:
						_phase = 12
						_timer = 0.0
			elif _timer > 0.4:
				_attack_count += 1
				_approach_and_attack("civilian_01")
				_attack_pressed = true
				_timer = 0.0
		12:
			if _timer > 0.5:
				var rafiq = _world.get_node("NPCManager").get_npc("civilian_01")
				if not bool(rafiq.is_dead):
					_failures.append("civilian_01 not dead after 3 hits (health %d)" % int(rafiq.health))
				var police = _world.get_node("PoliceManager")
				if int(police.wanted_level) < 1:
					_failures.append("wanted did not rise after attack (level %d)" % int(police.wanted_level))
				var wanted_label = _world.get_node("HUD/SafeArea/WantedLabel")
				if str(wanted_label.text) == "Wanted: 0":
					_failures.append("HUD wanted label still 0 after attack")
				_phase = 13
				_timer = 0.0
		13:
			# Pursuit: an officer must dispatch, capped at 2.
			# Checked 0.5 s after the kill: dispatch is
			# synchronous, but an arrest needs 1.5 s of
			# proximity, so no arrest can have completed yet.
			if _timer > 0.5:
				var police = _world.get_node("PoliceManager")
				var count := int(police.get_active_count())
				if count < 1:
					_failures.append("no police dispatched at wanted %d" % int(police.wanted_level))
				elif count > 2:
					_failures.append("police cap broken: %d active" % count)
				else:
					var states: Array = []
					for officer in police.officers:
						states.append(str(officer.get_state()))
					print("TEST Slice C: pursuit active, officer states ", states)
					for state in states:
						if state != "Investigate" and state != "Pursue":
							_failures.append("unexpected officer state right after dispatch: " + state)
				# Break proximity NOW: an officer already close
				# would finish an arrest in 1.5 s, before the
				# first 2 s teleport tick of the decay phase.
				_player.heal()
				_player.global_position = Vector3(45, 0, 45)
				_decay_deadline = 40.0
				_heal_timer = 0.0
				_phase = 14
				_timer = 0.0
		14:
			# Decay: wanted must fall back to 0 on its own. Keep
			# the player alive and away from the officers while
			# the heat drains (grace 8 s + 50 heat at 3/s).
			# The game must still be PLAYING here: in this test
			# the world inherits PROCESS_MODE_ALWAYS, so a dead
			# player would silently keep decaying — fail loudly
			# instead.
			if GameManager.get_state_name() != "PLAYING":
				_failures.append("player died/was arrested during pursuit (state %s)" % GameManager.get_state_name())
				_phase = 15
				_timer = 0.0
			_decay_deadline -= delta
			_heal_timer += delta
			if _heal_timer > 2.0:
				_heal_timer = 0.0
				_player.heal()
				# Far corners on the open z=+45 side (the z=-45
				# row has buildings; (-45,-45) is inside B11).
				if int(Time.get_ticks_msec() / 2000) % 2 == 0:
					_player.global_position = Vector3(45, 0, 45)
				else:
					_player.global_position = Vector3(-45, 0, 45)
			var police = _world.get_node("PoliceManager")
			if int(police.wanted_level) == 0:
				if int(police.get_active_count()) != 0:
					_failures.append("officers not recalled after wanted cleared")
				_phase = 15
				_timer = 0.0
			elif _decay_deadline <= 0.0:
				_failures.append("wanted did not decay to 0 (level %d, heat %s)" % [int(police.wanted_level), str(snappedf(police.heat, 0.1))])
				_phase = 15
				_timer = 0.0
		15:
			if _timer > 0.3:
				# Save/load position restore: save at a known
				# spot with a known facing, move away, load.
				# (0, 0, -30) is on the north road, not inside
				# a building (20, -20 would be inside B2).
				_player.global_position = Vector3(0, 0, -30)
				_player.set_facing(1.2)
				_saved_pos = Vector3(0, 0, -30)
				var data: Dictionary = _world.collect_save_data()
				var saved: Dictionary = SaveManager.save_game(1, data)
				if not bool(saved.get("ok", false)):
					_failures.append("save failed: " + str(saved.get("error", "?")))
					_finish()
					return
				_player.global_position = Vector3(0, 0, 8)
				_player.set_facing(0.0)
				var loaded: Dictionary = SaveManager.load_game(1)
				if not bool(loaded.get("ok", false)):
					_failures.append("load failed: " + str(loaded.get("error", "?")))
					_finish()
					return
				_world.apply_save_data(loaded["data"])
				_phase = 16
				_timer = 0.0
		16:
			if _timer > 0.3:
				if GameManager.get_state_name() != "PLAYING":
					_failures.append("not PLAYING before map check (state %s)" % GameManager.get_state_name())
					_finish()
					return
				if _player.global_position.distance_to(_saved_pos) > 0.05:
					_failures.append("position not restored (got %s, want %s)" % [str(_player.global_position), str(_saved_pos)])
				if absf(_player.get_facing_yaw() - 1.2) > 0.01:
					_failures.append("facing not restored (got %s)" % str(snappedf(_player.get_facing_yaw(), 0.01)))
				if _world.get_node("NPCManager").alive_count() != 4:
					_failures.append("NPCs did not respawn on load (alive %d)" % _world.get_node("NPCManager").alive_count())
				if int(_world.get_node("PoliceManager").wanted_level) != 0:
					_failures.append("wanted not 0 after load")
				# Map: open, check the player marker, close.
				Input.action_press("open_map")
				_phase = 17
				_timer = 0.0
		17:
			if _timer > 0.5:
				Input.action_release("open_map")
				var map = _world.get("_map_open")
				if map == null or not map.visible:
					_failures.append("map did not open")
					_finish()
					return
				if not get_tree().paused:
					_failures.append("tree not paused while map open")
				var marker: Vector2 = map.get_player_marker_pos()
				if marker == Vector2.ZERO or marker.x < 0.0 or marker.x > 1280.0 or marker.y < 0.0 or marker.y > 720.0:
					_failures.append("player marker off-screen: " + str(marker))
				map.get_node("ZoomInButton").emit_signal("pressed")
				map.get_node("CloseButton").emit_signal("pressed")
				_phase = 18
				_timer = 0.0
		18:
			if _timer > 0.3:
				if _world.get("_map_open") != null:
					_failures.append("map still open after Close")
				if get_tree().paused:
					_failures.append("tree still paused after map closed")
				# Death -> S15: autosave first, then die.
				_player.global_position = Vector3(30, 0, 30)
				var data: Dictionary = _world.collect_save_data()
				var saved: Dictionary = SaveManager.save_game(0, data)
				if not bool(saved.get("ok", false)):
					_failures.append("autosave failed: " + str(saved.get("error", "?")))
					_finish()
					return
				_player.global_position = Vector3(0, 0, 8)
				_player.damage(200, "police")
				_phase = 19
				_timer = 0.0
		19:
			if _timer > 0.5:
				var over = _world.get("_game_over")
				if over == null or not over.visible:
					_failures.append("game over did not open on death")
					_finish()
					return
				if over.get_node("Overlay/VBox/HeaderLabel").text != "DOWN AND OUT":
					_failures.append("death header wrong: " + str(over.get_node("Overlay/VBox/HeaderLabel").text))
				if over.get_node("Overlay/VBox/CauseLabel").text != "Killed by the police.":
					_failures.append("death cause wrong: " + str(over.get_node("Overlay/VBox/CauseLabel").text))
				if over.get_node("Overlay/VBox/RetryButton").disabled:
					_failures.append("Retry disabled despite autosave")
				over.get_node("Overlay/VBox/RetryButton").emit_signal("pressed")
				_phase = 20
				_timer = 0.0
		20:
			if _timer > 0.5:
				if _world.get("_game_over") != null:
					_failures.append("game over still open after Retry")
				if get_tree().paused:
					_failures.append("tree still paused after Retry")
				if int(_player.health) != 100:
					_failures.append("health not restored by Retry (%d)" % int(_player.health))
				if _player.global_position.distance_to(Vector3(30, 0, 30)) > 0.05:
					_failures.append("Retry did not restore checkpoint position (got %s)" % str(_player.global_position))
				# Arrest -> S15 (arrested variant): force wanted 2,
				# glue an officer to the player until caught.
				_world.get_node("PoliceManager").set_wanted_level(2)
				_arrest_deadline = 6.0
				_arrest_glue_timer = 0.0
				_phase = 21
				_timer = 0.0
		21:
			_arrest_deadline -= delta
			_arrest_glue_timer += delta
			if _arrest_glue_timer > 0.3:
				_arrest_glue_timer = 0.0
				var police = _world.get_node("PoliceManager")
				if int(police.get_active_count()) > 0:
					var officer = police.officers[0]
					if is_instance_valid(officer):
						officer.global_position = _player.global_position + Vector3(1, 0, 0)
			var over = _world.get("_game_over")
			if over != null and over.visible:
				if over.get_node("Overlay/VBox/HeaderLabel").text != "IN CUSTODY":
					_failures.append("arrest header wrong: " + str(over.get_node("Overlay/VBox/HeaderLabel").text))
				if over.get_node("Overlay/VBox/CauseLabel").text != "Arrested by the police.":
					_failures.append("arrest cause wrong: " + str(over.get_node("Overlay/VBox/CauseLabel").text))
				over.get_node("Overlay/VBox/QuitButton").emit_signal("pressed")
				_phase = 22
				_timer = 0.0
			elif _arrest_deadline <= 0.0:
				_failures.append("arrest did not happen (no game over in 6 s)")
				_finish()
		22:
			if _timer > 0.5:
				if GameManager.get_state_name() != "MENU":
					_failures.append("Quit did not reach MENU (state %s)" % GameManager.get_state_name())
				_finish()

var _attack_count := 0
var _attack_pressed := false

func _press_continue(dialogue) -> void:
	dialogue.get_node("DialogueBox/VBox/ContinueButton").emit_signal("pressed")

func _approach_and_attack(npc_id: String) -> void:
	var npc = _world.get_node("NPCManager").get_npc(npc_id)
	if npc == null or bool(npc.is_dead):
		return
	var target: Vector3 = npc.global_position
	_player.global_position = target + Vector3(1.5, 0, 0)
	var dir: Vector3 = target - _player.global_position
	_player.set_facing(atan2(dir.x, dir.z))
	# Press only — the release happens on a later tick (phase 11).
	Input.action_press("attack")

func _finish() -> void:
	SaveManager.delete_slot(0)
	SaveManager.delete_slot(1)
	if _failures.is_empty():
		print("TEST Slice C: PASS")
	else:
		print("TEST Slice C: FAIL — ", "; ".join(_failures))
	get_tree().quit()
