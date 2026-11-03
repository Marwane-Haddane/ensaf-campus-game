extends SceneTree
## Script-assisted native playtest. Captures are real engine frames. Repositioning
## between distant chapters is disclosed; this is not a manual full-route run.
var game: Node3D
var report := {"passed":false,"checks":0,"failures":[],"frames":[],"method":"Script-assisted native gameplay: physical movement/combat and real interaction callbacks; safe repositioning between distant chapters; other enemies temporarily held for reproducibility."}
var samples: Array[float] = []
func _init() -> void: call_deferred("run_test")
func check(ok: bool,label: String) -> void:
	report.checks += 1
	if not ok: report.failures.append(label)
	print("STORY_CHECK ",ok," ",label)
func advance(count: int) -> void:
	for frame: int in range(count): await process_frame
func aim(at: Vector3) -> void:
	var flat := at
	flat.y = game.player.global_position.y
	if game.player.global_position.distance_to(flat)>.01: game.player.look_at(flat,Vector3.UP)
	var direction: Vector3 = at-game.player.camera.global_position
	game.player.camera_pitch = atan2(direction.y,Vector2(direction.x,direction.z).length())
	game.player.camera.rotation.x = game.player.camera_pitch
func place(at: Vector3,look: Vector3) -> void:
	paused = false
	var safe := false
	for offset: Vector3 in [Vector3.ZERO,Vector3(0,0,.8),Vector3(.8,0,0),Vector3(-.8,0,0),Vector3(0,0,-.8),Vector3(0,0,1.6),Vector3(1.6,0,0),Vector3(-1.6,0,0),Vector3(0,0,-1.6)]:
		var candidate := at+offset
		if game.restore_safe_pose({"position":[candidate.x,candidate.y,candidate.z],"rotation_y":0.0,"camera_pitch":0.0}):
			safe=true
			break
	check(safe,"Safe chapter pose")
	game.player.velocity = Vector3.ZERO
	await advance(8)
	aim(look)
func capture(id: String,title: String,detail: String) -> void:
	await advance(5)
	RenderingServer.force_draw(false)
	var path := "res://tools/zombie_polish/captures/"+id+".png"
	root.get_texture().get_image().save_png(path)
	report.frames.append({"id":id,"title":title,"detail":detail,"image":"captures/"+id+".png"})
func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await advance(3)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await advance(3)
func run_test() -> void:
	DirAccess.make_dir_recursive_absolute("res://tools/zombie_polish/captures")
	root.size=Vector2i(1280,720)
	var settings = load("res://scripts/launcher/settings_store.gd").new()
	settings.path="user://ensagames/tests/zombie-polish.cfg"
	settings.initialize()
	var adapter = load("res://scripts/antigravity/zombie/zombie_mode_adapter.gd").new()
	adapter.save_service().path="user://ensagames/tests/zombie-polish-story.json"
	var resources: Dictionary = {}
	for path: String in adapter.required_resources(): resources[path]=load(path)
	game=adapter.create_session(resources,settings.saved)
	root.add_child(game)
	var started := Time.get_ticks_msec()
	while not game.initialization_finished and Time.get_ticks_msec()-started<120000: await process_frame
	check(game.ready_to_play,"Real campus/actors initialized")
	if not game.ready_to_play:
		finish()
		return
	for frame: int in range(4): await physics_frame
	check(adapter.validate_spawn(game),"Initial spawn has ground and capsule clearance")
	adapter.start(game)
	# Hold distant actors; the chosen combatant runs full AI during its chapter.
	for enemy: Node in game.active_enemies:
		enemy.set_physics_process(false)
	await advance(20)
	game._refresh_hud()
	await advance(3)
	var objective_card: Control = game.hud._objective_box
	check(objective_card.size.y <= 100.0 and objective_card.size.x <= 886.0,"Objective card stays compact")
	await press(KEY_I)
	check(game.hud.inventory_menu.visible and not game.player.input_enabled,"I opens the inventory and locks movement")
	await press(KEY_I)
	check(not game.hud.inventory_menu.visible and game.player.input_enabled,"I closes the inventory and restores movement")
	await press(KEY_TAB)
	check(game.hud.journal_menu.visible,"Tab opens the journal")
	await press(KEY_TAB)
	check(not game.hud.journal_menu.visible and game.player.input_enabled,"Tab closes the journal and restores movement")
	await capture("01-arrival","01 / Campus after hours","Read the objective, identify supplies and choose your route. Native first-person view with the revised HUD.")
	var origin: Vector3=game.player.global_position
	Input.action_press("move_forward")
	for frame: int in range(55):
		var tick := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec()-tick)/1000.0)
	Input.action_release("move_forward")
	await advance(8)
	check(game.player.global_position.distance_to(origin)>1.0,"Physical movement advances across the plaza")
	var enemy: Node3D=game.active_enemies[0]
	enemy.set_physics_process(true)
	for frame: int in range(30): await physics_frame
	aim(enemy.global_position+Vector3.UP*1.05)
	await capture("02-combat","02 / First contact","A walker closes in. Create distance, then fire. The selected enemy runs its normal AI and takes damage from real weapon traces.")
	var before: float=enemy.health
	for shot: int in range(10):
		if enemy.is_dead(): break
		aim(enemy.global_position+Vector3.UP*1.1)
		game.player.recoil_pitch_offset=0.0
		game.player.weapon_controller.trigger_fire()
		await advance(14)
	check(enemy.health<before,"Weapon ballistics damage a live AI enemy")
	check(enemy.is_dead(),"Live combatant defeated through weapon traces")
	check(game.inventory.get_progression_summary().xp>0,"Combat grants persistent RPG XP")
	for remaining: Node in game.active_enemies:
		if is_instance_valid(remaining): remaining.set_physics_process(false)
	game.player.heal(100)
	var fuse: Node3D=game.spawned_pickups.get("item_power_fuse")
	for door: Node in game.campus.door_system.doors:
		if door.door_name.to_lower().contains("reception"): door.toggle(game.player)
	await advance(35)
	await place(Vector3(-36.2,2.0,-100.5),fuse.global_position)
	await capture("03-reception","03 / Recover the fuse","Reception is the first power-component stop. Chapter positioning is scripted; collection uses the actual pickup interaction.")
	fuse.interact(game.player)
	await advance(12)
	check(game.inventory.has_item("item_power_fuse"),"Real fuse pickup collected")
	var relay: Node3D=game.spawned_pickups.get("item_power_relay")
	await place(Vector3(-8,2.8,-105),relay.global_position)
	relay.interact(game.player)
	await advance(8)
	check(game.inventory.has_item("item_power_relay"),"Real relay pickup collected")
	# Real cache grants scrap, then the same purchase signal as the workbench.
	for child: Node in game.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("loot_chest.gd") and child.get("loot_type")=="scrap": child.interact(game.player)
	await place(Vector3(-35,2.0,-103.4),Vector3(-35,2.3,-105))
	game.hud.toggle_upgrade_menu(true)
	await capture("04-upgrade","04 / Build your survivor","Spend recovered scrap on a real upgrade. Objective and kill XP improve rank and medkit effectiveness; rewards are saved once.")
	game.hud.upgrade_chosen.emit("upgrade_armor")
	game.hud.toggle_upgrade_menu(false)
	check(game.inventory.has_upgrade("upgrade_armor") and game.player.max_health==150,"Armor purchase spends resources and changes max health")
	var power: Node3D
	var shaun: Node3D
	for child: Node in game.get_children():
		if child.has_signal("power_restored"): power=child
		if child.has_signal("survivor_contacted") and child.get("character_name")=="Shaun": shaun=child
	await place(Vector3(0.9,3.0,-108.4),power.global_position)
	power.interact(game.player)
	await advance(12)
	check(game.mission_state.power_restored,"Both components restore the actual breaker")
	await capture("05-power","05 / Bring the grid online","The breaker consumes the fuse and relay. The objective and rank rewards advance from the interaction, not a fabricated timer.")
	await place(shaun.global_position+Vector3(.6,0,-1.65),shaun.global_position+Vector3.UP)
	shaun.interact(game.player)
	await advance(5)
	await capture("06-survivor","06 / Shaun's escape plan","Speak with the survivor after restoring power. Dialogue owns input and pauses threats; the journal explains the final route.")
	game.hud.close_dialogue()
	check(game.mission_state.survivor_talked,"Post-power survivor check-in recorded")
	var boss: Node3D=game.brute_boss
	await place(Vector3(-26,1.3,-82.5),boss.global_position+Vector3.UP)
	boss.set_physics_process(true)
	await advance(12)
	await capture("07-brute","07 / Clear the courtyard","The brute uses a distinct health bar, slower committed attacks and a readable windup. Move out of its contact range during the attack.")
	for shot: int in range(38):
		if boss.is_dead() or game.player.is_dead: break
		var weapon: Node3D=game.player.weapon_controller
		if weapon.mag_ammo==0:
			weapon.add_ammo(24)
			weapon.start_reload()
			await advance(150)
		aim(boss.global_position+Vector3.UP*1.1)
		game.player.recoil_pitch_offset=0.0
		weapon.trigger_fire()
		await advance(14)
	check(boss.is_dead(),"Brute defeated by real weapon damage")
	check(not game.player.is_dead,"Combat test survives without invulnerability")
	await place(Vector3(-20,1.3,-70),Vector3(-20,2,-67))
	for child: Node in game.get_children():
		if child.has_signal("extraction_triggered"): child.interact(game.player)
	await create_timer(1.4, true).timeout
	check(game.mission_state.extracted,"Actual extraction interaction reaches victory")
	await capture("08-extraction","08 / Extraction and debrief","The episode ends after the component, power, survivor and brute prerequisites. The debrief uses actual mission statistics.")
	var saved: Dictionary=adapter.capture(game)
	check(adapter.save_service().write_save(saved),"Enhanced progression checkpoint validates and writes")
	check(not adapter.save_service().read_save().is_empty(),"Enhanced checkpoint reads back")
	if not samples.is_empty():
		samples.sort()
		report["movement_frame_ms"]={"sample_count":samples.size(),"median":samples[samples.size()/2],"p95":samples[int(samples.size()*.95)],"note":"Short native movement sample; excludes captures/loading and is not a sustained FPS guarantee."}
	finish()
func finish() -> void:
	paused=false
	report.passed=report.failures.is_empty()
	FileAccess.open("res://tools/zombie_polish/storyboard-results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("STORYBOARD_RESULT ",JSON.stringify(report))
	if is_instance_valid(game): game.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
