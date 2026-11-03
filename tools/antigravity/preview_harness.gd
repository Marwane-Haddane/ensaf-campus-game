extends SceneTree
## Standalone SceneTree harness for native 1280x720 capture and performance QA across ENSA Fez campus areas.
## Operates non-destructively against unmodified main.tscn.

const VIEWS: Array[Dictionary] = [
	{
		"id": "plaza",
		"name": "Campus plaza",
		"spawn": "Campus plaza",
		"eye": Vector3(-27.0, 1.90, -85.0),
		"target": Vector3(-37.0, 1.90, -104.0),
		"pitch": 0.0,
		"description": "Courtyard paving, garden landscaping, palm trees, building exterior"
	},
	{
		"id": "reception",
		"name": "Reception / response desk",
		"spawn": "Reception / response desk",
		"eye": Vector3(-36.2, 2.56, -104.1),
		"target": Vector3(-36.2, 1.91, -106.0),
		"pitch": -0.23,
		"description": "Reception desk, PC terminal, chairs, glazed partition, counter shading"
	},
	{
		"id": "auditorium_rear",
		"name": "Auditorium rear aisle",
		"spawn": "Auditorium rear aisle",
		"eye": Vector3(-37.0, 2.574, -107.95),
		"target": Vector3(-37.0, 1.924, -122.0),
		"pitch": 0.0,
		"description": "Auditorium seating rows, ceiling panels, aisle lighting, stage distance"
	},
	{
		"id": "glazed_entrance",
		"name": "Glazed building entrance",
		"spawn": "Glazed building entrance",
		"eye": Vector3(-5.80, 3.45, -102.9),
		"target": Vector3(-8.0, 2.80, -107.0),
		"pitch": 0.0,
		"description": "Atrium glass facade, mullions, daylight glare, floor stone"
	},
	{
		"id": "security",
		"name": "Security training area",
		"spawn": "Security training area",
		"eye": Vector3(0.90, 3.45, -110.5),
		"target": Vector3(0.0, 2.80, -112.0),
		"pitch": -0.23,
		"description": "Workstation desk, chair, server racks (Lab & Recovery), window light"
	},
	{
		"id": "auditorium_teaching",
		"name": "Auditorium teaching desk",
		"spawn": "Auditorium teaching desk",
		"eye": Vector3(-43.0, 1.74, -121.4),
		"target": Vector3(-43.0, 1.09, -122.0),
		"pitch": -0.55,
		"description": "Teaching podium desk, PC terminal, chairs, stage border, floor wood"
	},
	{
		"id": "cream_front",
		"name": "Cream main entrance (front)",
		"spawn": "",
		"eye": Vector3(-14.0, 2.06, 1.8),
		"target": Vector3(-14.0, 1.75, 0.04),
		"pitch": 0.0,
		"description": "Front approach to cream main entrance, canopy underside, glass double doors"
	},
	{
		"id": "cream_exterior_45",
		"name": "Cream main entrance (45° exterior)",
		"spawn": "",
		"eye": Vector3(-18.0, 2.30, 5.3),
		"target": Vector3(-14.0, 1.70, 0.04),
		"pitch": 0.0,
		"description": "45-degree oblique view showing 3-step entrance stairs, plinth, and columns"
	},
	{
		"id": "cream_inside_out",
		"name": "Cream main entrance (inside looking out)",
		"spawn": "",
		"eye": Vector3(-14.0, 2.06, -2.4),
		"target": Vector3(-14.0, 1.65, 2.6),
		"pitch": 0.0,
		"description": "Interior vestibule looking out through double glass doors to exterior daylight"
	}
]

var game: Node3D = null
var polish_node: Node3D = null
var config: Dictionary = {}
var report: Dictionary = {
	"started_at": "",
	"finished_at": "",
	"passed": false,
	"viewport": "1280x720",
	"msaa": "2x",
	"captures": [],
	"benchmarks_baseline": [],
	"benchmarks_polished": [],
	"install_stats": {},
	"failures": []
}

func _init() -> void:
	call_deferred("_run_harness")

func _run_harness() -> void:
	report["started_at"] = Time.get_datetime_string_from_system(true)
	config = _parse_args()
	print("PREVIEW_HARNESS_START mode=%s out_dir=%s" % [config["mode"], config["out_dir"]])

	# 1. Viewport configuration (1280x720, 2x MSAA)
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_2X

	# 2. Instantiate unmodified production scene
	var scene_res: PackedScene = load("res://main.tscn")
	if scene_res == null:
		_fail("Could not load res://main.tscn")
		return
	
	game = scene_res.instantiate() as Node3D
	if game == null:
		_fail("Could not instantiate res://main.tscn as Node3D")
		return
	root.add_child(game)

	# 3. Suppress player inputs and physics to avoid drifting during captures
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	if is_instance_valid(game.training):
		game.training.set_process_input(false)

	# 4. Synchronize with asynchronous campus initialization
	var started_msec: int = Time.get_ticks_msec()
	var timeout_msec: int = 120000 # 2 minute safety guard
	while not game.ready_to_play and (Time.get_ticks_msec() - started_msec) < timeout_msec:
		await process_frame

	if not game.ready_to_play:
		_fail("Timed out waiting for game.ready_to_play (120s limit exceeded)")
		return

	print("CAMPUS_READY_CONFIRMED elapsed_ms=%d" % (Time.get_ticks_msec() - started_msec))
	# Production now installs polish automatically. Restore a real baseline before
	# comparison/lifecycle tests instead of silently comparing polish against itself.
	var production_polish: Node = game.get_node_or_null("AntigravityEnvironmentPolish")
	if is_instance_valid(production_polish) and production_polish.has_method("uninstall"):
		production_polish.call("uninstall")
		production_polish.free()
		game.environment_polish = null
		game.polish_stats = {}
		await process_frame

	# 5. Clean menu and pause overlays
	game._resume()
	if is_instance_valid(game.menu):
		game.menu.hide()
	if is_instance_valid(game.pause_menu):
		game.pause_menu.hide_menu()
	if is_instance_valid(game.menu_shade):
		game.menu_shade.hide()
	if is_instance_valid(game.training):
		game.training.set_exploration_visible(true)

	# 6. Mode Execution
	var mode: String = config["mode"]

	if mode == "polish-test":
		print("--- EXECUTING ENVIRONMENT POLISH UNIT/CONTRACT TESTS ---")
		_run_polish_tests()
		_finish(0 if report["failures"].is_empty() else 1)
		return

	if mode in ["baseline", "all"]:
		print("--- EXECUTING BASELINE CAPTURES ---")
		await _capture_all_views("baseline")

	if mode in ["benchmark", "all"]:
		print("--- EXECUTING BASELINE BENCHMARKS ---")
		report["benchmarks_baseline"] = await _benchmark_all_views("baseline")

	var polish_available: bool = ResourceLoader.exists("res://scripts/antigravity/environment_polish.gd")
	if (mode in ["polish", "all", "benchmark"]) and polish_available:
		print("--- INSTALLING ENVIRONMENT POLISH MODULE ---")
		var install_result: Dictionary = _install_polish()
		report["install_stats"] = install_result

		if mode in ["polish", "all"]:
			print("--- EXECUTING POLISHED CAPTURES ---")
			await _capture_all_views("polished")

		if mode in ["benchmark", "all"]:
			print("--- EXECUTING POLISHED BENCHMARKS ---")
			report["benchmarks_polished"] = await _benchmark_all_views("polished")
	elif (mode in ["polish", "all"]) and not polish_available:
		print("POLISH_MODULE_NOTICE: res://scripts/antigravity/environment_polish.gd not found. Skipping polish phase.")

	# 7. Clean Shutdown
	_finish(0 if report["failures"].is_empty() else 1)

func _parse_args() -> Dictionary:
	var parsed := {
		"mode": "all",
		"out_dir": "res://tools/visual-polish",
		"report_path": "res://tools/antigravity/preview_harness_report.json"
	}
	var all_args: PackedStringArray = OS.get_cmdline_args()
	all_args.append_array(OS.get_cmdline_user_args())

	for arg: String in all_args:
		if arg == "--baseline":
			parsed["mode"] = "baseline"
		elif arg == "--polish":
			parsed["mode"] = "polish"
		elif arg == "--benchmark":
			parsed["mode"] = "benchmark"
		elif arg == "--polish-test":
			parsed["mode"] = "polish-test"
		elif arg == "--all":
			parsed["mode"] = "all"
		elif arg.begins_with("--mode="):
			parsed["mode"] = arg.trim_prefix("--mode=")
		elif arg.begins_with("--out-dir="):
			parsed["out_dir"] = arg.trim_prefix("--out-dir=")
		elif arg.begins_with("--report="):
			parsed["report_path"] = arg.trim_prefix("--report=")
	return parsed

func _set_camera_view(view_def: Dictionary) -> void:
	# Reset rotation state to avoid pitch/yaw carryover between views
	game.player.velocity = Vector3.ZERO
	game.player.transform.basis = Basis.IDENTITY
	game.pitch = 0.0
	game.camera.transform.basis = Basis.IDENTITY
	game.camera.rotation = Vector3.ZERO

	var spawn_name: String = view_def.get("spawn", "")
	if spawn_name != "" and game.SPAWNS.has(spawn_name):
		game._spawn(spawn_name)
		game.player.velocity = Vector3.ZERO
	else:
		var eye: Vector3 = view_def["eye"]
		var target: Vector3 = view_def["target"]
		game.player.global_position = eye - Vector3(0.0, 0.65, 0.0)
		game.camera.look_at(target, Vector3.UP)

func _capture_all_views(prefix: String) -> void:
	for view_def: Dictionary in VIEWS:
		_set_camera_view(view_def)
		# 4 warming frames to let transforms and dynamic contact lights settle
		for _frame in range(4):
			await process_frame
		
		RenderingServer.force_draw(false)
		var img: Image = root.get_texture().get_image()
		
		var filename: String = "%s_%s.png" % [prefix, view_def["id"]]
		var rel_path: String = config["out_dir"].path_join(filename)
		var global_path: String = ProjectSettings.globalize_path(rel_path)
		var dir_path: String = global_path.get_base_dir()

		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)

		var err: Error = img.save_png(global_path)
		if err == OK:
			report["captures"].append(rel_path)
			print("CAPTURE_SAVED [%s]: %s (%dx%d)" % [prefix, rel_path, img.get_width(), img.get_height()])
		else:
			var err_msg: String = "Failed to save screenshot: %s (error %d)" % [rel_path, err]
			push_error(err_msg)
			report["failures"].append({"error": err_msg, "view": view_def["id"]})

func _benchmark_all_views(phase_name: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for view_def: Dictionary in VIEWS:
		_set_camera_view(view_def)

		# 1. Warm-up 20 frames with forced draws to eliminate first-frame pipeline stutter
		for _i in range(20):
			await process_frame
			RenderingServer.force_draw(false)

		# 2. Timed loop: 30 forced frames
		var draw_usec_total: int = 0
		var start_usec: int = Time.get_ticks_usec()
		for _i in range(30):
			await process_frame
			var frame_start: int = Time.get_ticks_usec()
			RenderingServer.force_draw(false)
			draw_usec_total += Time.get_ticks_usec() - frame_start

		var elapsed_usec: int = Time.get_ticks_usec() - start_usec
		var elapsed_sec: float = float(elapsed_usec) / 1000000.0
		var fps: float = 30.0 / elapsed_sec if elapsed_sec > 0.0 else 0.0
		var avg_frame_ms: float = (elapsed_sec * 1000.0) / 30.0
		var avg_forced_draw_ms: float = (float(draw_usec_total) / 1000.0) / 30.0

		var draw_calls: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var primitives: int = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var video_mem_mb: float = float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / (1024.0 * 1024.0)

		var record: Dictionary = {
			"phase": phase_name,
			"view_id": view_def["id"],
			"name": view_def["name"],
			"fps": snappedf(fps, 0.01),
			"avg_frame_ms": snappedf(avg_frame_ms, 0.01),
			"forced_draw_ms": snappedf(avg_forced_draw_ms, 0.01),
			"draw_calls": draw_calls,
			"primitives": primitives,
			"video_mem_mb": snappedf(video_mem_mb, 0.01)
		}
		results.append(record)
		print("BENCHMARK [%s | %s]: %.1f FPS, %.2f ms, %d draw calls, %d primitives" % [
			phase_name, view_def["id"], fps, avg_frame_ms, draw_calls, primitives
		])
	return results

func _install_polish() -> Dictionary:
	var script_path := "res://scripts/antigravity/environment_polish.gd"
	if not ResourceLoader.exists(script_path):
		return {"installed": false, "error": "file_not_found"}

	var PolishScript = load(script_path)
	if PolishScript == null:
		var err_msg: String = "Failed to load polish script: %s" % script_path
		report["failures"].append({"error": err_msg})
		return {"installed": false, "error": "load_failed"}

	polish_node = PolishScript.new()
	polish_node.name = "AntigravityEnvironmentPolish"
	game.add_child(polish_node)

	var install_stats: Dictionary = polish_node.install(game)
	print("POLISH_INSTALL_COMPLETED: ", JSON.stringify(install_stats))
	return install_stats

func _fail(message: String) -> void:
	push_error("PREVIEW_HARNESS_FAILURE: " + message)
	report["failures"].append({"error": message})
	print("PREVIEW_HARNESS_FAIL: ", message)
	_finish(1)

func _finish(exit_code: int) -> void:
	report["finished_at"] = Time.get_datetime_string_from_system(true)
	report["passed"] = (exit_code == 0 and report["failures"].is_empty())

	# Serialize report JSON
	var report_rel_path: String = config.get("report_path", "res://tools/antigravity/preview_harness_report.json")
	var global_report_path: String = ProjectSettings.globalize_path(report_rel_path)
	var dir_path: String = global_report_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var f: FileAccess = FileAccess.open(global_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
		print("REPORT_SAVED: ", global_report_path)
	else:
		push_error("Failed to write report to %s" % global_report_path)

	print("PREVIEW_HARNESS_DONE passed=%s failures=%d captures=%d" % [
		str(report["passed"]), report["failures"].size(), report["captures"].size()
	])

	# Cleanup game tree
	if is_instance_valid(game):
		game.queue_free()

	await process_frame
	quit(0 if report["passed"] else 1)

func _run_polish_tests() -> void:
	var script_path := "res://scripts/antigravity/environment_polish.gd"
	if not ResourceLoader.exists(script_path):
		_fail("environment_polish.gd not found")
		return
	var PolishScript = load(script_path)
	var polish: Node3D = PolishScript.new()

	# Test 1: install(null)
	var err_res: Dictionary = polish.install(null)
	if err_res.get("installed", false) != false or err_res.get("errors", []).is_empty():
		_fail("Test 1 failed: install(null) should fail")
		return
	print("TEST 1 PASSED: install(null) properly rejected")

	# Test 2: install on not ready game
	var dummy_game := Node3D.new()
	var not_ready_res: Dictionary = polish.install(dummy_game)
	if not_ready_res.get("installed", false) != false or not_ready_res.get("errors", []).is_empty():
		_fail("Test 2 failed: install on unready game should fail")
		dummy_game.free()
		return
	dummy_game.free()
	print("TEST 2 PASSED: install on unready game properly rejected")

	# Test 3: Clean install on game
	var res1: Dictionary = polish.install(game)
	if not res1.get("installed", false):
		_fail("Test 3 failed: install(game) did not return installed=true: " + str(res1))
		return
	for key in ["installed", "changes", "resource_counts", "affected_areas", "measured_costs"]:
		if not res1.has(key):
			_fail("Test 3 failed: missing required contract key: " + key)
			return
	print("TEST 3 PASSED: install(game) succeeded with full contract dictionary")

	# Test 4: Idempotent call to install
	var res2: Dictionary = polish.install(game)
	if not res2.get("already_installed", false):
		_fail("Test 4 failed: repeated install() did not report already_installed=true")
		return
	print("TEST 4 PASSED: install(game) is idempotent")

	# Test 5: Clean uninstall
	var uninst: Dictionary = polish.uninstall()
	if not uninst.get("uninstalled", false) or uninst.get("status") != "clean":
		_fail("Test 5 failed: uninstall() failed: " + str(uninst))
		return
	print("TEST 5 PASSED: uninstall() reverted all overrides cleanly")

	# Test 6: Idempotent uninstall
	var uninst2: Dictionary = polish.uninstall()
	if uninst2.get("uninstalled", false) != false or uninst2.get("status") != "not_installed":
		_fail("Test 6 failed: secondary uninstall() unexpected result: " + str(uninst2))
		return
	print("TEST 6 PASSED: secondary uninstall() safely handled")

	# Test 7: Re-install after uninstall
	var res3: Dictionary = polish.install(game)
	if not res3.get("installed", false):
		_fail("Test 7 failed: re-install failed: " + str(res3))
		return
	print("TEST 7 PASSED: re-installation after uninstall succeeded")

	# Test 8: Final clean uninstall
	var uninst3: Dictionary = polish.uninstall()
	if not uninst3.get("uninstalled", false):
		_fail("Test 8 failed: final uninstall failed: " + str(uninst3))
		return
	print("TEST 8 PASSED: final clean uninstall succeeded")
	polish.queue_free()
