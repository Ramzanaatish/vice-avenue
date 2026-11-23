extends Node3D

## Slice B — Mission 04 "A Small Favour" runner. Reads the mission
## definition from data (MissionManager). Builds its beacons at
## runtime from the mission's locations. Flow: briefing on world
## entry (or on walking into the workshop while AVAILABLE/FAILED)
## -> Accept -> pickup -> drive -> return -> reward + results.
## Rewards are granted exactly once (guarded); the mission stays
## replayable through the workshop beacon after a decline/failure.

const MISSION_ID := "mission_004"
const BEACON_RADIUS := 2.5

var player = null
var car = null
var hud = null
var vehicle_manager = null

var _beacons: Dictionary = {}
var _briefing = null
var _results = null
var _rewards_granted: bool = false

func _ready() -> void:
	var root = get_parent()
	player = root.get_node("Dynamic/Player")
	car = root.get_node("Dynamic/Car")
	hud = root.get_node("HUD")
	vehicle_manager = root.get_node_or_null("VehicleManager")
	MissionManager.unlock_mission(MISSION_ID)
	_build_beacons()
	_hide_all_beacons()
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.connect("mission_state_changed", _on_mission_state_changed)
	# Briefing once on entry, after the world settles.
	await get_tree().create_timer(1.0).timeout
	if MissionManager.get_state(MISSION_ID) == "AVAILABLE":
		_show_briefing()

func _build_beacons() -> void:
	var mission := MissionManager.get_mission(MISSION_ID)
	var locations: Dictionary = mission.get("locations", {})
	var objectives: Array = mission.get("objectives", [])
	for objective in objectives:
		var oid := str(objective.get("id", ""))
		var loc: Dictionary = locations.get(oid, {})
		var pos := Vector3(float(loc.get("x", 0.0)), 0.0, float(loc.get("z", 0.0)))
		_beacons[oid] = _make_beacon(oid, pos)

func _make_beacon(objective_id: String, pos: Vector3) -> Dictionary:
	var beacon := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.6
	cyl.bottom_radius = 1.6
	cyl.height = 4.0
	beacon.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beacon.material_override = mat
	beacon.position = pos + Vector3(0, 2.0, 0)
	add_child(beacon)
	var label := Label3D.new()
	label.text = objective_id.to_upper()
	label.position = pos + Vector3(0, 4.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	var area := Area3D.new()
	area.position = pos
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BEACON_RADIUS
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_beacon_body_entered.bind(objective_id))
	return {"beacon": beacon, "label": label, "area": area}

func _hide_all_beacons() -> void:
	for oid in _beacons:
		_set_beacon_visible(oid, false)

func _set_beacon_visible(objective_id: String, visible: bool) -> void:
	var entry: Dictionary = _beacons.get(objective_id, {})
	if entry.is_empty():
		return
	(entry["beacon"] as Node3D).visible = visible
	(entry["label"] as Node3D).visible = visible
	# The Area3D stays active: a declined/failed mission can be
	# re-offered from the workshop. Objective completion is
	# gated on the mission state instead.

func _on_beacon_body_entered(body: Node3D, objective_id: String) -> void:
	var state := MissionManager.get_state(MISSION_ID)
	# Only the player re-opens the briefing: Hamza himself
	# stands inside the pickup beacon, and an NPC must never
	# trigger the player's briefing.
	if state in ["AVAILABLE", "FAILED"] and objective_id == "pickup" and body == player:
		_show_briefing()
		return
	if state != "ACTIVE":
		return
	var current := MissionManager.get_current_objective(MISSION_ID)
	if str(current.get("id", "")) != objective_id:
		return
	match objective_id:
		"pickup":
			if body == player:
				_complete_pickup()
		"drive":
			if body == car:
				MissionManager.complete_objective(MISSION_ID, "drive")
				_notify("Parcel delivered to the drop-off. Now return to Hamza.")
		"return":
			if body == player or body == car:
				MissionManager.complete_objective(MISSION_ID, "return")

func _complete_pickup() -> void:
	if not InventoryManager.add_item("package", 1):
		_notify("Inventory is full — make room first.")
		return
	MissionManager.complete_objective(MISSION_ID, "pickup")
	_notify("Parcel picked up. Drive it to the drop-off.")

func _on_mission_state_changed(mission_id: String, new_state: String) -> void:
	if mission_id != MISSION_ID:
		return
	match new_state:
		"ACTIVE":
			_update_beacons_for_current_objective()
			_update_hud_objective()
		"SUCCESS":
			_hide_all_beacons()
			_grant_rewards()
			_update_hud_objective()
			_show_results(true)
		"FAILED":
			_hide_all_beacons()
			_update_hud_objective()
			_show_results(false)
		_:
			_update_hud_objective()

func _update_beacons_for_current_objective() -> void:
	_hide_all_beacons()
	var current := MissionManager.get_current_objective(MISSION_ID)
	var oid := str(current.get("id", ""))
	if oid != "":
		_set_beacon_visible(oid, true)

func _update_hud_objective() -> void:
	if hud == null:
		return
	var state := MissionManager.get_state(MISSION_ID)
	if state == "ACTIVE":
		var current := MissionManager.get_current_objective(MISSION_ID)
		hud.set_objective("Mission: " + str(current.get("text", "")))
	elif state == "SUCCESS":
		hud.set_objective("Mission complete — A Small Favour done.")
	else:
		hud.set_objective("Slice B: Drive the car, finish the favour.")

func _grant_rewards() -> void:
	# complete_objective notifies twice on the final objective
	# (OBJECTIVE_COMPLETE then SUCCESS), so guard the grant.
	if _rewards_granted:
		return
	_rewards_granted = true
	InventoryManager.remove_item("package", 1)
	var mission := MissionManager.get_mission(MISSION_ID)
	var money := int(mission.get("rewards", {}).get("money", 0))
	if money > 0:
		EconomyManager.add_cash(money, "mission:" + MISSION_ID)

func offer_mission(mission_id: String) -> void:
	# Step 6: the S12 dialogue mission-offer path. Shows the
	# S13 briefing for the mission when it is offerable.
	if mission_id != MISSION_ID:
		return
	if MissionManager.get_state(MISSION_ID) in ["AVAILABLE", "FAILED"]:
		_show_briefing()

func _show_briefing() -> void:
	if _briefing != null:
		return
	var scene: PackedScene = load("res://scenes/frontend/mission_briefing.tscn")
	_briefing = scene.instantiate()
	_briefing.accepted.connect(_on_briefing_accepted)
	_briefing.declined.connect(_on_briefing_declined)
	get_parent().add_child(_briefing)
	_briefing.show_mission(MISSION_ID)
	get_tree().paused = true

func _on_briefing_accepted() -> void:
	_close_briefing()
	get_tree().paused = false

func _on_briefing_declined() -> void:
	_close_briefing()
	get_tree().paused = false

func _close_briefing() -> void:
	if _briefing != null:
		_briefing.queue_free()
		_briefing = null

func _show_results(success: bool) -> void:
	if _results != null:
		return
	var mission := MissionManager.get_mission(MISSION_ID)
	var checklist: Array = []
	for objective in mission.get("objectives", []):
		checklist.append({"text": str(objective.get("text", "")), "done": success})
	var rewards: Array = []
	var money := int(mission.get("rewards", {}).get("money", 0))
	if money > 0:
		rewards.append("+Rs %d" % money)
	var scene: PackedScene = load("res://scenes/frontend/mission_results.tscn")
	_results = scene.instantiate()
	_results.continue_pressed.connect(_on_results_closed)
	_results.retry_pressed.connect(_on_results_retry)
	_results.quit_pressed.connect(_on_results_closed)
	get_parent().add_child(_results)
	_results.show_result(MISSION_ID, success, checklist, rewards, "")
	get_tree().paused = true

func _on_results_closed() -> void:
	_close_results()
	get_tree().paused = false

func _on_results_retry() -> void:
	_close_results()
	_rewards_granted = false
	MissionManager.retry_mission(MISSION_ID)
	get_tree().paused = false

func _close_results() -> void:
	if _results != null:
		_results.queue_free()
		_results = null

func _notify(text: String) -> void:
	var bus = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal("notification_requested", text)
