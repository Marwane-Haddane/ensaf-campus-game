extends SceneTree
const Registry = preload("res://scripts/launcher/mode_registry.gd")
const Services = preload("res://scripts/launcher/mode_services.gd")
var app
var report := {"passed":false,"checks":0,"failures":[]}
func _init() -> void: call_deferred("run_test")
func check(value: bool,label: String) -> void:
	report.checks += 1
	if not value:
		report.failures.append(label)
		print("MULTI_MODE_FAIL ",label)
func until(condition: Callable,timeout: int = 15000) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-started<timeout: await process_frame
	return bool(condition.call())
func frames(count: int = 4) -> void:
	for index: int in range(count): await process_frame
func intent(action: String,payload: Dictionary = {}) -> void:
	app._on_view_intent(StringName(action),payload)
func launch(mode: String,mission: String) -> bool:
	intent("start_mission",{"mode_id":mode,"mission_id":mission})
	await until(func():return app.state.value in ["READY","ERROR"])
	check(app.state.value=="READY","Registered fixture reaches Ready: "+mode)
	return app.state.value=="READY"

func run_test() -> void:
	app = load("res://scenes/launcher/boot.tscn").instantiate()
	app.registration_path = "res://tools/launcher/fixtures/modes.json"
	app.test_preferences_path = "user://ensagames/tests/multi-mode-platform.cfg"
	app.test_save_path = "user://ensagames/tests/multi-mode-platform.json"
	for path: String in [app.test_save_path,app.test_save_path.get_basename()+"-zombie_rpg.json",app.test_save_path.get_basename()+"-fixture_other.json",app.test_save_path.get_basename()+"-last-session.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	root.add_child(app)
	check(await until(func():return app.initialized),"Shared launcher initializes")
	check(app.loader.retained_resources.is_empty(),"Metadata and save services do not request a world at boot")
	check(not ResourceLoader.has_cached("res://tools/launcher/fixtures/session.tscn"),"Other-mode scenes stay out of boot cache")
	check(Registry.default_mission("zombie_rpg",app.registration_path)=="ZB-FIXTURE-001","Default mission belongs to the chosen mode")
	check(not Registry.can_launch("zombie_rpg","IR-2026-001",app.registration_path),"Cross-mode mission IDs are rejected")
	var legacy := Registry.mission_for("fixture_other","OTHER-001",app.registration_path)
	check(legacy.controls is Array and legacy.controls.is_empty() and not legacy.get("controls_text","").is_empty(),"Legacy prose controls cannot crash the native briefing grid")
	# A real valid cyber checkpoint remains byte-for-byte separate throughout.
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://design/incident.json"))
	var cyber := {"version":1,"mode_id":"incident_response","mission_id":"IR-2026-001","player":{"position":[-27,1.25,-85],"yaw":0.0,"pitch":0.0},"training":{"state":authored.initial_state,"points":0,"journal":[],"command_history":[],"report_answers":{},"report_preview_valid":false,"submitted_report_text":""}}
	check(app.saves.write_save(cyber),"Independent cyber checkpoint is valid")
	var cyber_bytes: String = FileAccess.get_file_as_string(app.test_save_path)
	app._refresh_continue()
	intent("show_modes")
	await frames()
	var cards: HBoxContainer = app.view._pages.modes._cards_container
	check(cards.get_child_count()==3,"Native mode page displays the registered modes")
	(cards.get_child(1) as Button).pressed.emit()
	check(app.page=="briefing" and app.selected_mode=="zombie_rpg" and app.selected_mission=="ZB-FIXTURE-001","Actual mode-card click opens its own mission, not the cyber mission")
	check(app.view._pages.briefing._mode_label.text=="Survival lifecycle fixture","Briefing branding follows the selected mode")
	check(app._model().mission.controls==[{"action":"Fixture action","binding":"F"}],"Briefing uses mode-specific controls")
	if not await launch("zombie_rpg","ZB-FIXTURE-001"):
		finish()
		return
	var ticks: int = app.game.ticks
	await frames(8)
	check(app.game.ticks==ticks,"Inherited AI processing is frozen behind Ready")
	check(not app.game.hud.visible and not app.game.input_enabled,"Ready hides the independent mode HUD and input")
	check(app.saves.path.ends_with("-zombie_rpg.json") and app.saves.path!=app.test_save_path,"Each mode has its own isolated checkpoint path")
	check(not FileAccess.file_exists(app.saves.path),"Preparing a scene does not create a playable checkpoint")
	intent("enter_game",{"request_id":app.current_request})
	await frames(8)
	check(app.game.input_enabled and app.game.ticks>ticks,"Enter enables the selected world and its actors")
	app.game.score = 37
	app.game.progress_changed.emit()
	app._save_checkpoint()
	check(int(app.saves.read_save().get("score",-1))==37,"Active mode checkpoint is captured through its own service")
	paused = true
	ticks = app.game.ticks
	app.game.launcher_settings_requested.emit()
	await frames(6)
	check(app.page=="settings" and app.view.visible,"Shared settings open while the independent mode pauses the tree")
	check(app.game.ticks==ticks and not app.game.input_enabled,"Settings do not resume AI or player input")
	var measured: int = app._last_frame_usec
	await frames()
	check(app._last_frame_usec>measured,"Shared launcher timers continue during a global mode pause")
	intent("back")
	check(paused and not app.view.visible,"Leaving settings preserves the existing paused session")
	app._return_home()
	await frames()
	check(not paused and app.page=="home" and not is_instance_valid(app.game),"Return clears global pause and releases the world")
	check(app.continue_data.mode_id=="zombie_rpg" and app.continue_data.available,"Continue identifies the correct mode")
	check(app.continue_data.summary=="Fixture checkpoint 37","Dictionary summaries become readable launcher text")
	check(FileAccess.get_file_as_string(app.test_save_path)==cyber_bytes,"Survival save/exit leaves the cyber checkpoint unchanged")
	check(app.case_summary.completed==0,"Survival progress never becomes cyber case progress")
	intent("continue_game")
	await until(func():return app.state.value in ["READY","ERROR"])
	check(app.state.value=="READY" and app.game.score==37,"Continue restores the matching mode checkpoint")
	if app.state.value=="READY":
		ticks = app.game.ticks
		await frames(6)
		check(app.game.ticks==ticks and not app.game.input_enabled,"Restored state stays frozen until Enter")
		intent("enter_game",{"request_id":app.current_request})
	app._return_home()
	await frames()
	if await launch("fixture_other","OTHER-001"):
		intent("enter_game",{"request_id":app.current_request})
		app.game.score = 84
		app._return_home()
		await frames()
		check(app.continue_data.mode_id=="fixture_other" and app.continue_data.summary=="Fixture checkpoint 84","A second mode owns its own latest checkpoint")
		var survival_store: RefCounted = app.mode_services.save_for("zombie_rpg")
		check(int(survival_store.read_save().get("score",-1))==37,"Switching modes preserves the previous survival checkpoint")
	check(FileAccess.get_file_as_string(app.test_save_path)==cyber_bytes,"Repeated mode changes still preserve cyber data")
	intent("show_briefing",{"mode_id":"incident_response"})
	check(app.selected_mission=="IR-2026-001","Cybersecurity keeps its original default briefing")
	var preferences_path: String = app.test_preferences_path
	var save_path: String = app.test_save_path
	app.queue_free()
	await frames()
	app = load("res://scenes/launcher/boot.tscn").instantiate()
	app.registration_path = "res://tools/launcher/fixtures/modes.json"
	app.test_preferences_path = preferences_path
	app.test_save_path = save_path
	root.add_child(app)
	check(await until(func():return app.initialized),"A fresh launcher instance initializes")
	check(app.continue_data.mode_id=="fixture_other" and app.continue_data.summary=="Fixture checkpoint 84","Recent-mode Continue survives launcher restart")
	check(app.loader.retained_resources.is_empty(),"Restoring recent-mode metadata does not load its world")
	finish()

func finish() -> void:
	paused = false
	report.passed = report.failures.is_empty()
	FileAccess.open("res://tools/launcher/multi-mode-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MULTI_MODE_RESULT ",JSON.stringify(report))
	if is_instance_valid(app): app.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
