## briefing_page.gd — Mission briefing page
## Explains mission context, objective, and configured controls before launching.
class_name LauncherBriefingPage
extends Control

const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")

signal intent_requested(action: StringName, payload: Dictionary)

var _mode_id: String = "incident_response"
var _mission_id: String = "IR-2026-001"

var _mode_label: Label
var _mission_code_label: Label
var _title_label: Label
var _objective_label: Label
var _desc_label: Label
var _controls_grid: GridContainer
var _controls_scroll: ScrollContainer

var _start_btn: Button
var _skip_btn: Button
var _back_btn: Button
var _cached_hints: Array = []
var _margin: MarginContainer

func get_page_id() -> String:
	return "briefing"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_build_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_instance_valid(_margin):
			_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_fit_controls_panel()

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

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 48)
	_margin.add_child(hbox)

	# ── Left Column: Mission Briefing ─────────────────────────────────────────
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.3
	left_vbox.add_theme_constant_override("separation", 18)
	hbox.add_child(left_vbox)

	# Breadcrumb / back
	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 16)
	left_vbox.add_child(nav_row)

	_back_btn = Button.new()
	_back_btn.text = "← Back"
	_back_btn.focus_mode = Control.FOCUS_ALL
	_back_btn.pressed.connect(func(): intent_requested.emit(&"back", {}))
	nav_row.add_child(_back_btn)

	_mode_label = Label.new()
	_mode_label.text = "ENSA Incident Response"
	_mode_label.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
	_mode_label.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
	nav_row.add_child(_mode_label)

	_mission_code_label = Label.new()
	_mission_code_label.text = "• Mission IR-2026-001"
	_mission_code_label.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
	_mission_code_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	nav_row.add_child(_mission_code_label)

	# Mission title
	_title_label = Label.new()
	_title_label.text = "The borrowed session"
	LauncherTheme.display(_title_label, LauncherTheme.FONT_TITLE)
	_title_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_stylebox_override("normal", LauncherTheme.make_card_style("normal", true))
	left_vbox.add_child(_title_label)

	# Primary Objective Card
	var obj_panel := PanelContainer.new()
	obj_panel.add_theme_stylebox_override("panel", LauncherTheme.make_card_style("normal", true))
	left_vbox.add_child(obj_panel)

	var obj_vbox := VBoxContainer.new()
	obj_vbox.add_theme_constant_override("separation", 6)
	obj_panel.add_child(obj_vbox)

	var obj_hdr := Label.new()
	obj_hdr.text = "PRIMARY OBJECTIVE"
	LauncherTheme.display(obj_hdr, 16)
	obj_hdr.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT_DIM)
	obj_vbox.add_child(obj_hdr)

	_objective_label = Label.new()
	_objective_label.text = "Find the marked workstation"
	LauncherTheme.display(_objective_label, 26)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	obj_vbox.add_child(_objective_label)

	# Briefing explanation
	var desc_scroll := ScrollContainer.new()
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(desc_scroll)

	_desc_label = Label.new()
	_desc_label.text = "A simulated cyber security incident has occurred on the campus network. An unauthorized access artifact was detected originating from a workstation inside the faculty complex.\n\nYour task is to explore the campus, locate the compromised machine indicated on your guide, inspect its simulated terminal files, preserve evidence, contain any active lateral movement, and file an official incident response report."
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc_label.add_theme_stylebox_override("normal", LauncherTheme.make_card_style("normal"))
	_desc_label.add_theme_font_size_override("font_size", LauncherTheme.FONT_BODY)
	_desc_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	desc_scroll.add_child(_desc_label)

	# Action buttons row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	left_vbox.add_child(btn_row)

	_start_btn = Button.new()
	_start_btn.text = "Start Mission"
	_start_btn.custom_minimum_size = Vector2(180, 48)
	_start_btn.focus_mode = Control.FOCUS_ALL
	LauncherTheme.style_primary(_start_btn)
	_start_btn.add_theme_font_size_override("font_size", 24)
	_start_btn.pressed.connect(func():
		intent_requested.emit(&"start_mission", {
			"mode_id": _mode_id,
			"mission_id": _mission_id,
			"skip_briefing": false
		})
	)
	btn_row.add_child(_start_btn)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip Briefing & Launch"
	_skip_btn.custom_minimum_size = Vector2(180, 48)
	_skip_btn.focus_mode = Control.FOCUS_ALL
	_skip_btn.pressed.connect(func():
		intent_requested.emit(&"start_mission", {
			"mode_id": _mode_id,
			"mission_id": _mission_id,
			"skip_briefing": true
		})
	)
	btn_row.add_child(_skip_btn)

	# ── Right Column: Configured Controls & Operational Intel ────────────────
	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_stretch_ratio = 0.9
	hbox.add_child(right_column)
	var controls_spacer := Control.new()
	controls_spacer.custom_minimum_size.y = 60
	right_column.add_child(controls_spacer)
	var right_panel := PanelContainer.new()
	right_panel.add_theme_stylebox_override("panel", LauncherTheme.make_card_style("normal", true))
	right_column.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 16)
	right_panel.add_child(right_vbox)

	var controls_title := Label.new()
	controls_title.text = "FIELD CONTROLS"
	LauncherTheme.display(controls_title, LauncherTheme.FONT_HEADING)
	controls_title.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	right_vbox.add_child(controls_title)

	_controls_scroll = ScrollContainer.new()
	_controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(_controls_scroll)

	_controls_grid = GridContainer.new()
	_controls_grid.columns = 2
	_controls_grid.add_theme_constant_override("h_separation", 24)
	_controls_grid.add_theme_constant_override("v_separation", 5)
	_controls_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_scroll.add_child(_controls_grid)
	_controls_grid.minimum_size_changed.connect(_fit_controls_panel, CONNECT_DEFERRED)

	_populate_default_controls()

func _fit_controls_panel() -> void:
	if not is_instance_valid(_controls_grid):
		return
	var available_height := maxf(100.0, size.y - 2.0 * LauncherTheme.MARGIN_SAFE - 156.0)
	_controls_scroll.custom_minimum_size.y = minf(_controls_grid.get_combined_minimum_size().y, available_height)

func _populate_default_controls() -> void:
	var default_hints = [
		{"action": "Move", "binding": "W A S D / Arrows"},
		{"action": "Look Around", "binding": "Mouse"},
		{"action": "Interact (PC/Door)", "binding": "E (within 2m)"},
		{"action": "Sprint", "binding": "Shift"},
		{"action": "Jump", "binding": "Space"},
		{"action": "Campus Guide", "binding": "Tab"},
		{"action": "Response Plan", "binding": "J"},
		{"action": "Pause / Menu", "binding": "Esc"}
	]
	_set_controls_hints(default_hints)

func _set_controls_hints(hints: Array) -> void:
	if _cached_hints == hints and _controls_grid.get_child_count() == hints.size() * 2:
		return
	_cached_hints = hints.duplicate(true)

	for child in _controls_grid.get_children():
		_controls_grid.remove_child(child)
		child.queue_free()

	for hint in hints:
		var act_label := Label.new()
		act_label.text = hint.get("action", "")
		act_label.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
		act_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
		act_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_controls_grid.add_child(act_label)

		var bind_label := Label.new()
		bind_label.text = hint.get("binding", "")
		LauncherTheme.display(bind_label, 15)
		bind_label.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
		bind_label.add_theme_stylebox_override("normal", LauncherTheme.make_badge_style(LauncherTheme.COL_VIOLET))
		bind_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_controls_grid.add_child(bind_label)

func update_from_model(model: Dictionary) -> void:
	_mode_id = model.get("selected_mode_id", "incident_response")
	var mission_data: Dictionary = model.get("mission", {})
	_mission_id = mission_data.get("id", "IR-2026-001")

	if mission_data.has("title"):
		_title_label.text = mission_data.get("title", "")
	if mission_data.has("objective"):
		_objective_label.text = mission_data.get("objective", "")
	if mission_data.has("briefing"):
		_desc_label.text = mission_data.get("briefing", "")
	
	_mission_code_label.text = "• Mission " + _mission_id

	# Controls from mission or control_hints
	var hints = mission_data.get("controls", [])
	if hints.is_empty():
		hints = model.get("control_hints", [])
	if not hints.is_empty():
		_set_controls_hints(hints)

func focus_primary() -> void:
	if is_instance_valid(_start_btn):
		_start_btn.grab_focus()
