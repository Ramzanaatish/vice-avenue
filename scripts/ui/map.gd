extends Control

## S08 — Fullscreen Map (Step 6, Slice C).
## Full map of the discovered district: player marker, mission
## markers, legend. Pan by dragging, zoom with the buttons,
## tap a mission marker to see its name. The game stays paused
## while the map is open; this control runs always so its
## buttons work. The map reads data only — it writes nothing
## (discovery flags are written by the world during play).

signal closed

const MIN_ZOOM := 0.6
const MAX_ZOOM := 2.5
const ZOOM_STEP := 0.25

var _district: Dictionary = {}
var _player: Node3D = null
var _mission_pos := Vector3.ZERO
var _mission_label := ""
var _has_mission := false
var _zoom := 1.0
var _pan := Vector2.ZERO
var _dragging := false
var _player_marker_pos := Vector2.ZERO
var _mission_marker_pos := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$CloseButton.pressed.connect(_on_close_pressed)
	$ZoomInButton.pressed.connect(_on_zoom_in_pressed)
	$ZoomOutButton.pressed.connect(_on_zoom_out_pressed)
	visible = false

func show_map(district: Dictionary, player: Node3D, mission_pos: Vector3, mission_label: String, has_mission: bool) -> void:
	_district = district
	_player = player
	_mission_pos = mission_pos
	_mission_label = mission_label
	_has_mission = has_mission
	_zoom = 1.0
	_pan = Vector2.ZERO
	$InfoLabel.text = mission_label if has_mission else "Old Quarter — no active mission."
	visible = true
	queue_redraw()

func close_map() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func get_player_marker_pos() -> Vector2:
	return _player_marker_pos

func get_mission_marker_pos() -> Vector2:
	return _mission_marker_pos

func _map_rect() -> Rect2:
	var side := minf(size.x, size.y) * 0.85
	return Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))

func _world_to_map(world_pos: Vector3) -> Vector2:
	var bounds: Dictionary = _district.get("bounds", {"min_x": -60, "max_x": 60, "min_z": -60, "max_z": 60})
	var w := float(bounds["max_x"]) - float(bounds["min_x"])
	var d := float(bounds["max_z"]) - float(bounds["min_z"])
	var rect := _map_rect()
	var nx := (world_pos.x - float(bounds["min_x"])) / w
	var nz := (world_pos.z - float(bounds["min_z"])) / d
	var local := Vector2(nx, nz) * rect.size
	return rect.position + rect.size * 0.5 + (local - rect.size * 0.5) * _zoom + _pan

func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7))
	var rect := _map_rect()
	draw_rect(rect, Color(0.12, 0.2, 0.14, 1.0))
	draw_rect(rect, Color(1, 1, 1, 0.4), false, 2.0)
	# Roads (the two greybox streets).
	var road_color := Color(0.25, 0.26, 0.28, 1.0)
	var bounds: Dictionary = _district.get("bounds", {"min_x": -60, "max_x": 60, "min_z": -60, "max_z": 60})
	var w := float(bounds["max_x"]) - float(bounds["min_x"])
	var d := float(bounds["max_z"]) - float(bounds["min_z"])
	var road_w := 12.0 / w * rect.size.x * _zoom
	var road_d := 12.0 / d * rect.size.y * _zoom
	var center := rect.get_center() + _pan
	draw_rect(Rect2(center.x - road_w * 0.5, rect.position.y, road_w, rect.size.y), road_color)
	draw_rect(Rect2(rect.position.x, center.y - road_d * 0.5, rect.size.x, road_d), road_color)
	# Buildings (center via the same world->map transform).
	for b in _district.get("buildings", []):
		var center_b := _world_to_map(Vector3(float(b["x"]), 0.0, float(b["z"])))
		var bw: float = float(b["w"]) / w * rect.size.x * _zoom
		var bd: float = float(b["d"]) / d * rect.size.y * _zoom
		draw_rect(Rect2(center_b - Vector2(bw, bd) * 0.5, Vector2(bw, bd)), Color(0.55, 0.5, 0.42, 1.0))
	# Mission marker (gold diamond + number).
	if _has_mission:
		_mission_marker_pos = _world_to_map(_mission_pos)
		var m := _mission_marker_pos
		draw_colored_polygon(PackedVector2Array([m + Vector2(0, -12), m + Vector2(10, 0), m + Vector2(0, 12), m + Vector2(-10, 0)]), Color(1.0, 0.8, 0.2, 1.0))
	# Player marker (arrow, rotates with facing).
	if _player != null:
		_player_marker_pos = _world_to_map(_player.global_position)
		var yaw := 0.0
		if _player.has_method("get_facing_yaw"):
			yaw = _player.get_facing_yaw()
		# Map north is -Z and screen up is -Y, but _world_to_map
		# maps world +Z to screen +Y, so world facing
		# (sin yaw, cos yaw) maps straight to screen (sin, cos).
		var fwd := Vector2(sin(yaw), cos(yaw))
		var side := Vector2(-fwd.y, fwd.x)
		var p := _player_marker_pos
		draw_colored_polygon(PackedVector2Array([p + fwd * 12.0, p - fwd * 8.0 + side * 8.0, p - fwd * 8.0 - side * 8.0]), Color(0.9, 0.65, 0.3, 1.0))

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed and _has_mission:
			if event.position.distance_to(_mission_marker_pos) < 24.0:
				$InfoLabel.text = _mission_label
	elif event is InputEventMouseMotion and _dragging:
		_pan += event.relative
		_pan = _pan.clamp(-_map_rect().size * 0.5, _map_rect().size * 0.5)
		queue_redraw()
	elif event is InputEventScreenDrag:
		_pan += event.relative
		_pan = _pan.clamp(-_map_rect().size * 0.5, _map_rect().size * 0.5)
		queue_redraw()
	elif event is InputEventScreenTouch and event.pressed and _has_mission:
		if event.position.distance_to(_mission_marker_pos) < 24.0:
			$InfoLabel.text = _mission_label

func _on_close_pressed() -> void:
	close_map()

func _on_zoom_in_pressed() -> void:
	_zoom = minf(MAX_ZOOM, _zoom + ZOOM_STEP)
	queue_redraw()

func _on_zoom_out_pressed() -> void:
	_zoom = maxf(MIN_ZOOM, _zoom - ZOOM_STEP)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("open_map") or event.is_action_pressed("ui_cancel"):
		close_map()
		get_viewport().set_input_as_handled()
