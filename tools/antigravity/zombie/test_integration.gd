@tool
extends SceneTree
## Full End-to-End Integration Test for Zombie RPG: After Hours (ZB-2026-001)
## Covers all 7 concrete launcher integration requirements:
## 1. Checkpoint ownership & overridable path
## 2. No initialization overwrite in managed mode
## 3. World state restoration, HUD refresh, player pose check, invalid restore error
## 4. Managed mode-local replay/restart preserving launcher
## 5. Freeze & input lifecycle, pause/resume, cancel completion
## 6. Shared preferences (InputMap, sensitivity, reduced motion, settings request)
## 7. Metadata contract

var game: Node3D
var report := {
	"checks": 0,
	"passed": true,
	"failures": [],
	"stats": {}
}

func _init() -> void:
	call_deferred("run_integration_test")

func verify(cond: bool, test_name: String, detail: Variant = null) -> void:
	report["checks"] += 1
	if not cond:
		report["passed"] = false
		report["failures"].append({"test": test_name, "detail": str(detail)})
		print("[INTEGRATION FAIL] ", test_name, " -> ", detail)
	else:
		print("[OK] ", test_name)

func run_integration_test() -> void:
	print("=== Running Zombie RPG Full Integration Test ===")
	var t_start := Time.get_ticks_msec()
	
	root.size = Vector2i(1280, 720)
	
	# 1. Setup Adapter and Isolated Save Path
	var adapter_script: Script = load("res://scripts/antigravity/zombie/zombie_mode_adapter.gd")
	var adapter = adapter_script.new()
	
	var test_save_path := "user://ensagames/saves/zombie_rpg/test_integration_save.json"
	adapter.save_service().path = test_save_path
	adapter.save_service().delete_save()
	verify(not adapter.save_service().has_save(), "Isolated test save cleared")
	
	# Prepare Resources Dictionary
	var res_dict: Dictionary = {}
	var scene_path: String = adapter.entry_scene()
	var packed: PackedScene = load(scene_path)
	verify(packed != null, "Zombie game scene loads as PackedScene")
	res_dict[scene_path] = packed
	
	# Pass runtime chunks if available
	var manifest_path := "res://assets/runtime_campus/manifest.json"
	if FileAccess.file_exists(manifest_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary and parsed.has("chunks"):
			for cp: String in parsed["chunks"]:
				var scn = load(cp) as PackedScene
				if scn:
					res_dict[cp] = scn
	
	var test_prefs := {
		"mouse_sensitivity": 1.5,
		"reduced_motion": true
	}
	
	# Create session through adapter
	game = adapter.create_session(res_dict, test_prefs)
	verify(game != null, "Adapter created session successfully")
	verify(game.launcher_managed == true, "Game session flagged as launcher_managed")
	verify(game.save_store == adapter.save_service(), "Game shares adapter's save service instance")
	verify(game.save_store.path == test_save_path, "Game save_store uses isolated test save path")
	
	root.add_child(game)
	
	# Wait for initialization to finish
	var max_wait_frames := 1500
	var frames := 0
	while not bool(game.get("initialization_finished")) and frames < max_wait_frames:
		await process_frame
		frames += 1
	
	var init_time_ms := Time.get_ticks_msec() - t_start
	print("Initialization finished in ", init_time_ms, " ms (frames: ", frames, ")")
	
	verify(bool(game.get("ready_to_play")), "Game is ready to play", game.get("initialization_error"))
	
	# Requirement 2: No initialization overwrite!
	verify(not adapter.save_service().has_save(), "Persistent checkpoint was NOT written during initialization in managed mode")
	
	# Requirement 5: Freeze lifecycle behind Loading / Ready
	verify(game.is_session_frozen == true, "Session is frozen during initialization in managed mode")
	verify(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE, "Mouse is NOT captured behind Ready screen")
	verify(not game.player.input_enabled, "Player input is disabled while frozen")
	
	# Damage is ignored while frozen
	var p_initial_hp: float = game.player.health
	game.player.take_damage(20.0)
	verify(game.player.health == p_initial_hp, "Attacks/damage ignored while session is frozen")
	
	# Verify Adapter validation methods
	verify(adapter.validate_ready(game), "Adapter validate_ready returns true")
	verify(adapter.validate_spawn(game), "Adapter validate_spawn confirms ground clearance")
	
	# Requirement 6: Preferences applied
	adapter.apply_preferences(game, test_prefs)
	verify(game.player.reduced_motion == true, "Reduced motion applied to player")
	verify(game.hud.reduced_motion == true, "Reduced motion applied to HUD")
	verify(absf(game.player.mouse_sensitivity - (0.002 * 1.5)) < 0.0001, "Mouse sensitivity preference applied")
	
	# Test graphics preset applied to DuskSun
	adapter.apply_preferences(game, {"graphics_preset": "low", "mouse_sensitivity": 1.5, "reduced_motion": true})
	var dusk_sun_node: DirectionalLight3D = game.find_child("DuskSun", true, false)
	verify(dusk_sun_node != null and not dusk_sun_node.shadow_enabled, "Low graphics preset disables DuskSun shadows")
	adapter.apply_preferences(game, {"graphics_preset": "high", "mouse_sensitivity": 1.5, "reduced_motion": true})
	verify(dusk_sun_node != null and dusk_sun_node.shadow_enabled and dusk_sun_node.directional_shadow_max_distance == 60.0, "High graphics preset sets 60m shadow distance")
	
	# Test Settings button emits settings_requested without silently toggling reduced_motion
	var signal_tracker := {"settings": false, "restart": false}
	game.launcher_settings_requested.connect(func(): signal_tracker["settings"] = true)
	game.hud.settings_requested.emit()
	verify(signal_tracker["settings"], "Settings action emitted launcher_settings_requested")
	verify(game.hud.reduced_motion == true, "Settings action did not silently toggle reduced_motion")
	
	# Start intentional gameplay entry via adapter
	adapter.start(game)
	verify(game.is_session_frozen == false, "Session is unfrozen after adapter start")
	verify(game.player.input_enabled == true, "Player input enabled after start")
	verify(adapter.save_service().has_save(), "Initial checkpoint created upon intentional gameplay entry")
	
	# Verify Player
	var player = game.get("player")
	verify(player != null, "Player exists in game")
	verify(player.health == 100.0, "Player starts with 100 health")
	verify(player.stamina == 100.0, "Player starts with 100 stamina")
	
	# Verify Campus and Doors
	var campus = game.get("campus")
	verify(campus != null and bool(campus.stats.get("ready", false)), "Campus is built and ready")
	verify(campus.doors.size() > 0, "Interactive campus doors exist", campus.doors.size())
	
	# Verify Precomputed Navmesh
	var nav = game.get("nav_region")
	verify(nav != null and nav.navigation_mesh != null, "Navigation region is active with precomputed navmesh")
	
	# Verify Shaun Survivor NPC
	var shaun = game.find_child("SurvivorCol", true, false)
	verify(shaun != null, "Shaun survivor NPC spawned in world")
	
	# Verify Dusk lighting active
	var dusk_sun = game.find_child("DuskSun", true, false)
	verify(dusk_sun != null, "Dusk lighting active")
	
	# Verify Pickups Spawned
	verify(game.spawned_pickups.has("item_power_fuse"), "Main Breaker Fuse pickup spawned")
	verify(game.spawned_pickups.has("item_power_relay"), "Control Bus Relay pickup spawned")
	
	# Verify Weapon and Shooting
	var wc = player.get("weapon_controller")
	verify(wc != null, "Player weapon controller active")
	var initial_mag: int = wc.mag_ammo
	verify(initial_mag == 12, "Pistol has 12 rounds in magazine")
	
	# Test firing
	var fired: bool = wc.trigger_fire()
	verify(fired, "Pistol fired successfully")
	verify(wc.mag_ammo == 11, "Mag ammo decremented to 11")
	
	# Test Weapon Reload
	wc.mag_ammo = 0
	wc.start_reload()
	verify(wc.is_reloading, "Pistol is reloading")
	for i in range(25):
		wc._process(0.1)
	verify(wc.mag_ammo == 12, "Pistol finished reload to 12 rounds")

	# Test Weapon Switching (Slot 1 <-> Slot 2)
	player.switch_weapon_slot(1)
	verify(wc.current_weapon_id == "scorpion", "Weapon switched to scorpion SMG")
	verify(wc.mag_ammo == 20, "Scorpion mag is 20 rounds")
	wc.trigger_fire()
	verify(wc.mag_ammo == 19, "Scorpion fired down to 19 rounds")
	player.switch_weapon_slot(0)
	verify(wc.current_weapon_id == "pistol", "Switched back to pistol")
	verify(wc.mag_ammo == 12, "Pistol mag is still 12 rounds (per-weapon pool retained)")

	# Test Friendly Survivor Target Exclusion
	var shaun_col = game.find_child("SurvivorCol", true, false)
	var enemy_check = wc._find_enemy_root(shaun_col)
	verify(enemy_check == null, "Survivor Shaun is excluded as enemy target")

	# Test Tree-Level Pause & Resume and HUD Pause Menu Resume
	game._pause()
	verify(game.get_tree().paused == true, "Pause successfully freezes game tree")
	game._resume()
	verify(game.get_tree().paused == false, "Resume unfreezes game tree")
	game._pause()
	game.hud.toggle_pause(true)
	verify(game.hud.pause_menu.visible == true, "Pause menu is visible")
	game.hud.toggle_pause(false)
	verify(game.get_tree().paused == false, "Pause menu Resume Game unpauses game tree")
	verify(game.player.input_enabled == true, "Pause menu Resume Game enables player input")
	
	# Test Enemies
	verify(game.active_enemies.size() > 0, "Enemies spawned in active list", game.active_enemies.size())
	verify(game.brute_boss != null, "Chubby Brute encounter spawned")
	
	# Test frozen enemy ignores damage
	var test_enemy = game.active_enemies[0] if not game.active_enemies.is_empty() else null
	if test_enemy:
		test_enemy.set_physics_process(false)
		var pre_hp: float = test_enemy.health
		test_enemy.take_damage(20.0, false)
		verify(test_enemy.health == pre_hp, "Enemy with physics disabled ignores damage")
		test_enemy.set_physics_process(true)
	
	# Test Taking Damage & Healing
	player.take_damage(25.0)
	verify(player.health == 75.0, "Player took 25 damage, health is 75")
	var inv = game.get("inventory")
	inv.add_item("medkit", 1)
	var healed: bool = inv.use_medkit(player)
	verify(healed, "Medkit used successfully")
	verify(player.health > 75.0, "Player health healed by medkit")
	
	# Test Upgrades
	inv.add_item("scrap", 30)
	verify(inv.can_afford_upgrade(25), "Player has enough scrap for upgrade")
	var upgraded: bool = inv.buy_upgrade("upgrade_armor", 25)
	verify(upgraded, "Armor upgrade purchased")
	player.apply_armor_upgrade(50.0)
	verify(player.max_health == 150.0, "Player max health increased to 150")
	
	# Test Objective Chain Sequence
	var mission = game.get("mission_state")
	verify(mission != null, "Mission state is active")
	
	# Simulate Fuse pickup
	var fuse_pickup = game.spawned_pickups.get("item_power_fuse")
	if fuse_pickup:
		fuse_pickup.interact(player)
	verify(inv.has_item("item_power_fuse"), "Player collected Main Breaker Fuse")
	
	# Simulate Relay pickup
	var relay_pickup = game.spawned_pickups.get("item_power_relay")
	if relay_pickup:
		relay_pickup.interact(player)
	verify(inv.has_item("item_power_relay"), "Player collected Control Bus Relay")
	
	# Simulate Power Restoration
	var p_station = null
	for c in game.get_children():
		if c.has_signal("power_restored"):
			p_station = c
			break
	verify(p_station != null, "Found power station node")
	if p_station:
		p_station.interact(player)
	verify(mission.power_restored, "Campus power successfully restored")
	
	# Simulate Speaking to Shaun
	var shaun_npc = null
	for c in game.get_children():
		if c.is_in_group("friendly_npc"):
			shaun_npc = c
			break
	verify(shaun_npc != null, "Found Shaun survivor node")
	if shaun_npc:
		shaun_npc.interact(player)
		game.hud.close_dialogue()
	verify(mission.survivor_talked, "Shaun survivor interaction completed")
	
	# Simulate Defeating Brute Boss
	if game.brute_boss:
		game.brute_boss.take_damage(300.0, true)
	verify(mission.boss_killed, "Chubby Brute boss defeated")
	
	# Simulate Extraction
	var ext_node = null
	for c in game.get_children():
		if c.has_signal("extraction_triggered"):
			ext_node = c
			break
	verify(ext_node != null, "Found extraction node")
	if ext_node:
		ext_node.interact(player)
	verify(mission.extracted, "Extraction triggered and mission completed")
	
	# Requirement 1 & 3: Checkpoint Persistence and Full World State Restoration
	var captured: Dictionary = adapter.capture(game)
	verify(captured.get("mode_id") == "zombie_rpg", "Captured state has mode_id zombie_rpg")
	verify(captured.get("mission_id") == "ZB-2026-001", "Captured state has mission_id ZB-2026-001")
	var written: bool = adapter.save_service().write_save(captured)
	verify(written, "Saved checkpoint using shared adapter save service")
	
	# Invalid restore rejection
	var invalid_restore = adapter.restore(game, {"mode_id": "invalid_mode"})
	verify(not invalid_restore, "Adapter rejects restore from invalid checkpoint")
	verify(adapter.last_error != "", "Adapter sets last_error on invalid restore: " + adapter.last_error)
	verify(adapter.save_service().last_error != "", "Shared save service exposes last_error for launcher diagnostics")
	verify(adapter.save_service().summary({}).is_empty(), "Save service returns empty dictionary for empty summary")
	
	# Safe pose restoration method check
	var safe_pose_ok: bool = game.restore_safe_pose(captured.get("player_state", {}))
	verify(safe_pose_ok, "Safe player pose restoration succeeded")
	
	# Valid restore
	var read_back: Dictionary = adapter.save_service().read_save()
	var restored: bool = adapter.restore(game, read_back)
	verify(restored, "Restored state from saved checkpoint via adapter")
	verify(game.is_session_frozen == true, "Adapter restore freezes world until start()")
	verify(game.has_restored_checkpoint == true, "Restored checkpoint flag set")
	
	# Verify world state resynchronization: brute defeated remains dead
	var brute_resurrected := false
	for e in game.active_enemies:
		if is_instance_valid(e) and str(e.get("enemy_id")) == "chubby_boss":
			brute_resurrected = true
	verify(not brute_resurrected, "Defeated boss is NOT resurrected on restore")
	
	# Resume world after restore
	adapter.start(game)
	verify(game.is_session_frozen == false, "Adapter start unfreezes restored session")
	
	# Requirement 4: Managed Replay / Reset
	game.launcher_restart_requested.connect(func(): signal_tracker["restart"] = true)
	game._restart_mission()
	verify(signal_tracker["restart"], "Managed replay emitted launcher_restart_requested")
	verify(game.player.health == 100.0, "Managed reset restored player health to 100")
	verify(game.player.weapon_controller.mag_ammo == 12, "Managed reset restored pistol magazine to 12")
	verify(game.player.weapon_controller.reserve_ammo == 36, "Managed reset restored pistol reserve to 36")
	verify(game.mission_state.get_current_step().get("id") == "obj_explore", "Managed reset restored mission to first step")
	verify(game.collected_pickups.is_empty(), "Managed reset cleared collected pickups")
	verify(game.defeated_enemies.is_empty(), "Managed reset cleared defeated enemies")
	
	# Requirement 5: Cancellation safeguard completes initialization with cancelled error
	var cancel_game: Node3D = adapter.create_session(res_dict, test_prefs)
	root.add_child(cancel_game)
	adapter.cancel(cancel_game)
	verify(cancel_game.initialization_finished == true, "Cancel completes initialization_finished")
	verify(cancel_game.ready_to_play == false, "Cancel results in ready_to_play == false")
	verify(cancel_game.initialization_error == "Initialization cancelled", "Cancel reports Initialization cancelled error")
	await process_frame
	root.remove_child(cancel_game)
	cancel_game.queue_free()


	
	# Cleanup isolated test save
	adapter.save_service().delete_save()
	verify(not adapter.save_service().has_save(), "Isolated test save cleaned up")
	
	# Capture screenshot if not headless
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var img_path := "res://assets/antigravity/zombie/gameplay_preview.png"
		var abs_img_path := ProjectSettings.globalize_path(img_path)
		img.save_png(abs_img_path)
		print("Saved gameplay preview screenshot to ", abs_img_path)
	
	print("\n=== INTEGRATION TEST SUMMARY ===")
	print("Total Checks: ", report["checks"], " Passed: ", report["passed"], " Failures: ", report["failures"].size())
	
	# Allow queued deletions to flush cleanly before tree quit
	await process_frame
	await process_frame
	quit(0 if report["passed"] else 1)


