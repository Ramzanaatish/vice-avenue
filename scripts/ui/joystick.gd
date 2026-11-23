extends Control

## Virtual movement stick (S07). Dragging presses the move_*
## Input actions with strength, so keyboard, touch and future
## controllers share one action map.

const RADIUS := 90.0
# Step 7 (Phase 14): ignore tiny thumb drift, and let the knob
# glide back to centre instead of snapping. The INPUT still
# releases instantly — only the knob visual is tweened.
const DEAD_ZONE := 0.12

var vehicle_mode: bool = false
var _touch_id := -1
var _knob_pos := Vector2.ZERO
var _knob_visual := Vector2.ZERO
var _knob_tween: Tween = null

func _ready() -> void:
	custom_minimum_size = Vector2(220, 220)

func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, RADIUS, Color(1, 1, 1, 0.08))
	draw_arc(c, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(c + _knob_visual, 38.0, Color(1, 1, 1, 0.25))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1:
			_touch_id = event.index
			_update_knob(event.position)
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			_release()
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_update_knob(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_update_knob(event.position)
		else:
			_release()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_knob(event.position)

func _update_knob(local_pos: Vector2) -> void:
	var c := size * 0.5
	var v := local_pos - c
	if v.length() > RADIUS:
		v = v.normalized() * RADIUS
	_knob_pos = v
	_knob_visual = v
	if _knob_tween != null:
		_knob_tween.kill()
		_knob_tween = null
	queue_redraw()
	_apply_input(v / RADIUS)

func _release() -> void:
	_knob_pos = Vector2.ZERO
	_apply_input(Vector2.ZERO)
	# Visual glide only — the input above is already zero.
	if _knob_tween != null:
		_knob_tween.kill()
	_knob_tween = create_tween()
	_knob_tween.tween_method(_set_knob_visual, _knob_visual, Vector2.ZERO, 0.12)

func _set_knob_visual(v: Vector2) -> void:
	_knob_visual = v
	queue_redraw()

func _apply_input(v: Vector2) -> void:
	if v.length() < DEAD_ZONE:
		v = Vector2.ZERO
	# v.y < 0 = up on screen = forward.
	if vehicle_mode:
		_set_action("accelerate", clampf(-v.y, 0.0, 1.0))
		_set_action("brake", clampf(v.y, 0.0, 1.0))
		_set_action("steer_left", clampf(-v.x, 0.0, 1.0))
		_set_action("steer_right", clampf(v.x, 0.0, 1.0))
	else:
		_set_action("move_forward", clampf(-v.y, 0.0, 1.0))
		_set_action("move_back", clampf(v.y, 0.0, 1.0))
		_set_action("move_left", clampf(-v.x, 0.0, 1.0))
		_set_action("move_right", clampf(v.x, 0.0, 1.0))

func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)
