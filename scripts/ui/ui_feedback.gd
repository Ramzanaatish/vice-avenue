class_name UiFeedback

## Step 7 (Phase 14): one shared press treatment for UI buttons.
## Blueprint S03: a button press plays a click SFX and a 0.1 s
## scale animation. Call from pressed handlers — never connect
## it to the signal itself, so the game action still runs first
## and the feedback can never block it.

static func press(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	var audio = Engine.get_main_loop().root.get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_ui_click"):
		audio.play_ui_click()
	# 0.1 s scale pop around the button centre. The tween is
	# bound to the button, so freeing the scene kills it safely.
	if button is Control:
		var control := button as Control
		control.pivot_offset = control.size * 0.5
		# Return to the button's own base scale (HUD buttons may
		# be scaled up by the touch-layout setting — never reset
		# that to 1.0).
		var base: Vector2 = control.scale
		var tween := control.create_tween()
		tween.tween_property(control, "scale", base * 0.94, 0.05)
		tween.tween_property(control, "scale", base, 0.05)
