extends SceneTree

class TrainingFixture extends Node:
	signal mission_progress_changed(completed: int, total: int)
	var mission: Dictionary = {}
	var state: Dictionary = {}

const DESTINATIONS: Array[String] = ["Campus plaza", "Reception / response desk", "Auditorium rear aisle", "Glazed building entrance", "Security training area", "Auditorium teaching desk"]
var checks: int = 0
var failures: Array[String] = []
var pause_ui: Control
var resumes: int = 0
var guides: int = 0
var quits: int = 0
var selected_destination: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var captured_scene := "res://tools/visual-polish/plaza-preview.png"
	if FileAccess.file_exists(captured_scene) and DisplayServer.get_name() != "headless":
		var captured_image := Image.new()
		captured_image.load_png_from_buffer(FileAccess.get_file_as_bytes(captured_scene))
		background.texture = ImageTexture.create_from_image(captured_image)
	root.add_child(background)
	var fixture := TrainingFixture.new()
	fixture.mission = JSON.parse_string(FileAccess.get_file_as_string("res://design/incident.json"))
	fixture.state = fixture.mission.get("initial_state", {}).duplicate(true)
	root.add_child(fixture)
	var ui_script: Script = load("res://scripts/pause_menu.gd")
	pause_ui = ui_script.new()
	root.add_child(pause_ui)
	pause_ui.connect("resume_requested", func() -> void: resumes += 1)
	pause_ui.connect("destinations_requested", func() -> void: guides += 1)
	pause_ui.connect("destination_requested", func(destination: String) -> void: selected_destination = destination)
	pause_ui.connect("quit_requested", func() -> void: quits += 1)
	pause_ui.call("configure", fixture)
	await process_frame
	_check(not pause_ui.call("is_menu_visible"), "Starts hidden")
	pause_ui.call("show_pause", true)
	var heading: Label = pause_ui.get("_heading")
	var session: Label = pause_ui.get("_session_label")
	var buttons: Array = pause_ui.get("_nav_buttons")
	_check(heading.text == "Campus" and not session.text.contains("PAUSED"), "Initial loading screen does not claim session is paused")
	_check(buttons[0].disabled and buttons[1].disabled and not buttons[2].disabled, "Loading disables exploration and destinations but permits quit")
	pause_ui.call("set_loading", "Preparing campus fixtures…")
	var loading: Label = pause_ui.get("_loading_label")
	_check(loading.visible and loading.text.contains("fixtures"), "Loading feedback is visible")
	pause_ui.call("set_ready", true)
	await process_frame
	buttons = pause_ui.get("_nav_buttons")
	_check(heading.text == "Ready" and buttons[0].text == "Start exploration" and not buttons[0].disabled, "Ready state enables Start exploration")
	_check(not loading.visible, "Ready state removes stale loading text")
	await _capture("initial")
	buttons[0].emit_signal("pressed")
	_check(resumes == 1, "Start emits resume_requested")
	pause_ui.call("hide_menu")
	_check(not pause_ui.visible, "hide_menu uses native visibility")
	pause_ui.call("show_pause", false)
	await process_frame
	buttons = pause_ui.get("_nav_buttons")
	_check(heading.text == "Paused" and buttons.size() == 3 and buttons[0].text == "Resume exploration", "Pause screen has exactly three expected actions")
	_check(root.gui_get_focus_owner() == buttons[0], "Primary action receives native keyboard focus")
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	down.pressed = false
	Input.parse_input_event(down)
	_check(root.gui_get_focus_owner() == buttons[1], "Native Down moves focus to Campus destinations")
	buttons[1].emit_signal("pressed")
	buttons[2].emit_signal("pressed")
	_check(guides == 1 and quits == 1, "Guide and quit signals are emitted")
	buttons[0].grab_focus()
	await _capture("paused")
	pause_ui.call("show_destinations", DESTINATIONS)
	await process_frame
	buttons = pause_ui.get("_nav_buttons")
	_check(buttons.size() == 8 and buttons[0].text == DESTINATIONS[0] and buttons[5].text == DESTINATIONS[5], "Guide lists all six actual destinations, back, and resume")
	buttons[3].emit_signal("pressed")
	_check(selected_destination == DESTINATIONS[3], "Destination signal preserves exact name")
	await _capture("destinations")
	buttons[6].emit_signal("pressed")
	_check(heading.text == "Paused", "Back returns to pause screen")
	fixture.state["triage_complete"] = true
	fixture.emit_signal("mission_progress_changed", 1, 7)
	var case_title: Label = pause_ui.get("_case_title")
	var objective: Label = pause_ui.get("_case_objective")
	_check(case_title.text == fixture.mission.title and objective.text == "Save the evidence bundle", "Case summary follows actual mission progress")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures}
	var report := FileAccess.open("res://tools/pause_menu_test.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(result, "\t"))
	print("PAUSE_MENU_TEST " + JSON.stringify(result))
	pause_ui.queue_free()
	fixture.queue_free()
	background.queue_free()
	quit(0 if failures.is_empty() else 1)


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/pause_menu_" + name + ".png")
