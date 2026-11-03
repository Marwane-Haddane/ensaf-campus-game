extends CanvasLayer
## A local, data-driven training console. Commands select authored fixtures only.

signal capture_changed(captured: bool)
signal mission_progress_changed(completed: int, total: int)

const WorkstationDesktop = preload("res://scripts/workstation_desktop.gd")
const WorkstationShell = preload("res://scripts/workstation_shell.gd")
const MISSION_PATH := "res://design/incident.json"
const INK := Color("#eef3f5")
const MUTED := Color("#a6b6bf")
const TEAL := Color("#37dfd3")
const AMBER := Color("#efbb5b")
const NAVY := Color("#1b2931")
const DARK := Color("#10191f")


class ShieldMark extends Control:
	func _draw() -> void:
		var outline := PackedVector2Array([Vector2(15, 2), Vector2(27, 8), Vector2(25, 23), Vector2(15, 30), Vector2(5, 23), Vector2(3, 8), Vector2(15, 2)])
		draw_polyline(outline, Color("#dfeaf0"), 1.35, true)
		draw_polyline(PackedVector2Array([Vector2(10, 14), Vector2(10, 10), Vector2(15, 7), Vector2(20, 10), Vector2(20, 14)]), Color("#dfeaf0"), 1.2, true)
		draw_style_box(_lock_box(), Rect2(9, 13, 12, 9))
		draw_line(Vector2(7, 18), Vector2(23, 18), Color("#dfeaf0"), 1.0, true)

	func _lock_box() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0)
		box.border_color = Color("#dfeaf0")
		box.set_border_width_all(1)
		box.set_corner_radius_all(2)
		return box


class SegmentedProgress extends Control:
	var completed: int = 0
	var total: int = 7

	func _draw() -> void:
		var segment_width := size.x / float(maxi(1, total))
		for index in total:
			var rect := Rect2(Vector2(index * segment_width, 0), Vector2(segment_width - 1.0, size.y))
			draw_rect(rect, Color(0.05, 0.1, 0.13, 0.20), true)
			if index < completed:
				draw_rect(rect.grow(-2.0), Color("#37dfd3"), true)
			draw_rect(rect, Color(0.64, 0.73, 0.78, 0.7), false, 1.0)

var terminal_open: bool = false
var mission: Dictionary = {}
var state: Dictionary = {}
var points: int = 0
var journal: Array[String] = []
var command_history: Array[String] = []
var report_answers: Dictionary = {}
var report_preview_valid: bool = false
var submitted_report_text: String = ""

var _root: Control
var _terminal: Control
var _desktop
var workstation_shell: RefCounted
var _crosshair: Label
var _exploration: Control
var _exploration_visible: bool = true
var _plan_open: bool = false
var _plan: PanelContainer
var _plan_labels: Array[Label] = []
var _hud_status: Label
var _hud_current: Label
var _hud_subobjective: Label
var _hud_index: Label
var _hud_progress: SegmentedProgress
var _hud_progress_label: Label
var _hud_status_dot: Label
var _step_buttons: Array[Button] = []
var _console_output: RichTextLabel
var _command_input: LineEdit
var _feedback: Label
var _evidence_text: RichTextLabel
var _pages: Dictionary = {}
var _tabs: Dictionary = {}
var _report_summary: TextEdit
var _report_finding: OptionButton
var _report_follow_up: OptionButton
var _report_checks: Dictionary = {}
var _reflection_options: Array[OptionButton] = []
var _reflection_explanations: Array[Label] = []
var _report_error: Label
var _report_preview: RichTextLabel
var _report_submit: Button
var _reset_dialog: ConfirmationDialog
var _history_index: int = 0
var _log_text: String = ""
var _current_page: String = "response"
var _testing: bool = false
var _ui_ready: bool = false
var _loading_error: String = ""


func _ready() -> void:
	if mission.is_empty():
		_load_mission()
	_reset_state()
	_build_ui()
	_ui_ready = true
	_refresh_ui()
	_append_output("TRAINING CASE / " + str(mission.get("title", "Incident response")) + "\n" + str(mission.get("disclaimer", "Fictional local simulation.")) + "\n\nChoose an action on the left, or type help. All commands are simulated.")
	if not _loading_error.is_empty():
		_append_output(_loading_error)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()


func configure_mission(data: Dictionary) -> void:
	mission = data.duplicate(true)
	_reset_state()
	if _ui_ready:
		_root.queue_free()
		_ui_ready = false
		_step_buttons.clear()
		_plan_labels.clear()
		_pages.clear()
		_tabs.clear()
		_report_checks.clear()
		_reflection_options.clear()
		_reflection_explanations.clear()
		_current_page = "response"
		_build_ui()
		_ui_ready = true
		_terminal.visible = terminal_open
		_crosshair.visible = not terminal_open
		_refresh_ui()
		_fit_layout()


func _load_mission() -> void:
	if not FileAccess.file_exists(MISSION_PATH):
		_loading_error = "The training case could not be found. Please restart after the mission file is restored."
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSION_PATH))
	if parsed is Dictionary:
		mission = parsed
	else:
		_loading_error = "The training case could not be read. The console remains in local simulation mode."


func _reset_state() -> void:
	state = mission.get("initial_state", {}).duplicate(true)
	points = 0
	journal.clear()
	command_history.clear()
	_history_index = 0
	report_answers = {"summary": "", "finding": "", "evidence_ids": [], "follow_up": ""}
	report_preview_valid = false
	submitted_report_text = ""
	_log_text = ""


func open_terminal() -> void:
	if not _ui_ready:
		return
	terminal_open = true
	_plan_open = false
	_terminal.show()
	_crosshair.hide()
	capture_changed.emit(false)
	_refresh_ui()
	_fit_layout()
	_desktop.focus_terminal()


func close_terminal() -> void:
	if not terminal_open:
		return
	terminal_open = false
	if is_instance_valid(_reset_dialog):
		_reset_dialog.hide()
	_terminal.hide()
	_crosshair.show()
	_fit_layout()
	capture_changed.emit(true)


func toggle_terminal() -> void:
	if terminal_open:
		close_terminal()
	else:
		open_terminal()


func set_exploration_visible(visible: bool) -> void:
	_exploration_visible = visible
	if not visible:
		_plan_open = false
	if _ui_ready:
		_fit_layout()


func toggle_plan() -> void:
	if terminal_open or not _exploration_visible:
		return
	_plan_open = not _plan_open
	if _ui_ready:
		_plan.visible = _plan_open


func is_plan_open() -> bool:
	return _plan_open


func _input(event: InputEvent) -> void:
	if not terminal_open and _exploration_visible and ((InputMap.has_action("response_plan") and event.is_action_pressed("response_plan")) or (not InputMap.has_action("response_plan") and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J)):
		toggle_plan()
		get_viewport().set_input_as_handled()
		return
	if _plan_open and not terminal_open and event.is_action_pressed("ui_cancel"):
		_plan_open = false
		_plan.hide()
		get_viewport().set_input_as_handled()
		return
	if terminal_open and event.is_action_pressed("ui_cancel"):
		if _reset_dialog.visible:
			_reset_dialog.hide()
		else:
			close_terminal()
		get_viewport().set_input_as_handled()


func get_completion_count() -> int:
	var count := 0
	for raw_step in mission.get("steps", []):
		var step: Dictionary = raw_step
		if bool(state.get(str(step.get("completion_flag", "")), false)):
			count += 1
	return count


func run_command(text: String) -> String:
	var normalized := " ".join(text.strip_edges().replace("\t", " ").split(" ", false)).to_lower()
	if normalized.is_empty():
		return ""
	command_history.append(text.strip_edges())
	_history_index = command_history.size()
	var response: String = ""
	match normalized:
		"help", "?":
			response = "LOCAL TRAINING COMMANDS\nhelp — show this guide\nstatus — show case progress\nevidence — review unlocked evidence\nreport — open the incident report\nclear — clear this display\nreset — ask to restart this local case\n\nMISSION ACTIONS\n"
			for raw_step in mission.get("steps", []):
				var help_step: Dictionary = raw_step
				response += str(help_step.get("terminal", {}).get("command", "")) + "\n"
			response += "\nThese commands only select training results. They do not control a computer."
		"status":
			response = _status_text()
		"evidence":
			response = _evidence_content()
			_show_page("evidence")
		"report":
			response = "Complete recovery verification, then write and preview your incident report."
			_show_page("report")
		"clear":
			_log_text = ""
			if _ui_ready and not _testing:
				_console_output.text = ""
			return "Display cleared. The evidence journal and progress are unchanged."
		"reset":
			response = "Restart confirmation opened. Nothing changes until you confirm."
			if _ui_ready and not _testing:
				_reset_dialog.popup_centered(Vector2i(490, 220))
		_:
			var matched := false
			for raw_step in mission.get("steps", []):
				var step: Dictionary = raw_step
				if normalized == str(step.get("terminal", {}).get("command", "")).to_lower():
					matched = true
					response = _execute_step(step)
					break
			if not matched:
				response = "Unknown training action. Type help or choose a labeled action. Only this case's simulated commands are available."
	_append_output("> " + text.strip_edges() + "\n" + response)
	_refresh_ui()
	return response


func _execute_step(step: Dictionary) -> String:
	var completion_flag := str(step.get("completion_flag", ""))
	if bool(state.get(completion_flag, false)):
		return "Already completed — no additional points.\n" + "\n".join(step.get("terminal", {}).get("output_lines", []))
	for flag in step.get("requires", []):
		if not bool(state.get(str(flag), false)):
			return "ACTION LOCKED\n" + str(step.get("blocked_feedback", "Complete the preceding action first."))
	if str(step.get("interaction", {}).get("type", "")) == "form":
		var errors := _validate_report()
		if not errors.is_empty() or not report_preview_valid:
			_show_page("report")
			var explanation := "\n".join(errors)
			if not report_preview_valid:
				explanation += "\nPreview your completed report before submitting it."
			return "REPORT NEEDS REVIEW\n" + explanation.strip_edges()
		submitted_report_text = _report_preview_text()
	var effects: Dictionary = step.get("on_success", {})
	var set_state: Dictionary = effects.get("set_state", {})
	for key in set_state:
		state[str(key)] = set_state[key]
	points += int(effects.get("points", 0))
	journal.append(str(step.get("journal_entry", "")))
	if not _testing:
		mission_progress_changed.emit(get_completion_count(), mission.get("steps", []).size())
	if _ui_ready and not _testing:
		_feedback.text = str(step.get("feedback", ""))
	if bool(state.get("mission_complete", false)):
		_show_page("debrief")
	return "\n".join(step.get("terminal", {}).get("output_lines", [])) + "\n\nWHY THIS MATTERS\n" + str(step.get("feedback", ""))


func _status_text() -> String:
	var result := "CASE " + str(mission.get("entities", {}).get("case_id", "")) + "\n"
	result += "%d / %d actions complete  •  %d / %d points\n" % [get_completion_count(), mission.get("steps", []).size(), points, int(mission.get("max_points", 100))]
	if bool(state.get("host_reconnected", false)):
		result += "Workstation: reconnected after verified recovery\n"
	elif bool(state.get("host_isolated", false)):
		result += "Workstation: isolated\n"
	else:
		result += "Workstation: investigation pending\n"
	result += "Demo session: " + ("revoked" if bool(state.get("session_revoked", false)) else "not yet revoked")
	return result


func _evidence_content() -> String:
	var result := "EVIDENCE JOURNAL\nAll records are fictional. Times are UTC.\n"
	var available := 0
	for raw_evidence in mission.get("evidence", []):
		var item: Dictionary = raw_evidence
		if bool(state.get(str(item.get("unlock_when", "")), false)):
			available += 1
			result += "\n────────────────────────────────\n" + str(item.get("id", "")) + " / " + str(item.get("title", "")) + "\n"
			result += str(item.get("source", "")) + "\n\n" + "\n".join(item.get("lines", []))
			result += "\n\nWhat this supports: " + str(item.get("interpretation", "")) + "\n"
	if available == 0:
		result += "\nInspect the case to unlock the source records."
	if not journal.is_empty():
		result += "\n\nRESPONSE JOURNAL\n"
		for index in journal.size():
			result += "%d. %s\n\n" % [index + 1, journal[index]]
	return result


func _validate_report() -> Array[String]:
	var errors: Array[String] = []
	for raw_field in mission.get("report_form", {}).get("fields", []):
		var field: Dictionary = raw_field
		var field_id := str(field.get("id", ""))
		var validation: Dictionary = field.get("validation", {})
		var value: Variant = report_answers.get(field_id, "")
		var valid := true
		if validation.has("min_length"):
			var summary := str(value).strip_edges()
			valid = summary.length() >= int(validation.get("min_length", 0)) and summary.length() <= int(validation.get("max_length", 10000))
		if validation.has("equals"):
			valid = value == validation["equals"]
		if validation.has("exact_set"):
			var expected: Array = validation.get("exact_set", [])
			if not value is Array:
				valid = false
			else:
				valid = value.size() == expected.size()
				for item in expected:
					valid = valid and value.has(item)
		if bool(validation.get("required", false)) and str(value).strip_edges().is_empty():
			valid = false
		if not valid:
			errors.append(str(field.get("invalid_feedback", "Complete " + field_id + ".")))
	return errors


func _report_preview_text() -> String:
	var form: Dictionary = mission.get("report_form", {})
	var prefill: Dictionary = form.get("prefill", {})
	var result := "INCIDENT HANDOVER / " + str(prefill.get("case", "")) + "\n\n"
	result += "SUMMARY\n" + str(report_answers.get("summary", "")).strip_edges() + "\n\n"
	for pair in [["Affected asset", "affected_asset"], ["Affected account", "affected_account"], ["Preserved bundle", "preserved_bundle"], ["Integrity note", "integrity_note"], ["Actions", "actions"], ["Verification", "verification"], ["Limits", "limits"]]:
		result += str(pair[0]).to_upper() + "\n" + str(prefill.get(pair[1], "")) + "\n\n"
	for raw_field in form.get("fields", []):
		var field: Dictionary = raw_field
		var field_id := str(field.get("id", ""))
		if field_id == "summary":
			continue
		var value: Variant = report_answers.get(field_id, "")
		var chosen: Array[String] = []
		for raw_option in field.get("options", []):
			var option: Dictionary = raw_option
			var selected: bool = false
			if value is Array:
				selected = value.has(option.get("id"))
			else:
				selected = value == option.get("id")
			if selected:
				chosen.append(str(option.get("label", "")))
		result += str(field.get("label", field_id)).to_upper() + "\n" + "; ".join(chosen) + "\n\n"
	return result


func _preview_report() -> void:
	if bool(state.get("report_submitted", false)):
		if _ui_ready and not _testing:
			_report_preview.text = submitted_report_text
			_report_error.text = "Submitted handover — saved for this local case."
			_report_error.modulate = TEAL
			_report_submit.disabled = true
		return
	var errors := _validate_report()
	report_preview_valid = errors.is_empty()
	if _ui_ready and not _testing:
		_report_error.text = "Ready to submit. Review the full handover below." if report_preview_valid else "\n".join(errors)
		_report_error.modulate = TEAL if report_preview_valid else AMBER
		_report_preview.text = _report_preview_text() if report_preview_valid else "Complete the fields above, then preview your handover."
		_report_submit.disabled = not report_preview_valid or not bool(state.get("recovery_verified", false)) or bool(state.get("report_submitted", false))


func _answer_changed(field_id: String, value: Variant) -> void:
	if bool(state.get("report_submitted", false)):
		return
	report_answers[field_id] = value
	report_preview_valid = false
	if _ui_ready:
		_report_submit.disabled = true
		_report_error.text = "Preview the report after making your changes."


func _on_evidence_toggled(_pressed: bool) -> void:
	var selected: Array[String] = []
	for evidence_id in _report_checks:
		var checkbox: CheckBox = _report_checks[evidence_id]
		if checkbox.button_pressed:
			selected.append(str(evidence_id))
	_answer_changed("evidence_ids", selected)


func _on_report_submit() -> void:
	for raw_step in mission.get("steps", []):
		var step: Dictionary = raw_step
		if str(step.get("interaction", {}).get("type", "")) == "form":
			run_command(str(step.get("terminal", {}).get("command", "")))
			return


func _request_reset() -> void:
	_reset_dialog.popup_centered(Vector2i(490, 220))


func _confirm_reset() -> void:
	_reset_state()
	_report_summary.text = ""
	_report_finding.select(0)
	_report_follow_up.select(0)
	for key in _report_checks:
		var checkbox: CheckBox = _report_checks[key]
		checkbox.set_pressed_no_signal(false)
	for option in _reflection_options:
		option.select(0)
	for explanation in _reflection_explanations:
		explanation.text = ""
	_report_preview.text = "Your final handover appears here after you preview it."
	_report_error.text = "Write your summary and choose the supported answers."
	_command_input.text = ""
	_feedback.text = "Case restarted. Begin by inspecting the workstation and timeline."
	_show_page("response")
	_refresh_ui()
	_append_output("LOCAL CASE RESTARTED\nYour training progress and report were reset. No external data was changed.")
	workstation_shell.configure(self)
	_desktop.reset_session()
	mission_progress_changed.emit(0, mission.get("steps", []).size())


func _submit_command(text: String) -> void:
	_command_input.clear()
	run_command(text)
	if _current_page == "response":
		_command_input.grab_focus()


func _command_key(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or command_history.is_empty():
		return
	if event.keycode == KEY_UP:
		_history_index = maxi(0, _history_index - 1)
		_command_input.text = command_history[_history_index]
		_command_input.caret_column = _command_input.text.length()
		_command_input.accept_event()
	elif event.keycode == KEY_DOWN:
		_history_index = mini(command_history.size(), _history_index + 1)
		_command_input.text = "" if _history_index == command_history.size() else command_history[_history_index]
		_command_input.caret_column = _command_input.text.length()
		_command_input.accept_event()


func _append_output(text: String) -> void:
	if _testing:
		return
	_log_text += ("\n\n" if not _log_text.is_empty() else "") + text
	if _log_text.length() > 45000:
		_log_text = _log_text.right(40000)
	if _ui_ready and not is_instance_valid(_desktop):
		_console_output.text = _log_text


func _show_page(page_id: String) -> void:
	if _testing:
		return
	_current_page = page_id
	if not _ui_ready:
		return
	if page_id == "response":
		_desktop.focus_terminal()
		return
	if page_id == "evidence":
		_evidence_text.text = _evidence_content()
	if _pages.has(page_id):
		var titles := {"evidence":"Evidence journal", "report":"Incident handover", "debrief":"Case debrief"}
		_desktop.show_document_app(titles.get(page_id,page_id),_pages[page_id])


func _refresh_ui() -> void:
	if not _ui_ready or _testing:
		return
	var current_id := "complete"
	var found_next := false
	var current_index: int = mission.get("steps", []).size()
	var index := 0
	for raw_step in mission.get("steps", []):
		var step: Dictionary = raw_step
		var complete := bool(state.get(str(step.get("completion_flag", "")), false))
		var ready := true
		for required in step.get("requires", []):
			ready = ready and bool(state.get(str(required), false))
		var mark := "✓" if complete else ("›" if ready else "·")
		var color := TEAL if complete else (INK if ready else MUTED)
		if index < _plan_labels.size():
			_plan_labels[index].text = mark + "  %02d  " % (index + 1) + str(step.get("title", ""))
			_plan_labels[index].modulate = color
		if not complete and not found_next:
			current_id = str(step.get("id", ""))
			current_index = index + 1
			found_next = true
		if index < _step_buttons.size():
			var button := _step_buttons[index]
			button.text = mark + "  " + str(index + 1) + ". " + str(step.get("title", ""))
			button.modulate = color
			button.tooltip_text = str(step.get("feedback", "")) if complete else (str(step.get("blocked_feedback", "")) if not ready else str(step.get("action_label", "")))
		index += 1
	var objective_copy: Dictionary = {
		"inspect": ["Inspect the workstation", "Review the session timeline"],
		"preserve": ["Preserve the evidence", "Save the paused logs and snapshot"],
		"isolate": ["Isolate the workstation", "Contain the affected lab computer"],
		"revoke": ["Revoke the reused session", "End access from every source"],
		"restore": ["Restore the clean baseline", "Apply the approved training image"],
		"verify": ["Verify the recovery", "Check the baseline, then reconnect"],
		"report": ["Write the incident report", "Review evidence and hand over the case"],
		"complete": ["Recovery complete", "Your report and debrief are ready"]
	}
	var copy: Array = objective_copy.get(current_id, ["Review the training case", "Use a marked response console"])
	_hud_current.text = str(copy[0])
	_hud_subobjective.text = str(copy[1])
	_hud_index.text = "%02d / %02d" % [current_index, mission.get("steps", []).size()]
	_hud_progress.total = maxi(1, mission.get("steps", []).size())
	_hud_progress.completed = get_completion_count()
	_hud_progress.queue_redraw()
	_hud_progress_label.text = "%d / %d complete" % [get_completion_count(), mission.get("steps", []).size()]
	var status_copy := "Investigation pending"
	if bool(state.get("mission_complete", false)):
		status_copy = "Case complete"
	elif bool(state.get("recovery_verified", false)):
		status_copy = "Recovery verified"
	elif bool(state.get("restore_complete", false)):
		status_copy = "Recovery in progress"
	elif bool(state.get("session_revoked", false)):
		status_copy = "Session revoked"
	elif bool(state.get("host_isolated", false)):
		status_copy = "Workstation isolated"
	elif bool(state.get("evidence_preserved", false)):
		status_copy = "Evidence preserved"
	elif bool(state.get("triage_complete", false)):
		status_copy = "Investigation active"
	_hud_status.text = status_copy
	_hud_status.modulate = TEAL if bool(state.get("recovery_verified", false)) else AMBER
	_hud_status_dot.modulate = _hud_status.modulate
	_evidence_text.text = _evidence_content()
	_desktop.refresh_state()
	var debrief_tab: Button = _tabs["debrief"]
	debrief_tab.disabled = not bool(state.get("mission_complete", false))
	_report_submit.disabled = not report_preview_valid or not bool(state.get("recovery_verified", false)) or bool(state.get("report_submitted", false))
	var submitted := bool(state.get("report_submitted", false))
	_report_summary.editable = not submitted
	_report_finding.disabled = submitted
	_report_follow_up.disabled = submitted
	for evidence_id in _report_checks:
		var checkbox: CheckBox = _report_checks[evidence_id]
		checkbox.disabled = submitted


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "TrainingOverlay"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_build_hud()
	_build_terminal()
	_reset_dialog = ConfirmationDialog.new()
	_reset_dialog.title = "Restart this training case?"
	_reset_dialog.dialog_text = "This clears only the current local mission progress, evidence journal, and report. You can begin again immediately."
	_reset_dialog.ok_button_text = "Restart case"
	_reset_dialog.cancel_button_text = "Keep progress"
	_reset_dialog.confirmed.connect(_confirm_reset)
	_root.add_child(_reset_dialog)


func _build_hud() -> void:
	_exploration = Control.new()
	_exploration.name = "ExplorationHUD"
	_exploration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exploration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_exploration)
	var header := _panel(_exploration, Color(0.035, 0.075, 0.095, 0.57), 5)
	header.name = "Brand"
	header.position = Vector2(36, 21)
	header.size = Vector2(270, 38)
	var brand_body := Control.new()
	header.add_child(brand_body)
	var shield := ShieldMark.new()
	shield.position = Vector2(4, -2)
	shield.size = Vector2(30, 32)
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand_body.add_child(shield)
	var brand := _label("CAMPUS / INCIDENT RESPONSE", 11, INK)
	brand.position = Vector2(43, 5)
	brand_body.add_child(brand)
	var header_rule := ColorRect.new()
	header_rule.name = "HeaderRule"
	header_rule.color = Color(0.73, 0.80, 0.84, 0.4)
	header_rule.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header_rule.offset_left = 322
	header_rule.offset_right = -353
	header_rule.offset_top = 35
	header_rule.offset_bottom = 36
	header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exploration.add_child(header_rule)
	var status_area := Control.new()
	status_area.name = "CaseStatus"
	status_area.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status_area.offset_left = -333
	status_area.offset_right = -36
	status_area.offset_top = 23
	status_area.offset_bottom = 69
	status_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exploration.add_child(status_area)
	var status_backing := _hud_backing(status_area)
	status_backing.position = Vector2(-10, -7)
	status_backing.size = Vector2(317, 54)
	var case_id := _label(str(mission.get("entities", {}).get("case_id", "IR-2026-001")), 12, INK)
	case_id.position = Vector2.ZERO
	status_area.add_child(case_id)
	_hud_status_dot = _label("●", 12, INK)
	_hud_status_dot.position = Vector2(96, 0)
	status_area.add_child(_hud_status_dot)
	_hud_status = _label("Investigation pending", 13, INK)
	_hud_status.position = Vector2(115, 0)
	status_area.add_child(_hud_status)
	_hud_progress = SegmentedProgress.new()
	_hud_progress.position = Vector2(0, 27)
	_hud_progress.size = Vector2(149, 12)
	_hud_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_area.add_child(_hud_progress)
	_hud_progress_label = _label("0 / 7 complete", 12, MUTED)
	_hud_progress_label.position = Vector2(167, 24)
	status_area.add_child(_hud_progress_label)
	var objective_panel := _panel(_exploration, Color(0.025, 0.065, 0.085, 0.85), 14)
	objective_panel.name = "ObjectivePanel"
	objective_panel.position = Vector2(36, 75)
	objective_panel.size = Vector2(270, 190)
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := Control.new()
	objective_panel.add_child(card)
	_place_label(card, "ACTIVE CASE", Vector2(0, 0), 10, MUTED)
	_place_label(card, str(mission.get("title", "Training case")), Vector2(0, 19), 18, INK)
	_rule(card, Vector2(0, 47), 242)
	_place_label(card, "CURRENT OBJECTIVE", Vector2(0, 59), 10, MUTED)
	var accent := ColorRect.new()
	accent.color = TEAL
	accent.position = Vector2(0, 81)
	accent.size = Vector2(3, 34)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(accent)
	_hud_current = _place_label(card, "", Vector2(14, 78), 15, INK)
	_hud_subobjective = _place_label(card, "", Vector2(14, 102), 11, MUTED)
	_rule(card, Vector2(0, 129), 242)
	_hud_index = _place_label(card, "01 / 07", Vector2(0, 140), 12, MUTED)
	var plan_hint := HBoxContainer.new()
	plan_hint.position = Vector2(93, 139)
	plan_hint.add_theme_constant_override("separation", 8)
	card.add_child(plan_hint)
	plan_hint.add_child(_keycap("J", 19))
	plan_hint.add_child(_label("Response plan", 11, MUTED))
	var controls_backing := _hud_backing(_exploration)
	controls_backing.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls_backing.offset_left = 30
	controls_backing.offset_right = 326
	controls_backing.offset_top = -64
	controls_backing.offset_bottom = -24
	var controls := HBoxContainer.new()
	controls.name = "ControlHints"
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 38
	controls.offset_right = 460
	controls.offset_top = -56
	controls.offset_bottom = -31
	controls.add_theme_constant_override("separation", 10)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exploration.add_child(controls)
	controls.add_child(_keycap("J", 24))
	controls.add_child(_label("Response plan", 12, INK))
	var space := Control.new()
	space.custom_minimum_size.x = 10
	controls.add_child(space)
	controls.add_child(_keycap("Esc", 24))
	controls.add_child(_label("Release cursor", 12, INK))
	var simulation := _label("FICTIONAL TRAINING", 9, Color(0.9, 0.95, 1.0, 0.65))
	simulation.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	simulation.offset_left = -150
	simulation.offset_right = -36
	simulation.offset_top = -48
	simulation.offset_bottom = -32
	simulation.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_exploration.add_child(simulation)
	_build_plan()
	_crosshair = _label("+", 22, Color(1, 1, 1, 0.84))
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -10
	_crosshair.offset_top = -17
	_crosshair.offset_right = 10
	_crosshair.offset_bottom = 17
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exploration.add_child(_crosshair)


func _build_plan() -> void:
	_plan = _panel(_exploration, Color(0.025, 0.065, 0.085, 0.95), 17)
	_plan.name = "ResponsePlan"
	_plan.position = Vector2(36, 283)
	_plan.size = Vector2(330, 333)
	var column := _vbox(_plan, 13)
	column.add_child(_label("RESPONSE PLAN", 12, TEAL))
	for raw_step in mission.get("steps", []):
		var step: Dictionary = raw_step
		var step_label := _label(str(step.get("title", "")), 13, MUTED)
		column.add_child(step_label)
		_plan_labels.append(step_label)
	var note := _label("Open a marked response console to carry out the next action.", 12, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	column.add_child(_label("J  Close plan", 11, TEAL))
	_plan.hide()


func _place_label(parent: Node, text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := _label(text, font_size, color)
	label.position = at
	parent.add_child(label)
	return label


func _rule(parent: Node, at: Vector2, width: float) -> void:
	var rule := ColorRect.new()
	rule.position = at
	rule.size = Vector2(width, 1)
	rule.color = Color(0.57, 0.68, 0.73, 0.30)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)


func _keycap(text: String, height: float) -> PanelContainer:
	var panel := PanelContainer.new()
	var key_style := _style(Color(0.06, 0.1, 0.13, 0.45), 2)
	key_style.border_color = Color(0.8, 0.87, 0.91, 0.8)
	key_style.set_corner_radius_all(2)
	panel.add_theme_stylebox_override("panel", key_style)
	panel.custom_minimum_size = Vector2(maxf(height, text.length() * 7 + 10), height)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _label(text, 11, INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _hud_backing(parent: Node) -> Panel:
	var backing := Panel.new()
	var backing_style := _style(Color(0.025, 0.065, 0.085, 0.70), 0)
	backing_style.border_color = Color(0.61, 0.70, 0.75, 0.22)
	backing_style.set_corner_radius_all(4)
	backing.add_theme_stylebox_override("panel", backing_style)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(backing)
	return backing


func _build_terminal() -> void:
	workstation_shell = WorkstationShell.new()
	workstation_shell.configure(self)
	_desktop = WorkstationDesktop.new()
	_desktop.name = "ResponseTerminal"
	_root.add_child(_desktop)
	_desktop.configure(self, workstation_shell)
	_terminal = _desktop
	_desktop.exit_requested.connect(close_terminal)
	_desktop.report_requested.connect(_show_page.bind("report"))
	_desktop.journal_requested.connect(_show_page.bind("evidence"))
	_console_output = _desktop.output
	_command_input = _desktop.command_input
	var storage := Control.new()
	storage.name = "DocumentStorage"
	storage.hide()
	_terminal.add_child(storage)
	_feedback = Label.new()
	storage.add_child(_feedback)
	_build_evidence_page(storage)
	_build_report_page(storage)
	_build_debrief_page(storage)
	for page_id: String in _pages:
		var tab := Button.new()
		storage.add_child(tab)
		_tabs[page_id] = tab
		(_pages[page_id] as Control).hide()
	_terminal.hide()


func _action_pressed(command: String) -> void:
	_show_page("response")
	var result := run_command(command)
	if result.begins_with("ACTION LOCKED"):
		_feedback.text = result.replace("ACTION LOCKED\n", "")


func _build_response_page(parent: Control) -> void:
	var page := _page(parent, "response")
	page.add_child(_label("CASE TERMINAL", 13, TEAL))
	var output_panel := _panel(page, Color("#121e25"), 15)
	output_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_console_output = _rich(output_panel)
	_console_output.scroll_following = true
	_feedback = _label("Inspect the workstation to begin. Read each result before choosing your next action.", 14, AMBER)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size.y = 45
	page.add_child(_feedback)
	var input_row := HBoxContainer.new()
	page.add_child(input_row)
	input_row.add_child(_label("SIM ›", 15, TEAL))
	_command_input = LineEdit.new()
	_command_input.placeholder_text = "Type help, or choose an action on the left"
	_command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_input.max_length = 180
	_command_input.text_submitted.connect(_submit_command)
	_command_input.gui_input.connect(_command_key)
	input_row.add_child(_command_input)
	input_row.add_child(_button("Run", func() -> void: _submit_command(_command_input.text)))
	var tools := HBoxContainer.new()
	page.add_child(tools)
	tools.add_child(_button("Help", func() -> void: run_command("help")))
	tools.add_child(_button("Status", func() -> void: run_command("status")))
	tools.add_child(_button("Clear display", func() -> void: run_command("clear")))
	tools.add_child(_label("↑ ↓ Command history", 12, MUTED))


func _build_evidence_page(parent: Control) -> void:
	var page := _page(parent, "evidence")
	page.add_child(_label("PRESERVE THE STORY", 13, TEAL))
	page.add_child(_label("Source records and your response notes stay available throughout recovery.", 14, MUTED))
	var panel := _panel(page, Color("#121e25"), 15)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_evidence_text = _rich(panel)


func _build_report_page(parent: Control) -> void:
	var page := _page(parent, "report")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var column := _vbox(scroll, 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_label("A FACTUAL HANDOVER", 18, INK))
	var explanation := _label("Your asset, evidence bundle, actions, verification, and limits are filled in for you. Add your summary and supported conclusions, then preview the report.", 14, MUTED)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(explanation)
	for raw_field in mission.get("report_form", {}).get("fields", []):
		var field: Dictionary = raw_field
		var field_id := str(field.get("id", ""))
		column.add_child(_label(str(field.get("label", "")), 15, INK))
		match str(field.get("type", "")):
			"textarea":
				_report_summary = TextEdit.new()
				_report_summary.placeholder_text = str(field.get("placeholder", ""))
				_report_summary.custom_minimum_size.y = 105
				_report_summary.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
				_report_summary.text_changed.connect(func() -> void: _answer_changed("summary", _report_summary.text))
				column.add_child(_report_summary)
				var hint := _label("Hint: " + str(field.get("hint", "")), 12, MUTED)
				hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				column.add_child(hint)
			"select":
				var option := OptionButton.new()
				option.add_item("Choose an answer…")
				option.set_item_metadata(0, "")
				for raw_choice in field.get("options", []):
					var choice: Dictionary = raw_choice
					option.add_item(str(choice.get("label", "")))
					option.set_item_metadata(option.item_count - 1, str(choice.get("id", "")))
				option.item_selected.connect(_option_selected.bind(option, field_id))
				option.clip_text = true
				column.add_child(option)
				if field_id == "finding":
					_report_finding = option
				else:
					_report_follow_up = option
			"multiselect":
				for raw_choice in field.get("options", []):
					var choice: Dictionary = raw_choice
					var checkbox := CheckBox.new()
					checkbox.text = str(choice.get("label", ""))
					checkbox.add_theme_font_size_override("font_size", 14)
					checkbox.toggled.connect(_on_evidence_toggled)
					column.add_child(checkbox)
					_report_checks[str(choice.get("id", ""))] = checkbox
	_report_error = _label("Write your summary and choose the supported answers.", 14, AMBER)
	_report_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_report_error)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	buttons.add_child(_button("Preview handover", _preview_report))
	_report_submit = _button("Submit report", _on_report_submit)
	_report_submit.disabled = true
	buttons.add_child(_report_submit)
	var preview_panel := _panel(column, Color("#121e25"), 15)
	preview_panel.custom_minimum_size.y = 270
	_report_preview = _rich(preview_panel)
	_report_preview.text = "Your final handover appears here after you preview it."
	_report_preview.fit_content = true
	_report_preview.scroll_active = false


func _option_selected(index: int, option: OptionButton, field_id: String) -> void:
	_answer_changed(field_id, option.get_item_metadata(index))


func _build_debrief_page(parent: Control) -> void:
	var page := _page(parent, "debrief")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var column := _vbox(scroll, 13)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_label("CASE COMPLETE / 100 POINTS", 22, TEAL))
	var title := _label(str(mission.get("debrief", {}).get("title", "Review your decisions")), 17, INK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	for takeaway in mission.get("debrief", {}).get("takeaways", []):
		var takeaway_label := _label("• " + str(takeaway), 15, INK)
		takeaway_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(takeaway_label)
	column.add_child(_label("REFLECT / no points or penalties", 13, TEAL))
	for raw_question in mission.get("debrief", {}).get("reflection_questions", []):
		var question: Dictionary = raw_question
		var question_label := _label(str(question.get("question", "")), 15, INK)
		question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(question_label)
		var options := OptionButton.new()
		options.add_item("Choose your answer…")
		for option_text in question.get("options", []):
			options.add_item(str(option_text))
		options.clip_text = true
		column.add_child(options)
		_reflection_options.append(options)
		var explanation := _label("", 14, AMBER)
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(explanation)
		_reflection_explanations.append(explanation)
		options.item_selected.connect(_reflection_selected.bind(question, explanation))
	column.add_child(_button("Review submitted handover", _show_submitted_report))
	column.add_child(_button("Replay this training case…", _request_reset))


func _reflection_selected(index: int, question: Dictionary, label: Label) -> void:
	if index == 0:
		label.text = ""
		return
	var correct := index - 1 == int(question.get("correct_option_index", -1))
	label.text = ("Yes. " if correct else "Review this decision: ") + str(question.get("explanation", ""))
	label.modulate = TEAL if correct else AMBER


func _show_submitted_report() -> void:
	_show_page("report")
	_preview_report()


func _page(parent: Control, id: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 11)
	parent.add_child(page)
	_pages[id] = page
	return page


func _label(text: String, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _vbox(parent: Node, separation: int = 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.pressed.connect(callback)
	return button


func _rich(parent: Node) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = false
	rich.selection_enabled = true
	rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich.add_theme_color_override("default_color", INK)
	rich.add_theme_font_size_override("normal_font_size", 14)
	rich.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	parent.add_child(rich)
	return rich


func _panel(parent: Node, color: Color, padding: int = 14) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(color, padding))
	parent.add_child(panel)
	return panel


func _style(color: Color, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.42, 0.51, 0.56, 0.40)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", TEAL)
	theme.set_color("font_focus_color", "Button", TEAL)
	theme.set_stylebox("normal", "Button", _style(Color("#202f38"), 9))
	theme.set_stylebox("hover", "Button", _style(Color("#2b404a"), 9))
	theme.set_stylebox("pressed", "Button", _style(Color("#36525b"), 9))
	theme.set_stylebox("disabled", "Button", _style(Color("#192329"), 9))
	theme.set_color("font_disabled_color", "Button", Color("#6f7d85"))
	var focus := _style(Color(0, 0, 0, 0), 9)
	focus.border_color = TEAL
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("normal", "LineEdit", _style(Color("#172932"), 10))
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("caret_color", "LineEdit", TEAL)
	theme.set_stylebox("normal", "TextEdit", _style(Color("#172932"), 10))
	theme.set_stylebox("focus", "TextEdit", focus)
	theme.set_color("font_color", "TextEdit", INK)
	theme.set_color("caret_color", "TextEdit", TEAL)
	theme.set_stylebox("background", "ProgressBar", _style(Color("#32434d"), 0))
	theme.set_stylebox("fill", "ProgressBar", _style(TEAL, 0))
	return theme


func _fit_layout() -> void:
	if not _ui_ready:
		return
	var view_size := get_viewport().get_visible_rect().size
	_exploration.visible = _exploration_visible and not terminal_open
	_crosshair.visible = _exploration.visible
	_plan.visible = _plan_open and _exploration.visible
	var rule := _exploration.get_node_or_null("HeaderRule") as Control
	if is_instance_valid(rule):
		rule.visible = view_size.x >= 1000


func run_self_test() -> Dictionary:
	# Preserve the player's session while exercising the exact command dispatcher.
	var saved_state := state.duplicate(true)
	var saved_points := points
	var saved_journal := journal.duplicate()
	var saved_history := command_history.duplicate()
	var saved_answers := report_answers.duplicate(true)
	var saved_preview := report_preview_valid
	var saved_submitted := submitted_report_text
	var saved_log := _log_text
	var saved_history_index := _history_index
	var failures: Array[String] = []
	_testing = true
	_reset_state()
	var steps: Array = mission.get("steps", [])
	if steps.size() != 7:
		failures.append("Expected seven mission steps.")
	else:
		var last_step: Dictionary = steps.back()
		var original := state.duplicate(true)
		var invalid_result := run_command("not-a-training-command")
		if state != original or not invalid_result.begins_with("Unknown"):
			failures.append("Unknown command changed state.")
		var locked_result := run_command(str(last_step.get("terminal", {}).get("command", "")))
		if state != original or not locked_result.begins_with("ACTION LOCKED"):
			failures.append("A locked action advanced the case.")
		for index in range(6):
			var step: Dictionary = steps[index]
			run_command(str(step.get("terminal", {}).get("command", "")))
			if not bool(state.get(str(step.get("completion_flag", "")), false)):
				failures.append("Step did not complete: " + str(step.get("id", "")))
		var report_result := run_command(str(last_step.get("terminal", {}).get("command", "")))
		if get_completion_count() != 6 or not report_result.begins_with("REPORT NEEDS REVIEW"):
			failures.append("Report submitted without validated answers.")
		report_answers = {
			"summary": "The demo workstation showed suspicious session reuse. I preserved evidence, contained the host and session, and verified a clean restore.",
			"finding": "session_reuse",
			"evidence_ids": ["EV-VERIFY", "EV-ARCHIVE"],
			"follow_up": "monitor_review"
		}
		_preview_report()
		run_command(str(last_step.get("terminal", {}).get("command", "")))
		if get_completion_count() != 7 or points != 100 or not bool(state.get("mission_complete", false)):
			failures.append("Seven-step completion or score failed.")
		if not submitted_report_text.contains("INCIDENT HANDOVER") or not submitted_report_text.contains("EV-ARCHIVE"):
			failures.append("Submitted handover is missing or incomplete.")
		if bool(state.get("host_isolated", true)) or not bool(state.get("host_reconnected", false)):
			failures.append("Recovery connection state is inconsistent.")
		var final_points := points
		var first: Dictionary = steps.front()
		run_command(str(first.get("terminal", {}).get("command", "")))
		if points != final_points or journal.size() != 7:
			failures.append("Repeated completion awarded points or duplicated the journal.")
	var result := {"passed": failures.is_empty(), "checks": 8, "steps": get_completion_count(), "points": points, "failures": failures}
	state = saved_state
	points = saved_points
	journal.assign(saved_journal)
	command_history.assign(saved_history)
	report_answers = saved_answers
	report_preview_valid = saved_preview
	submitted_report_text = saved_submitted
	_log_text = saved_log
	_history_index = saved_history_index
	_testing = false
	_refresh_ui()
	return result
