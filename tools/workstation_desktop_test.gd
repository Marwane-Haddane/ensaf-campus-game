extends SceneTree
## Native desktop integration checks; standalone TrainingUI, no campus loading.

const HOME_DIR := "/home/analyst"
var training
var desktop
var checks: int = 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var capture_events: Array[bool] = []
var minimized_events: int = 0
var closed_events: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		print("WORKSTATION_DESKTOP_FAIL " + description)


func _settle() -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)


func _type(command: String) -> void:
	desktop.command_input.text = command
	desktop.command_input.text_submitted.emit(command)


func _key(code: Key, control: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = control
	desktop.command_input.gui_input.emit(event)


func _plain_output() -> String:
	return desktop.output.get_parsed_text()


func _button(parent: Node, tooltip: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.tooltip_text == tooltip:
			return child
		var nested := _button(child, tooltip)
		if nested != null:
			return nested
	return null


func _text_button(parent: Node, caption: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == caption:
			return child
		var nested := _text_button(child, caption)
		if nested != null:
			return nested
	return null


func _select_file(name: String) -> bool:
	var tree: Tree = desktop.file_list
	var item := tree.get_root().get_first_child()
	while item != null:
		if item.get_text(0) == name:
			item.select(0)
			tree.item_selected.emit()
			return true
		item = item.get_next()
	return false


func _choose(option: OptionButton, value: String) -> void:
	for index in option.item_count:
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			option.item_selected.emit(index)
			return


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var ui_script: Script = load("res://scripts/training_ui.gd")
	training = ui_script.new()
	root.add_child(training)
	training.capture_changed.connect(func(captured: bool) -> void: capture_events.append(captured))
	await _settle()
	desktop = training.get("_desktop")
	_check(desktop != null and training.workstation_shell != null, "TrainingUI instantiates the native desktop and virtual shell")
	training.open_terminal()
	await _settle()
	_check(training.terminal_open and desktop.visible and capture_events.back() == false, "The same open API called by E releases mouse capture")
	_check(root.gui_get_focus_owner() == desktop.command_input, "Opening desktop focuses its native LineEdit")
	_check(desktop.terminal_window.visible and not desktop.file_window.visible, "Boot starts with the terminal open and file manager closed")
	_check(_plain_output().contains("cat ~/Help/START_HERE.md") and not _plain_output().contains("WHY THIS MATTERS"), "Boot output is a concise workstation welcome")
	var lower_prompt: Label
	for child in desktop.command_input.get_parent().get_children():
		if child is Label and child.text == "└─$":
			lower_prompt = child
	_check(desktop.prompt.text.contains("analyst@campus-lab") and lower_prompt != null, "Prompt has a native header row and separate lower-dollar input row")
	_check(desktop.command_input.size_flags_vertical == Control.SIZE_SHRINK_END, "Command entry aligns with the lower-dollar prompt baseline")
	_check(desktop.output.fit_content and not desktop.output.scroll_active and desktop.prompt.get_global_rect().position.y - desktop.output.get_global_rect().end.y <= 16.0, "Prompt follows welcome output without a large blank terminal gap")
	await _capture_pair("boot")
	_test_terminal()
	desktop.terminal_window.configure("analyst@campus-lab: ~/Evidence", Rect2(177, 70, 1045, 570))
	await _capture_pair("commands")
	await _test_windows()
	await _test_files()
	await _capture_pair("help")
	await _test_report()
	_test_exit()
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "captures": captures, "mission_steps": training.get_completion_count(), "points": training.points}
	var report := FileAccess.open("res://tools/workstation_desktop_test.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(result, "\t"))
	print("WORKSTATION_DESKTOP_TEST " + JSON.stringify(result))
	training.queue_free()
	quit(0 if failures.is_empty() else 1)


func _test_terminal() -> void:
	_type("ls")
	_check(_plain_output().contains("Evidence") and desktop.command_input.text.is_empty(), "Native text submission lists virtual folders and clears the LineEdit")
	_type("cd Evidence")
	_check(training.workstation_shell.cwd == HOME_DIR + "/Evidence" and desktop.prompt.text.contains("~/Evidence"), "cd updates virtual working directory and visible prompt")
	_type("cat session.log")
	_check(_plain_output().contains(str(training.mission.entities.session_id)) and _plain_output().contains(str(training.mission.entities.unexpected_client_ip)), "cat displays actual fictional authentication facts")
	desktop.command_input.text = "unfinished draft"
	_key(KEY_UP)
	_check(desktop.command_input.text == "cat session.log", "Up recalls the most recent typed command")
	_key(KEY_UP)
	_check(desktop.command_input.text == "cd Evidence", "Repeated Up moves backward through command history")
	_key(KEY_DOWN)
	_key(KEY_DOWN)
	_check(desktop.command_input.text == "unfinished draft", "Down restores the learner's unsubmitted draft")
	desktop.command_input.text = "cat ses"
	_key(KEY_TAB)
	_check(desktop.command_input.text == "cat session.log", "Tab completes a filename in the current virtual folder")
	desktop.command_input.text = "ir pre"
	_key(KEY_TAB)
	_check(desktop.command_input.text == "ir preserve", "Tab completes an incident action")
	var history_size: int = desktop.history.size()
	_key(KEY_L, true)
	_check(_plain_output().is_empty() and desktop.history.size() == history_size, "Ctrl+L clears output while preserving history")
	_type("pwd")
	_type("ls")
	_type("cat session.log")
	_check(training.get_completion_count() == 0, "Typing filesystem commands does not advance the incident")


func _test_windows() -> void:
	var window: Panel = desktop.terminal_window
	window.connect("minimized", func() -> void: minimized_events += 1)
	window.connect("closed", func() -> void: closed_events += 1)
	var original := Rect2(window.position, window.size)
	var maximize := _button(window.title_bar, "Maximize")
	_check(maximize != null, "Native title bar exposes a maximize button")
	if maximize != null:
		maximize.pressed.emit()
		_check(window.maximized and window.position == Vector2(9, 45) and window.size == Vector2(1262, 628), "Maximize fills the desktop work area without covering system bars")
		maximize.pressed.emit()
		_check(not window.maximized and Rect2(window.position, window.size) == original, "Second maximize press restores exact prior geometry")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	window.title_bar.gui_input.emit(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(24, 17) * window.get_global_transform().get_scale()
	window.call("_input", motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	window.call("_input", release)
	_check(window.position.is_equal_approx(original.position + Vector2(24, 17)), "Native title-bar drag moves in desktop coordinates")
	window.configure("analyst@campus-lab: ~/Evidence", original)
	var grip: Control
	for child in window.get_children():
		if child is Control and child.mouse_default_cursor_shape == Control.CURSOR_FDIAGSIZE:
			grip = child
	if grip != null:
		grip.gui_input.emit(press)
		motion.relative = Vector2(30, 20) * window.get_global_transform().get_scale()
		window.call("_input", motion)
		window.call("_input", release)
	_check(grip != null and window.size.is_equal_approx(original.size + Vector2(30, 20)), "Native resize grip changes window dimensions")
	window.configure("analyst@campus-lab: ~/Evidence", original)
	var minimize := _button(window.title_bar, "Minimize")
	if minimize != null:
		minimize.pressed.emit()
	await _settle()
	var task: Button = desktop.get("_task_terminal")
	_check(minimize != null and minimized_events == 1 and not window.visible, "Minimize hides the terminal and emits its native signal")
	_check(task.visible, "Minimized terminal retains a visible restore task button")
	task.pressed.emit()
	_check(window.visible and root.gui_get_focus_owner() == desktop.command_input, "Terminal task button restores and focuses the app")
	var close := _button(window.title_bar, "Close")
	if close != null:
		close.pressed.emit()
	_check(close != null and closed_events == 1 and not window.visible, "Close hides the terminal and emits its native signal")
	desktop.focus_terminal()
	_check(window.visible, "Terminal launcher reopens a closed terminal")
	desktop.call("_switch_workspace", 2)
	_check(not window.visible, "Switching workspace hides the previous workspace's windows")
	desktop.call("_switch_workspace", 1)
	_check(window.visible, "Returning to a workspace restores its windows")


func _test_files() -> void:
	desktop.open_folder(HOME_DIR + "/Help")
	await _settle()
	_check(desktop.file_window.visible and desktop.file_path == HOME_DIR + "/Help", "Help opens in the native file manager")
	_check(desktop.selected_file.ends_with("/START_HERE.md") and desktop.preview.get_parsed_text().contains("Incident response field guide"), "Help selects and previews START_HERE automatically")
	_check(desktop.file_list.get_root().get_first_child().get_text(0) == "START_HERE.md", "START_HERE is pinned as the first visible guide row")
	_check(desktop.file_list.get_root().get_child_count() == 8, "Help lists the seven step guides plus START_HERE")
	_check(desktop.file_window.position.x + desktop.file_window.size.x < desktop.terminal_window.position.x, "Opening files arranges file manager and terminal side by side")
	_check(_select_file("02-preserve-evidence.md") and desktop.preview.get_parsed_text().contains("Preserve the evidence"), "Native Tree selection previews the preservation guide")
	_check(desktop.preview.text.contains("[url=ir preserve]"), "Guide preview exposes its action as a clickable command")
	desktop.preview.meta_clicked.emit("ir preserve")
	_check(training.get_completion_count() == 0 and _plain_output().contains("ACTION LOCKED"), "Guide command link respects incident prerequisites")
	_check(_select_file("01-inspect.md"), "Inspection guide is selectable by filename")
	desktop.clear_terminal()
	desktop.preview.meta_clicked.emit("ir inspect")
	_check(training.get_completion_count() == 1 and _plain_output().contains(str(training.mission.entities.workstation.hostname)), "Inspection guide click runs the actual mission action")
	_select_file("02-preserve-evidence.md")
	desktop.path_input.text = HOME_DIR + "/Evidence"
	desktop.path_input.text_submitted.emit(desktop.path_input.text)
	_check(desktop.file_path == HOME_DIR + "/Evidence", "Typing an address navigates the file manager")
	desktop.call("_folder_back")
	_check(desktop.file_path == HOME_DIR + "/Help", "Back returns to the previous folder")
	desktop.call("_folder_forward")
	_check(desktop.file_path == HOME_DIR + "/Evidence", "Forward restores folder history")
	desktop.open_folder(HOME_DIR)
	_check(_select_file("Evidence"), "Home lists the Evidence folder")
	desktop.file_list.item_activated.emit()
	_check(desktop.file_path == HOME_DIR + "/Evidence", "Activating a native folder row opens it")
	var file_minimize := _button(desktop.file_window.title_bar, "Minimize")
	if file_minimize != null:
		file_minimize.pressed.emit()
	await _settle()
	var files_task: Button = desktop.get("_task_files")
	_check(not desktop.file_window.visible and files_task.visible, "Minimized file manager retains a visible restore task")
	files_task.pressed.emit()
	_check(desktop.file_window.visible, "File manager task button restores its app")
	desktop.open_folder(HOME_DIR + "/Help")
	_select_file("START_HERE.md")
	desktop.focus_terminal()
	await _settle()


func _test_report() -> void:
	for action: String in ["preserve", "isolate", "revoke", "restore", "verify"]:
		_type("ir " + action)
	_check(training.get_completion_count() == 6, "Typed desktop actions progress the first six incident steps")
	_type("ir report")
	await _settle()
	var apps: Dictionary = desktop.get("_apps")
	_check(apps.has("Incident handover"), "ir report opens a native document window")
	var report_window: Panel = apps.get("Incident handover")
	var report_page: Control = training.get("_pages")["report"]
	_check(report_window != null and report_window.visible and report_page.get_parent() == report_window.content and report_page.visible, "Actual incident form is reparented into its native window")
	_check(report_window.content.get_theme_constant("margin_left") >= 16 and report_window.content.get_theme_constant("margin_right") >= 16 and report_window.content.get_theme_constant("margin_top") >= 10, "Native document form has readable inner spacing")
	var summary: TextEdit = training.get("_report_summary")
	summary.text = "The fictional workstation showed suspicious reuse of its demo session. I preserved the logs, contained endpoint and identity access, and verified the approved recovery baseline."
	summary.text_changed.emit()
	_choose(training.get("_report_finding"), "session_reuse")
	var report_checks: Dictionary = training.get("_report_checks")
	for id: String in ["EV-ARCHIVE", "EV-VERIFY"]:
		var checkbox: CheckBox = report_checks[id]
		checkbox.button_pressed = true
	_choose(training.get("_report_follow_up"), "monitor_review")
	var preview_button := _text_button(report_page, "Preview handover")
	_check(preview_button != null, "Native report form exposes Preview handover")
	if preview_button != null:
		preview_button.pressed.emit()
	_check(training.report_preview_valid and not training.get("_report_submit").disabled, "Native controls produce a validated report and enable submission")
	_check(training.get("_report_preview").get_parsed_text().contains("INCIDENT HANDOVER"), "Report preview renders the actual handover")
	var report_minimize := _button(report_window.title_bar, "Minimize")
	if report_minimize != null:
		report_minimize.pressed.emit()
	await _settle()
	var app_tasks: Dictionary = desktop.get("_app_tasks")
	_check(not report_window.visible and app_tasks.has("Incident handover") and app_tasks["Incident handover"].visible, "Minimized report retains a native document task button")
	if app_tasks.has("Incident handover"):
		app_tasks["Incident handover"].pressed.emit()
	_check(report_window.visible and report_page.visible, "Document task restores the actual report form")
	await _capture_pair("report")
	training.get("_report_submit").pressed.emit()
	await _settle()
	_check(training.get_completion_count() == 7 and training.points == 100 and bool(training.state.mission_complete), "Native report submission completes the mission for 100 points")
	_check(apps.has("Case debrief") and apps["Case debrief"].visible, "Successful report opens the native debrief window")
	desktop.open_folder(HOME_DIR + "/Reports")
	_check(_select_file("incident-report.md") and desktop.preview.get_parsed_text().contains(str(training.mission.entities.workstation.hostname)), "Reports folder previews the submitted factual handover")
	var prior_count: int = apps.size()
	desktop.file_list.item_activated.emit()
	_check(apps.size() == prior_count and apps["Incident handover"].visible, "Activating the report file reuses its native window")
	_check(not summary.editable, "Submitted report summary is locked against accidental edits")


func _test_exit() -> void:
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	training.call("_input", escape)
	_check(not training.terminal_open and not desktop.visible and capture_events.back(), "Escape closes the workstation and requests mouse recapture")
	training.open_terminal()
	var leave := _text_button(desktop, "Esc   Return to campus")
	_check(leave != null, "Desktop exposes a native Return to campus control")
	if leave != null:
		leave.pressed.emit()
	_check(not training.terminal_open and capture_events.back(), "Return to campus control uses the same close/capture contract")


func _capture_pair(state_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(1672, 941)]:
		root.size = extent
		await _settle()
		var image := root.get_texture().get_image()
		var filename := "res://tools/workstation_desktop_" + state_name + "_%dx%d.png" % [extent.x, extent.y]
		image.save_png(filename)
		captures.append({"state": state_name, "requested": str(extent), "actual": str(image.get_size()), "path": filename})
		_check(absi(image.get_width() - extent.x) <= 1 and absi(image.get_height() - extent.y) <= 1, "Canvas capture tracks requested size within one-pixel aspect rounding: " + str(extent) + " / " + state_name)
	root.size = Vector2i(1280, 720)
	await _settle()
