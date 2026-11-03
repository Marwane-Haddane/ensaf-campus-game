extends SceneTree
var app
var report := {"passed":false,"checks":0,"failures":[],"captures":[],"metrics":{}}
var native := false
func _init() -> void: call_deferred("run_test")
func check(value: bool,message: String,details: Variant = null) -> void:
	report.checks += 1
	if not value:
		report.failures.append({"check":message,"details":str(details)})
		print("LAUNCHER_TEST_FAIL ",message," ",details)
func until(condition: Callable, timeout: int = 120000) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-started<timeout: await process_frame
	return bool(condition.call())
func intent(action: String,payload: Dictionary = {}) -> void:
	app._on_view_intent(StringName(action),payload)
func run_test() -> void:
	native = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280,720)
	app = load("res://scenes/launcher/boot.tscn").instantiate()
	app.test_preferences_path = "user://ensagames/tests/launcher-integration.cfg"
	app.test_save_path = "user://ensagames/tests/launcher-integration.json"
	for path: String in [app.test_preferences_path,app.test_save_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	root.add_child(app)
	check(await until(func():return app.initialized,15000),"Launcher initializes without a world")
	if not app.initialized:
		finish()
		return
	check(app.state.value == "MAIN_MENU" and app.page == "home","Interactive main menu is the first destination")
	check(app.loader.retained_resources.is_empty() and not is_instance_valid(app.game),"Menu did not request campus/props or create a world")
	check(not ResourceLoader.has_cached("res://assets/campus.glb"),"Campus is absent from resource cache at menu startup")
	check(app.view.get_contract_version()==1,"Antigravity version-1 interface connected")
	check(app.view.get_script().resource_path.ends_with("launcher_view_adapter.gd"),"Delivered presentation connected through compatibility adapter")
	check(not app.continue_data.available,"No fictitious Continue when save absent")
	await capture("home")
	intent("show_modes")
	await capture("modes")
	var previous: String = app.page
	intent("start_mission",{"mode_id":"zombie_rpg","mission_id":"IR-2026-001"})
	check(app.page == previous and app.loader.retained_resources.is_empty(),"Forged Zombie start cannot load a scene")
	intent("back")
	intent("show_settings")
	intent("edit_setting",{"key":"mouse_sensitivity","value":1.7})
	check(is_equal_approx(app.settings.draft.mouse_sensitivity,1.7),"Settings accepts draft sensitivity")
	var settings_page: Node = app.view._pages.settings
	check(is_equal_approx(settings_page._sens_slider.value,1.7),"Settings view reflects authoritative draft")
	intent("cancel_settings")
	check(is_equal_approx(settings_page._sens_slider.value,1.0),"Cancel restores widget values and saved values")
	intent("edit_setting",{"key":"mouse_sensitivity","value":1.4})
	intent("apply_settings")
	var fresh = load("res://scripts/launcher/settings_store.gd").new()
	fresh.path = app.test_preferences_path
	fresh.initialize(false)
	check(is_equal_approx(fresh.saved.mouse_sensitivity,1.4),"Preferences survive a new store instance")
	intent("restore_defaults")
	check(is_equal_approx(app.settings.saved.mouse_sensitivity,1.4) and is_equal_approx(app.settings.draft.mouse_sensitivity,1),"Defaults populate draft without overwriting saved preferences")
	intent("cancel_settings")
	intent("capture_binding",{"action":"interact"})
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.physical_keycode = KEY_F
	key.pressed = true
	app._input(key)
	check(app.settings.draft.bindings.interact == [KEY_F],"Captured binding updates draft")
	intent("apply_settings")
	check(InputMap.action_get_events("interact")[0].physical_keycode==KEY_F,"Applied binding reaches engine InputMap")
	intent("capture_binding",{"action":"interact"})
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	app._input(key)
	check(app.capturing_action.is_empty() and app.settings.draft.bindings.interact == [KEY_F],"Escape cancels capture without changing binding")
	intent("edit_setting",{"key":"language","value":"fr"})
	intent("apply_settings")
	check(not app.settings.errors.is_empty() and app.settings.saved.language == "en","Unsupported locale is rejected")
	intent("cancel_settings")
	intent("edit_setting",{"key":"reduced_motion","value":true})
	intent("apply_settings")
	await capture("settings")
	intent("back")
	app.loader.resource_paths.assign(["res://missing-launcher-fixture.tscn"])
	intent("play")
	intent("start_mission",{"mode_id":"incident_response","mission_id":"IR-2026-001"})
	check(await until(func():return app.state.value=="ERROR",15000),"Missing-resource failure reaches recoverable Error")
	await capture("error")
	var error_id: String = app.current_request
	intent("retry_loading",{"request_id":"STALE"})
	check(app.state.value == "ERROR" and app.current_request == error_id,"Stale retry cannot start a new transition")
	app.loader.resource_paths.assign(load("res://scripts/launcher/mode_registry.gd").asset_paths())
	app.loader.test_frame_gate = true
	intent("retry_loading",{"request_id":error_id})
	var request: String = app.current_request
	intent("start_mission",{"mode_id":"incident_response","mission_id":"IR-2026-001"})
	check(app.current_request == request,"Double Start cannot create a second request")
	check(await until(func():return app.loading_data.get("stage_id","")=="test_gate"),"Background resources finish before test cancellation gate")
	await capture("loading")
	intent("cancel_loading",{"request_id":request})
	check(app.state.value == "MAIN_MENU" and not is_instance_valid(app.game),"Cancellation returns immediately to an interactive menu")
	app.loader.test_frame_gate = false
	intent("play")
	intent("start_mission",{"mode_id":"incident_response","mission_id":"IR-2026-001"})
	check(await until(func():return app.state.value in ["READY","ERROR"]),"Real campus build reaches terminal loading state")
	check(app.state.value == "READY","Full game reaches genuine READY",app.error_data)
	if app.state.value != "READY":
		finish()
		return
	check(app.game.initialization_finished and app.game.ready_to_play,"World readiness includes final initialization")
	check(app.game.stations.size()==5 and app.game.campus.door_system.doors.size()==4,"All gameplay stations and entrances exist")
	check(app.game.campus.stats.mesh_nodes==5965,"Derived sections retain every source mesh")
	check(app.game.campus.stats.multimesh_batches==28 and app.game.campus.stats.static_surface_batches==92,"Derived resource sharing retains original batching")
	for x: float in [-3.50,-3.1,-2.65,-2.30]:
		for z: float in [-104.5,-105.0,-105.6,-106.1,-106.65,-107.8,-108.3]:
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x,2.05,z),Vector3(x,-.5,z),1,[app.game.player.get_rid()])
			var hit: Dictionary = app.game.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and absf(float(hit.get("position",Vector3.ZERO).y)-1.814)<.005,"Chunked side landing remains continuously walkable")
	check(InputMap.action_get_events("interact")[0].physical_keycode==KEY_F,"World initialization preserves custom bindings")
	check(is_equal_approx(app.game.mouse_sensitivity,1.4),"World receives saved mouse sensitivity")
	await capture("ready")
	intent("enter_game",{"request_id":"STALE"})
	check(app.state.value == "READY","Stale Enter cannot capture player")
	intent("enter_game",{"request_id":app.current_request})
	check(app.state.value == "PLAYING" and app.game.moving,"Enter enables actual exploration")
	check(not app.view.visible and not app.view.is_processing_unhandled_input(),"Hidden launcher releases gameplay input")
	check(not app.saves.read_save().is_empty(),"Entered session creates a valid real checkpoint")
	app.game.training.workstation_shell.execute("ir inspect")
	check(app.game.training.get_completion_count()==1,"Existing mission command still progresses the case")
	app.game._show_menu("Pause","",true)
	check(not app.game.moving,"Pause releases movement")
	intent("show_settings")
	check(app.view.visible and not app.game.is_processing_unhandled_input(),"In-game settings own input while world is suspended")
	intent("back")
	check(not app.view.visible and app.game.is_processing_unhandled_input(),"Returning from settings preserves paused game input routing")
	app._return_home()
	await process_frame
	check(app.continue_data.available and not is_instance_valid(app.game),"Return to launcher unloads world and shows valid Continue")
	intent("continue_game")
	check(await until(func():return app.state.value in ["READY","ERROR"]),"Continue loads a new session")
	check(app.state.value == "READY","Validated checkpoint restored into a ready world",app.error_data)
	if app.state.value == "READY":
		check(app.game.training.get_completion_count()==1 and app.game.training.points>0,"Continue restores actual evidence/points prerequisites")
		intent("enter_game",{"request_id":app.current_request})
		app._return_home()
	await process_frame
	app._refresh_continue()
	var saved: Dictionary = app.saves.read_save()
	check(not saved.is_empty(),"Continue roundtrip remains valid")
	if "--stress" in OS.get_cmdline_user_args():
		var counts: Array[int] = []
		for cycle: int in range(3):
			intent("play")
			intent("start_mission",{"mode_id":"incident_response","mission_id":"IR-2026-001"})
			check(await until(func():return app.state.value in ["READY","ERROR"]),"Stress load completes")
			check(app.state.value=="READY","Stress session ready",cycle)
			if app.state.value != "READY": break
			counts.append(app.game.get_child_count())
			intent("enter_game",{"request_id":app.current_request})
			app._return_home()
			check(await until(func():return app.loader._disposing==0),"Stress cleanup completes")
		check(counts.size()==3 and counts.min()==counts.max(),"Five total mode cycles retain stable world-root child counts",counts)
	FileAccess.open(app.test_save_path,FileAccess.WRITE).store_string("{broken")
	app._refresh_continue()
	check(not app.continue_data.available,"Corrupt checkpoint removes Continue without breaking New Mission")
	report.metrics = app.metrics
	finish()

func capture(name: String) -> void:
	if not native: return
	for frame: int in range(3): await process_frame
	RenderingServer.force_draw(false)
	var path := "res://tools/launcher/integrated-"+name+".png"
	root.get_texture().get_image().save_png(path)
	report.captures.append(path)

func finish() -> void:
	report.passed = report.failures.is_empty()
	var file := FileAccess.open("res://tools/launcher/integration-test.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("LAUNCHER_TEST_RESULT ",JSON.stringify(report))
	if is_instance_valid(app): app.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
