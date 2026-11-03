extends SceneTree
var report := {"passed":false,"checks":0,"failures":[]}
func _init() -> void: call_deferred("run_test")
func check(value: bool, label: String) -> void:
	report.checks += 1
	if not value: report.failures.append(label)
func run_test() -> void:
	var store = load("res://scripts/launcher/settings_store.gd").new()
	store.path = "user://ensagames/tests/settings-services.cfg"
	if "--read-persistence" in OS.get_cmdline_user_args():
		store.initialize(false)
		check(is_equal_approx(store.saved.mouse_sensitivity,1.8),"Preferences survive a different process")
		finish("-restart")
		return
	store.initialize()
	store.restore_defaults()
	check(store.apply(false),"Defaults can be applied")
	store.edit("mouse_sensitivity",1.8)
	store.edit("frame_cap",30)
	store.edit("vsync",false)
	store.edit("graphics_preset","low")
	store.edit("master_volume",0)
	store.edit("music_volume",20)
	store.edit("sfx_volume",70)
	check(store.apply(false),"Valid preferences apply")
	check(Engine.max_fps==30,"Frame cap is functional")
	check(root.msaa_3d==Viewport.MSAA_DISABLED,"Low graphics preset changes actual antialiasing")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"Master mute is functional")
	check(not is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")),AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))),"Music and SFX have independent volumes")
	store.edit("master_volume",70)
	check(not AudioServer.is_bus_mute(0),"Audio draft preview is live")
	store.cancel()
	check(AudioServer.is_bus_mute(0),"Cancel restores saved audio")
	store.bind("interact",KEY_W)
	check(not store.errors.is_empty() and store.draft.bindings.interact==[KEY_E],"Conflicting binding is rejected")
	store.cancel()
	store.bind("pause",KEY_P)
	check(not store.errors.is_empty(),"Escape recovery cannot be rebound away")
	store.cancel()
	if DisplayServer.get_name() != "headless":
		store.edit("resolution","1600x900")
		check(store.apply(),"Native display preview starts")
		await process_frame
		check(store.confirmation_pending and DisplayServer.window_get_size()==Vector2i(1600,900),"Display changes while awaiting Keep")
		check(store.saved.resolution=="1280x720","Unconfirmed resolution is not saved")
		store.confirmation_deadline = Time.get_ticks_msec()-1
		check(store.tick(),"Display timeout invokes Revert")
		await process_frame
		check(DisplayServer.window_get_size()==Vector2i(1280,720) and not store.confirmation_pending,"Timeout restores actual window")
		store.edit("resolution","1600x900")
		store.apply()
		check(store.confirm_display(),"Keep commits display preferences")
		store.edit("resolution","1280x720")
		store.apply()
		check(store.confirm_display(),"Native test restores original resolution")
		store.edit("fullscreen",true)
		store.apply()
		await process_frame
		check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"Fullscreen mode is functional")
		store.revert_display()
		await process_frame
		check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED,"Revert restores windowed mode")
	# Keep the restart fixture meaningful while returning the test process to a cap.
	Engine.max_fps = 60
	finish("")
func finish(suffix: String) -> void:
	report.passed = report.failures.is_empty()
	FileAccess.open("res://tools/launcher/settings-test%s.json" % suffix,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LAUNCHER_SETTINGS_TEST ",JSON.stringify(report))
	quit(0 if report.passed else 1)
