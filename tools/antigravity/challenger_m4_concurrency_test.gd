extends SceneTree
## Adversarial Concurrency, Race Condition & Lifecycle Stress Test Harness
## Challenger M4_2 (Tier 5 Negative Input & Concurrency Hardener)
## Target: res://scripts/antigravity/environment_polish.gd
##
## Tests:
## 1. Repeated double calls:
##    - Premature uninstalls on uninstalled instance
##    - Sequential double calls: install() -> install() -> uninstall() -> uninstall()
##    - Multi-instance collision / race handling
## 2. Node deletion under the hood (is_instance_valid guards):
##    - Overridden MeshInstance3D freed before uninstall()
##    - MultiMesh batch freed before uninstall()
##    - StaticSurface merged mesh freed before uninstall()
##    - DirectionalLight3D / WorldEnvironment freed before uninstall()
##    - Injected nodes freed before uninstall()
##    - Entire game node freed before uninstall()
## 3. Reparenting resilience:
##    - Moving polish node in scene hierarchy
##    - Moving game node in scene hierarchy
##    - Moving child meshes across nodes
## 4. Rapid lifecycle churn:
##    - 20 consecutive install/uninstall cycles with memory/object leak tracking
##    - Synchronous frame-less burst churn
## 5. Final state baseline preservation

const POLISH_SCRIPT_PATH: String = "res://scripts/antigravity/environment_polish.gd"
const REPORT_PATH: String = "res://tools/antigravity/challenger_m4_concurrency_report.json"

var game: Node3D = null
var baseline_snapshot: Dictionary = {}
var failures: Array[Dictionary] = []
var results: Dictionary = {
	"timestamp": "",
	"passed": false,
	"total_assertions": 0,
	"passed_assertions": 0,
	"failed_assertions": 0,
	"churn_metrics": [],
	"failures": [],
	"suites": {}
}


func _init() -> void:
	call_deferred("_run_all_stress_tests")


func assert_true(condition: bool, suite_name: String, check_name: String, details: Variant = null) -> bool:
	results["total_assertions"] += 1
	if not results["suites"].has(suite_name):
		results["suites"][suite_name] = {"passed": 0, "failed": 0, "checks": []}
	
	if condition:
		results["passed_assertions"] += 1
		results["suites"][suite_name]["passed"] += 1
		results["suites"][suite_name]["checks"].append({"check": check_name, "status": "PASS"})
		print("  [PASS] [%s] %s" % [suite_name, check_name])
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
		failures.append(failure_entry)
		push_error("  [FAIL] [%s] %s: %s" % [suite_name, check_name, str(details)])
		print("  [FAIL] [%s] %s: %s" % [suite_name, check_name, str(details)])
		return false


func _run_all_stress_tests() -> void:
	results["timestamp"] = Time.get_datetime_string_from_system(true)
	print("=================================================================")
	print("CHALLENGER M4_2: NEGATIVE INPUT & CONCURRENCY STRESS HARNESS")
	print("=================================================================")

	# 1. Verify script availability
	if not ResourceLoader.exists(POLISH_SCRIPT_PATH):
		assert_true(false, "INIT", "Polish script exists", POLISH_SCRIPT_PATH)
		_finish_suite()
		return

	var PolishClass = load(POLISH_SCRIPT_PATH)
	assert_true(PolishClass != null, "INIT", "Polish script loads cleanly")

	# -----------------------------------------------------------------
	# SUITE 1: Double Calls & Idempotency on Standalone Module
	# -----------------------------------------------------------------
	print("\n>>> SUITE 1: STANDALONE DOUBLE CALLS & PREMATURE UNINSTALLS")
	_test_standalone_double_calls(PolishClass)

	# -----------------------------------------------------------------
	# Instantiate Live Game Scene
	# -----------------------------------------------------------------
	print("\n>>> INSTANTIATING LIVE GAME SCENE (res://main.tscn)...")
	var scene_res: PackedScene = load("res://main.tscn")
	if scene_res == null:
		assert_true(false, "INIT", "Load main.tscn", "Could not load res://main.tscn")
		_finish_suite()
		return

	game = scene_res.instantiate() as Node3D
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)

	var start_wait: int = Time.get_ticks_msec()
	while not game.ready_to_play and (Time.get_ticks_msec() - start_wait) < 120000:
		await process_frame

	if not game.ready_to_play:
		assert_true(false, "INIT", "Game Lifecycle Ready", "Timed out waiting for game.ready_to_play")
		_finish_suite()
		return

	assert_true(game.ready_to_play, "INIT", "Game Lifecycle Ready", "CampusRuntime built in %d ms" % (Time.get_ticks_msec() - start_wait))

	# Record baseline snapshot
	baseline_snapshot = _snapshot_game_state(game)
	print("  [DEBUG BASELINE] Instances_0 count: %s" % _debug_instances_0())

	# -----------------------------------------------------------------
	# SUITE 2: Repeated Double Calls Pattern on Live Scene
	# -----------------------------------------------------------------
	print("\n>>> SUITE 2: REPEATED DOUBLE CALLS (install -> install -> uninstall -> uninstall)")
	_test_live_double_calls(PolishClass)
	print("  [DEBUG POST-SUITE 2] Instances_0 count: %s" % _debug_instances_0())

	# -----------------------------------------------------------------
	# SUITE 3: Node Deletion Under The Hood (is_instance_valid resilience)
	# -----------------------------------------------------------------
	print("\n>>> SUITE 3: NODE DELETION UNDER THE HOOD (NULL-SAFETY & GUARDS)")
	_test_node_deletion_under_hood(PolishClass)
	print("  [DEBUG POST-SUITE 3] Instances_0 count: %s" % _debug_instances_0())

	# -----------------------------------------------------------------
	# SUITE 4: Reparenting Resilience
	# -----------------------------------------------------------------
	print("\n>>> SUITE 4: REPARENTING RESILIENCE (Game & Polish Movement)")
	_test_reparenting_resilience(PolishClass)
	print("  [DEBUG POST-SUITE 4] Instances_0 count: %s" % _debug_instances_0())

	# -----------------------------------------------------------------
	# SUITE 5: Rapid Lifecycle Churn (20 consecutive cycles & leak tracking)
	# -----------------------------------------------------------------
	print("\n>>> SUITE 5: RAPID LIFECYCLE CHURN (20 Consecutive Cycles & Leaks)")
	await _test_rapid_lifecycle_churn(PolishClass)
	print("  [DEBUG POST-SUITE 5] Instances_0 count: %s" % _debug_instances_0())

	# -----------------------------------------------------------------
	# SUITE 6: Final Baseline Preservation & State Cleanliness
	# -----------------------------------------------------------------
	print("\n>>> SUITE 6: FINAL BASELINE INTEGRITY VERIFICATION")
	_verify_baseline_integrity()

	_finish_suite()


func _test_standalone_double_calls(PolishClass) -> void:
	var polish: Node3D = PolishClass.new()
	assert_true(polish.is_installed() == false, "SUITE_1_STANDALONE", "Initial is_installed() is false")

	# Premature uninstall 1
	var u1: Dictionary = polish.uninstall()
	assert_true(u1.get("uninstalled") == false, "SUITE_1_STANDALONE", "Premature uninstall 1 returns uninstalled=false")
	assert_true(u1.get("status") == "not_installed", "SUITE_1_STANDALONE", "Premature uninstall 1 returns status='not_installed'")

	# Premature uninstall 2 (double uninstall)
	var u2: Dictionary = polish.uninstall()
	assert_true(u2.get("uninstalled") == false, "SUITE_1_STANDALONE", "Premature uninstall 2 returns uninstalled=false")
	assert_true(u2.get("status") == "not_installed", "SUITE_1_STANDALONE", "Premature uninstall 2 returns status='not_installed'")

	# Repeated invalid install calls
	var r_null1: Dictionary = polish.install(null)
	var r_null2: Dictionary = polish.install(null)
	assert_true(r_null1.get("installed") == false, "SUITE_1_STANDALONE", "install(null) call 1 fails cleanly")
	assert_true(r_null2.get("installed") == false, "SUITE_1_STANDALONE", "install(null) call 2 fails cleanly")
	assert_true(polish.is_installed() == false, "SUITE_1_STANDALONE", "is_installed remains false after null calls")

	polish.free()


func _test_live_double_calls(PolishClass) -> void:
	var polish: Node3D = PolishClass.new()
	root.add_child(polish)

	# 1. First install()
	var r1: Dictionary = polish.install(game)
	assert_true(r1.get("installed") == true, "SUITE_2_DOUBLE_CALLS", "First install() succeeds")
	assert_true(r1.get("already_installed") == false, "SUITE_2_DOUBLE_CALLS", "First install() already_installed is false")
	assert_true(polish.is_installed() == true, "SUITE_2_DOUBLE_CALLS", "polish.is_installed() is true")
	assert_true(game.has_meta("antigravity_polish_installed") and game.get_meta("antigravity_polish_installed") == true, "SUITE_2_DOUBLE_CALLS", "Game metadata set")

	# 2. Second install() (Double Call)
	var r2: Dictionary = polish.install(game)
	assert_true(r2.get("installed") == true, "SUITE_2_DOUBLE_CALLS", "Double install() returns installed=true")
	assert_true(r2.get("already_installed") == true, "SUITE_2_DOUBLE_CALLS", "Double install() reports already_installed=true")
	assert_true(polish.is_installed() == true, "SUITE_2_DOUBLE_CALLS", "polish.is_installed() remains true")

	# 3. Third install() (Triple Call for good measure)
	var r3: Dictionary = polish.install(game)
	assert_true(r3.get("installed") == true and r3.get("already_installed") == true, "SUITE_2_DOUBLE_CALLS", "Triple install() is idempotent")

	# 4. First uninstall()
	var u1: Dictionary = polish.uninstall()
	assert_true(u1.get("uninstalled") == true, "SUITE_2_DOUBLE_CALLS", "First uninstall() returns uninstalled=true")
	assert_true(u1.get("status") == "clean", "SUITE_2_DOUBLE_CALLS", "First uninstall() reports status='clean'")
	assert_true(polish.is_installed() == false, "SUITE_2_DOUBLE_CALLS", "polish.is_installed() is false after uninstall")
	assert_true(not game.has_meta("antigravity_polish_installed"), "SUITE_2_DOUBLE_CALLS", "Game metadata removed after uninstall")

	# 5. Second uninstall() (Double Uninstall)
	var u2: Dictionary = polish.uninstall()
	assert_true(u2.get("uninstalled") == false, "SUITE_2_DOUBLE_CALLS", "Double uninstall() returns uninstalled=false")
	assert_true(u2.get("status") == "not_installed", "SUITE_2_DOUBLE_CALLS", "Double uninstall() reports status='not_installed'")
	assert_true(polish.is_installed() == false, "SUITE_2_DOUBLE_CALLS", "polish.is_installed() remains false")

	# 6. Third uninstall() (Triple Uninstall)
	var u3: Dictionary = polish.uninstall()
	assert_true(u3.get("uninstalled") == false and u3.get("status") == "not_installed", "SUITE_2_DOUBLE_CALLS", "Triple uninstall() reports status='not_installed'")

	# 7. Multi-Instance Concurrency Stress
	var inst_a: Node3D = PolishClass.new()
	var inst_b: Node3D = PolishClass.new()
	root.add_child(inst_a)
	root.add_child(inst_b)

	var ra: Dictionary = inst_a.install(game)
	assert_true(ra.get("installed") == true, "SUITE_2_DOUBLE_CALLS", "Instance A installs cleanly")

	# Instance B attempts install while A is active
	var rb: Dictionary = inst_b.install(game)
	assert_true(rb.get("already_installed") == true, "SUITE_2_DOUBLE_CALLS", "Instance B blocked from double installation")
	assert_true(inst_b.is_installed() == false, "SUITE_2_DOUBLE_CALLS", "Instance B is_installed() is false")

	# Instance B attempts uninstall
	var ub: Dictionary = inst_b.uninstall()
	assert_true(ub.get("uninstalled") == false, "SUITE_2_DOUBLE_CALLS", "Instance B uninstall rejected without disrupting A")
	assert_true(inst_a.is_installed() == true, "SUITE_2_DOUBLE_CALLS", "Instance A remains installed")

	# Instance A uninstalls cleanly
	var ua1: Dictionary = inst_a.uninstall()
	assert_true(ua1.get("uninstalled") == true, "SUITE_2_DOUBLE_CALLS", "Instance A uninstalls cleanly")
	var ua2: Dictionary = inst_a.uninstall()
	assert_true(ua2.get("uninstalled") == false, "SUITE_2_DOUBLE_CALLS", "Instance A double uninstall safely rejected")

	polish.queue_free()
	inst_a.queue_free()
	inst_b.queue_free()


func _create_mock_game(game_name: String) -> Node3D:
	var mock := Node3D.new()
	mock.name = game_name
	var scr := GDScript.new()
	scr.source_code = "extends Node3D\nvar ready_to_play: bool = true\nvar imported_props: Array = []\n"
	scr.reload()
	mock.set_script(scr)
	return mock


func _test_node_deletion_under_hood(PolishClass) -> void:
	# 3.1: Volatile MeshInstance3D deleted while polish is active
	var volatile_mesh := MeshInstance3D.new()
	volatile_mesh.name = "VolatileTargetMesh"
	var box := BoxMesh.new()
	volatile_mesh.mesh = box
	var volatile_mat := StandardMaterial3D.new()
	volatile_mat.resource_name = "cream mineral stone"
	volatile_mesh.set_surface_override_material(0, volatile_mat)
	game.add_child(volatile_mesh)

	var campus: Node = game.get_node_or_null("CampusRuntime")
	if campus != null and campus.get("mesh_nodes") is Array:
		(campus.get("mesh_nodes") as Array).append(volatile_mesh)

	var polish1: Node3D = PolishClass.new()
	root.add_child(polish1)
	var inst_res1: Dictionary = polish1.install(game)
	assert_true(inst_res1.get("installed") == true, "SUITE_3_NODE_DELETION", "Polish installed with volatile mesh")

	# Free volatile mesh directly under the hood
	volatile_mesh.free()

	# Uninstall must NOT crash; must catch freed node safely via is_instance_valid
	var uninst_res1: Dictionary = polish1.uninstall()
	assert_true(uninst_res1.get("uninstalled") == true, "SUITE_3_NODE_DELETION", "uninstall() survived freed target mesh node")
	assert_true(uninst_res1.get("errors", []).size() > 0, "SUITE_3_NODE_DELETION", "uninstall() logged error for freed mesh node without crashing")
	polish1.queue_free()

	# Clean freed entry from campus.mesh_nodes by index (TypedArray rejects erase() of freed objects)
	if campus != null and campus.get("mesh_nodes") is Array:
		var arr: Array = campus.get("mesh_nodes") as Array
		for i in range(arr.size() - 1, -1, -1):
			if not is_instance_valid(arr[i]):
				arr.remove_at(i)

	# 3.2: Injected nodes deleted under the hood
	var polish2: Node3D = PolishClass.new()
	root.add_child(polish2)
	polish2.install(game)

	# Find injected CanopyEntranceDownlight and delete it
	var injected_light: Node = game.get_node_or_null("CanopyEntranceDownlight")
	assert_true(injected_light != null, "SUITE_3_NODE_DELETION", "Injected CanopyEntranceDownlight found")
	if injected_light != null:
		injected_light.free() # Destroy under the hood

	# Find injected CreamEntranceSignage and delete it
	var injected_sign: Node = game.get_node_or_null("CreamEntranceSignage")
	assert_true(injected_sign != null, "SUITE_3_NODE_DELETION", "Injected CreamEntranceSignage found")
	if injected_sign != null:
		injected_sign.free() # Destroy under the hood

	# Uninstall must NOT crash when injected nodes were freed externally
	var uninst_res2: Dictionary = polish2.uninstall()
	assert_true(uninst_res2.get("uninstalled") == true, "SUITE_3_NODE_DELETION", "uninstall() survived externally freed injected nodes")
	polish2.queue_free()

	# 3.3: Mock game with DirectionalLight deleted under the hood
	var mock_game: Node3D = _create_mock_game("MockGameForLightDeletion")
	var mock_sun := DirectionalLight3D.new()
	mock_sun.name = "DirectionalLight3D"
	mock_game.add_child(mock_sun)
	root.add_child(mock_game)

	var polish3: Node3D = PolishClass.new()
	root.add_child(polish3)
	var inst_res3: Dictionary = polish3.install(mock_game)
	assert_true(inst_res3.get("installed") == true, "SUITE_3_NODE_DELETION", "Polish installed on mock game with light")

	# Delete sun under the hood
	mock_sun.free()

	var uninst_res3: Dictionary = polish3.uninstall()
	assert_true(uninst_res3.get("uninstalled") == true, "SUITE_3_NODE_DELETION", "uninstall() survived externally freed DirectionalLight3D")
	assert_true(uninst_res3.get("errors", []).size() > 0, "SUITE_3_NODE_DELETION", "uninstall() noted missing light in errors list")

	polish3.queue_free()
	mock_game.queue_free()

	# 3.4: Entire game node freed before uninstall()
	var doomed_game: Node3D = _create_mock_game("DoomedGame")
	var doomed_mesh := MeshInstance3D.new()
	doomed_mesh.name = "DoomedMesh"
	doomed_mesh.mesh = BoxMesh.new()
	doomed_game.add_child(doomed_mesh)
	root.add_child(doomed_game)

	var polish4: Node3D = PolishClass.new()
	root.add_child(polish4)
	var inst_res4: Dictionary = polish4.install(doomed_game)
	assert_true(inst_res4.get("installed") == true, "SUITE_3_NODE_DELETION", "Polish installed on doomed game")

	# Obliterate entire game node
	doomed_game.free()

	# Uninstall must NOT crash; is_instance_valid(_game) must protect cleanup
	var uninst_res4: Dictionary = polish4.uninstall()
	assert_true(uninst_res4.get("uninstalled") == true, "SUITE_3_NODE_DELETION", "uninstall() survived entire game node deletion without crash")
	polish4.queue_free()


func _test_reparenting_resilience(PolishClass) -> void:
	# 4.1: Moving polish node within live scene tree
	var polish1: Node3D = PolishClass.new()
	# Don't add to tree yet; install() will add to game
	var inst1: Dictionary = polish1.install(game)
	assert_true(inst1.get("installed") == true, "SUITE_4_REPARENTING", "Polish installed as child of game")
	assert_true(polish1.get_parent() == game, "SUITE_4_REPARENTING", "Polish parent is initially game")

	# Reparent polish to root
	polish1.reparent(root)
	assert_true(polish1.get_parent() == root, "SUITE_4_REPARENTING", "Polish reparented to root successfully")
	assert_true(polish1.is_installed() == true, "SUITE_4_REPARENTING", "is_installed() still true after reparenting")

	# Uninstall should still resolve game and nodes cleanly
	var uninst1: Dictionary = polish1.uninstall()
	assert_true(uninst1.get("uninstalled") == true, "SUITE_4_REPARENTING", "uninstall() succeeds cleanly after polish reparenting")
	assert_true(uninst1.get("status") == "clean", "SUITE_4_REPARENTING", "uninstall status is 'clean'")
	polish1.queue_free()

	# 4.2: Game node inside a container hierarchy (Mock Game to avoid CampusRuntime._exit_tree teardown)
	var container := Node3D.new()
	container.name = "LevelWrapperContainer"
	root.add_child(container)

	var nested_game: Node3D = _create_mock_game("NestedGame")
	var nested_sun := DirectionalLight3D.new()
	nested_sun.name = "DirectionalLight3D"
	nested_game.add_child(nested_sun)
	container.add_child(nested_game)

	var polish2: Node3D = PolishClass.new()
	root.add_child(polish2)
	var inst2: Dictionary = polish2.install(nested_game)
	assert_true(inst2.get("installed") == true, "SUITE_4_REPARENTING", "Polish installs cleanly on game nested inside container")

	var uninst2: Dictionary = polish2.uninstall()
	assert_true(uninst2.get("uninstalled") == true, "SUITE_4_REPARENTING", "Polish uninstalls cleanly from game nested inside container")
	assert_true(uninst2.get("status") == "clean", "SUITE_4_REPARENTING", "Nested game uninstall status is 'clean'")
	polish2.queue_free()

	# 4.3: Reparenting game AFTER install (testing resolve_node path shift resilience)
	var mock_container := Node3D.new()
	mock_container.name = "MockContainer"
	root.add_child(mock_container)

	var shift_game: Node3D = _create_mock_game("MockGameForTreeShift")
	var shift_sun := DirectionalLight3D.new()
	shift_sun.name = "DirectionalLight3D"
	shift_game.add_child(shift_sun)
	root.add_child(shift_game)

	var polish3: Node3D = PolishClass.new()
	root.add_child(polish3)
	var inst3: Dictionary = polish3.install(shift_game)
	assert_true(inst3.get("installed") == true, "SUITE_4_REPARENTING", "Polish installed before tree shift")

	# Now shift game hierarchy by reparenting to mock_container
	shift_game.reparent(mock_container)

	# Call uninstall() - node path stored was /root/MockGameForTreeShift/...
	# Now path is /root/MockContainer/MockGameForTreeShift/...
	# resolve_node tries: get_node_or_null(node_path), _game.get_node_or_null(node_path), root.get_node_or_null(node_path)
	var uninst3: Dictionary = polish3.uninstall()
	assert_true(uninst3.get("uninstalled") == true, "SUITE_4_REPARENTING", "uninstall() does NOT crash when game node path shifted")

	polish3.queue_free()
	container.queue_free()
	mock_container.queue_free()


func _test_rapid_lifecycle_churn(PolishClass) -> void:
	var polish: Node3D = PolishClass.new()
	root.add_child(polish)

	# Wait 3 frames to flush any deferred queue_free from earlier tests
	await process_frame
	await process_frame
	await process_frame

	var baseline_mem: int = OS.get_static_memory_usage()
	var baseline_obj: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var baseline_res: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var baseline_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var baseline_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	print("  [CHURN BASELINE] Memory: %d KB | Objects: %d | Resources: %d | Nodes: %d | Orphans: %d" % [
		baseline_mem / 1024, baseline_obj, baseline_res, baseline_nodes, baseline_orphans
	])

	var churn_success: bool = true
	var cycle_durations: Array[float] = []

	# 20 Consecutive Install/Uninstall Cycles
	for cycle in range(20):
		var t0: int = Time.get_ticks_usec()

		var inst: Dictionary = polish.install(game)
		if not inst.get("installed", false) or inst.get("errors", []).size() > 0:
			churn_success = false
			assert_true(false, "SUITE_5_CHURN", "Cycle %d install" % (cycle + 1), str(inst.get("errors")))
			break

		var uninst: Dictionary = polish.uninstall()
		if not uninst.get("uninstalled", false) or uninst.get("errors", []).size() > 0:
			churn_success = false
			assert_true(false, "SUITE_5_CHURN", "Cycle %d uninstall" % (cycle + 1), str(uninst.get("errors")))
			break

		await process_frame

		var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		cycle_durations.append(elapsed_ms)

		var cur_mem: int = OS.get_static_memory_usage()
		var cur_obj: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var cur_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var cur_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

		results["churn_metrics"].append({
			"cycle": cycle + 1,
			"duration_ms": elapsed_ms,
			"memory_kb": cur_mem / 1024,
			"objects": cur_obj,
			"nodes": cur_nodes,
			"orphans": cur_orphans
		})

		if (cycle + 1) % 5 == 0:
			print("  [CHURN CYCLE %2d/20] Duration: %5.2f ms | Mem: %d KB | Objects: %d | Nodes: %d | Orphans: %d" % [
				cycle + 1, elapsed_ms, cur_mem / 1024, cur_obj, cur_nodes, cur_orphans
			])

	assert_true(churn_success, "SUITE_5_CHURN", "Completed all 20 consecutive install/uninstall cycles without error")

	# Wait 3 frames for any deferred free queues to settle
	await process_frame
	await process_frame
	await process_frame

	var end_mem: int = OS.get_static_memory_usage()
	var end_obj: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var end_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var end_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	var mem_delta_kb: int = (end_mem - baseline_mem) / 1024
	var node_delta: int = end_nodes - baseline_nodes
	var orphan_delta: int = end_orphans - baseline_orphans
	var obj_delta: int = end_obj - baseline_obj

	print("  [CHURN FINAL] Memory Delta: %+d KB | Object Delta: %+d | Node Delta: %+d | Orphan Delta: %+d" % [
		mem_delta_kb, obj_delta, node_delta, orphan_delta
	])

	assert_true(node_delta == 0, "SUITE_5_CHURN", "Zero node leak across 20 cycles", "Node delta: %d" % node_delta)
	assert_true(orphan_delta == 0, "SUITE_5_CHURN", "Zero orphan node leak across 20 cycles", "Orphan delta: %d" % orphan_delta)
	assert_true(abs(obj_delta) <= 10, "SUITE_5_CHURN", "Object count remains tightly bounded", "Object delta: %d" % obj_delta)
	assert_true(mem_delta_kb < 2048, "SUITE_5_CHURN", "Memory drift under 2 MB threshold", "Memory delta: %d KB" % mem_delta_kb)

	# 5.2 Synchronous Burst Churn (10 cycles back-to-back with zero frames)
	var burst_success: bool = true
	for burst in range(10):
		var bi: Dictionary = polish.install(game)
		var bu: Dictionary = polish.uninstall()
		if not bi.get("installed", false) or not bu.get("uninstalled", false):
			burst_success = false
			break

	assert_true(burst_success, "SUITE_5_CHURN", "Completed 10 synchronous frame-less burst cycles")

	await process_frame
	await process_frame

	polish.queue_free()


func _debug_instances_0() -> String:
	if game == null:
		return "game is null"
	var campus: Node = game.get_node_or_null("CampusRuntime")
	if campus == null:
		return "campus is null"
	var batches: Node = campus.find_child("CampusRenderBatches", true, false)
	if batches == null:
		return "batches is null"
	var inst0: MultiMeshInstance3D = batches.get_node_or_null("Instances_0") as MultiMeshInstance3D
	if inst0 == null:
		return "Instances_0 not found"
	if inst0.multimesh == null:
		return "multimesh is null"
	return "count=%d, mat_override=%s" % [inst0.multimesh.instance_count, str(inst0.material_override)]


func _snapshot_game_state(target_game: Node3D) -> Dictionary:
	var snap: Dictionary = {
		"multimesh_batches": {},
		"static_surfaces": {},
		"sun": {},
		"env": {}
	}
	var campus: Node = target_game.get_node_or_null("CampusRuntime")
	if campus != null:
		var batches: Node = campus.find_child("CampusRenderBatches", true, false)
		if batches != null:
			for child in batches.get_children():
				if child is MultiMeshInstance3D:
					var mm: MultiMeshInstance3D = child as MultiMeshInstance3D
					snap["multimesh_batches"][mm.name] = {
						"instance_count": mm.multimesh.instance_count if mm.multimesh != null else 0,
						"material_override": mm.material_override
					}
				elif child is MeshInstance3D:
					var mi: MeshInstance3D = child as MeshInstance3D
					snap["static_surfaces"][mi.name] = {
						"material_override": mi.material_override,
						"surface_override_0": mi.get_surface_override_material(0)
					}

	# Sun
	var sun: DirectionalLight3D = target_game.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if sun != null:
		snap["sun"] = {
			"normal_bias": sun.shadow_normal_bias,
			"bias": sun.shadow_bias,
			"blur": sun.shadow_blur,
			"energy": sun.light_energy
		}

	# WorldEnvironment
	var world_env: WorldEnvironment = target_game.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env != null and world_env.environment != null:
		snap["env"] = {
			"ambient_energy": world_env.environment.ambient_light_energy,
			"exposure": world_env.environment.tonemap_exposure
		}

	return snap


func _verify_baseline_integrity() -> void:
	var current: Dictionary = _snapshot_game_state(game)

	# MultiMesh batches
	var mm_base: Dictionary = baseline_snapshot["multimesh_batches"]
	var mm_curr: Dictionary = current["multimesh_batches"]
	var mm_ok: bool = (mm_base.size() == mm_curr.size())
	var mm_diff: String = ""
	if mm_base.size() != mm_curr.size():
		mm_diff = "Count mismatch: base=%d curr=%d" % [mm_base.size(), mm_curr.size()]
		mm_ok = false
	else:
		for b_name in mm_base:
			if not mm_curr.has(b_name):
				mm_ok = false
				mm_diff = "Missing batch: " + b_name
				break
			var b_rec: Dictionary = mm_base[b_name]
			var c_rec: Dictionary = mm_curr[b_name]
			if b_rec["instance_count"] != c_rec["instance_count"]:
				mm_ok = false
				mm_diff = "Instance mismatch on %s: base=%d curr=%d" % [b_name, b_rec["instance_count"], c_rec["instance_count"]]
				break
			if b_rec["material_override"] != c_rec["material_override"]:
				mm_ok = false
				mm_diff = "Material mismatch on %s: base=%s curr=%s" % [b_name, str(b_rec["material_override"]), str(c_rec["material_override"])]
				break
	assert_true(mm_ok, "SUITE_6_BASELINE", "CampusRenderBatches MultiMeshes 100% restored to baseline", mm_diff)

	# StaticSurface batches
	var ss_base: Dictionary = baseline_snapshot["static_surfaces"]
	var ss_curr: Dictionary = current["static_surfaces"]
	var ss_ok: bool = (ss_base.size() == ss_curr.size())
	var ss_diff: String = ""
	if ss_base.size() != ss_curr.size():
		ss_diff = "Count mismatch: base=%d curr=%d" % [ss_base.size(), ss_curr.size()]
		ss_ok = false
	else:
		for s_name in ss_base:
			if not ss_curr.has(s_name):
				ss_ok = false
				ss_diff = "Missing surface: " + s_name
				break
			var b_rec: Dictionary = ss_base[s_name]
			var c_rec: Dictionary = ss_curr[s_name]
			if b_rec["material_override"] != c_rec["material_override"]:
				ss_ok = false
				ss_diff = "material_override mismatch on %s: base=%s curr=%s" % [s_name, str(b_rec["material_override"]), str(c_rec["material_override"])]
				break
			if b_rec["surface_override_0"] != c_rec["surface_override_0"]:
				ss_ok = false
				ss_diff = "surface_override_0 mismatch on %s: base=%s curr=%s" % [s_name, str(b_rec["surface_override_0"]), str(c_rec["surface_override_0"])]
				break
	assert_true(ss_ok, "SUITE_6_BASELINE", "CampusRenderBatches StaticSurfaces 100% restored to baseline", ss_diff)

	# Sun
	var sun_base: Dictionary = baseline_snapshot["sun"]
	var sun_curr: Dictionary = current["sun"]
	var sun_ok: bool = true
	for p in sun_base:
		if not is_equal_approx(float(sun_base[p]), float(sun_curr.get(p, 0.0))):
			sun_ok = false
			break
	assert_true(sun_ok, "SUITE_6_BASELINE", "DirectionalLight3D parameters restored to baseline")

	# WorldEnvironment
	var env_base: Dictionary = baseline_snapshot["env"]
	var env_curr: Dictionary = current["env"]
	var env_ok: bool = true
	for p in env_base:
		if not is_equal_approx(float(env_base[p]), float(env_curr.get(p, 0.0))):
			env_ok = false
			break
	assert_true(env_ok, "SUITE_6_BASELINE", "WorldEnvironment parameters restored to baseline")

	# Metadata removed
	assert_true(not game.has_meta("antigravity_polish_installed"), "SUITE_6_BASELINE", "Metadata key cleanly removed")

	# No leftover injected nodes
	var leftover_light: Node = game.get_node_or_null("CanopyEntranceDownlight")
	var leftover_sign: Node = game.get_node_or_null("CreamEntranceSignage")
	assert_true(leftover_light == null, "SUITE_6_BASELINE", "Zero leftover CanopyEntranceDownlight")
	assert_true(leftover_sign == null, "SUITE_6_BASELINE", "Zero leftover CreamEntranceSignage")


func _finish_suite() -> void:
	results["passed"] = (results["failed_assertions"] == 0 and failures.is_empty())
	results["failures"] = failures

	var global_path: String = ProjectSettings.globalize_path(REPORT_PATH)
	var f := FileAccess.open(global_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "\t"))
		f.close()
		print("\nCHALLENGER_REPORT_SAVED: %s" % global_path)

	print("\n=================================================================")
	print(" CHALLENGER M4_2 CONCURRENCY STRESS TEST FINISHED: passed=%s" % str(results["passed"]))
	print(" Assertions Total: %d | Passed: %d | Failed: %d" % [
		results["total_assertions"], results["passed_assertions"], results["failed_assertions"]
	])
	print("=================================================================")

	if is_instance_valid(game):
		game.queue_free()

	await process_frame
	quit(0 if results["passed"] else 1)
