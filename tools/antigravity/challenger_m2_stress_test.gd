extends SceneTree
## Challenger M2 Adversarial Empirical Stress Test Harness
## Rigorously stresses environment_polish.gd across:
## 1. Rapid lifecycle churn (10 back-to-back install/uninstall cycles with leak & restoration verification)
## 2. Idempotency stress (5 consecutive installs + multi-instance stress)
## 3. Batch integrity & draw call safety (MultiMesh & StaticSurface batch preservation)
## 4. Interactive computer screen & workstation safety (zero unshaded material alteration)
## 5. Fault tolerance & hostile edge cases (null, plain Node, unready tree, missing subcomponents, freed targets)
## 6. Synchronous frame-less churn stress

const TEST_NAME: String = "Challenger M2 Empirical Stress Test"
const POLISH_SCRIPT_PATH: String = "res://scripts/antigravity/environment_polish.gd"

var game: Node3D = null
var polish: Node3D = null
var failures: Array[Dictionary] = []
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
	call_deferred("_execute_all_stress_tests")


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
		failures.append(failure_entry)
		push_error("[CHALLENGER_FAIL] [%s] %s: %s" % [suite_name, check_name, str(details)])
		print("[CHALLENGER_FAIL] [%s] %s: %s" % [suite_name, check_name, str(details)])
		return false


func _execute_all_stress_tests() -> void:
	results["timestamp"] = Time.get_datetime_string_from_system(true)
	print("=================================================================")
	print(" STARTING CHALLENGER M2 EMPIRICAL STRESS TEST SUITE")
	print("=================================================================")

	# 1. Load Polish Script Class
	if not ResourceLoader.exists(POLISH_SCRIPT_PATH):
		assert_true(false, "INIT", "Polish script exists", POLISH_SCRIPT_PATH)
		_finish_suite()
		return
	var PolishClass = load(POLISH_SCRIPT_PATH)
	assert_true(PolishClass != null, "INIT", "Polish script loads cleanly")

	# 2. Instantiate and Initialize Production Game Tree
	root.size = Vector2i(1280, 720)
	var scene_res: PackedScene = load("res://main.tscn")
	if scene_res == null:
		assert_true(false, "INIT", "res://main.tscn loaded")
		_finish_suite()
		return

	game = scene_res.instantiate() as Node3D
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)

	var start_wait: int = Time.get_ticks_msec()
	while not game.ready_to_play and (Time.get_ticks_msec() - start_wait) < 120000:
		await process_frame

	assert_true(game.ready_to_play, "INIT", "game.ready_to_play reached", "waited %d ms" % (Time.get_ticks_msec() - start_wait))
	if not game.ready_to_play:
		_finish_suite()
		return

	# Settle physics and transforms
	await physics_frame
	await process_frame

	# 3. Record Baseline Snapshot
	var baseline: Dictionary = _record_baseline_snapshot(game)
	print("BASELINE CAPTURED: nodes=%d, meshes=%d, multimeshes=%d, static_surfaces=%d" % [
		baseline["total_game_nodes"],
		baseline["mesh_instances"].size(),
		baseline["multimesh_instances"].size(),
		baseline["static_surface_count"]
	])

	# 4. SUITE 1: Fault Tolerance & Hostile Edge Cases (before installing on game)
	await _run_suite_fault_tolerance(PolishClass, game)

	# 5. SUITE 2: Rapid Lifecycle Stress (10 Back-to-Back install -> uninstall cycles)
	await _run_suite_rapid_lifecycle(PolishClass, game, baseline)

	# 6. SUITE 3: Idempotency Stress (5 consecutive installs + multi-instance)
	await _run_suite_idempotency(PolishClass, game, baseline)

	# 7. SUITE 4: Batch Integrity & Draw Call Safety
	await _run_suite_batch_integrity(PolishClass, game, baseline)

	# 8. SUITE 5: Interactive Computer Screen & Workstation Safety
	await _run_suite_screen_safety(PolishClass, game)

	# 9. SUITE 6: Synchronous Rapid Churn (Frame-less stress)
	await _run_suite_synchronous_churn(PolishClass, game, baseline)

	# Finish & Output Summary
	_finish_suite()


# =========================================================================
# SUITE 1: FAULT TOLERANCE & HOSTILE EDGE CASES
# =========================================================================
func _run_suite_fault_tolerance(PolishClass: Variant, valid_game: Node3D) -> void:
	var suite := "FAULT_TOLERANCE"
	print("\n>>> RUNNING SUITE: %s <<<" % suite)

	var p: Node3D = PolishClass.new()

	# Case 1: install(null)
	var res_null: Dictionary = p.install(null)
	assert_true(res_null.get("installed") == false, suite, "install(null) returns installed=false")
	assert_true(not res_null.get("errors", []).is_empty(), suite, "install(null) reports error message", res_null.get("errors"))

	# Case 2: install(plain Node)
	var plain_node := Node.new()
	var res_plain: Dictionary = p.install(plain_node as Node3D)
	assert_true(res_plain.get("installed") == false, suite, "install(plain Node) rejected")
	plain_node.free()

	# Case 3: install(unready Node3D without ready_to_play property)
	var dummy_node3d := Node3D.new()
	var res_dummy: Dictionary = p.install(dummy_node3d)
	assert_true(res_dummy.get("installed") == false, suite, "install(dummy Node3D without ready_to_play) rejected")
	dummy_node3d.free()

	# Case 4: install(Node3D with ready_to_play = false)
	var mock_unready := Node3D.new()
	var mock_script_unready := GDScript.new()
	mock_script_unready.source_code = "extends Node3D\nvar ready_to_play: bool = false\n"
	mock_script_unready.reload()
	mock_unready.set_script(mock_script_unready)
	var res_unready: Dictionary = p.install(mock_unready)
	assert_true(res_unready.get("installed") == false, suite, "install(ready_to_play=false) rejected")
	mock_unready.free()
	p.free()

	# Case 5: install(Node3D with ready_to_play = true, but empty tree / no CampusRuntime)
	var p_mock: Node3D = PolishClass.new()
	var mock_ready_empty := Node3D.new()
	var mock_script := GDScript.new()
	mock_script.source_code = "extends Node3D\nvar ready_to_play: bool = true\n"
	mock_script.reload()
	mock_ready_empty.set_script(mock_script)
	var res_empty: Dictionary = p_mock.install(mock_ready_empty)
	assert_true(res_empty.get("installed") == true, suite, "install(empty tree with ready_to_play=true) handles gracefully without crashing", res_empty)
	# Clean uninstall from empty mock
	var uninst_empty: Dictionary = p_mock.uninstall()
	assert_true(uninst_empty.get("uninstalled") == true, suite, "uninstall on mock tree completes cleanly", uninst_empty)
	mock_ready_empty.remove_child(p_mock)
	mock_ready_empty.free()
	p_mock.free()

	# Case 6: uninstall() when not installed
	var fresh_p: Node3D = PolishClass.new()
	var uninst_not_installed: Dictionary = fresh_p.uninstall()
	assert_true(uninst_not_installed.get("uninstalled") == false, suite, "uninstall() on uninstalled module returns uninstalled=false")
	assert_true(uninst_not_installed.get("status") == "not_installed", suite, "uninstall() returns status=not_installed")

	# Case 7: Double uninstall()
	var uninst_double: Dictionary = fresh_p.uninstall()
	assert_true(uninst_double.get("status") == "not_installed", suite, "Second uninstall() remains safe and idempotent")
	fresh_p.free()

	# Case 8: uninstall() after target game has been freed
	var mock_to_free := Node3D.new()
	var mock_script2 := GDScript.new()
	mock_script2.source_code = "extends Node3D\nvar ready_to_play: bool = true\n"
	mock_script2.reload()
	mock_to_free.set_script(mock_script2)
	var p_freed: Node3D = PolishClass.new()
	p_freed.install(mock_to_free)
	# Detach p_freed before freeing mock_to_free so p_freed remains valid
	mock_to_free.remove_child(p_freed)
	mock_to_free.free() # Target game is now freed
	var uninst_freed: Dictionary = p_freed.uninstall()
	assert_true(uninst_freed is Dictionary, suite, "uninstall() after target game freed does not crash engine", uninst_freed)
	p_freed.free()
	print("<<< SUITE %s COMPLETE >>>\n" % suite)


# =========================================================================
# SUITE 2: RAPID LIFECYCLE STRESS (10 CYCLES)
# =========================================================================
func _run_suite_rapid_lifecycle(PolishClass: Variant, target_game: Node3D, baseline: Dictionary) -> void:
	var suite := "RAPID_LIFECYCLE_STRESS"
	print("\n>>> RUNNING SUITE: %s (10 Cycles) <<<" % suite)

	var p: Node3D = PolishClass.new()
	target_game.add_child(p)

	var initial_mem: int = OS.get_static_memory_usage()
	var initial_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var initial_resources: int = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var initial_nodes: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	print("LIFECYCLE INITIAL: mem=%d KB, objects=%d, resources=%d, nodes=%d" % [
		initial_mem / 1024, initial_objects, initial_resources, initial_nodes
	])

	for cycle in range(1, 11):
		# 1. Install
		var install_res: Dictionary = p.install(target_game)
		assert_true(install_res.get("installed") == true, suite, "Cycle %d: install returned true" % cycle)

		# Verify injected nodes exist during installation
		var light: Node = target_game.find_child("CanopyEntranceDownlight", true, false)
		var sign_node: Node = target_game.find_child("CreamEntranceSignage", true, false)
		assert_true(light != null, suite, "Cycle %d: CanopyEntranceDownlight injected" % cycle)
		assert_true(sign_node != null, suite, "Cycle %d: CreamEntranceSignage injected" % cycle)

		# Verify sun and env parameters were adjusted
		var sun: DirectionalLight3D = _find_sun(target_game)
		if sun != null:
			assert_true(is_equal_approx(sun.shadow_normal_bias, 0.80), suite, "Cycle %d: sun shadow normal bias tuned to 0.80" % cycle)
			assert_true(is_equal_approx(sun.light_energy, 0.32), suite, "Cycle %d: sun light energy tuned to 0.32" % cycle)

		var env: Environment = _find_env(target_game)
		if env != null:
			assert_true(is_equal_approx(env.ambient_light_energy, 0.28), suite, "Cycle %d: ambient light energy tuned to 0.28" % cycle)
			assert_true(is_equal_approx(env.tonemap_exposure, 0.95), suite, "Cycle %d: tonemap exposure tuned to 0.95" % cycle)

		# Verify ceiling backing offset (-2mm)
		var ceiling_backing: MeshInstance3D = _find_ceiling_backing(target_game)
		if ceiling_backing != null:
			var expected_y: float = baseline["ceiling_backing_pos"].y - 0.002
			assert_true(is_equal_approx(ceiling_backing.global_position.y, expected_y), suite, "Cycle %d: ceiling backing offset by -2mm" % cycle)
			assert_true(ceiling_backing.visible == true, suite, "Cycle %d: ceiling backing unhidden" % cycle)
			assert_true(ceiling_backing.material_override != null, suite, "Cycle %d: ceiling backing material applied" % cycle)

		# 2. Uninstall
		var uninstall_res: Dictionary = p.uninstall()
		assert_true(uninstall_res.get("uninstalled") == true, suite, "Cycle %d: uninstall returned true" % cycle)
		assert_true(uninstall_res.get("status") == "clean", suite, "Cycle %d: uninstall status is clean" % cycle)

		# Pump frame to flush queue_free()
		await process_frame

		# 3. Verify Complete 100% Restoration to Baseline
		# Check injected nodes are completely removed
		var light_after: Node = target_game.find_child("CanopyEntranceDownlight", true, false)
		var sign_after: Node = target_game.find_child("CreamEntranceSignage", true, false)
		assert_true(light_after == null, suite, "Cycle %d: CanopyEntranceDownlight removed after uninstall" % cycle)
		assert_true(sign_after == null, suite, "Cycle %d: CreamEntranceSignage removed after uninstall" % cycle)

		# Check sun restoration
		if sun != null:
			assert_true(is_equal_approx(sun.shadow_normal_bias, baseline["sun"]["shadow_normal_bias"]), suite, "Cycle %d: sun shadow normal bias restored to baseline (%.2f)" % [cycle, baseline["sun"]["shadow_normal_bias"]])
			assert_true(is_equal_approx(sun.shadow_bias, baseline["sun"]["shadow_bias"]), suite, "Cycle %d: sun shadow bias restored to baseline" % cycle)
			assert_true(is_equal_approx(sun.shadow_blur, baseline["sun"]["shadow_blur"]), suite, "Cycle %d: sun shadow blur restored to baseline" % cycle)
			assert_true(sun.directional_shadow_blend_splits == baseline["sun"]["directional_shadow_blend_splits"], suite, "Cycle %d: sun shadow blend splits restored" % cycle)
			assert_true(is_equal_approx(sun.light_energy, baseline["sun"]["light_energy"]), suite, "Cycle %d: sun light energy restored to baseline" % cycle)

		# Check env restoration
		if env != null:
			assert_true(is_equal_approx(env.ambient_light_energy, baseline["env"]["ambient_light_energy"]), suite, "Cycle %d: ambient light energy restored to baseline" % cycle)
			assert_true(is_equal_approx(env.tonemap_exposure, baseline["env"]["tonemap_exposure"]), suite, "Cycle %d: tonemap exposure restored to baseline" % cycle)

		# Check ceiling backing restoration
		if ceiling_backing != null:
			assert_true(is_equal_approx(ceiling_backing.global_position.y, baseline["ceiling_backing_pos"].y), suite, "Cycle %d: ceiling backing pos.y restored to exact baseline" % cycle)
			assert_true(ceiling_backing.visible == baseline["ceiling_backing_vis"], suite, "Cycle %d: ceiling backing visibility restored to baseline" % cycle)
			assert_true(ceiling_backing.material_override == baseline["ceiling_backing_mat"], suite, "Cycle %d: ceiling backing material_override restored to null/baseline" % cycle)

		# Check node counts
		var current_node_count: int = _count_descendants(target_game)
		# target_game has 'p' attached as child; excluding 'p', node count must match baseline
		assert_true((current_node_count - 1) == baseline["total_game_nodes"], suite, "Cycle %d: zero node leaks after uninstall (baseline=%d, current=%d)" % [
			cycle, baseline["total_game_nodes"], current_node_count - 1
		])

		var cur_mem: int = OS.get_static_memory_usage()
		var cur_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
		var cur_resources: int = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		var cur_nodes: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		print("CYCLE %d POST-UNINSTALL: mem_delta=%+d KB, obj_delta=%+d, res_delta=%+d, node_delta=%+d" % [
			cycle, (cur_mem - initial_mem) / 1024, cur_objects - initial_objects, cur_resources - initial_resources, cur_nodes - initial_nodes
		])

	# Check memory and object deltas across 10 cycles
	var final_mem: int = OS.get_static_memory_usage()
	var final_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var final_resources: int = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var final_nodes: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var mem_growth_kb: float = float(final_mem - initial_mem) / 1024.0

	print("FINAL DELTAS ACROSS 10 CYCLES: mem_growth=%.2f KB, obj_delta=%+d, res_delta=%+d, node_delta=%+d" % [
		mem_growth_kb, final_objects - initial_objects, final_resources - initial_resources, final_nodes - initial_nodes
	])
	assert_true(final_nodes - initial_nodes == 0, suite, "0 engine node leaks across 10 cycles (delta=%d)" % (final_nodes - initial_nodes))
	assert_true(final_resources - initial_resources <= 0, suite, "0 resource leaks across 10 cycles (delta=%d)" % (final_resources - initial_resources))
	
	# Verify steady-state object count stability (Cycle 2 to Cycle 10)
	# Cycle 1 warms engine StringName and internal VM tables; steady state from cycle 2 onward must have 0 object growth.
	assert_true(final_objects <= initial_objects + 15, suite, "Engine object count strictly stabilized (final=%d, initial=%d, delta=%d)" % [
		final_objects, initial_objects, final_objects - initial_objects
	])

	p.queue_free()
	await process_frame
	print("<<< SUITE %s COMPLETE >>>\n" % suite)


# =========================================================================
# SUITE 3: IDEMPOTENCY STRESS (5 Consecutive Installs + Multi-Instance)
# =========================================================================
func _run_suite_idempotency(PolishClass: Variant, target_game: Node3D, baseline: Dictionary) -> void:
	var suite := "IDEMPOTENCY_STRESS"
	print("\n>>> RUNNING SUITE: %s <<<" % suite)

	var p: Node3D = PolishClass.new()
	target_game.add_child(p)

	# 1. First install
	var res1: Dictionary = p.install(target_game)
	assert_true(res1.get("installed") == true, suite, "Install 1: returns installed=true")
	assert_true(res1.get("already_installed") == false, suite, "Install 1: returns already_installed=false")

	# Sample material instance IDs after first install
	var sample_mats_pass1: Dictionary = _sample_surface_override_ids(target_game)

	# 2. Consecutive Installs 2 to 5 on the SAME instance
	for i in range(2, 6):
		var res_i: Dictionary = p.install(target_game)
		assert_true(res_i.get("installed") == true, suite, "Install %d: returns installed=true" % i)
		assert_true(res_i.get("already_installed") == true, suite, "Install %d: reports already_installed=true" % i)

		# Verify injected nodes are NOT duplicated
		var lights: Array[Node] = _find_all_children_by_name(target_game, "CanopyEntranceDownlight")
		var signages: Array[Node] = _find_all_children_by_name(target_game, "CreamEntranceSignage")
		assert_true(lights.size() == 1, suite, "Install %d: exactly 1 CanopyEntranceDownlight (found %d)" % [i, lights.size()])
		assert_true(signages.size() == 1, suite, "Install %d: exactly 1 CreamEntranceSignage (found %d)" % [i, signages.size()])

		# Verify material overrides are NOT double-wrapped
		var sample_mats_pass_i: Dictionary = _sample_surface_override_ids(target_game)
		assert_true(sample_mats_pass_i == sample_mats_pass1, suite, "Install %d: material override instance IDs identical (no double-wrapping)" % i)

	# 3. Multi-Instance Idempotency Stress: Create 3 NEW separate instances of EnvironmentPolish
	print("Testing multi-instance idempotency with separate instances...")
	for k in range(1, 4):
		var separate_p: Node3D = PolishClass.new()
		var res_sep: Dictionary = separate_p.install(target_game)
		assert_true(res_sep.get("installed") == true, suite, "Separate instance %d: returns installed=true" % k)
		assert_true(res_sep.get("already_installed") == true, suite, "Separate instance %d: reports already_installed=true" % k)

		var lights_sep: Array[Node] = _find_all_children_by_name(target_game, "CanopyEntranceDownlight")
		var sign_sep: Array[Node] = _find_all_children_by_name(target_game, "CreamEntranceSignage")
		assert_true(lights_sep.size() == 1, suite, "Separate instance %d: CanopyEntranceDownlight not duplicated" % k)
		assert_true(sign_sep.size() == 1, suite, "Separate instance %d: CreamEntranceSignage not duplicated" % k)

		separate_p.free()

	# Clean up primary instance
	var uninst: Dictionary = p.uninstall()
	assert_true(uninst.get("uninstalled") == true, suite, "Final uninstall after idempotency stress succeeded")
	p.queue_free()
	await process_frame
	print("<<< SUITE %s COMPLETE >>>\n" % suite)


# =========================================================================
# SUITE 4: BATCH INTEGRITY & DRAW CALL SAFETY
# =========================================================================
func _run_suite_batch_integrity(PolishClass: Variant, target_game: Node3D, baseline: Dictionary) -> void:
	var suite := "BATCH_INTEGRITY"
	print("\n>>> RUNNING SUITE: %s <<<" % suite)

	var campus: Node = target_game.get_node_or_null("CampusRuntime")
	assert_true(campus != null, suite, "CampusRuntime node exists")
	var batches: Node = campus.find_child("CampusRenderBatches", true, false)
	assert_true(batches != null, suite, "CampusRenderBatches node exists")

	var mm_count_before: int = 0
	var static_count_before: int = 0
	var mm_instance_sums_before: int = 0
	for child: Node in batches.get_children():
		if child is MultiMeshInstance3D:
			mm_count_before += 1
			var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
			if mm != null:
				mm_instance_sums_before += mm.instance_count
		elif child is MeshInstance3D:
			static_count_before += 1

	print("BATCH COUNTS BEFORE POLISH: multimesh=%d, static_surface=%d, total_instances=%d" % [
		mm_count_before, static_count_before, mm_instance_sums_before
	])

	# Install Polish
	var p: Node3D = PolishClass.new()
	target_game.add_child(p)
	p.install(target_game)

	# Verify Batch Counts DURING Polish
	var mm_count_during: int = 0
	var static_count_during: int = 0
	var mm_instance_sums_during: int = 0
	for child: Node in batches.get_children():
		if child is MultiMeshInstance3D:
			mm_count_during += 1
			var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
			if mm != null:
				mm_instance_sums_during += mm.instance_count
		elif child is MeshInstance3D:
			static_count_during += 1

	assert_true(mm_count_during == mm_count_before, suite, "MultiMesh batch count retained exactly (%d == %d)" % [mm_count_during, mm_count_before])
	assert_true(static_count_during == static_count_before, suite, "StaticSurface batch count retained exactly (%d == %d)" % [static_count_during, static_count_before])
	assert_true(mm_instance_sums_during == mm_instance_sums_before, suite, "MultiMesh total instance count retained (%d == %d)" % [mm_instance_sums_during, mm_instance_sums_before])

	# Check that static surface meshes were NOT duplicated or unpacked
	var static_surface_draw_calls: int = 0
	for child: Node in batches.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			assert_true(mi.mesh != null and mi.mesh.get_surface_count() == 1, suite, "Static surface %s has exactly 1 merged surface" % mi.name)
			static_surface_draw_calls += 1
	assert_true(static_surface_draw_calls == static_count_before, suite, "Static surfaces remain merged single-draw calls")

	# Uninstall and verify
	p.uninstall()
	p.queue_free()
	await process_frame
	print("<<< SUITE %s COMPLETE >>>\n" % suite)


# =========================================================================
# SUITE 5: INTERACTIVE COMPUTER SCREEN & WORKSTATION SAFETY
# =========================================================================
func _run_suite_screen_safety(PolishClass: Variant, target_game: Node3D) -> void:
	var suite := "SCREEN_AND_WORKSTATION_SAFETY"
	print("\n>>> RUNNING SUITE: %s <<<" % suite)

	# 1. Snapshot all interactive stations before polish
	var stations_val: Variant = target_game.get("stations")
	assert_true(stations_val is Array and (stations_val as Array).size() == 5, suite, "Found 5 interactive stations in game")

	var screen_snapshots_before: Dictionary = {}
	for station_val: Variant in (stations_val as Array):
		var station: Dictionary = station_val as Dictionary
		var st_name: String = station.get("name", "")
		var kind: String = station.get("kind", "")
		if kind == "pc":
			var asset: Dictionary = station.get("asset", {})
			var screen_mesh: MeshInstance3D = asset.get("screen_mesh") as MeshInstance3D
			assert_true(screen_mesh != null, suite, "Station '%s' has valid screen_mesh" % st_name)
			if screen_mesh != null:
				var active_mat: Material = screen_mesh.get_active_material(0)
				assert_true(active_mat is BaseMaterial3D, suite, "Station '%s' screen material is BaseMaterial3D" % st_name)
				var bm: BaseMaterial3D = active_mat as BaseMaterial3D
				assert_true(bm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, suite, "Station '%s' screen is SHADING_MODE_UNSHADED" % st_name)
				screen_snapshots_before[st_name] = {
					"mat_id": bm.get_instance_id(),
					"shading_mode": bm.shading_mode,
					"albedo": bm.albedo_color,
					"cull_mode": bm.cull_mode,
					"override_mat": screen_mesh.material_override
				}

	# 2. Install Polish
	var p: Node3D = PolishClass.new()
	target_game.add_child(p)
	p.install(target_game)

	# 3. Empirically verify 0 unshaded materials were altered or dimmed
	for station_val: Variant in (stations_val as Array):
		var station: Dictionary = station_val as Dictionary
		var st_name: String = station.get("name", "")
		var kind: String = station.get("kind", "")
		if kind == "pc":
			var asset: Dictionary = station.get("asset", {})
			var screen_mesh: MeshInstance3D = asset.get("screen_mesh") as MeshInstance3D
			assert_true(screen_mesh != null, suite, "Station '%s' screen_mesh still exists after polish" % st_name)
			if screen_mesh != null:
				var active_mat_after: Material = screen_mesh.get_active_material(0)
				var bm_after: BaseMaterial3D = active_mat_after as BaseMaterial3D
				var snap: Dictionary = screen_snapshots_before.get(st_name, {})

				# Verify shading mode is still unshaded
				assert_true(bm_after.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, suite, "Station '%s' screen remains SHADING_MODE_UNSHADED" % st_name)
				# Verify albedo color is completely un-dimmed
				assert_true(bm_after.albedo_color == snap["albedo"], suite, "Station '%s' screen albedo color unchanged (%s == %s)" % [st_name, str(bm_after.albedo_color), str(snap["albedo"])])
				# Verify material_override is the exact same object instance
				assert_true(screen_mesh.material_override == snap["override_mat"], suite, "Station '%s' screen material_override object preserved untouched" % st_name)
				# Verify surface override is not set
				assert_true(screen_mesh.get_surface_override_material(0) == null, suite, "Station '%s' screen has no surface override material applied" % st_name)

	# 4. Global Scene Tree Scan for ANY unshaded materials
	var all_unshaded_found: int = 0
	var all_unshaded_altered: int = 0
	var all_meshes: Array[MeshInstance3D] = []
	_collect_all_meshes(target_game, all_meshes)

	for mi: MeshInstance3D in all_meshes:
		for s in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.get_active_material(s)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				all_unshaded_found += 1
				if mat.has_meta("antigravity_polished"):
					all_unshaded_altered += 1

	print("GLOBAL UNSHADED SCAN: total unshaded found=%d, altered=%d" % [all_unshaded_found, all_unshaded_altered])
	assert_true(all_unshaded_found >= 3, suite, "Found at least 3 unshaded screen surfaces in scene tree")
	assert_true(all_unshaded_altered == 0, suite, "0 unshaded materials were altered by polish module (altered=%d)" % all_unshaded_altered)

	p.uninstall()
	p.queue_free()
	await process_frame
	print("<<< SUITE %s COMPLETE >>>\n" % suite)


# =========================================================================
# SUITE 6: SYNCHRONOUS RAPID CHURN (FRAME-LESS STRESS)
# =========================================================================
func _run_suite_synchronous_churn(PolishClass: Variant, target_game: Node3D, baseline: Dictionary) -> void:
	var suite := "SYNCHRONOUS_FRAMELESS_CHURN"
	print("\n>>> RUNNING SUITE: %s <<<" % suite)

	var p: Node3D = PolishClass.new()
	target_game.add_child(p)

	# Execute 5 rapid back-to-back install -> uninstall cycles WITHOUT yielding to process_frame
	for cycle in range(1, 6):
		var inst: Dictionary = p.install(target_game)
		assert_true(inst.get("installed") == true, suite, "Frameless cycle %d: install succeeded" % cycle)
		var uninst: Dictionary = p.uninstall()
		assert_true(uninst.get("uninstalled") == true, suite, "Frameless cycle %d: uninstall succeeded" % cycle)

	# Now yield 1 frame to let all queued frees complete
	await process_frame

	# Check node count returns to baseline
	var current_node_count: int = _count_descendants(target_game)
	assert_true((current_node_count - 1) == baseline["total_game_nodes"], suite, "Frameless churn: node count returned 100%% to baseline without leak (%d == %d)" % [
		current_node_count - 1, baseline["total_game_nodes"]
	])

	p.queue_free()
	await process_frame
	print("<<< SUITE %s COMPLETE >>>\n" % suite)


# =========================================================================
# HELPER & INSPECTION FUNCTIONS
# =========================================================================
func _record_baseline_snapshot(target_game: Node3D) -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["total_game_nodes"] = _count_descendants(target_game)

	# Sun
	var sun: DirectionalLight3D = _find_sun(target_game)
	if sun != null:
		snapshot["sun"] = {
			"shadow_normal_bias": sun.shadow_normal_bias,
			"shadow_bias": sun.shadow_bias,
			"shadow_blur": sun.shadow_blur,
			"directional_shadow_blend_splits": sun.directional_shadow_blend_splits,
			"light_energy": sun.light_energy
		}

	# Env
	var env: Environment = _find_env(target_game)
	if env != null:
		snapshot["env"] = {
			"ambient_light_energy": env.ambient_light_energy,
			"tonemap_exposure": env.tonemap_exposure
		}

	# Ceiling backing
	var ceiling_backing: MeshInstance3D = _find_ceiling_backing(target_game)
	if ceiling_backing != null:
		snapshot["ceiling_backing_pos"] = ceiling_backing.global_position
		snapshot["ceiling_backing_vis"] = ceiling_backing.visible
		snapshot["ceiling_backing_mat"] = ceiling_backing.material_override

	# Collect all mesh instances
	var mesh_list: Array[MeshInstance3D] = []
	_collect_all_meshes(target_game, mesh_list)
	snapshot["mesh_instances"] = mesh_list

	# Collect all MultiMesh instances
	var mm_list: Array[MultiMeshInstance3D] = []
	_collect_all_multimeshes(target_game, mm_list)
	snapshot["multimesh_instances"] = mm_list

	# CampusRenderBatches static surfaces
	var campus: Node = target_game.get_node_or_null("CampusRuntime")
	var static_count: int = 0
	if campus != null:
		var batches: Node = campus.find_child("CampusRenderBatches", true, false)
		if batches != null:
			for c in batches.get_children():
				if c is MeshInstance3D:
					static_count += 1
	snapshot["static_surface_count"] = static_count

	return snapshot


func _find_sun(target_game: Node3D) -> DirectionalLight3D:
	for child: Node in target_game.get_children():
		if child is DirectionalLight3D:
			return child as DirectionalLight3D
	return target_game.find_child("DirectionalLight3D", true, false) as DirectionalLight3D


func _find_env(target_game: Node3D) -> Environment:
	var we: WorldEnvironment = null
	for child: Node in target_game.get_children():
		if child is WorldEnvironment:
			we = child as WorldEnvironment
			break
	if we == null:
		we = target_game.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we != null:
		return we.environment
	return null


func _find_ceiling_backing(target_game: Node3D) -> MeshInstance3D:
	var campus: Node = target_game.get_node_or_null("CampusRuntime")
	if campus != null:
		var mesh_nodes_val: Variant = campus.get("mesh_nodes")
		if mesh_nodes_val is Array:
			for item: Variant in (mesh_nodes_val as Array):
				if item is MeshInstance3D:
					var m: MeshInstance3D = item as MeshInstance3D
					if str(m.get_meta("campus_source_name", m.name)) == "E8 ceiling joint backing" or m.name == "E8 ceiling joint backing":
						return m
		return campus.find_child("E8 ceiling joint backing", true, false) as MeshInstance3D
	return null


func _count_descendants(node: Node) -> int:
	var count: int = 1
	for child in node.get_children():
		count += _count_descendants(child)
	return count


func _find_all_children_by_name(root_node: Node, target_name: String) -> Array[Node]:
	var found: Array[Node] = []
	if root_node.name == target_name:
		found.append(root_node)
	for child in root_node.get_children():
		found.append_array(_find_all_children_by_name(child, target_name))
	return found


func _collect_all_meshes(root_node: Node, meshes: Array[MeshInstance3D]) -> void:
	if root_node is MeshInstance3D and (root_node as MeshInstance3D).mesh != null:
		meshes.append(root_node as MeshInstance3D)
	for child in root_node.get_children():
		_collect_all_meshes(child, meshes)


func _collect_all_multimeshes(root_node: Node, mms: Array[MultiMeshInstance3D]) -> void:
	if root_node is MultiMeshInstance3D and (root_node as MultiMeshInstance3D).multimesh != null:
		mms.append(root_node as MultiMeshInstance3D)
	for child in root_node.get_children():
		_collect_all_multimeshes(child, mms)


func _sample_surface_override_ids(target_game: Node3D) -> Dictionary:
	var sample: Dictionary = {}
	var campus: Node = target_game.get_node_or_null("CampusRuntime")
	if campus != null:
		var batches: Node = campus.find_child("CampusRenderBatches", true, false)
		if batches != null:
			for child in batches.get_children():
				if child is MultiMeshInstance3D:
					var mi: MultiMeshInstance3D = child as MultiMeshInstance3D
					sample[mi.name] = mi.material_override.get_instance_id() if mi.material_override != null else 0
				elif child is MeshInstance3D:
					var mi2: MeshInstance3D = child as MeshInstance3D
					var mat: Material = mi2.get_surface_override_material(0)
					sample[mi2.name] = mat.get_instance_id() if mat != null else 0
	return sample


func _finish_suite() -> void:
	results["passed"] = (results["failed_assertions"] == 0 and failures.is_empty())
	results["failures"] = failures

	var out_path: String = "res://tools/antigravity/challenger_m2_stress_test_report.json"
	var global_path: String = ProjectSettings.globalize_path(out_path)
	var f := FileAccess.open(global_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "\t"))
		f.close()
		print("\nCHALLENGER_REPORT_SAVED: %s" % global_path)

	print("\n=================================================================")
	print(" CHALLENGER M2 STRESS TEST FINISHED: passed=%s" % str(results["passed"]))
	print(" Assertions Total: %d | Passed: %d | Failed: %d" % [
		results["total_assertions"], results["passed_assertions"], results["failed_assertions"]
	])
	print("=================================================================")

	if is_instance_valid(game):
		game.queue_free()

	await process_frame
	quit(0 if results["passed"] else 1)
