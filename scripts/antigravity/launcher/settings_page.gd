## settings_page.gd — Complete settings configuration page
## Tabs: Graphics & Display, Audio, Controls, Gameplay & Accessibility.
## Fully intent-driven, reflects saved vs draft states, supports key rebinding.
class_name LauncherSettingsPage
extends Control

const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")

signal intent_requested(action: StringName, payload: Dictionary)

const RESOLUTIONS := ["1280x720", "1920x1080", "1600x900"]
const PRESETS := ["low", "medium", "high"]
const FPS_LIMITS := [30, 60, 0]
const BINDING_ACTIONS: Array[String] = [
	"move_forward",
	"move_backward",
	"move_left",
	"move_right",
	"sprint",
	"jump",
	"interact",
	"campus_guide",
	"response_plan",
	"pause"
]
const ALIAS_MAP := {
	"move_backward": "move_back",
	"sprint": "run",
	"campus_guide": "destinations"
}

var _tab_bar: TabBar
var _tab_containers: Array[Control] = []

var _apply_btn: Button
var _cancel_btn: Button
var _defaults_btn: Button
var _back_btn: Button
var _status_label: Label
var _discard_modal: PanelContainer
var _discard_scrim: ColorRect
var _modal_previous_focus: Control = null
var _content_panel: PanelContainer

# Cached model data
var _settings_data: Dictionary = {}
var _draft_data: Dictionary = {}
var _capabilities: Dictionary = {}
var _is_dirty: bool = false
var _capturing_action: String = ""

# Controls references for updates and adapter compatibility
var _res_option: OptionButton
var _fullscreen_check: CheckBox
var _preset_option: OptionButton
var _fps_option: OptionButton
var _vsync_check: CheckBox

var _master_slider: HSlider
var _master_val: Label
var _music_slider: HSlider
var _music_val: Label
var _sfx_slider: HSlider
var _sfx_val: Label

var _sens_slider: HSlider
var _sens_val: Label
var _bindings_vbox: VBoxContainer

var _lang_option: OptionButton
var _subtitles_check: CheckBox
var _reduced_motion_check: CheckBox

func get_page_id() -> String:
	return "settings"

var _margin: MarginContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_build_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_recenter_discard_modal()
		if is_instance_valid(_margin):
			_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if is_instance_valid(_discard_scrim):
			_discard_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _recenter_discard_modal() -> void:
	if _discard_modal != null and _discard_modal.visible:
		_discard_modal.position = Vector2(
			maxf(0.0, (size.x - _discard_modal.size.x) * 0.5),
			maxf(0.0, (size.y - _discard_modal.size.y) * 0.5)
		)

func _build_ui() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_margin.grow_vertical = Control.GROW_DIRECTION_BOTH
	_margin.add_theme_constant_override("margin_left", LauncherTheme.MARGIN_SAFE)
	_margin.add_theme_constant_override("margin_right", LauncherTheme.MARGIN_SAFE)
	_margin.add_theme_constant_override("margin_top", LauncherTheme.MARGIN_SAFE)
	_margin.add_theme_constant_override("margin_bottom", LauncherTheme.MARGIN_SAFE)
	add_child(_margin)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 18)
	_margin.add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	_back_btn = Button.new()
	_back_btn.text = "← Back"
	_back_btn.focus_mode = Control.FOCUS_ALL
	_back_btn.pressed.connect(_on_back_pressed)
	header.add_child(_back_btn)

	var title := Label.new()
	title.text = "SETTINGS & PREFERENCES"
	LauncherTheme.display(title, LauncherTheme.FONT_HEADING)
	title.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	header.add_child(title)

	# Tab navigation
	_tab_bar = TabBar.new()
	_tab_bar.focus_mode = Control.FOCUS_ALL
	_tab_bar.add_tab("Graphics & Display")
	_tab_bar.add_tab("Audio")
	_tab_bar.add_tab("Controls")
	_tab_bar.add_tab("Gameplay & Accessibility")
	_tab_bar.tab_changed.connect(_on_tab_changed)
	vbox.add_child(_tab_bar)

	# Content area
	_content_panel = PanelContainer.new()
	_content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_panel.custom_minimum_size = Vector2(0, 300)
	_content_panel.add_theme_stylebox_override("panel", LauncherTheme.make_card_style("normal", true))
	vbox.add_child(_content_panel)

	var tab_stack := MarginContainer.new()
	tab_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_panel.add_child(tab_stack)

	# Create tab panels
	var tab_gfx = _build_graphics_tab()
	var tab_aud = _build_audio_tab()
	var tab_ctrl = _build_controls_tab()
	var tab_acc = _build_accessibility_tab()

	_tab_containers = [tab_gfx, tab_aud, tab_ctrl, tab_acc]
	for tab in _tab_containers:
		tab_stack.add_child(tab)

	_on_tab_changed(0)

	# Bottom action bar
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	vbox.add_child(bar)

	_apply_btn = Button.new()
	_apply_btn.text = "Apply Changes"
	_apply_btn.custom_minimum_size = Vector2(150, 42)
	_apply_btn.focus_mode = Control.FOCUS_ALL
	LauncherTheme.style_primary(_apply_btn)
	_apply_btn.pressed.connect(func(): intent_requested.emit(&"apply_settings", {}))
	_apply_btn.disabled = true
	bar.add_child(_apply_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.custom_minimum_size = Vector2(100, 42)
	_cancel_btn.focus_mode = Control.FOCUS_ALL
	_cancel_btn.pressed.connect(func(): intent_requested.emit(&"cancel_settings", {}))
	bar.add_child(_cancel_btn)

	_defaults_btn = Button.new()
	_defaults_btn.text = "Restore Defaults"
	_defaults_btn.custom_minimum_size = Vector2(150, 42)
	_defaults_btn.focus_mode = Control.FOCUS_ALL
	_defaults_btn.pressed.connect(func(): intent_requested.emit(&"restore_defaults", {}))
	bar.add_child(_defaults_btn)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
	_status_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_status_label)

	_build_discard_modal()

# ── Tab Builders ─────────────────────────────────────────────────────────────

func _build_graphics_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 11)
	scroll.add_child(vbox)

	# Resolution
	var res_row := _create_graphics_row(vbox, "Display Resolution")
	_res_option = OptionButton.new()
	_res_option.focus_mode = Control.FOCUS_ALL
	_res_option.add_item("1280 × 720 (Native Iris Target)")
	_res_option.add_item("1920 × 1080 (Full HD)")
	_res_option.add_item("1600 × 900")
	_res_option.item_selected.connect(func(idx):
		var res_str = RESOLUTIONS[clampi(idx, 0, RESOLUTIONS.size() - 1)]
		_emit_edit("resolution", res_str)
	)
	res_row.add_child(_res_option)

	# Fullscreen
	var fs_row := _create_graphics_row(vbox, "Display Mode")
	_fullscreen_check = CheckBox.new()
	_fullscreen_check.focus_mode = Control.FOCUS_ALL
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.toggled.connect(func(val): _emit_edit("fullscreen", val))
	fs_row.add_child(_fullscreen_check)

	# Presets
	var preset_row := _create_graphics_row(vbox, "Graphics Preset")
	_preset_option = OptionButton.new()
	_preset_option.focus_mode = Control.FOCUS_ALL
	_preset_option.add_item("Low")
	_preset_option.add_item("Medium (Recommended)")
	_preset_option.add_item("High")
	_preset_option.selected = 1
	_preset_option.item_selected.connect(func(idx):
		var p_str = PRESETS[clampi(idx, 0, PRESETS.size() - 1)]
		_emit_edit("graphics_preset", p_str)
	)
	preset_row.add_child(_preset_option)

	# Frame Cap
	var fps_row := _create_graphics_row(vbox, "Frame Rate Limit")
	_fps_option = OptionButton.new()
	_fps_option.focus_mode = Control.FOCUS_ALL
	_fps_option.add_item("30 FPS (Power Saving)")
	_fps_option.add_item("60 FPS")
	_fps_option.add_item("Unlimited")
	_fps_option.selected = 1
	_fps_option.item_selected.connect(func(idx):
		var fps_val = FPS_LIMITS[clampi(idx, 0, FPS_LIMITS.size() - 1)]
		_emit_edit("frame_cap", fps_val)
	)
	fps_row.add_child(_fps_option)

	# V-Sync
	var vsync_row := _create_graphics_row(vbox, "Vertical Sync")
	_vsync_check = CheckBox.new()
	_vsync_check.focus_mode = Control.FOCUS_ALL
	_vsync_check.text = "Enable V-Sync"
	_vsync_check.toggled.connect(func(val): _emit_edit("vsync", val))
	vsync_row.add_child(_vsync_check)

	return scroll

func _build_audio_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 24)
	scroll.add_child(vbox)

	# Master
	var m_row := _create_row(vbox, "Master Volume")
	_master_slider = HSlider.new()
	_master_slider.focus_mode = Control.FOCUS_ALL
	_master_slider.min_value = 0
	_master_slider.max_value = 100
	_master_slider.value = 80
	_master_slider.custom_minimum_size = Vector2(240, 0)
	_master_val = Label.new()
	_master_val.text = "80%"
	_master_val.custom_minimum_size = Vector2(48, 0)
	_master_slider.value_changed.connect(func(val):
		_master_val.text = "%d%%" % int(val)
		_emit_edit("master_volume", val)
	)
	m_row.add_child(_master_slider)
	m_row.add_child(_master_val)

	# SFX
	var s_row := _create_row(vbox, "Sound Effects (SFX)")
	_sfx_slider = HSlider.new()
	_sfx_slider.focus_mode = Control.FOCUS_ALL
	_sfx_slider.min_value = 0
	_sfx_slider.max_value = 100
	_sfx_slider.value = 85
	_sfx_slider.custom_minimum_size = Vector2(240, 0)
	_sfx_val = Label.new()
	_sfx_val.text = "85%"
	_sfx_val.custom_minimum_size = Vector2(48, 0)
	_sfx_slider.value_changed.connect(func(val):
		_sfx_val.text = "%d%%" % int(val)
		_emit_edit("sfx_volume", val)
	)
	s_row.add_child(_sfx_slider)
	s_row.add_child(_sfx_val)

	# Music
	var mus_row := _create_row(vbox, "Music Volume")
	_music_slider = HSlider.new()
	_music_slider.focus_mode = Control.FOCUS_ALL
	_music_slider.min_value = 0
	_music_slider.max_value = 100
	_music_slider.value = 50
	_music_slider.custom_minimum_size = Vector2(240, 0)
	_music_val = Label.new()
	_music_val.text = "50%"
	_music_val.custom_minimum_size = Vector2(48, 0)
	_music_slider.value_changed.connect(func(val):
		_music_val.text = "%d%%" % int(val)
		_emit_edit("music_volume", val)
	)
	mus_row.add_child(_music_slider)
	mus_row.add_child(_music_val)

	var mus_note := Label.new()
	mus_note.text = "Audio buses are available. This version has no background soundtrack or spoken dialogue. SFX volume controls the launcher feedback tone."
	mus_note.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
	mus_note.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_DISABLED)
	mus_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(mus_note)

	return scroll

func _build_controls_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(vbox)

	# Sensitivity
	var sens_row := _create_row(vbox, "Mouse Look Sensitivity")
	_sens_slider = HSlider.new()
	_sens_slider.focus_mode = Control.FOCUS_ALL
	_sens_slider.min_value = 0.5
	_sens_slider.max_value = 3.0
	_sens_slider.step = 0.1
	_sens_slider.value = 1.0
	_sens_slider.custom_minimum_size = Vector2(240, 0)
	_sens_val = Label.new()
	_sens_val.text = "1.0×"
	_sens_val.custom_minimum_size = Vector2(48, 0)
	_sens_slider.value_changed.connect(func(val):
		_sens_val.text = "%.1f×" % val
		_emit_edit("mouse_sensitivity", val)
	)
	sens_row.add_child(_sens_slider)
	sens_row.add_child(_sens_val)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = LauncherTheme.COL_BORDER
	vbox.add_child(divider)

	var bind_hdr := Label.new()
	bind_hdr.text = "KEYBOARD & MOUSE BINDINGS (Click button to rebind)"
	bind_hdr.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
	bind_hdr.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	vbox.add_child(bind_hdr)

	_bindings_vbox = VBoxContainer.new()
	_bindings_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_bindings_vbox)

	_populate_default_bindings()

	return scroll

func _populate_default_bindings() -> void:
	for child in _bindings_vbox.get_children():
		child.queue_free()

	var default_bindings = [
		{"action": "move_forward", "label": "Move Forward", "key": "W / Up"},
		{"action": "move_backward", "label": "Move Backward", "key": "S / Down"},
		{"action": "move_left", "label": "Move Left", "key": "A / Left"},
		{"action": "move_right", "label": "Move Right", "key": "D / Right"},
		{"action": "sprint", "label": "Sprint / Fast Walk", "key": "Shift"},
		{"action": "jump", "label": "Jump", "key": "Space"},
		{"action": "interact", "label": "Interact (PC / Door)", "key": "E"},
		{"action": "campus_guide", "label": "Campus Guide & Destinations", "key": "Tab"},
		{"action": "response_plan", "label": "Incident Response Plan", "key": "J"},
		{"action": "pause", "label": "Pause Simulation", "key": "Escape"}
	]

	for b in default_bindings:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		_bindings_vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = b["label"]
		lbl.custom_minimum_size = Vector2(220, 0)
		lbl.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
		lbl.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = b["key"]
		btn.custom_minimum_size = Vector2(160, 32)
		btn.focus_mode = Control.FOCUS_ALL
		var act_id = b["action"]
		if act_id == "pause":
			btn.disabled = true
		else:
			btn.pressed.connect(func(): _start_capture_binding(act_id, btn))
		row.add_child(btn)

func _start_capture_binding(action_id: String, btn: Button) -> void:
	if action_id == "pause":
		return
	_capturing_action = action_id
	btn.text = "Press a key… (Esc cancels)"
	intent_requested.emit(&"capture_binding", {"action": action_id})

func _build_accessibility_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 24)
	scroll.add_child(vbox)

	# Language
	var lang_row := _create_row(vbox, "Interface Language")
	_lang_option = OptionButton.new()
	_lang_option.focus_mode = Control.FOCUS_ALL
	_lang_option.add_item("English (Supplied)")
	_lang_option.add_item("Français (Not supplied in this version)")
	_lang_option.set_item_disabled(1, true)
	_lang_option.tooltip_text = "English is the supplied interface translation."
	_lang_option.item_selected.connect(func(idx):
		var lang_code = "en" if idx == 0 else "fr"
		_emit_edit("language", lang_code)
	)
	lang_row.add_child(_lang_option)

	# Subtitles
	var sub_row := _create_row(vbox, "Subtitles / Captions")
	_subtitles_check = CheckBox.new()
	_subtitles_check.focus_mode = Control.FOCUS_ALL
	_subtitles_check.text = "Enable Closed Captions"
	_subtitles_check.disabled = true
	_subtitles_check.tooltip_text = "There is no spoken dialogue in this version."
	_subtitles_check.toggled.connect(func(val): _emit_edit("subtitles", val))
	sub_row.add_child(_subtitles_check)

	# Reduced motion
	var mot_row := _create_row(vbox, "Motion Accessibility")
	_reduced_motion_check = CheckBox.new()
	_reduced_motion_check.focus_mode = Control.FOCUS_ALL
	_reduced_motion_check.text = "Reduced Motion (Disable decorative pulses, instant page swaps)"
	_reduced_motion_check.toggled.connect(func(val):
		_emit_edit("reduced_motion", val)
		intent_requested.emit(&"set_preferences_preview", {"reduced_motion": val})
	)
	mot_row.add_child(_reduced_motion_check)

	return scroll

func _create_graphics_row(parent: Control, label_text: String) -> HBoxContainer:
	if parent.get_child_count() > 0:
		var rule := HSeparator.new()
		var style := StyleBoxLine.new()
		style.color = LauncherTheme.COL_BORDER
		rule.add_theme_stylebox_override("separator", style)
		parent.add_child(rule)
	return _create_row(parent, label_text)

func _create_row(parent: Control, label_text: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(260, 0)
	lbl.add_theme_font_size_override("font_size", LauncherTheme.FONT_BODY)
	lbl.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	hbox.add_child(lbl)

	return hbox

func _on_tab_changed(index: int) -> void:
	for i in range(_tab_containers.size()):
		_tab_containers[i].visible = (i == index)

func select_tab(index: int) -> void:
	if _tab_bar != null and index >= 0 and index < _tab_bar.tab_count:
		_tab_bar.current_tab = index
		_on_tab_changed(index)

func get_active_tab_index() -> int:
	return _tab_bar.current_tab if _tab_bar != null else -1

func get_tab_container(index: int) -> Control:
	if index >= 0 and index < _tab_containers.size():
		return _tab_containers[index]
	return null

func get_content_panel() -> PanelContainer:
	return _content_panel

func _emit_edit(key: String, value) -> void:
	_is_dirty = true
	_apply_btn.disabled = false
	_status_label.text = "• Unsaved draft changes"
	_status_label.add_theme_color_override("font_color", LauncherTheme.COL_WARNING)
	intent_requested.emit(&"edit_setting", {"key": key, "value": value})

func _on_back_pressed() -> void:
	if _settings_data.get("display_confirmation_required", false):
		return
	var errors: Array = _settings_data.get("validation_errors", [])
	if _is_dirty or not errors.is_empty():
		show_discard_prompt()
	else:
		intent_requested.emit(&"back", {})

# ── Discard Modal ────────────────────────────────────────────────────────────

func _build_discard_modal() -> void:
	_discard_scrim = ColorRect.new()
	_discard_scrim.color = Color(0.0, 0.0, 0.0, 0.6)
	_discard_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_discard_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_discard_scrim.visible = false
	add_child(_discard_scrim)

	_discard_modal = PanelContainer.new()
	_discard_modal.set_anchors_preset(Control.PRESET_CENTER)
	_discard_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_discard_modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	_discard_modal.custom_minimum_size = Vector2(460, 180)
	_discard_modal.visible = false
	var sb := LauncherTheme._make_flat_box(
		LauncherTheme.COL_BG_PANEL, LauncherTheme.CORNER_RADIUS_LG,
		LauncherTheme.COL_BORDER, 2, 24.0)
	_discard_modal.add_theme_stylebox_override("panel", sb)
	add_child(_discard_modal)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 16)
	_discard_modal.add_child(vbox)

	var title := Label.new()
	title.text = "Unsaved Changes"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", LauncherTheme.FONT_HEADING)
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = "You have modified settings that have not been applied yet."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", LauncherTheme.FONT_BODY)
	msg.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	vbox.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var apply_b := Button.new()
	apply_b.name = "ApplyButton"
	apply_b.text = "Apply & Exit"
	apply_b.focus_mode = Control.FOCUS_ALL
	LauncherTheme.style_primary(apply_b)
	apply_b.pressed.connect(func():
		_close_discard_modal()
		intent_requested.emit(&"apply_settings", {})
		intent_requested.emit(&"back", {})
	)
	btn_row.add_child(apply_b)

	var discard_b := Button.new()
	discard_b.name = "DiscardButton"
	discard_b.text = "Discard & Exit"
	discard_b.focus_mode = Control.FOCUS_ALL
	discard_b.pressed.connect(func():
		_close_discard_modal()
		_is_dirty = false
		intent_requested.emit(&"cancel_settings", {})
		intent_requested.emit(&"back", {})
	)
	btn_row.add_child(discard_b)

	var stay_b := Button.new()
	stay_b.name = "StayButton"
	stay_b.text = "Stay on Page"
	stay_b.focus_mode = Control.FOCUS_ALL
	stay_b.pressed.connect(func():
		_close_discard_modal()
	)
	btn_row.add_child(stay_b)

	# Focus containment loop (all directions)
	apply_b.focus_next = NodePath("../DiscardButton")
	apply_b.focus_previous = NodePath("../StayButton")
	apply_b.focus_neighbor_right = NodePath("../DiscardButton")
	apply_b.focus_neighbor_left = NodePath("../StayButton")
	apply_b.focus_neighbor_top = NodePath("../StayButton")
	apply_b.focus_neighbor_bottom = NodePath("../DiscardButton")

	discard_b.focus_next = NodePath("../StayButton")
	discard_b.focus_previous = NodePath("../ApplyButton")
	discard_b.focus_neighbor_right = NodePath("../StayButton")
	discard_b.focus_neighbor_left = NodePath("../ApplyButton")
	discard_b.focus_neighbor_top = NodePath("../ApplyButton")
	discard_b.focus_neighbor_bottom = NodePath("../StayButton")

	stay_b.focus_next = NodePath("../ApplyButton")
	stay_b.focus_previous = NodePath("../DiscardButton")
	stay_b.focus_neighbor_right = NodePath("../ApplyButton")
	stay_b.focus_neighbor_left = NodePath("../DiscardButton")
	stay_b.focus_neighbor_top = NodePath("../DiscardButton")
	stay_b.focus_neighbor_bottom = NodePath("../ApplyButton")

func show_discard_prompt() -> void:
	if is_instance_valid(_discard_modal):
		_modal_previous_focus = get_viewport().gui_get_focus_owner()
		_discard_scrim.visible = true
		_discard_modal.visible = true
		_recenter_discard_modal()
		var errors: Array = _settings_data.get("validation_errors", [])
		var has_errors: bool = not errors.is_empty()
		var apply_b: Button = _discard_modal.find_child("ApplyButton", true, false)
		if apply_b:
			apply_b.disabled = has_errors
		var stay_b: Button = _discard_modal.find_child("StayButton", true, false)
		var discard_b: Button = _discard_modal.find_child("DiscardButton", true, false)
		if has_errors and discard_b:
			discard_b.grab_focus.call_deferred()
		elif stay_b:
			stay_b.grab_focus.call_deferred()

func hide_discard_prompt() -> void:
	_close_discard_modal()

func _close_discard_modal() -> void:
	if is_instance_valid(_discard_scrim):
		_discard_scrim.visible = false
	if is_instance_valid(_discard_modal):
		_discard_modal.visible = false
	if _modal_previous_focus != null and is_instance_valid(_modal_previous_focus) and _modal_previous_focus.is_inside_tree():
		_modal_previous_focus.grab_focus.call_deferred()
		_modal_previous_focus = null

func _set_choice(option: OptionButton, index: int) -> void:
	if option == null:
		return
	option.set_block_signals(true)
	option.select(maxi(index, 0))
	option.set_block_signals(false)

func update_from_model(model: Dictionary) -> void:
	_settings_data = model.get("settings", {})
	_capabilities = _settings_data.get("capabilities", {})
	_is_dirty = _settings_data.get("dirty", false)
	_capturing_action = model.get("capturing_action", "")

	var draft: Dictionary = _settings_data.get("draft", {})
	if draft.is_empty():
		draft = _settings_data.get("saved", {})

	if not draft.is_empty():
		# Synchronize Display & Graphics
		var res_str := str(draft.get("resolution", "1280x720"))
		var res_idx := RESOLUTIONS.find(res_str)
		_set_choice(_res_option, res_idx)

		var preset_str := str(draft.get("graphics_preset", "medium"))
		var preset_idx := PRESETS.find(preset_str)
		_set_choice(_preset_option, preset_idx)

		var fps_val := int(draft.get("frame_cap", 60))
		var fps_idx := FPS_LIMITS.find(fps_val)
		_set_choice(_fps_option, fps_idx)

		_fullscreen_check.set_pressed_no_signal(bool(draft.get("fullscreen", false)))
		_vsync_check.set_pressed_no_signal(bool(draft.get("vsync", true)))

		# Synchronize Audio
		var m_val := float(draft.get("master_volume", 80))
		_master_slider.set_value_no_signal(m_val)
		_master_val.text = "%d%%" % int(m_val)

		var mus_val := float(draft.get("music_volume", 50))
		_music_slider.set_value_no_signal(mus_val)
		_music_val.text = "%d%%" % int(mus_val)

		var sfx_val := float(draft.get("sfx_volume", 85))
		_sfx_slider.set_value_no_signal(sfx_val)
		_sfx_val.text = "%d%%" % int(sfx_val)

		# Synchronize Sensitivity
		var sens_val := float(draft.get("mouse_sensitivity", 1.0))
		_sens_slider.set_value_no_signal(sens_val)
		_sens_val.text = "%.1f×" % sens_val

		# Synchronize Accessibility & Language
		_lang_option.set_item_disabled(1, true)
		_set_choice(_lang_option, 0)
		_lang_option.tooltip_text = "English is the supplied interface translation."

		_subtitles_check.set_pressed_no_signal(bool(draft.get("subtitles", false)))
		_subtitles_check.disabled = true
		_subtitles_check.tooltip_text = "There is no spoken dialogue in this version."

		_reduced_motion_check.set_pressed_no_signal(bool(draft.get("reduced_motion", false)))

		# Synchronize Key Bindings
		var bindings_map: Dictionary = draft.get("bindings", {})
		var disp_req: bool = bool(_settings_data.get("display_confirmation_required", false))

		for idx in range(mini(BINDING_ACTIONS.size(), _bindings_vbox.get_child_count())):
			var row: Node = _bindings_vbox.get_child(idx)
			var btn: Button = row.get_child(1) as Button
			if btn == null:
				continue
			var act_id: String = BINDING_ACTIONS[idx]
			var canon_id: String = ALIAS_MAP.get(act_id, act_id)

			var is_capturing: bool = (_capturing_action != "" and (_capturing_action == act_id or _capturing_action == canon_id))
			if is_capturing:
				btn.text = "Press a key… (Esc cancels)"
			else:
				var raw_codes = bindings_map.get(canon_id, bindings_map.get(act_id, []))
				var code_list: Array = []
				if raw_codes is Array:
					code_list = raw_codes
				elif raw_codes is int and raw_codes > 0:
					code_list = [raw_codes]

				if code_list.is_empty():
					btn.text = "Unbound"
				else:
					var names: PackedStringArray = []
					for code in code_list:
						names.append(OS.get_keycode_string(int(code)))
					btn.text = " / ".join(names)

			btn.disabled = (act_id == "pause" or canon_id == "pause" or disp_req)

	# Update modal position if visible
	if _discard_modal != null and _discard_modal.visible:
		_recenter_discard_modal()

	# Update dirty state, buttons and status label
	var errors: Array = _settings_data.get("validation_errors", [])
	var disp_req_flag: bool = bool(_settings_data.get("display_confirmation_required", false))

	_apply_btn.disabled = not _is_dirty or disp_req_flag
	_cancel_btn.disabled = disp_req_flag
	_defaults_btn.disabled = disp_req_flag

	if not errors.is_empty():
		_status_label.text = "Error: " + str(errors[0])
		_status_label.add_theme_color_override("font_color", LauncherTheme.COL_ERROR)
	elif _capturing_action != "":
		_status_label.text = "Press a key; Esc cancels."
		_status_label.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
	elif not str(_settings_data.get("message", "")).is_empty() and not _is_dirty:
		_status_label.text = str(_settings_data.get("message", ""))
		_status_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	elif _is_dirty:
		_status_label.text = "• Unsaved draft changes"
		_status_label.add_theme_color_override("font_color", LauncherTheme.COL_WARNING)
	else:
		_status_label.text = "All settings up to date"
		_status_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_DISABLED)

func focus_primary() -> void:
	if is_instance_valid(_back_btn):
		_back_btn.grab_focus()
