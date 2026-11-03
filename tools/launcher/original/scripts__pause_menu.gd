extends Control
## Full-screen native navigation over the paused campus. Input shortcuts belong to main.

signal resume_requested
signal destination_requested(destination: String)
signal destinations_requested
signal quit_requested

const BACKDROP = preload("res://shaders/pause_backdrop.gdshader")
const WHITE := Color("#f1f4f6")
const SOFT := Color("#c5d2dd")
const MUTED := Color("#91a3b4")
const TEAL := Color("#79eed7")

class CampusShield extends Control:
	func _draw() -> void:
		var ink := Color("#d9e7f2")
		draw_polyline(PackedVector2Array([Vector2(18, 2), Vector2(34, 6), Vector2(33, 23), Vector2(28, 33), Vector2(18, 40), Vector2(8, 33), Vector2(3, 23), Vector2(2, 6), Vector2(18, 2)]), ink, 1.15, true)
		draw_polyline(PackedVector2Array([Vector2(10, 14), Vector2(18, 10), Vector2(26, 14), Vector2(10, 14)]), ink, 1.0, true)
		draw_line(Vector2(9, 27), Vector2(27, 27), ink, 1.0, true)
		draw_line(Vector2(10, 24), Vector2(26, 24), ink, 1.0, true)
		for x in [12.0, 18.0, 24.0]:
			draw_line(Vector2(x, 15), Vector2(x, 24), ink, 1.0, true)

class SessionSymbol extends Control:
	var initial: bool = false
	func _draw() -> void:
		var ink := Color("#d9e7f2")
		draw_arc(Vector2(14, 14), 13, 0, TAU, 40, ink, 1.0, true)
		if initial:
			draw_colored_polygon(PackedVector2Array([Vector2(11, 8), Vector2(20, 14), Vector2(11, 20)]), ink)
		else:
			draw_line(Vector2(11, 9), Vector2(11, 19), ink, 2.1, true)
			draw_line(Vector2(17, 9), Vector2(17, 19), ink, 2.1, true)

class WorkstationSymbol extends Control:
	func _draw() -> void:
		var ink := Color("#79eed7")
		draw_rect(Rect2(1, 1, 25, 17), ink, false, 1.5)
		draw_line(Vector2(13, 18), Vector2(13, 24), ink, 1.5, true)
		draw_line(Vector2(7, 24), Vector2(19, 24), ink, 1.5, true)

var _training: Node
var _ready_for_play: bool = false
var _initial: bool = true
var _screen: String = "pause"
var _loading_text: String = "Preparing campus…"
var _built: bool = false
var _destination_names: Array[String] = []
var _nav_buttons: Array[Button] = []
var _nav_chevrons: Array[Label] = []
var _nav_actions: Array[String] = []
var _selected: int = 0
var _brand: HBoxContainer
var _session: HBoxContainer
var _session_symbol: SessionSymbol
var _session_label: Label
var _intro: Control
var _eyebrow: Label
var _heading: Label
var _helper: Label
var _nav: VBoxContainer
var _loading_label: Label
var _case: Control
var _case_id: Label
var _case_title: Label
var _case_objective: Label
var _case_hint: Label
var _footer_rule: ColorRect
var _footer: HBoxContainer
var _footer_action: Label
var _local_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_built = true
	_update_copy()
	_refresh_case()
	_layout()
	get_viewport().size_changed.connect(_layout)
	hide()


func configure(training: Node) -> void:
	if is_instance_valid(_training) and _training.has_signal("mission_progress_changed") and _training.is_connected("mission_progress_changed", _on_progress_changed):
		_training.disconnect("mission_progress_changed", _on_progress_changed)
	_training = training
	if is_instance_valid(_training) and _training.has_signal("mission_progress_changed"):
		_training.connect("mission_progress_changed", _on_progress_changed)
	if _built:
		_refresh_case()


func set_loading(text: String) -> void:
	_loading_text = text
	if _built:
		_loading_label.text = text
		_loading_label.visible = _initial and not _ready_for_play and not text.is_empty()


func set_ready(ready_to_play: bool) -> void:
	_ready_for_play = ready_to_play
	if not _built:
		return
	_update_copy()
	_build_navigation()
	if visible:
		call_deferred("_focus_primary")


func show_pause(is_initial: bool = false) -> void:
	_initial = is_initial
	_screen = "pause"
	show()
	if not _built:
		return
	_update_copy()
	_build_navigation()
	_refresh_case()
	_layout()
	call_deferred("_focus_primary")


func show_destinations(destinations: Array[String]) -> void:
	_destination_names.assign(destinations)
	_screen = "destinations"
	show()
	if not _built:
		return
	_update_copy()
	_build_navigation()
	_refresh_case()
	_layout()
	call_deferred("_focus_primary")


func hide_menu() -> void:
	hide()


func is_menu_visible() -> bool:
	return visible


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "PausedCampusBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop_material := ShaderMaterial.new()
	backdrop_material.shader = BACKDROP
	backdrop.material = backdrop_material
	add_child(backdrop)
	_brand = HBoxContainer.new()
	_brand.add_theme_constant_override("separation", 21)
	add_child(_brand)
	var shield := CampusShield.new()
	shield.custom_minimum_size = Vector2(37, 42)
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brand.add_child(shield)
	_brand.add_child(_label("C A M P U S  /  I N C I D E N T  R E S P O N S E", 10, SOFT))
	_session = HBoxContainer.new()
	_session.add_theme_constant_override("separation", 18)
	add_child(_session)
	_session_symbol = SessionSymbol.new()
	_session_symbol.custom_minimum_size = Vector2(29, 29)
	_session_symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_session.add_child(_session_symbol)
	_session_label = _label("S E S S I O N  P A U S E D", 10, SOFT)
	_session.add_child(_session_label)
	_intro = Control.new()
	add_child(_intro)
	_eyebrow = _label("C A M P U S  E X P L O R A T I O N", 11, SOFT)
	_eyebrow.position = Vector2(0, 0)
	_intro.add_child(_eyebrow)
	_heading = _label("Paused", 60, WHITE)
	_heading.position = Vector2(-4, 17)
	_intro.add_child(_heading)
	_helper = _label("Continue when you’re ready.", 18, MUTED)
	_helper.position = Vector2(0, 99)
	_intro.add_child(_helper)
	_nav = VBoxContainer.new()
	_nav.add_theme_constant_override("separation", 0)
	add_child(_nav)
	_loading_label = _label(_loading_text, 12, MUTED)
	add_child(_loading_label)
	_build_case()
	_footer_rule = ColorRect.new()
	_footer_rule.color = Color(0.65, 0.76, 0.82, 0.25)
	_footer_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_footer_rule)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 15)
	add_child(_footer)
	_footer.add_child(_keycap("Esc"))
	_footer_action = _label("Resume", 12, SOFT)
	_footer.add_child(_footer_action)
	var separator := _label("│", 15, Color(0.65, 0.76, 0.82, 0.48))
	separator.custom_minimum_size.x = 28
	separator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_child(separator)
	_footer.add_child(_keycap("Tab"))
	_footer.add_child(_label("Campus guide", 12, SOFT))
	_local_label = _label("L O C A L  T R A I N I N G  S I M U L A T I O N", 9, MUTED)
	add_child(_local_label)
	_build_navigation()


func _build_case() -> void:
	_case = Control.new()
	_case.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_case)
	var rule := ColorRect.new()
	rule.color = Color(0.63, 0.75, 0.80, 0.22)
	rule.position = Vector2.ZERO
	rule.size = Vector2(320, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_case.add_child(rule)
	var accent := ColorRect.new()
	accent.color = TEAL
	accent.size = Vector2(41, 2)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_case.add_child(accent)
	_case_id = _label("ACTIVE CASE / IR-2026-001", 10, SOFT)
	_case_id.position = Vector2(0, 21)
	_case.add_child(_case_id)
	_case_title = _label("The borrowed session", 20, WHITE)
	_case_title.position = Vector2(0, 42)
	_case_title.size = Vector2(320, 30)
	_case_title.clip_text = true
	_case.add_child(_case_title)
	var workstation := WorkstationSymbol.new()
	workstation.position = Vector2(0, 91)
	workstation.size = Vector2(27, 26)
	workstation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_case.add_child(workstation)
	_case_objective = _label("Find the marked workstation", 14, WHITE)
	_case_objective.position = Vector2(48, 89)
	_case_objective.size = Vector2(272, 25)
	_case_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_case.add_child(_case_objective)
	_case_hint = _label("Press E at a training PC to begin.", 13, MUTED)
	_case_hint.position = Vector2(48, 116)
	_case_hint.size = Vector2(272, 40)
	_case_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_case.add_child(_case_hint)


func _update_copy() -> void:
	if not _built:
		return
	if _screen == "destinations":
		_eyebrow.text = "C H O O S E  A  D E S T I N A T I O N"
		_heading.text = "Campus guide"
		_heading.add_theme_font_size_override("font_size", 49)
		_helper.text = "Choose where to continue exploring."
		_session_label.text = "C A M P U S  G U I D E"
		_footer_action.text = "Resume" if _ready_for_play else "Start when ready"
	else:
		_eyebrow.text = "C A M P U S  E X P L O R A T I O N"
		_heading.text = ("Ready" if _ready_for_play else "Campus") if _initial else "Paused"
		_heading.add_theme_font_size_override("font_size", 60)
		_helper.text = ("Begin when you’re ready." if _ready_for_play else "Preparing your training exercise.") if _initial else "Continue when you’re ready."
		_session_label.text = ("S E S S I O N  R E A D Y" if _ready_for_play else "L O C A L  E X E R C I S E") if _initial else "S E S S I O N  P A U S E D"
		_footer_action.text = ("Start" if _ready_for_play else "Start when ready") if _initial else "Resume"
	_session_symbol.initial = _initial
	_session_symbol.queue_redraw()
	_loading_label.text = _loading_text
	_loading_label.visible = _initial and not _ready_for_play and _screen == "pause" and not _loading_text.is_empty()


func _build_navigation() -> void:
	if not is_instance_valid(_nav):
		return
	for child in _nav.get_children():
		_nav.remove_child(child)
		child.queue_free()
	_nav_buttons.clear()
	_nav_chevrons.clear()
	_nav_actions.clear()
	_selected = 0
	if _screen == "destinations":
		for destination in _destination_names:
			_add_navigation(destination, "destination", _request_destination.bind(destination), 36, 18)
		_add_navigation("Back to " + ("start" if _initial else "pause"), "back", show_pause.bind(_initial), 38, 17)
		_add_navigation("Start exploration" if _initial else "Resume exploration", "resume", _request_resume, 38, 17)
	else:
		_add_navigation("Start exploration" if _initial else "Resume exploration", "resume", _request_resume, 64, 27)
		_add_navigation("Campus destinations", "destinations", _request_destinations, 64, 27)
		_add_navigation("Quit game", "quit", _request_quit, 64, 27)
	for index in _nav_buttons.size():
		var button := _nav_buttons[index]
		button.disabled = not _ready_for_play and _nav_actions[index] not in ["quit", "back"]
		if not _nav_buttons.is_empty():
			button.focus_neighbor_top = button.get_path_to(_nav_buttons[(index - 1 + _nav_buttons.size()) % _nav_buttons.size()])
			button.focus_neighbor_bottom = button.get_path_to(_nav_buttons[(index + 1) % _nav_buttons.size()])
	_select_navigation(0)


func _add_navigation(text: String, action: String, callback: Callable, height: float, font_size: int) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(465, height)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", WHITE if action != "quit" else MUTED)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_focus_color", WHITE)
	button.add_theme_color_override("font_pressed_color", WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#687e8d"))
	button.add_theme_stylebox_override("hover", _nav_style(true))
	button.add_theme_stylebox_override("focus", _nav_style(true))
	button.add_theme_stylebox_override("pressed", _nav_style(true))
	button.add_theme_stylebox_override("disabled", _nav_style(false))
	button.pressed.connect(callback)
	var index := _nav_buttons.size()
	button.focus_entered.connect(_select_navigation.bind(index))
	button.mouse_entered.connect(_hover_navigation.bind(index))
	_nav.add_child(button)
	_nav_buttons.append(button)
	_nav_actions.append(action)
	var chevron := _label("›", 38 if height > 50 else 29, TEAL)
	chevron.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	chevron.offset_left = -49
	chevron.offset_right = -22
	chevron.offset_top = -24 if height > 50 else -20
	chevron.offset_bottom = 24 if height > 50 else 20
	button.add_child(chevron)
	_nav_chevrons.append(chevron)


func _nav_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.40, 0.53, 0.59, 0.11) if selected else Color(0, 0, 0, 0)
	style.border_color = TEAL
	style.border_width_left = 5 if selected else 0
	style.content_margin_left = 29
	style.content_margin_right = 57
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _select_navigation(index: int) -> void:
	_selected = index
	for i in _nav_buttons.size():
		_nav_buttons[i].add_theme_stylebox_override("normal", _nav_style(i == index))
		_nav_chevrons[i].visible = i == index and not _nav_buttons[i].disabled


func _hover_navigation(index: int) -> void:
	if index < _nav_buttons.size() and not _nav_buttons[index].disabled:
		_nav_buttons[index].grab_focus()


func _focus_primary() -> void:
	if not visible:
		return
	for button in _nav_buttons:
		if not button.disabled:
			button.grab_focus()
			return


func _request_resume() -> void:
	if _ready_for_play:
		resume_requested.emit()


func _request_destinations() -> void:
	if _ready_for_play:
		destinations_requested.emit()


func _request_destination(destination: String) -> void:
	if _ready_for_play:
		destination_requested.emit(destination)


func _request_quit() -> void:
	quit_requested.emit()


func _on_progress_changed(_completed: int, _total: int) -> void:
	_refresh_case()


func _refresh_case() -> void:
	if not _built:
		return
	var mission_data: Dictionary = {}
	var mission_state: Dictionary = {}
	if is_instance_valid(_training):
		var incoming: Variant = _training.get("mission")
		if incoming is Dictionary:
			mission_data = incoming
		var incoming_state: Variant = _training.get("state")
		if incoming_state is Dictionary:
			mission_state = incoming_state
	_case_id.text = "ACTIVE CASE / " + str(mission_data.get("entities", {}).get("case_id", "IR-2026-001"))
	_case_title.text = str(mission_data.get("title", "The borrowed session"))
	var objective := "Find the marked workstation"
	var hint := "Press E at a training PC to begin."
	if bool(mission_state.get("mission_complete", false)):
		objective = "Recovery complete"
		hint = "Your report and debrief are ready."
	elif bool(mission_state.get("triage_complete", false)):
		for raw_step in mission_data.get("steps", []):
			var step: Dictionary = raw_step
			if not bool(mission_state.get(str(step.get("completion_flag", "")), false)):
				objective = str(step.get("action_label", "Continue the response"))
				hint = "Use a response PC to continue the case."
				break
	_case_objective.text = objective
	_case_hint.text = hint


func _layout() -> void:
	if not _built:
		return
	var extent := get_viewport().get_visible_rect().size
	_brand.position = Vector2(extent.x * 0.06, extent.y * 0.045)
	_session.position = Vector2(extent.x - 233, extent.y * 0.053)
	_intro.position = Vector2(extent.x * 0.08, extent.y * 0.252)
	_nav.position = Vector2(extent.x * 0.071, extent.y * (0.442 if _screen == "destinations" else 0.48))
	_nav.size.x = minf(500, extent.x * 0.43)
	_loading_label.position = Vector2(extent.x * 0.08, extent.y * 0.79)
	_case.position = Vector2(extent.x - 351, extent.y * 0.628)
	_case.size = Vector2(320, 162)
	_footer_rule.position = Vector2(extent.x * 0.047, extent.y * 0.874)
	_footer_rule.size = Vector2(extent.x * 0.906, 1)
	_footer.position = Vector2(extent.x * 0.06, extent.y * 0.902)
	_local_label.position = Vector2(extent.x - 276, extent.y * 0.912)
	_case.visible = extent.x >= 1080


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _keycap(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.10, 0.15)
	style.border_color = SOFT
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_label(text, 12, SOFT))
	return panel
