extends SceneTree
## Real Antigravity mode through Codex's shared launcher, with isolated saves.
var app
var report := {"passed":false,"checks":0,"failures":[]}
func _init() -> void: call_deferred("run_test")
func check(value: bool,label: String) -> void:
	report.checks += 1
	if not value:
		report.failures.append(label)
		print("ZOMBIE_LAUNCHER_FAIL ",label)
func until(condition: Callable,timeout: int = 120000) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-started<timeout: await process_frame
	return bool(condition.call())
func frames(count: int = 4) -> void:
	for index: int in range(count): await process_frame
func intent(action: String,payload: Dictionary = {}) -> void:
	app._on_view_intent(StringName(action),payload)
func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames()
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tools/launcher/zombie-integrated-"+name+".png")

func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames()

func run_test() -> void:
	var proposed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://antigravity/zombie/MODE-REGISTRATION.json"))
	check(proposed is Dictionary,"Real module supplies registration metadata")
	if not proposed is Dictionary:
		finish()
		return
	# Test metadata is not production activation.
	var path := "res://tools/launcher/zombie-test-registration.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify([proposed],"  "))
	app = load("res://scenes/launcher/boot.tscn").instantiate()
	app.registration_path = path
	app.test_preferences_path = "user://ensagames/tests/real-zombie-launcher.cfg"
	app.test_save_path = "user://ensagames/tests/real-zombie-launcher.json"
	for file: String in [app.test_save_path,app.test_save_path.get_basename()+"-zombie_rpg.json",app.test_save_path.get_basename()+"-last-session.cfg"]:
		if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	root.add_child(app)
	check(await until(func():return app.initialized,15000),"Launcher initializes before the real survival world")
	check(app.loader.retained_resources.is_empty() and not ResourceLoader.has_cached(proposed.scene_path),"Real zombie world is absent from menu startup")
	intent("show_modes")
	await frames()
	(app.view._pages.modes._cards_container.get_child(1) as Button).pressed.emit()
	check(app.selected_mode=="zombie_rpg" and app.selected_mission=="ZB-2026-001","Real card selects After Hours")
	check(app.view._pages.briefing._mode_label.text=="Zombie RPG","Real briefing has its own mode branding")
	await capture("briefing")
	intent("start_mission",{"mode_id":"zombie_rpg","mission_id":"ZB-2026-001"})
	await until(func():return app.state.value in ["READY","ERROR"])
	check(app.state.value=="READY","Real survival mode reaches launcher Ready: "+str(app.error_data))
	if app.state.value!="READY":
		finish()
		return
	check(app.game.save_store==app.saves,"Game and launcher share one independent save service")
	check(app.saves.path.ends_with("real-zombie-launcher-zombie_rpg.json"),"Real module uses an isolated test checkpoint")
	check(not FileAccess.file_exists(app.saves.path),"Loading and Ready did not overwrite a checkpoint")
	var initial_hp: float = app.game.player.health
	app.game.player.take_damage(20.0)
	await frames(8)
	check(is_equal_approx(app.game.player.health,initial_hp),"Damage is rejected behind Ready")
	check(not app.game.hud.visible and not app.game.player.input_enabled,"Ready keeps real HUD and input suspended")
	await capture("ready")
	intent("enter_game",{"request_id":app.current_request})
	await frames(3)
	check(app.state.value=="PLAYING" and app.game.player.input_enabled,"Enter starts real survival gameplay")
	check(not app.saves.read_save().is_empty(),"Intentional entry creates a validated survival checkpoint")
	await capture("playing")
	await press(KEY_ESCAPE)
	check(paused and app.game.hud.pause_menu.visible,"Real Escape input pauses survival gameplay")
	var settings_button: Button
	var resume_button: Button
	for node: Node in app.game.hud.pause_menu.find_children("*","Button",true,false):
		match (node as Button).text.to_upper():
			"SETTINGS": settings_button = node
			"RESUME GAME": resume_button = node
	check(settings_button != null and resume_button != null,"Pause exposes Settings and Resume Game buttons")
	if settings_button != null and resume_button != null:
		await click(settings_button)
		check(app.page=="settings" and app.view.visible and paused,"Clicking Settings opens the shared settings screen")
		check(not app.game.hud.visible and not resume_button.is_visible_in_tree(),"Settings hide the gameplay HUD and underlying Resume button")
		await click(app.view._pages.settings._back_btn)
		check(not app.view.visible and paused and resume_button.is_visible_in_tree(),"Clicking Back returns to the pause menu")
		check(not app.game.player.input_enabled,"Player input remains disabled until Resume")
		await click(resume_button)
		check(not paused and not app.view.visible and not app.game.hud.pause_menu.visible and app.game.player.input_enabled,"Clicking Resume restores the world and input")
	await press(KEY_ESCAPE)
	check(paused,"Escape can pause the resumed game")
	await press(KEY_ESCAPE)
	check(not paused and not app.game.hud.pause_menu.visible,"Escape can also resume the paused game")
	# Keep testing checkpoint routing even when a mode-owned pause UI needs work.
	if paused: app.game._resume()
	app.game.player.take_damage(5000.0)
	await frames()
	var retry := root.gui_get_focus_owner() as Button
	check(paused and retry != null and retry.text.to_upper() == "RETRY FROM CHECKPOINT","Death focuses the checkpoint retry action")
	if retry != null:
		await click(retry)
	check(not paused and app.game.player.input_enabled and not app.game.hud._modal_scrim.visible,
		"Checkpoint retry restores gameplay and removes the input-blocking overlay")
	check(root.get_camera_3d() == app.game.player.camera,"Checkpoint retry restores the player camera")
	app.game.inventory.add_item("scrap",7)
	var scrap: int = app.game.inventory.get_item_count("scrap")
	app._save_checkpoint()
	app._return_home()
	await until(func():return app.loader._disposing==0)
	var saved_bytes: String = FileAccess.get_file_as_string(app.saves.path)
	check(app.continue_data.available and app.continue_data.mode_id=="zombie_rpg" and app.continue_data.summary is String,"Real survival Continue is readable and identifies its mode")
	intent("continue_game")
	await until(func():return app.state.value in ["READY","ERROR"])
	check(app.state.value=="READY","Real survival checkpoint restores through the launcher")
	if app.state.value=="READY":
		check(app.game.inventory.get_item_count("scrap")==scrap,"Independent inventory survives Continue")
		check(FileAccess.get_file_as_string(app.saves.path)==saved_bytes,"Restoring to Ready does not rewrite the checkpoint")
		check(not app.game.player.input_enabled and not app.game.hud.visible,"Restored real mode stays frozen until Enter")
		intent("enter_game",{"request_id":app.current_request})
		app._return_home()
		await until(func():return app.loader._disposing==0)
	check(not paused,"Real mode exit releases the global pause state")
	# Cancel with an actual construction coroutine active, then immediately
	# replace the request. No scene may be freed while its builder still awaits.
	saved_bytes = FileAccess.get_file_as_string(app.saves.path)
	intent("start_mission",{"mode_id":"zombie_rpg","mission_id":"ZB-2026-001"})
	await until(func():return is_instance_valid(app.loader._building_game) and app.loading_data.stage_id in ["instantiate","collision","campus"])
	var cancelled_id: String = app.current_request
	intent("cancel_loading",{"request_id":cancelled_id})
	check(app.state.value=="MAIN_MENU" and not is_instance_valid(app.game),"Cancelling a live build returns immediately to an interactive menu")
	intent("start_mission",{"mode_id":"zombie_rpg","mission_id":"ZB-2026-001"})
	await until(func():return app.state.value in ["READY","ERROR"])
	check(app.state.value=="READY","A replacement request drains old construction and reaches Ready")
	check(FileAccess.get_file_as_string(app.saves.path)==saved_bytes,"Cancel/replacement without Enter preserves the previous checkpoint")
	intent("enter_game",{"request_id":cancelled_id})
	check(app.state.value=="READY","A cancelled request cannot enter the replacement session")
	if app.state.value=="READY":
		intent("enter_game",{"request_id":app.current_request})
		await verify_extraction_drive()
	intent("return_to_menu")
	await until(func():return app.loader._disposing==0)
	finish()

func verify_extraction_drive() -> void:
	var game: Node3D = app.game
	var exit: Area3D = game.extraction_point
	var mission: RefCounted = game.mission_state
	var truck: CharacterBody3D = exit._vehicle
	var parked := truck.global_position
	exit.interact(game.player)
	check(not exit.boarding,"The truck remains locked before the mission objectives")
	var pistol: Node = game.spawned_pickups.get("item_intro_pistol")
	check(is_instance_valid(pistol), "The opening emergency pistol is present")
	if not is_instance_valid(pistol):
		return
	pistol.interact(game.player)
	mission.on_event("pickup_item",{"item_id":"item_power_fuse"})
	mission.on_event("pickup_item",{"item_id":"item_power_relay"})
	mission.on_event("power_restored")
	exit.set_powered(true)
	mission.on_event("talk_survivor")
	mission.on_event("boss_killed")
	var player: CharacterBody3D = game.player
	player.global_position = parked + truck.global_basis.x * 3.2
	player.look_at(Vector3(parked.x, player.global_position.y, parked.z))
	check(await until(func(): return player.current_interactable == exit, 2000),"The truck can be targeted from beside the cab")
	await press(KEY_E)
	check(exit.boarding and paused,"Interact boards the truck and pauses the world during the camera transition")
	if not await until(func(): return exit.driving, 4000):
		check(false,"Boarding gives the player control of the truck")
		return
	check(not paused and not mission.extracted and not game.player.input_enabled,"The camera handoff enables driving with the on-foot controls suspended")
	check(root.get_camera_3d() == exit._drive_camera,"Driving uses the truck camera")
	Input.action_press("move_right")
	var steering := await until(func(): return absf(truck._wheel_pivots[1].rotation.y) > 0.1, 2000)
	Input.action_release("move_right")
	check(steering,"Steering turns the front wheels")
	await until(func(): return is_zero_approx(truck._wheel_pivots[1].rotation.y), 1000)
	Input.action_press("move_back")
	var reversed := await until(func(): return truck.global_position.z > parked.z + 0.4, 2500)
	Input.action_release("move_back")
	check(reversed,"The truck can reverse")
	check(absf(truck._wheel_pivots[0].rotation.x) > 0.1,"Wheels roll as the truck moves")
	await press(KEY_ESCAPE)
	check(paused and exit.driving,"The pause menu suspends driving without leaving the truck")
	await press(KEY_ESCAPE)
	check(not paused and not game.player.input_enabled,"Resuming keeps control assigned to the truck")
	Input.action_press("move_forward")
	var escaped := await until(func(): return mission.extracted, 6000)
	Input.action_release("move_forward")
	check(escaped and game.hud.victory_screen.visible,"Driving through the gate completes extraction at the debrief")

func finish() -> void:
	paused = false
	report.passed = report.failures.is_empty()
	FileAccess.open("res://tools/launcher/zombie-launcher-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ZOMBIE_LAUNCHER_RESULT ",JSON.stringify(report))
	if is_instance_valid(app): app.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
