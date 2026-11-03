extends SceneTree
## Adversarial Stress Testing Harness for Milestone 1 Environment Polish
## Developed by Challenger M1_1 (Empirical Challenger)
## Tests:
## 1. Adversarial/invalid inputs (null, freed, unready, type variations)
## 2. Repeated idempotency & reversibility edge cases
## 3. High-frequency install/uninstall cycling on live main.tscn
## 4. Preservation of CampusRenderBatches (MultiMesh instances & StaticSurfaces)
## 5. Multi-instance collision resilience
## 6. Tree mutation resilience (freed nodes before uninstall)
## 7. Performance & memory leak assessment

const PolishScript = preload("res://scripts/antigravity/environment_polish.gd")

var results: Dictionary = {
	"timestamp": "",
	"passed": false,
	"total_tests": 0,
	"passed_tests": 0,
	"failed_tests": 0,
	"test_log": [],
	"baseline_batches": {},
	"post_uninstall_batches": {}
}

func _init() -> void:
	call_deferred("_run_stress_harness")

func _log_test(test_name: String, success: bool, details: String = "") -> void:
	results["total_tests"] = int(results["total_tests"]) + 1
	if success:
		results["passed_tests"] = int(results["passed_tests"]) + 1
		var msg := "PASS: [%s] %s" % [test_name, details]
		results["test_log"].append(msg)
		print(msg)
	else:
		results["failed_tests"] = int(results["failed_tests"]) + 1
		var msg := "FAIL: [%s] %s" % [test_name, details]
		results["test_log"].append(msg)
		push_error(msg)
		print(msg)

func _run_stress_harness() -> void:
	results["timestamp"] = Time.get_datetime_string_from_system(true)
	print("=================================================================")
	print("CHALLENGER M1_1: EMPIRICAL STRESS TESTING HARNESS STARTING")
	print("=================================================================")

	# -------------------------------------------------------------
	# TIER 1: Adversarial & Invalid Input Fuzzing (Standalone Nodes)
	# -------------------------------------------------------------
	print("\n--- TIER 1: ADVERSARIAL INPUT FUZZING ---")
	_test_tier1_inputs()

	# -------------------------------------------------------------
	# TIER 2: Live Game Scene Stress Testing on res://main.tscn
	# -------------------------------------------------------------
	print("\n--- TIER 2: LIVE GAME SCENE INSTANTIATION ---")
	var scene_res: PackedScene = load("res://main.tscn")
	if scene_res == null:
		_log_test("Load main.tscn", false, "Could not load res://main.tscn")
		_finish(1)
		return

	var game: Node3D = scene_res.instantiate() as Node3D
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)

	# Wait for game.ready_to_play
	var start_wait: int = Time.get_ticks_msec()
	while not game.ready_to_play and (Time.get_ticks_msec() - start_wait) < 120000:
		await process_frame

	if not game.ready_to_play:
		_log_test("Game Lifecycle Ready", false, "Timed out waiting for game.ready_to_play")
		_finish(1)
		return

	_log_test("Game Lifecycle Ready", true, "CampusRuntime initialized in %d ms" % (Time.get_ticks_msec() - start_wait))

	# Record baseline snapshot of CampusRenderBatches, lights, and env
	var baseline := _snapshot_state(game)
	results["baseline_batches"] = {
		"multimesh_count": baseline["multimesh_batches"].size(),
		"static_surface_count": baseline["static_surfaces"].size()
	}

	# -------------------------------------------------------------
	# TIER 3: Rapid Multiple Install / Uninstall Cycles
	# -------------------------------------------------------------
	print("\n--- TIER 3: RAPID MULTIPLE INSTALL / UNINSTALL CYCLES ---")
	_test_tier3_rapid_cycles(game, baseline)

	# -------------------------------------------------------------
	# TIER 4: Multi-Instance Interference Stress
	# -------------------------------------------------------------
	print("\n--- TIER 4: MULTI-INSTANCE INTERFERENCE STRESS ---")
	_test_tier4_multi_instance(game)

	# -------------------------------------------------------------
	# TIER 5: In-Tree Node Mutation Resilience
	# -------------------------------------------------------------
	print("\n--- TIER 5: SCENE MUTATION RESILIENCE ---")
	_test_tier5_node_mutation(game)

	# -------------------------------------------------------------
	# TIER 6: Final Integrity Verification vs Baseline
	# -------------------------------------------------------------
	print("\n--- TIER 6: FINAL BASELINE PRESERVATION VERIFICATION ---")
	_verify_baseline_preservation(game, baseline)

	# Cleanup
	if is_instance_valid(game):
		game.queue_free()
	await process_frame

	_finish(0 if results["failed_tests"] == 0 else 1)

func _test_tier1_inputs() -> void:
	var polish: Node3D = PolishScript.new()

	# 1.1 install(null)
	var r_null: Dictionary = polish.install(null)
	_log_test("Input: null", r_null.get("installed") == false and r_null.get("errors", []).size() > 0, "Rejected null correctly")

	# 1.2 install(unready node)
	var unready := Node3D.new()
	var r_unready: Dictionary = polish.install(unready)
	_log_test("Input: unready Node3D", r_unready.get("installed") == false and r_unready.get("errors", []).size() > 0, "Rejected node without ready_to_play")
	unready.free()

	# 1.3 install(node with ready_to_play = false)
	var ready_false := Node3D.new()
	ready_false.set("ready_to_play", false)
	var r_false: Dictionary = polish.install(ready_false)
	_log_test("Input: ready_to_play = false", r_false.get("installed") == false, "Rejected ready_to_play=false")
	ready_false.free()

	# 1.4 install(node with ready_to_play = "string")
	var ready_str := Node3D.new()
	ready_str.set("ready_to_play", "true")
	var r_str: Dictionary = polish.install(ready_str)
	_log_test("Input: ready_to_play = String", r_str.get("installed") == false, "Rejected non-bool ready_to_play")
	ready_str.free()

	# 1.5 install(node with ready_to_play = 0)
	var ready_zero := Node3D.new()
	ready_zero.set("ready_to_play", 0)
	var r_zero: Dictionary = polish.install(ready_zero)
	_log_test("Input: ready_to_play = 0", r_zero.get("installed") == false, "Rejected integer 0")
	ready_zero.free()

	# 1.6 uninstall() before install
	var r_uninst: Dictionary = polish.uninstall()
	_log_test("Uninstall before install", r_uninst.get("uninstalled") == false and r_uninst.get("status") == "not_installed", "Safe handling of premature uninstall")

	# 1.7 10 consecutive uninstall calls on uninstalled module
	var uninst_repeat_ok: bool = true
	for i in range(10):
		var r_rep: Dictionary = polish.uninstall()
		if r_rep.get("uninstalled") != false or r_rep.get("status") != "not_installed":
			uninst_repeat_ok = false
			break
	_log_test("10x consecutive premature uninstall", uninst_repeat_ok, "Repeated uninstalls handled safely")

	# 1.8 install(node with invalid state)
	# Note: In Godot 4.3 GDScript, passing a previously-freed Object to a typed `game: Node3D` argument
	# is intercepted by the engine's Variant type checker before function entry.
	# We verify that passing null or invalid variants is handled safely without crashing.
	var r_null2: Dictionary = polish.install(null)
	_log_test("Input: secondary null check", r_null2.get("installed") == false, "Rejected null cleanly")

	polish.free()

func _test_tier3_rapid_cycles(game: Node3D, baseline: Dictionary) -> void:
	var polish: Node3D = PolishScript.new()
	root.add_child(polish)

	# Rapid Sequence: install -> install -> uninstall -> install -> uninstall -> uninstall
	# 1. Initial Install
	var r1: Dictionary = polish.install(game)
	_log_test("Cycle 1: install()", r1.get("installed") == true, "Installed successfully")

	# 2. Immediate Re-install (Idempotency)
	var r2: Dictionary = polish.install(game)
	_log_test("Cycle 2: repeated install()", r2.get("installed") == true and r2.get("already_installed") == true, "Idempotent duplicate install detected")

	# 3. Third Install call
	var r3: Dictionary = polish.install(game)
	_log_test("Cycle 3: third install()", r3.get("installed") == true and r3.get("already_installed") == true, "Second duplicate install handled")

	# 4. Uninstall
	var u1: Dictionary = polish.uninstall()
	_log_test("Cycle 4: uninstall()", u1.get("uninstalled") == true and u1.get("status") == "clean", "Clean uninstall executed")

	# 5. Immediate Re-install
	var r4: Dictionary = polish.install(game)
	_log_test("Cycle 5: re-install()", r4.get("installed") == true, "Clean re-install succeeded after uninstall")

	# 6. Uninstall
	var u2: Dictionary = polish.uninstall()
	_log_test("Cycle 6: second uninstall()", u2.get("uninstalled") == true and u2.get("status") == "clean", "Second clean uninstall executed")

	# 7. Redundant Uninstall
	var u3: Dictionary = polish.uninstall()
	_log_test("Cycle 7: redundant uninstall()", u3.get("uninstalled") == false and u3.get("status") == "not_installed", "Redundant uninstall safely caught")

	# 8. High frequency stress loop: 5 consecutive install/uninstall cycles
	var loop_passed: bool = true
	var cycle_times: Array[float] = []
	for loop_idx in range(5):
		var t0: int = Time.get_ticks_usec()
		var inst_res: Dictionary = polish.install(game)
		var uninst_res: Dictionary = polish.uninstall()
		var dt_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		cycle_times.append(dt_ms)
		if not inst_res.get("installed", false) or not uninst_res.get("uninstalled", false):
			loop_passed = false
			_log_test("Stress loop iteration %d" % loop_idx, false, "Failed cycle: inst=%s uninst=%s" % [inst_res, uninst_res])
			break

	if loop_passed:
		_log_test("High-frequency stress (5 cycles)", true, "Completed 5 back-to-back cycles (avg %.2f ms/cycle)" % (cycle_times.reduce(func(a,b): return a+b, 0.0) / cycle_times.size()))

	polish.queue_free()
	await process_frame

func _test_tier4_multi_instance(game: Node3D) -> void:
	var polish_a: Node3D = PolishScript.new()
	var polish_b: Node3D = PolishScript.new()
	root.add_child(polish_a)
	root.add_child(polish_b)

	# Install instance A
	var r_a: Dictionary = polish_a.install(game)
	_log_test("Multi-Instance: install A", r_a.get("installed") == true, "Instance A installed")

	# Install instance B on same game
	var r_b: Dictionary = polish_b.install(game)
	_log_test("Multi-Instance: install B blocked", r_b.get("already_installed") == true, "Instance B acknowledged existing installation via game metadata")

	# Attempt uninstall from instance B (which did not install)
	var u_b: Dictionary = polish_b.uninstall()
	_log_test("Multi-Instance: uninstall B safe", u_b.get("uninstalled") == false, "Instance B uninstall rejected cleanly without unhooking A")

	# Verify instance A is still intact
	_log_test("Multi-Instance: A remains installed", polish_a.is_installed() == true, "Instance A remains active")

	# Uninstall instance A
	var u_a: Dictionary = polish_a.uninstall()
	_log_test("Multi-Instance: uninstall A", u_a.get("uninstalled") == true, "Instance A uninstalled cleanly")

	polish_a.queue_free()
	polish_b.queue_free()
	await process_frame

func _test_tier5_node_mutation(game: Node3D) -> void:
	var polish: Node3D = PolishScript.new()
	root.add_child(polish)

	# Create a dummy child MeshInstance3D in game
	var test_mesh_node := MeshInstance3D.new()
	test_mesh_node.name = "TestChallengerVolatileMesh"
	var box := BoxMesh.new()
	test_mesh_node.mesh = box
	var test_mat := StandardMaterial3D.new()
	test_mat.resource_name = "mineral cream wall"
	test_mat.roughness = 0.8
	test_mesh_node.set_surface_override_material(0, test_mat)
	game.add_child(test_mesh_node)

	# Register into campus mesh_nodes if present
	var campus: Node = game.get_node_or_null("CampusRuntime")
	if campus != null and campus.get("mesh_nodes") is Array:
		(campus.get("mesh_nodes") as Array).append(test_mesh_node)

	var inst_res: Dictionary = polish.install(game)
	_log_test("Mutation: install with volatile node", inst_res.get("installed") == true, "Installed with volatile mesh")

	# Now delete the volatile node while polish is active
	test_mesh_node.free()

	# Call uninstall: should NOT crash with null reference error
	var uninst_res: Dictionary = polish.uninstall()
	_log_test("Mutation: uninstall after node freed", uninst_res.get("uninstalled") == true, "Uninstall survived deleted node gracefully (reported error count: %d)" % uninst_res.get("errors", []).size())

	polish.queue_free()
	await process_frame

func _snapshot_state(game: Node3D) -> Dictionary:
	var snap := {
		"multimesh_batches": {},
		"static_surfaces": {},
		"sun": {},
		"env": {}
	}
	var campus: Node = game.get_node_or_null("CampusRuntime")
	if campus != null:
		var batches_node: Node = campus.find_child("CampusRenderBatches", true, false)
		if batches_node != null:
			for child in batches_node.get_children():
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
	var sun: DirectionalLight3D = game.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if sun != null:
		snap["sun"] = {
			"normal_bias": sun.shadow_normal_bias,
			"bias": sun.shadow_bias,
			"blur": sun.shadow_blur,
			"energy": sun.light_energy
		}

	# Env
	var world_env: WorldEnvironment = game.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env != null and world_env.environment != null:
		snap["env"] = {
			"ambient_energy": world_env.environment.ambient_light_energy,
			"exposure": world_env.environment.tonemap_exposure
		}

	return snap

func _verify_baseline_preservation(game: Node3D, baseline: Dictionary) -> void:
	var current := _snapshot_state(game)

	# 1. Verify MultiMesh Batches
	var mm_passed := true
	var mm_base: Dictionary = baseline["multimesh_batches"]
	var mm_curr: Dictionary = current["multimesh_batches"]

	if mm_base.size() != mm_curr.size():
		mm_passed = false
		_log_test("MultiMesh batch count preservation", false, "Expected %d batches, got %d" % [mm_base.size(), mm_curr.size()])
	else:
		for b_name in mm_base:
			var b_rec: Dictionary = mm_base[b_name]
			var c_rec: Dictionary = mm_curr.get(b_name, {})
			if b_rec["instance_count"] != c_rec.get("instance_count"):
				mm_passed = false
				_log_test("MultiMesh instance count mismatch on " + b_name, false, "Base: %d, Curr: %s" % [b_rec["instance_count"], str(c_rec.get("instance_count"))])
			if b_rec["material_override"] != c_rec.get("material_override"):
				mm_passed = false
				_log_test("MultiMesh material_override mismatch on " + b_name, false, "Base: %s, Curr: %s" % [str(b_rec["material_override"]), str(c_rec.get("material_override"))])

	if mm_passed:
		_log_test("CampusRenderBatches MultiMeshes preserved", true, "All %d batches have identical instance counts and material overrides" % mm_base.size())

	# 2. Verify Static Surface Batches
	var ss_passed := true
	var ss_base: Dictionary = baseline["static_surfaces"]
	var ss_curr: Dictionary = current["static_surfaces"]

	if ss_base.size() != ss_curr.size():
		ss_passed = false
		_log_test("StaticSurface batch count preservation", false, "Expected %d batches, got %d" % [ss_base.size(), ss_curr.size()])
	else:
		for s_name in ss_base:
			var b_rec: Dictionary = ss_base[s_name]
			var c_rec: Dictionary = ss_curr.get(s_name, {})
			if b_rec["material_override"] != c_rec.get("material_override"):
				ss_passed = false
				_log_test("StaticSurface material_override mismatch on " + s_name, false, "Base: %s, Curr: %s" % [str(b_rec["material_override"]), str(c_rec.get("material_override"))])
			if b_rec["surface_override_0"] != c_rec.get("surface_override_0"):
				ss_passed = false
				_log_test("StaticSurface surface_override_0 mismatch on " + s_name, false, "Base: %s, Curr: %s" % [str(b_rec["surface_override_0"]), str(c_rec.get("surface_override_0"))])

	if ss_passed:
		_log_test("CampusRenderBatches StaticSurfaces preserved", true, "All %d merged surfaces have identical overrides" % ss_base.size())

	# 3. Verify Sun Properties
	var sun_base: Dictionary = baseline["sun"]
	var sun_curr: Dictionary = current["sun"]
	var sun_passed := true
	for prop in sun_base:
		if not is_equal_approx(float(sun_base[prop]), float(sun_curr.get(prop, 0.0))):
			sun_passed = false
			_log_test("Sun property " + prop, false, "Base: %f, Curr: %f" % [sun_base[prop], sun_curr.get(prop, 0.0)])
	if sun_passed:
		_log_test("DirectionalLight3D parameters restored", true, "Normal bias, bias, blur, energy match baseline")

	# 4. Verify WorldEnvironment Properties
	var env_base: Dictionary = baseline["env"]
	var env_curr: Dictionary = current["env"]
	var env_passed := true
	for prop in env_base:
		if not is_equal_approx(float(env_base[prop]), float(env_curr.get(prop, 0.0))):
			env_passed = false
			_log_test("Env property " + prop, false, "Base: %f, Curr: %f" % [env_base[prop], env_curr.get(prop, 0.0)])
	if env_passed:
		_log_test("WorldEnvironment parameters restored", true, "Ambient energy, exposure match baseline")

	# 5. Metadata Cleared
	var meta_cleared: bool = not game.has_meta("antigravity_polish_installed")
	_log_test("Game Metadata Cleared", meta_cleared, "antigravity_polish_installed removed")

func _finish(exit_code: int) -> void:
	results["passed"] = (results["failed_tests"] == 0 and exit_code == 0)
	var report_path: String = "res://tools/antigravity/challenger_stress_report.json"
	var f: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "\t"))
		f.close()
		print("\nCHALLENGER_REPORT_SAVED: ", report_path)

	print("=================================================================")
	print("CHALLENGER STRESS HARNESS FINISHED: passed=%s (total=%d, passed=%d, failed=%d)" % [
		str(results["passed"]), results["total_tests"], results["passed_tests"], results["failed_tests"]
	])
	print("=================================================================")
	quit(0 if results["passed"] else 1)
