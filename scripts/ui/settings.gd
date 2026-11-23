extends Control

## S04 — Settings (Step 3).
## Reads/writes ONLY through SettingsManager. Every change
## applies immediately and persists to user://settings.cfg.

var _loading := false

func _ready() -> void:
	$TabContainer/Graphics/VBox/QualityOption.add_item("Low")
	$TabContainer/Graphics/VBox/QualityOption.add_item("Medium")
	$TabContainer/Graphics/VBox/QualityOption.add_item("High")
	$TabContainer/Graphics/VBox/QualityOption.item_selected.connect(_on_quality_selected)
	$TabContainer/Graphics/VBox/ResolutionSlider.value_changed.connect(_on_resolution_changed)
	$TabContainer/Graphics/VBox/ShadowsCheck.toggled.connect(_on_shadows_toggled)
	$TabContainer/Graphics/VBox/FpsCheck.toggled.connect(_on_fps_toggled)
	$TabContainer/Audio/VBox/MusicSlider.value_changed.connect(_on_music_changed)
	$TabContainer/Audio/VBox/SfxSlider.value_changed.connect(_on_sfx_changed)
	$TabContainer/Audio/VBox/DialogueSlider.value_changed.connect(_on_dialogue_changed)
	$TabContainer/Audio/VBox/AmbienceSlider.value_changed.connect(_on_ambience_changed)
	$TabContainer/Audio/VBox/MuteCheck.toggled.connect(_on_mute_toggled)
	$TabContainer/Controls/VBox/SensitivitySlider.value_changed.connect(_on_sensitivity_changed)
	$TabContainer/Controls/VBox/ButtonSizeSlider.value_changed.connect(_on_button_size_changed)
	$TabContainer/Controls/VBox/ButtonOpacitySlider.value_changed.connect(_on_button_opacity_changed)
	$TabContainer/Controls/VBox/InvertCheck.toggled.connect(_on_invert_toggled)
	$TabContainer/Controls/VBox/ResetLayoutButton.pressed.connect(_on_reset_layout_pressed)
	$TabContainer/Accessibility/VBox/SubtitlesCheck.toggled.connect(_on_subtitles_toggled)
	$TabContainer/Accessibility/VBox/ShakeCheck.toggled.connect(_on_shake_toggled)
	$BottomBar/BackButton.pressed.connect(_on_back_pressed)
	$BottomBar/ResetButton.pressed.connect(_on_reset_pressed)
	$ResetConfirm.confirmed.connect(_on_reset_confirmed)
	_refresh()
	print("Settings shown.")

func _refresh() -> void:
	_loading = true
	var quality := str(SettingsManager.get_value("graphics/quality"))
	$TabContainer/Graphics/VBox/QualityOption.select(["Low", "Medium", "High"].find(quality) if quality in ["Low", "Medium", "High"] else 1)
	$TabContainer/Graphics/VBox/ResolutionSlider.set_value_no_signal(float(SettingsManager.get_value("graphics/resolution_scale")))
	$TabContainer/Graphics/VBox/ShadowsCheck.set_pressed_no_signal(bool(SettingsManager.get_value("graphics/shadows")))
	$TabContainer/Graphics/VBox/FpsCheck.set_pressed_no_signal(bool(SettingsManager.get_value("graphics/show_fps")))
	$TabContainer/Audio/VBox/MusicSlider.set_value_no_signal(float(SettingsManager.get_value("audio/music_volume")))
	$TabContainer/Audio/VBox/SfxSlider.set_value_no_signal(float(SettingsManager.get_value("audio/sfx_volume")))
	$TabContainer/Audio/VBox/DialogueSlider.set_value_no_signal(float(SettingsManager.get_value("audio/dialogue_volume")))
	$TabContainer/Audio/VBox/AmbienceSlider.set_value_no_signal(float(SettingsManager.get_value("audio/ambience_volume")))
	$TabContainer/Audio/VBox/MuteCheck.set_pressed_no_signal(bool(SettingsManager.get_value("audio/muted")))
	$TabContainer/Controls/VBox/SensitivitySlider.set_value_no_signal(float(SettingsManager.get_value("controls/sensitivity")))
	$TabContainer/Controls/VBox/ButtonSizeSlider.set_value_no_signal(float(SettingsManager.get_value("controls/button_size")))
	$TabContainer/Controls/VBox/ButtonOpacitySlider.set_value_no_signal(float(SettingsManager.get_value("controls/button_opacity")))
	$TabContainer/Controls/VBox/InvertCheck.set_pressed_no_signal(bool(SettingsManager.get_value("controls/invert_camera")))
	$TabContainer/Accessibility/VBox/SubtitlesCheck.set_pressed_no_signal(bool(SettingsManager.get_value("accessibility/subtitles")))
	$TabContainer/Accessibility/VBox/ShakeCheck.set_pressed_no_signal(bool(SettingsManager.get_value("accessibility/camera_shake")))
	_loading = false

func _on_quality_selected(index: int) -> void:
	if _loading:
		return
	var preset: String = ["Low", "Medium", "High"][index]
	SettingsManager.set_value("graphics/quality", preset)
	match preset:
		"Low":
			SettingsManager.set_value("graphics/shadows", false)
			SettingsManager.set_value("graphics/resolution_scale", 0.75)
		"Medium":
			SettingsManager.set_value("graphics/shadows", false)
			SettingsManager.set_value("graphics/resolution_scale", 1.0)
		"High":
			SettingsManager.set_value("graphics/shadows", true)
			SettingsManager.set_value("graphics/resolution_scale", 1.0)
	_refresh()

func _on_resolution_changed(value: float) -> void:
	if not _loading:
		SettingsManager.set_value("graphics/resolution_scale", value)

func _on_shadows_toggled(on: bool) -> void:
	if not _loading:
		SettingsManager.set_value("graphics/shadows", on)

func _on_fps_toggled(on: bool) -> void:
	if not _loading:
		SettingsManager.set_value("graphics/show_fps", on)

func _on_music_changed(value: float) -> void:
	if not _loading:
		SettingsManager.set_value("audio/music_volume", value)

func _on_sfx_changed(value: float) -> void:
	if not _loading:
		SettingsManager.set_value("audio/sfx_volume", value)

func _on_dialogue_changed(value: float) -> void:
	if not _loading:
		SettingsManager.set_value("audio/dialogue_volume", value)

func _on_ambience_changed(value: float) -> void:
	if not _loading:
		SettingsManager.set_value("audio/ambience_volume", value)

func _on_mute_toggled(on: bool) -> void:
	if not _loading:
		SettingsManager.set_value("audio/muted", on)

func _on_sensitivity_changed(value: float) -> void:
	if not _loading:
		SettingsManager.set_value("controls/sensitivity", value)

func _on_button_size_changed(value: float) -> void:
	if not _loading:
		SettingsManager.set_value("controls/button_size", value)

func _on_button_opacity_changed(value: float) -> void:
	if not _loading:
		SettingsManager.set_value("controls/button_opacity", value)

func _on_invert_toggled(on: bool) -> void:
	if not _loading:
		SettingsManager.set_value("controls/invert_camera", on)

func _on_reset_layout_pressed() -> void:
	UiFeedback.press($TabContainer/Controls/VBox/ResetLayoutButton)
	for key in ["controls/sensitivity", "controls/invert_camera", "controls/button_size", "controls/button_opacity"]:
		SettingsManager.set_value(key, SettingsManager.DEFAULTS[key])
	_refresh()

func _on_subtitles_toggled(on: bool) -> void:
	if not _loading:
		SettingsManager.set_value("accessibility/subtitles", on)

func _on_shake_toggled(on: bool) -> void:
	if not _loading:
		SettingsManager.set_value("accessibility/camera_shake", on)

func _on_back_pressed() -> void:
	UiFeedback.press($BottomBar/BackButton)
	# Step 7 (Phase 14, S04): Back returns to the calling scene.
	# From the Pause Menu the world was autosaved to slot 0 on
	# the way in — come back through it; otherwise the menu.
	if GameManager.settings_return_target == "world":
		GameManager.settings_return_target = "menu"
		GameManager.continue_game(0)
	else:
		GameManager.request_scene("res://scenes/frontend/main_menu.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _on_reset_pressed() -> void:
	UiFeedback.press($BottomBar/ResetButton)
	$ResetConfirm.popup_centered()

func _on_reset_confirmed() -> void:
	SettingsManager.reset_to_defaults()
	_refresh()
