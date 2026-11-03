extends SceneTree
## Focused checks and actual-renderer captures for the exploration HUD.

var ui: CanvasLayer
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var ui_script: Script = load("res://scripts/training_ui.gd")
	ui = ui_script.new()
	root.add_child(ui)
	await process_frame
	var result: Dictionary = ui.call("run_self_test")
	_check(bool(result.get("passed", false)), "Existing seven-step state self-test passes")
	var exploration: Control = ui.get("_exploration")
	_check(exploration.visible, "Exploration HUD starts visible")
	var objective := exploration.get_node("ObjectivePanel") as Control
	_check(objective.size.x <= 271 and objective.size.y <= 191, "Active-case card stays compact")
	_check(not bool(ui.call("is_plan_open")), "Full response plan is closed by default")
	await _capture("exploration")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_J
	ui.call("_input", key)
	_check(bool(ui.call("is_plan_open")), "J opens the response plan")
	await _capture("plan")
	ui.call("_input", key)
	_check(not bool(ui.call("is_plan_open")), "J closes the response plan")
	ui.call("run_command", "sim inspect lab-ws-07")
	var current: Label = ui.get("_hud_current")
	_check(current.text == "Preserve the evidence", "Current objective tracks mission progress")
	await _capture("after-triage")
	ui.call("set_exploration_visible", false)
	_check(not exploration.visible, "Parent can hide exploration HUD for menus")
	ui.call("set_exploration_visible", true)
	ui.call("open_terminal")
	_check(not exploration.visible, "Terminal automatically hides exploration HUD")
	await _capture("terminal")
	ui.call("run_command", "evidence")
	await _capture("evidence")
	ui.call("run_command", "report")
	await _capture("report")
	ui.call("close_terminal")
	_check(exploration.visible, "Closing terminal restores exploration HUD")
	ui.call("set_exploration_visible", false)
	ui.call("open_terminal")
	ui.call("close_terminal")
	_check(not exploration.visible, "Menu visibility survives terminal close")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "mission": result}
	var file := FileAccess.open("res://tools/polish_ui_test.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("POLISH_UI_TEST " + JSON.stringify(report))
	ui.queue_free()
	quit(0 if failures.is_empty() else 1)


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://tools/polish_ui_" + name + ".png")
