extends Control

## Safe-area inset (C-01): there is no built-in SafeAreaRoot
## node in Godot. Reads DisplayServer.get_display_safe_area()
## and insets this Control so HUD elements never sit under a
## notch or in the Android gesture areas.

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_apply()
	get_viewport().size_changed.connect(_apply)

func _apply() -> void:
	var area := DisplayServer.get_display_safe_area()
	var vp := get_viewport_rect().size
	offset_left = area.position.x
	offset_top = area.position.y
	offset_right = -(vp.x - area.end.x)
	offset_bottom = -(vp.y - area.end.y)
