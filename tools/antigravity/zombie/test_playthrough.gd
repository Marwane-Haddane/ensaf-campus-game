extends SceneTree
## Full Playthrough and Scenario Verification for Zombie RPG: After Hours (ZB-2026-001)
## Steps through all 7 mission checkpoints in real-time and captures validation snapshots.

var report := {
	"total_checks": 0,
	"passed_checks": 0,
	"failures": [],
	"checkpoints_verified": []
}

func check(condition: bool, label: String) -> void:
	report.total_checks += 1
	if condition:
		report.passed_checks += 1
		print("[PASS] ", label)
	else:
		report.failures.append(label)
		printerr("[FAIL] ", label)

func _init() -> void:
	call_deferred("_run_playthrough")

func _run_playthrough() -> void:
	root.size = Vector2i(1280, 720)
	print("=== Starting Zombie RPG Playthrough Scenario Verification ===")
	
	var scene_path := "res://scenes/antigravity/zombie/zombie_game.tscn"
	var game_scene: PackedScene = load(scene_path)
	check(game_scene != null, "Zombie game root scene loaded")
	if not game_scene:
		quit(1)
		return

	var game: Node3D = game_scene.instantiate() as Node3D
	game.set("launcher_managed", false)
	root.add_child(game)

	# 1. Wait for campus build and initialization
	var timeout := 0
	while not bool(game.get("initialization_finished")) and timeout < 1000:
		await process_frame
		timeout += 1

	check(bool(game.get("ready_to_play")), "Episode initialized and ready to play")

	for i in range(10):
		await process_frame

	var photos_dir := "res://tools/antigravity/zombie/photos/"
	var out_dir: String = ProjectSettings.globalize_path(photos_dir)

	# ── Checkpoint 1: Plaza Arrival ──────────────────────────────────────────
	report.checkpoints_verified.append("cp_start")
	check(game.mission_state.current_step_index == 0, "Mission starts at step 0 (Explore)")
	_capture(root, out_dir + "01_playthrough_plaza.png")

	# ── Checkpoint 2: Scavenge Fuse ──────────────────────────────────────────
	game.inventory.add_item("item_power_fuse", 1)
	game.collected_pickups.append("item_power_fuse")
	game.mission_state.on_event("pickup_item", {"item_id": "item_power_fuse"})
	game._create_checkpoint("cp_fuse", "Main Breaker Fuse Retrieved")
	report.checkpoints_verified.append("cp_fuse")
	check(game.inventory.has_item("item_power_fuse"), "Main Breaker Fuse in inventory")
	check(game.mission_state.current_step_index >= 1, "Mission advanced after Fuse retrieval")
	await process_frame
	_capture(root, out_dir + "02_playthrough_fuse.png")

	# ── Checkpoint 3: Scavenge Relay ─────────────────────────────────────────
	game.inventory.add_item("item_power_relay", 1)
	game.collected_pickups.append("item_power_relay")
	game.mission_state.on_event("pickup_item", {"item_id": "item_power_relay"})
	game._create_checkpoint("cp_relay", "Control Bus Relay Retrieved")
	report.checkpoints_verified.append("cp_relay")
	check(game.inventory.has_item("item_power_relay"), "Control Bus Relay in inventory")
	check(game.mission_state.current_step_index >= 3, "Both items found; ready for breaker panel")
	await process_frame
	_capture(root, out_dir + "03_playthrough_relay.png")

	# ── Checkpoint 4: Security Substation Power Restored ─────────────────────
	game.mission_state.on_event("power_restored")
	game._create_checkpoint("cp_power", "Campus Power Restored")
	report.checkpoints_verified.append("cp_power")
	check(game.mission_state.current_step_index == 4, "Power restored; advanced to Shaun objective")
	await process_frame
	_capture(root, out_dir + "04_playthrough_power.png")

	# ── Checkpoint 5: Shaun Interaction ──────────────────────────────────────
	game.mission_state.on_event("talk_survivor")
	game._create_checkpoint("cp_shaun", "Survivor Shaun Contacted")
	report.checkpoints_verified.append("cp_shaun")
	check(game.mission_state.current_step_index == 5, "Shaun dialogue complete; advanced to Brute encounter")
	await process_frame
	_capture(root, out_dir + "05_playthrough_survivor.png")

	# ── Checkpoint 6: Heavy Brute Boss Defeated ──────────────────────────────
	game.mission_state.on_event("boss_killed")
	game._create_checkpoint("cp_boss", "Chubby Brute Neutralized")
	report.checkpoints_verified.append("cp_boss")
	check(game.mission_state.current_step_index == 6, "Brute defeated; advanced to vehicle extraction")
	await process_frame
	_capture(root, out_dir + "06_playthrough_boss.png")

	# ── Checkpoint 7: Vehicle Extraction & Victory Debrief ───────────────────
	game.mission_state.on_event("reach_extraction")
	game._create_checkpoint("cp_extraction", "Perimeter Gate Extraction")
	report.checkpoints_verified.append("cp_extraction")
	check(game.mission_state.extracted, "Mission successfully completed")
	
	# Let debrief victory modal render
	for i in range(15):
		await process_frame
	_capture(root, out_dir + "07_playthrough_victory.png")

	# Final Save Verification
	var save_file := "user://ensagames/saves/zombie_rpg/checkpoint.json"
	check(FileAccess.file_exists(save_file), "Atomic checkpoint save persisted on disk")

	print("\n=== Playthrough Scenario Summary ===")
	print("Total Checks: ", report.total_checks)
	print("Passed: ", report.passed_checks)
	print("Failures: ", report.failures.size())
	print("Checkpoints Verified: ", report.checkpoints_verified)

	quit(0 if report.failures.is_empty() else 1)

func _capture(vp: Viewport, path: String) -> void:
	RenderingServer.force_draw(false)
	var img := vp.get_texture().get_image()
	if img:
		img.save_png(path)
