extends SceneTree
## Native load measurement without screenshots/readbacks or fixture navigation.
func _init() -> void: call_deferred("run_test")
func run_test() -> void:
	var app = load("res://scenes/launcher/boot.tscn").instantiate()
	app.test_preferences_path = "user://ensagames/tests/profile.cfg"
	app.test_save_path = "user://ensagames/tests/profile.json"
	root.add_child(app)
	var started := Time.get_ticks_msec()
	while not app.initialized and Time.get_ticks_msec()-started<15000: await process_frame
	if not app.initialized:
		quit(1)
		return
	app._on_view_intent(&"play",{})
	app._on_view_intent(&"start_mission",{"mode_id":"incident_response","mission_id":"IR-2026-001"})
	while app.state.value not in ["READY","ERROR"] and Time.get_ticks_msec()-started<120000: await process_frame
	var result := {"passed":app.state.value=="READY","metrics":app.metrics.duplicate(true),"stage_data":{},"first_playable_frames_ms":0.0}
	if app.state.value == "READY":
		result.stage_data = app.game.campus.stats.stage_timings
		var frame_start := Time.get_ticks_usec()
		app._on_view_intent(&"enter_game",{"request_id":app.current_request})
		for frame: int in range(4): await process_frame
		result.first_playable_frames_ms = (Time.get_ticks_usec()-frame_start)/1000.0
		result.gameplay_metrics = app.metrics.duplicate(true)
		if "--capture-after-enter" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://tools/launcher/production-playing.png")
		app._return_home()
		while app.loader._disposing>0: await process_frame
		result.cleanup_metrics = app.metrics.duplicate(true)
	FileAccess.open("res://tools/launcher/load-profile.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("LAUNCHER_LOAD_PROFILE ",JSON.stringify(result))
	app.queue_free()
	await process_frame
	quit(0 if result.passed else 1)
