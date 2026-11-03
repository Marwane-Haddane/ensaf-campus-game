extends SceneTree
## Challenger M3 Empirical Integration Snippet Test Harness
## Adversarially challenges:
## 1. Exact 8-line proposed integration snippet from INTEGRATION.md Section 3 on main.tscn
## 2. Runtime uninstallation snippet from STATUS.md Section 5
## 3. Secondary uninstallation safety (calling uninstall when node is null or already uninstalled)
## 4. Re-installation lifecycle roundtrip
## 5. Fault-tolerance with missing script (simulated path & temporary file absence)
## 6. Fault-tolerance on unready game target

const REPORT_PATH: String = "res://tools/antigravity/challenger_m3_snippet_report.json"
const POLISH_SCRIPT_PATH: String = "res://scripts/antigravity/environment_polish.gd"

var game: Node3D = null
var sun_node: DirectionalLight3D = null
var world_env_node: WorldEnvironment = null
var baseline_sun_normal_bias: float = 2.0
var baseline_ambient_energy: float = 0.32

var results: Dictionary = {
	"timestamp": "",
	"passed": false,
	"total_assertions": 0,
	"passed_assertions": 0,
	"failed_assertions": 0,
	"failures": [],
	"suites": {}
}


func _init() -> void:
	call_deferred("_run_all_challenger_tests")


func assert_true(condition: bool, suite_name: String, check_name: String, details: Variant = null) -> bool:
	results["total_assertions"] += 1
	if not results["suites"].has(suite_name):
		results["suites"][suite_name] = {"passed": 0, "failed": 0, "checks": []}
	
	if condition:
		results["passed_assertions"] += 1
		results["suites"][suite_name]["passed"] += 1
		results["suites"][suite_name]["checks"].append({"check": check_name, "status": "PASS"})
		return true
	else:
		results["failed_assertions"] += 1
		results["suites"][suite_name]["failed"] += 1
		var failure_entry: Dictionary = {
			"suite": suite_name,
			"check": check_name,
			"details": str(details)
		}
		results["suites"][suite_name]["checks"].append({"check": check_name, "status": "FAIL", "details": str(details)})
		results["failures"].append(failure_entry)
		push_error("[CHALLENGER_M3_FAIL] [%s] %s: %s" % [suite_name, check_name, str(details)])
		print("[CHALLENGER_M3_FAIL] [%s] %s: %s" % [suite_name, check_name, str(details)])
		return false


func _run_all_challenger_tests() -> void:
	results["timestamp"] = Time.get_datetime_string_from_system(true)
	print("=================================================================")
	print(" STARTING CHALLENGER M3 EMPIRICAL SNIPPET & INTEGRATION TEST")
	print("=================================================================")

	# 1. Instantiate Game Scene
	root.size = Vector2i(1280, 720)
	var scene_res: PackedScene = load("res://main.tscn")
	if not assert_true(scene_res != null, "SETUP", "Load res://main.tscn"):
		_finish()
		return

	game = scene_res.instantiate() as Node3D
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)

	# 2. Wait for ready_to_play
	var start_wait: int = Time.get_ticks_msec()
	while not game.ready_to_play and (Time.get_ticks_msec() - start_wait) < 120000:
		await process_frame

	if not assert_true(game.ready_to_play, "SETUP", "Game reached ready_to_play", "elapsed %d ms" % (Time.get_ticks_msec() - start_wait)):
		_finish()
		return

	# Settle frame
	await physics_frame
	await process_frame

	# In headless mode, main.gd:_setup_environment() returns early.
	# If running headless, ensure standard DirectionalLight3D and WorldEnvironment exist with production baseline values
	for child in game.get_children():
		if child is DirectionalLight3D:
			sun_node = child as DirectionalLight3D
		elif child is WorldEnvironment:
			world_env_node = child as WorldEnvironment

	if sun_node == null:
		sun_node = DirectionalLight3D.new()
		sun_node.name = "DirectionalLight3D"
		sun_node.rotation_degrees = Vector3(-45, -30, 0)
		sun_node.light_color = Color("fff0d5")
		sun_node.light_energy = 0.32
		sun_node.shadow_enabled = true
		sun_node.shadow_bias = 0.12
		sun_node.shadow_normal_bias = 2.0
		sun_node.shadow_blur = 1.4
		sun_node.directional_shadow_blend_splits = true
		game.add_child(sun_node)

	if world_env_node == null:
		world_env_node = WorldEnvironment.new()
		world_env_node.name = "WorldEnvironment"
		var env := Environment.new()
		env.ambient_light_energy = 0.32
		env.tonemap_exposure = 0.92
		world_env_node.environment = env
		game.add_child(world_env_node)

	assert_true(sun_node != null, "SETUP", "DirectionalLight3D sun node active")
	assert_true(world_env_node != null, "SETUP", "WorldEnvironment node active")
	baseline_sun_normal_bias = sun_node.shadow_normal_bias
	baseline_ambient_energy = world_env_node.environment.ambient_light_energy
	print("BASELINE SUN normal_bias: ", baseline_sun_normal_bias)
	print("BASELINE ENV ambient_energy: ", baseline_ambient_energy)

	# =================================================================
	# SUITE 1: Test Exact Proposed 8-Line Integration Snippet
	# =================================================================
	print("\n--- SUITE 1: EXACT PROPOSED 8-LINE SNIPPET ---")
	
	# Verify initial state
	assert_true(game.get_node_or_null("AntigravityEnvironmentPolish") == null, "SUITE_1", "Polish node initially absent")
	assert_true(not game.has_meta("antigravity_polish_installed"), "SUITE_1", "Meta initially absent")

	# EXACT SNIPPET EXECUTION
	var snippet_stats: Dictionary = {}
	var snippet_executed: bool = false
	
	# BEGIN EXACT 8-LINE SNIPPET (as in INTEGRATION.md Section 3)
	if ResourceLoader.exists("res://scripts/antigravity/environment_polish.gd"):
		var polish_script: GDScript = load("res://scripts/antigravity/environment_polish.gd")
		var polish_node: Node3D = polish_script.new()
		polish_node.name = "AntigravityEnvironmentPolish"
		game.add_child(polish_node)
		var polish_stats: Dictionary = polish_node.install(game)
		print("ANTIGRAVITY_POLISH_READY: ", polish_stats.get("installed", false))
		snippet_stats = polish_stats
		snippet_executed = true
	# END EXACT 8-LINE SNIPPET

	assert_true(snippet_executed, "SUITE_1", "Snippet condition met and executed")
	assert_true(snippet_stats.get("installed", false) == true, "SUITE_1", "Snippet returned installed == true")
	assert_true(snippet_stats.get("already_installed", true) == false, "SUITE_1", "First install is not redundant")

	var installed_polish: Node = game.get_node_or_null("AntigravityEnvironmentPolish")
	assert_true(installed_polish != null, "SUITE_1", "AntigravityEnvironmentPolish node exists in scene tree")
	assert_true(installed_polish is Node3D, "SUITE_1", "Polish node is Node3D")
	assert_true(installed_polish.has_method("is_installed") and installed_polish.call("is_installed") == true, "SUITE_1", "polish.is_installed() is true")
	assert_true(game.has_meta("antigravity_polish_installed") and game.get_meta("antigravity_polish_installed") == true, "SUITE_1", "Game meta flag set")

	# Verify injected nodes
	var canopy_light: Node = game.get_node_or_null("CanopyEntranceDownlight")
	assert_true(canopy_light != null and canopy_light is SpotLight3D, "SUITE_1", "Canopy downlight injected as SpotLight3D")
	var signage: Node = game.get_node_or_null("CreamEntranceSignage")
	assert_true(signage != null, "SUITE_1", "Cream entrance signage injected")

	# Verify sun parameters tuned
	if sun_node != null:
		assert_true(is_equal_approx(sun_node.shadow_normal_bias, 0.80), "SUITE_1", "Sun normal bias tuned to 0.80", "current: %f" % sun_node.shadow_normal_bias)

	# Verify resource counts
	var rc: Dictionary = snippet_stats.get("resource_counts", {})
	assert_true(rc.get("materials_duplicated", 0) > 0, "SUITE_1", "Materials duplicated > 0", rc.get("materials_duplicated", 0))
	assert_true(rc.get("lights_tuned", 0) >= 1, "SUITE_1", "Lights tuned >= 1", rc.get("lights_tuned", 0))
	assert_true(rc.get("environments_tuned", 0) >= 1, "SUITE_1", "Environments tuned >= 1", rc.get("environments_tuned", 0))

	# =================================================================
	# SUITE 2: Redundant Snippet Execution (Idempotency Challenge)
	# =================================================================
	print("\n--- SUITE 2: REDUNDANT SNIPPET EXECUTION (IDEMPOTENCY) ---")
	
	var redundant_stats: Dictionary = {}
	var redundant_node: Node3D = null
	# Execute snippet a second time while already installed
	if ResourceLoader.exists("res://scripts/antigravity/environment_polish.gd"):
		var polish_script2: GDScript = load("res://scripts/antigravity/environment_polish.gd")
		redundant_node = polish_script2.new()
		redundant_node.name = "AntigravityEnvironmentPolish2"
		game.add_child(redundant_node)
		redundant_stats = redundant_node.install(game)
		print("ANTIGRAVITY_POLISH_REDUNDANT: ", redundant_stats.get("installed", false))

	assert_true(redundant_stats.get("installed", false) == true, "SUITE_2", "Redundant install returns installed == true")
	assert_true(redundant_stats.get("already_installed", false) == true, "SUITE_2", "Redundant install flags already_installed == true")
	
	# Cleanup redundant second node
	if redundant_node != null and is_instance_valid(redundant_node):
		redundant_node.queue_free()
	await process_frame

	# =================================================================
	# SUITE 3: Runtime Uninstallation Snippet Execution
	# =================================================================
	print("\n--- SUITE 3: RUNTIME UNINSTALLATION SNIPPET ---")

	# EXACT DOCUMENTED UNINSTALLATION SNIPPET (as in STATUS.md Section 5)
	var polish: Node = game.get_node_or_null("AntigravityEnvironmentPolish")
	var uninstalled_cleanly: bool = false
	if polish != null and polish.has_method("uninstall"):
		var uninst_res: Variant = polish.call("uninstall")
		polish.queue_free()
		uninstalled_cleanly = true
		print("ANTIGRAVITY_POLISH_UNINSTALLED: ", uninst_res)
	# END EXACT UNINSTALLATION SNIPPET

	assert_true(uninstalled_cleanly, "SUITE_3", "Uninstallation snippet found node and called uninstall()")
	
	# Wait 2 frames for queue_free
	await process_frame
	await process_frame

	assert_true(game.get_node_or_null("AntigravityEnvironmentPolish") == null, "SUITE_3", "AntigravityEnvironmentPolish freed from scene tree")
	assert_true(game.get_node_or_null("CanopyEntranceDownlight") == null, "SUITE_3", "Canopy downlight removed")
	assert_true(game.get_node_or_null("CreamEntranceSignage") == null, "SUITE_3", "Cream entrance signage removed")
	assert_true(not game.has_meta("antigravity_polish_installed"), "SUITE_3", "Meta flag removed from game")

	if sun_node != null:
		assert_true(is_equal_approx(sun_node.shadow_normal_bias, baseline_sun_normal_bias), "SUITE_3", "Sun normal bias restored to baseline", "current: %f, baseline: %f" % [sun_node.shadow_normal_bias, baseline_sun_normal_bias])
	if world_env_node != null and world_env_node.environment != null:
		assert_true(is_equal_approx(world_env_node.environment.ambient_light_energy, baseline_ambient_energy), "SUITE_3", "Environment ambient energy restored to baseline", "current: %f, baseline: %f" % [world_env_node.environment.ambient_light_energy, baseline_ambient_energy])

	# =================================================================
	# SUITE 4: Secondary Uninstallation Call Safety
	# =================================================================
	print("\n--- SUITE 4: SECONDARY UNINSTALLATION CALL SAFETY ---")

	var second_uninst_attempt: bool = false
	# Re-execute uninstallation snippet when node is already gone
	var polish2: Node = game.get_node_or_null("AntigravityEnvironmentPolish")
	if polish2 != null and polish2.has_method("uninstall"):
		polish2.call("uninstall")
		polish2.queue_free()
		second_uninst_attempt = true

	assert_true(second_uninst_attempt == false, "SUITE_4", "Secondary uninstallation safely skipped without error when node is absent")
	assert_true(polish2 == null, "SUITE_4", "polish2 was correctly null")

	# =================================================================
	# SUITE 5: Re-Installation Lifecycle Roundtrip
	# =================================================================
	print("\n--- SUITE 5: RE-INSTALLATION LIFECYCLE ROUNDTRIP ---")

	var reinstall_stats: Dictionary = {}
	if ResourceLoader.exists("res://scripts/antigravity/environment_polish.gd"):
		var polish_script3: GDScript = load("res://scripts/antigravity/environment_polish.gd")
		var polish_node3: Node3D = polish_script3.new()
		polish_node3.name = "AntigravityEnvironmentPolish"
		game.add_child(polish_node3)
		reinstall_stats = polish_node3.install(game)
		print("ANTIGRAVITY_POLISH_REINSTALLED: ", reinstall_stats.get("installed", false))

	assert_true(reinstall_stats.get("installed", false) == true, "SUITE_5", "Re-installation returned installed == true")
	assert_true(reinstall_stats.get("already_installed", true) == false, "SUITE_5", "Re-installation treated as fresh install")
	assert_true(game.get_node_or_null("AntigravityEnvironmentPolish") != null, "SUITE_5", "Re-installed node present")

	# Cleanly uninstall before fault-tolerance tests
	var p_cleanup: Node = game.get_node_or_null("AntigravityEnvironmentPolish")
	if p_cleanup != null and p_cleanup.has_method("uninstall"):
		p_cleanup.call("uninstall")
		p_cleanup.queue_free()
	await process_frame
	await process_frame

	# =================================================================
	# SUITE 6: Fault-Tolerance & Missing Script Simulation
	# =================================================================
	print("\n--- SUITE 6: FAULT TOLERANCE & MISSING SCRIPT SIMULATION ---")

	# 6.1 Check non-existent path
	var non_existent_path: String = "res://scripts/antigravity/non_existent_environment_polish.gd"
	var exists_fake: bool = ResourceLoader.exists(non_existent_path)
	assert_true(not exists_fake, "SUITE_6", "ResourceLoader.exists returns false for non-existent path")

	var fake_snippet_executed: bool = false
	if ResourceLoader.exists(non_existent_path):
		fake_snippet_executed = true
		var s: GDScript = load(non_existent_path)
		var n: Node3D = s.new()
		n.name = "AntigravityEnvironmentPolish"
		game.add_child(n)
		n.install(game)

	assert_true(not fake_snippet_executed, "SUITE_6", "Snippet guarded by ResourceLoader.exists does not execute when path is missing")
	assert_true(game.get_node_or_null("AntigravityEnvironmentPolish") == null, "SUITE_6", "Game tree remains clean after simulated missing script")

	# 6.2 Temporary disk-level script rename test
	var da: DirAccess = DirAccess.open("res://scripts/antigravity")
	if assert_true(da != null, "SUITE_6", "Can access res://scripts/antigravity"):
		var rename_err: Error = da.rename("environment_polish.gd", "environment_polish.gd.challenger_bak")
		if assert_true(rename_err == OK, "SUITE_6", "Temporarily renamed environment_polish.gd to test disk absence"):
			
			var disk_exists: bool = FileAccess.file_exists("res://scripts/antigravity/environment_polish.gd")
			assert_true(not disk_exists, "SUITE_6", "FileAccess confirms environment_polish.gd is absent from disk")

			var fallback_executed: bool = false
			if FileAccess.file_exists("res://scripts/antigravity/environment_polish.gd") and ResourceLoader.exists("res://scripts/antigravity/environment_polish.gd"):
				fallback_executed = true
				var script_missing: GDScript = load("res://scripts/antigravity/environment_polish.gd")
				var node_missing: Node3D = script_missing.new()
				node_missing.name = "AntigravityEnvironmentPolish"
				game.add_child(node_missing)
				node_missing.install(game)

			assert_true(not fallback_executed, "SUITE_6", "Snippet safely skipped when file is missing from disk")
			assert_true(game.get_node_or_null("AntigravityEnvironmentPolish") == null, "SUITE_6", "No node added when script missing")

			# RESTORE FILE IMMEDIATELY
			var restore_err: Error = da.rename("environment_polish.gd.challenger_bak", "environment_polish.gd")
			assert_true(restore_err == OK, "SUITE_6", "environment_polish.gd restored to original location")
			assert_true(FileAccess.file_exists("res://scripts/antigravity/environment_polish.gd"), "SUITE_6", "Restored file verified on disk")

	# =================================================================
	# SUITE 7: Fault-Tolerance on Unready Game Target
	# =================================================================
	print("\n--- SUITE 7: FAULT TOLERANCE ON UNREADY TARGET ---")

	var unready_game := Node3D.new()
	var unready_script: GDScript = load(POLISH_SCRIPT_PATH)
	var unready_polish: Node3D = unready_script.new()
	unready_game.add_child(unready_polish)
	
	var unready_stats: Dictionary = unready_polish.install(unready_game)
	assert_true(unready_stats.get("installed", true) == false, "SUITE_7", "install() on unready game rejected cleanly")
	assert_true(unready_stats.has("errors") and unready_stats["errors"].size() > 0, "SUITE_7", "install() returns error message on unready target", unready_stats.get("errors", []))
	
	unready_polish.queue_free()
	unready_game.queue_free()

	_finish()


func _finish() -> void:
	results["passed"] = (results["failed_assertions"] == 0 and results["total_assertions"] > 0)
	print("\n=================================================================")
	print(" CHALLENGER M3 TEST SUITE FINISHED")
	print(" Passed: %s" % str(results["passed"]))
	print(" Assertions Total: %d | Passed: %d | Failed: %d" % [
		results["total_assertions"],
		results["passed_assertions"],
		results["failed_assertions"]
	])
	print("=================================================================")

	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(results, "\t"))
		file.close()
		print("REPORT WRITTEN TO: %s" % REPORT_PATH)
	else:
		push_error("Failed to write report to %s" % REPORT_PATH)

	if results["passed"]:
		quit(0)
	else:
		quit(1)
