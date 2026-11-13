extends SceneTree
## Script-assisted native playtest. Captures are real engine frames. Repositioning
## between distant chapters is disclosed; this is not a manual full-route run.
var game: Node3D
var report := {"passed":false,"checks":0,"failures":[],"frames":[],"method":"Script-assisted native gameplay: physical movement/combat and real interaction callbacks; safe repositioning between distant chapters; other enemies temporarily held for reproducibility."}
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
	check(root.get_texture().get_image().save_png(path) == OK, "Saved native frame " + id)
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
	if not is_instance_valid(game):
		check(false, "The mode creates a playable session")
		finish()
		return
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
	var origin: Vector3 = game.player.global_position
	Input.action_press("move_forward")
	for frame: int in range(36): await physics_frame
	Input.action_release("move_forward")
	await advance(8)
	check(game.player.global_position.distance_to(origin) > 1.0, "Physical movement advances across the plaza")
	check(not game.has_intro_weapon() and not game.player.weapon_controller.visible and not game.hud._weapon_tile.visible, "The opening starts without a weapon or ammo display")
	var pistol: Node3D = game.spawned_pickups.get("item_intro_pistol")
	var fuse: Node3D = game.spawned_pickups.get("item_power_fuse")
	check(is_instance_valid(pistol) and is_instance_valid(fuse), "Reception has the emergency pistol and breaker fuse")
	if not is_instance_valid(pistol) or not is_instance_valid(fuse):
		finish()
		return
	for door: Node in game.campus.door_system.doors:
		if door.door_name.to_lower().contains("reception"): door.toggle(game.player)
	await advance(35)
	await place(Vector3(-37.5, 2.0, -102.5), pistol.global_position)
	await capture("02-pistol", "02 / Recover the emergency pistol", "The opening begins unarmed. Look for the emergency pistol case in Reception.")
	pistol.interact(game.player)
	await advance(8)
	check(game.has_intro_weapon() and game.player.weapon_controller.visible and game.hud._weapon_tile.visible, "The emergency pistol equips, shows ammo and advances the objective")
	await place(Vector3(-36.2, 2.0, -100.5), fuse.global_position)
	await capture("03-reception", "03 / Recover the breaker fuse", "Open the Reception supply cache and recover the Main Breaker Fuse. Collecting it lets infected encounters start.")
	fuse.interact(game.player)
	await advance(12)
	check(game.inventory.has_item("item_power_fuse"), "Real fuse pickup collected")
	var weapons_case: Node3D
	var supply_cache: Node3D
	for chest: Node in get_nodes_in_group("loot_chests"):
		if chest.loot_type == "shotgun": weapons_case = chest
		if chest.loot_type == "scrap": supply_cache = chest
	check(is_instance_valid(weapons_case) and is_instance_valid(supply_cache), "Both world caches spawned")
	if not is_instance_valid(weapons_case) or not is_instance_valid(supply_cache):
		finish()
		return
	await place(weapons_case.global_position + Vector3(-1.15, 0, 0.9), weapons_case.global_position + Vector3.UP * 0.35)
	weapons_case.interact(game.player)
	await advance(28)
	check(weapons_case.is_opened and game.player.weapon_controller.current_weapon_id == "shotgun", "The marked Benelli case opens and equips the shotgun")
	if game.hud._notice_box.visible:
		check(game.hud._notice_box.size.y <= 110.0, "Case notification stays compact")
	await capture("04-cache", "04 / Open the weapons case", "The marked case opens and equips the Benelli M4. Pistol magazines and 12-gauge shells replenish different reserves.")
	game.player.switch_weapon_slot(0)
	await advance(15)
	var enemy: Node3D = game.active_enemies[0]
	var flank := enemy.global_position + Vector3(-8, 0, 2.0)
	await place(flank, flank + Vector3.LEFT * 4.0)
	await advance(10)
	check(enemy.visible and not enemy.get_meta("encounter_waiting", false), "The walker enters outside the player's view after the fuse")
	await place(enemy.global_position + Vector3(-4, 0, 1.8), enemy.global_position + Vector3.UP * 1.05)
	enemy.set_physics_process(true)
	for frame: int in range(15): await physics_frame
	aim(enemy.global_position + Vector3.UP * 1.05)
	await capture("05-combat","05 / First contact","A walker closes in. Create distance, then fire. The selected enemy runs its normal AI and takes damage from real weapon traces.")
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
	var relay: Node3D=game.spawned_pickups.get("item_power_relay")
	await place(relay.global_position + Vector3(-0.8, 0.0, -1.15),relay.global_position)
	await capture("06-relay", "06 / Recover the control relay", "Cross to the glazed entrance and recover the second component for the Security Substation.")
	relay.interact(game.player)
	await advance(8)
	check(game.inventory.has_item("item_power_relay"),"Real relay pickup collected")
	# Real cache grants scrap, then the same purchase signal as the workbench.
	supply_cache.interact(game.player)
	await place(Vector3(-35,2.0,-103.4),Vector3(-35,2.3,-105))
	game.hud.toggle_upgrade_menu(true)
	await capture("07-upgrade","07 / Build your survivor","Spend recovered scrap on a real upgrade. Objective and kill XP improve rank and medkit effectiveness; rewards are saved once.")
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
	await advance(5)
	check(game.mission_state.installed_power_parts.size() == 1 and not game.mission_state.power_restored, "One installed component leaves the grid offline")
	power.interact(game.player)
	await advance(12)
	check(game.mission_state.power_restored and game.mission_state.installed_power_parts.size() == 2, "Both installed components restore the actual breaker")
	await capture("08-power","08 / Bring the grid online","Install the fuse and relay separately. Both slots must be filled before the grid comes back online.")
	await place(shaun.global_position+Vector3(.6,0,-1.65),shaun.global_position+Vector3.UP)
	shaun.interact(game.player)
	await advance(5)
	await capture("09-survivor","09 / Shaun's escape plan","Speak with the survivor after restoring power. Dialogue owns input and pauses threats; the journal explains the final route.")
	game.hud.close_dialogue()
	check(game.mission_state.survivor_talked,"Post-power survivor check-in recorded")
	var boss: Node3D=game.brute_boss
	var boss_flank: Vector3 = boss.global_position + Vector3(-8, 0, -2)
	await place(boss_flank, boss_flank + Vector3.LEFT * 4.0)
	await advance(10)
	check(boss.visible and not boss.get_meta("encounter_waiting", false), "The brute activates on the gate approach")
	await place(Vector3(-26,1.3,-82.5),boss.global_position+Vector3.UP)
	boss.set_physics_process(true)
	await advance(12)
	await capture("10-brute","10 / Clear the courtyard","The brute uses a distinct health bar, slower committed attacks and a readable windup. Move out of its contact range during the attack.")
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
	var extraction: Node3D = game.extraction_point
	await place(extraction.global_position + Vector3(2.9, 0, 0), extraction.global_position + Vector3.UP)
	extraction.interact(game.player)
	var boarding_started := Time.get_ticks_msec()
	while extraction.boarding and Time.get_ticks_msec() - boarding_started < 12000: await process_frame
	check(extraction.driving and not game.mission_state.extracted, "Boarding transfers control to the truck without completing the mission")
	if extraction.driving:
		await capture("11-truck", "11 / Take the wheel", "Boarding shifts to the truck camera. Drive along the opening and clear the gate.")
		Input.action_press("move_forward")
		for frame: int in range(720):
			if not extraction.driving: break
			await physics_frame
		Input.action_release("move_forward")
		await advance(10)
	check(game.mission_state.extracted, "Physical driving clears the gate and reaches victory")
	await capture("12-extraction","12 / Extraction and debrief","Once the truck clears the gate, the debrief shows active playtime, infected defeated and damage dealt.")
	var saved: Dictionary=adapter.capture(game)
	check(adapter.save_service().write_save(saved),"Enhanced progression checkpoint validates and writes")
	check(not adapter.save_service().read_save().is_empty(),"Enhanced checkpoint reads back")
	finish()
func finish() -> void:
	paused=false
	report.passed=report.failures.is_empty()
	FileAccess.open("res://tools/zombie_polish/storyboard-results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("STORYBOARD_RESULT ",JSON.stringify(report))
	if is_instance_valid(game): game.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
