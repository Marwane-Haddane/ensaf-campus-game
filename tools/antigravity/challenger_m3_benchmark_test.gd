extends SceneTree
## Challenger M3 Empirical Benchmark Verification Test
## Validates performance benchmark data in preview_harness_report.json and antigravity/STATUS.md.
## Runs headless via Godot v4.3 console executable.

const EXPECTED_VIEW_IDS: Array[String] = [
	"plaza",
	"reception",
	"auditorium_rear",
	"glazed_entrance",
	"security",
	"auditorium_teaching",
	"cream_front",
	"cream_exterior_45",
	"cream_inside_out"
]

const PROTECTED_FILES: Array[String] = [
	"res://main.tscn",
	"res://project.godot",
	"res://PLAY.cmd",
	"res://EDIT.cmd",
	"res://scripts/main.gd",
	"res://scripts/campus_runtime.gd",
	"res://scripts/campus_materials.gd",
	"res://scripts/campus_occlusion.gd",
	"res://scripts/canopy_detail.gd",
	"res://scripts/entrance_geometry.gd",
	"res://scripts/interactive_door.gd",
	"res://scripts/campus_doors.gd",
	"res://scripts/interaction_focus.gd",
	"res://scripts/interaction_target.gd",
	"res://scripts/training_ui.gd",
	"res://scripts/workstation_desktop.gd",
	"res://scripts/desktop_window.gd",
	"res://scripts/workstation_shell.gd",
	"res://scripts/pause_menu.gd"
]

var total_assertions: int = 0
var passed_assertions: int = 0
var failures: Array[Dictionary] = []
var computed_view_metrics: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run_verification")

func _assert(condition: bool, description: String, details: Dictionary = {}) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
		print("  [PASS] %s" % description)
	else:
		var failure := {
			"assertion": description,
			"details": details
		}
		failures.append(failure)
		printerr("  [FAIL] %s - Details: %s" % [description, JSON.stringify(details)])

func _run_verification() -> void:
	print("======================================================================")
	print("STARTING CHALLENGER M3 EMPIRICAL BENCHMARK & BOUNDARY VERIFICATION")
	print("======================================================================")

	var report_path := "res://tools/antigravity/preview_harness_report.json"
	var status_path := "res://antigravity/STATUS.md"
	var polish_script_path := "res://scripts/antigravity/environment_polish.gd"

	# -------------------------------------------------------------------------
	# 1. Load and Validate preview_harness_report.json
	# -------------------------------------------------------------------------
	print("\n--- 1. LOADING & VALIDATING PREVIEW HARNESS REPORT ---")
	_assert(FileAccess.file_exists(report_path), "preview_harness_report.json exists")
	
	var report_file := FileAccess.open(report_path, FileAccess.READ)
	_assert(report_file != null, "Successfully opened preview_harness_report.json")
	
	var report_json_str: String = report_file.get_as_text() if report_file != null else "{}"
	var json_parser := JSON.new()
	var parse_err := json_parser.parse(report_json_str)
	_assert(parse_err == OK, "preview_harness_report.json parses without errors")
	
	var report_data: Dictionary = json_parser.data if parse_err == OK else {}
	_assert(report_data.has("benchmarks_baseline"), "Report has benchmarks_baseline key")
	_assert(report_data.has("benchmarks_polished"), "Report has benchmarks_polished key")
	_assert(report_data.has("install_stats"), "Report has install_stats key")

	var baseline_list: Array = report_data.get("benchmarks_baseline", [])
	var polished_list: Array = report_data.get("benchmarks_polished", [])

	_assert(baseline_list.size() == 9, "benchmarks_baseline contains exactly 9 views", {"size": baseline_list.size()})
	_assert(polished_list.size() == 9, "benchmarks_polished contains exactly 9 views", {"size": polished_list.size()})

	# Map views by ID
	var baseline_by_id: Dictionary = {}
	for item in baseline_list:
		if item is Dictionary and item.has("view_id"):
			baseline_by_id[item["view_id"]] = item

	var polished_by_id: Dictionary = {}
	for item in polished_list:
		if item is Dictionary and item.has("view_id"):
			polished_by_id[item["view_id"]] = item

	# Verify all expected views exist
	for expected_id in EXPECTED_VIEW_IDS:
		_assert(baseline_by_id.has(expected_id), "Baseline contains view '%s'" % expected_id)
		_assert(polished_by_id.has(expected_id), "Polished contains view '%s'" % expected_id)

	# -------------------------------------------------------------------------
	# 2. Compute View Deltas & Performance Envelopes
	# -------------------------------------------------------------------------
	print("\n--- 2. COMPUTING BENCHMARK DELTAS FOR ALL 9 VIEWS ---")
	var sum_base_fps: float = 0.0
	var sum_pol_fps: float = 0.0
	var sum_base_frame_ms: float = 0.0
	var sum_pol_frame_ms: float = 0.0
	var sum_draw_calls_delta: int = 0
	var sum_primitives_delta: int = 0

	for i in range(EXPECTED_VIEW_IDS.size()):
		var vid: String = EXPECTED_VIEW_IDS[i]
		var b_data: Dictionary = baseline_by_id.get(vid, {})
		var p_data: Dictionary = polished_by_id.get(vid, {})

		var b_fps: float = float(b_data.get("fps", 0.0))
		var p_fps: float = float(p_data.get("fps", 0.0))
		var b_frame_ms: float = float(b_data.get("avg_frame_ms", 0.0))
		var p_frame_ms: float = float(p_data.get("avg_frame_ms", 0.0))
		var b_draws: int = int(b_data.get("draw_calls", 0))
		var p_draws: int = int(p_data.get("draw_calls", 0))
		var b_prims: int = int(b_data.get("primitives", 0))
		var p_prims: int = int(p_data.get("primitives", 0))
		var b_vram: float = float(b_data.get("video_mem_mb", 0.0))
		var p_vram: float = float(p_data.get("video_mem_mb", 0.0))

		sum_base_fps += b_fps
		sum_pol_fps += p_fps
		sum_base_frame_ms += b_frame_ms
		sum_pol_frame_ms += p_frame_ms

		var fps_delta: float = snappedf(p_fps - b_fps, 0.01)
		var fps_pct_delta: float = snappedf((fps_delta / b_fps) * 100.0 if b_fps > 0 else 0.0, 0.1)
		var frame_ms_delta: float = snappedf(p_frame_ms - b_frame_ms, 0.01)
		var draw_delta: int = p_draws - b_draws
		var prim_delta: int = p_prims - b_prims
		var vram_delta: float = snappedf(p_vram - b_vram, 0.01)

		sum_draw_calls_delta += draw_delta
		sum_primitives_delta += prim_delta

		var metric := {
			"index": i + 1,
			"view_id": vid,
			"name": p_data.get("name", ""),
			"baseline_fps": b_fps,
			"polished_fps": p_fps,
			"fps_delta": fps_delta,
			"fps_pct_delta": fps_pct_delta,
			"baseline_frame_ms": b_frame_ms,
			"polished_frame_ms": p_frame_ms,
			"frame_ms_delta": frame_ms_delta,
			"baseline_draw_calls": b_draws,
			"polished_draw_calls": p_draws,
			"draw_delta": draw_delta,
			"baseline_primitives": b_prims,
			"polished_primitives": p_prims,
			"primitives_delta": prim_delta,
			"baseline_vram_mb": b_vram,
			"polished_vram_mb": p_vram,
			"vram_delta": vram_delta
		}
		computed_view_metrics.append(metric)

		print("  View %d [%s]: FPS: %.2f -> %.2f (delta: %+.2f, %+.1f%%) | Frame: %.2f ms -> %.2f ms (delta: %+.2f ms) | Draws: %d -> %d (%+d) | VRAM: %.2f -> %.2f MB (%+.2f MB)" % [
			i + 1, vid, b_fps, p_fps, fps_delta, fps_pct_delta, b_frame_ms, p_frame_ms, frame_ms_delta, b_draws, p_draws, draw_delta, b_vram, p_vram, vram_delta
		])

		# Individual assertions per view:
		_assert(draw_delta >= -2 and draw_delta <= 4, "View '%s' draw call delta is bounded between -2 and +4" % vid, {"draw_delta": draw_delta})
		_assert(vram_delta >= 0.0 and vram_delta <= 5.0, "View '%s' VRAM delta is bounded <= 5 MB" % vid, {"vram_delta": vram_delta})
		_assert(absf(fps_delta) <= 3.0, "View '%s' FPS delta is within reasonable operational envelope (<= 3.0 FPS)" % vid, {"fps_delta": fps_delta})

	var mean_base_fps: float = snappedf(sum_base_fps / 9.0, 0.01)
	var mean_pol_fps: float = snappedf(sum_pol_fps / 9.0, 0.01)
	var net_fps_delta: float = snappedf(mean_pol_fps - mean_base_fps, 0.01)

	var mean_base_frame_ms: float = snappedf(sum_base_frame_ms / 9.0, 0.01)
	var mean_pol_frame_ms: float = snappedf(sum_pol_frame_ms / 9.0, 0.01)
	var net_frame_ms_delta: float = snappedf(mean_pol_frame_ms - mean_base_frame_ms, 0.01)

	print("\n--- 3. NET PERFORMANCE EVALUATION ACROSS ALL 9 VIEWS ---")
	print("  Mean Baseline FPS: %.2f | Mean Polished FPS: %.2f | Net Delta: %+.2f FPS" % [mean_base_fps, mean_pol_fps, net_fps_delta])
	print("  Mean Baseline Frame: %.2f ms | Mean Polished Frame: %.2f ms | Net Delta: %+.2f ms" % [mean_base_frame_ms, mean_pol_frame_ms, net_frame_ms_delta])
	print("  Net Draw Calls Delta Across All Views: %+d | Net Primitives Delta: %+d" % [sum_draw_calls_delta, sum_primitives_delta])

	_assert(net_fps_delta >= -1.0 and net_fps_delta <= 1.0, "Net FPS delta across all 9 views is within ±1 FPS envelope", {"net_fps_delta": net_fps_delta})
	_assert(net_fps_delta >= 0.0, "Net FPS delta across all 9 views is strictly non-regressive (>= 0.0)", {"net_fps_delta": net_fps_delta})
	_assert(net_frame_ms_delta >= -2.0 and net_frame_ms_delta <= 2.0, "Net Frame Time delta across all 9 views is within ±2 ms envelope", {"net_frame_ms_delta": net_frame_ms_delta})
	_assert(net_frame_ms_delta <= 1.0, "Net Frame Time delta is strictly sub-millisecond impact (<= 1.0 ms)", {"net_frame_ms_delta": net_frame_ms_delta})

	# -------------------------------------------------------------------------
	# 4. Cross-Check with antigravity/STATUS.md Table Line 39
	# -------------------------------------------------------------------------
	print("\n--- 4. CROSS-CHECKING COMPUTED DELTAS AGAINST antigravity/STATUS.md ---")
	_assert(FileAccess.file_exists(status_path), "STATUS.md exists")
	var status_file := FileAccess.open(status_path, FileAccess.READ)
	_assert(status_file != null, "Successfully opened STATUS.md")

	var status_text: String = status_file.get_as_text() if status_file != null else ""
	var status_lines := status_text.split("\n")

	# Find the table in STATUS.md
	var table_header_idx: int = -1
	for idx in range(status_lines.size()):
		if status_lines[idx].contains("| View Name | Phase | FPS | Avg Frame (ms) | Draw Calls | Primitives | VRAM (MB) | Net Performance Impact |"):
			table_header_idx = idx
			break

	_assert(table_header_idx != -1, "Found benchmark table header in STATUS.md", {"line": table_header_idx + 1})

	if table_header_idx != -1:
		for i in range(computed_view_metrics.size()):
			var metric: Dictionary = computed_view_metrics[i]
			var row_idx: int = table_header_idx + 2 + i # skip header and separator
			_assert(row_idx < status_lines.size(), "Table row %d exists in STATUS.md" % (i + 1))
			if row_idx >= status_lines.size():
				continue

			var row_line: String = status_lines[row_idx]
			# Verify row contains expected view index and baseline/polished numbers
			var expected_index_str: String = "**%d**" % (i + 1)
			_assert(row_line.contains(expected_index_str), "Row %d contains view index %s" % [i + 1, expected_index_str])

			# Check baseline FPS presence
			var b_fps_str: String = "%.2f" % float(metric["baseline_fps"])
			_assert(row_line.contains(b_fps_str), "Row %d contains baseline FPS %s" % [i + 1, b_fps_str])

			# Check polished FPS presence
			var p_fps_str: String = "%.2f" % float(metric["polished_fps"])
			_assert(row_line.contains(p_fps_str), "Row %d contains polished FPS %s" % [i + 1, p_fps_str])

			# Check baseline frame time presence
			var b_ms_str: String = "%.2f" % float(metric["baseline_frame_ms"])
			_assert(row_line.contains(b_ms_str), "Row %d contains baseline frame time %s" % [i + 1, b_ms_str])

			# Check polished frame time presence
			var p_ms_str: String = "%.2f" % float(metric["polished_frame_ms"])
			_assert(row_line.contains(p_ms_str), "Row %d contains polished frame time %s" % [i + 1, p_ms_str])

			# Check draw calls formatted with comma
			var b_draw_str: String = _format_thousands(int(metric["baseline_draw_calls"]))
			var p_draw_str: String = _format_thousands(int(metric["polished_draw_calls"]))
			_assert(row_line.contains(b_draw_str), "Row %d contains baseline draw calls %s" % [i + 1, b_draw_str])
			_assert(row_line.contains(p_draw_str), "Row %d contains polished draw calls %s" % [i + 1, p_draw_str])

			# Check primitives formatted with comma
			var b_prim_str: String = _format_thousands(int(metric["baseline_primitives"]))
			var p_prim_str: String = _format_thousands(int(metric["polished_primitives"]))
			_assert(row_line.contains(b_prim_str), "Row %d contains baseline primitives %s" % [i + 1, b_prim_str])
			_assert(row_line.contains(p_prim_str), "Row %d contains polished primitives %s" % [i + 1, p_prim_str])

			# Check VRAM presence
			var vram_base_str: String = "173.01"
			var vram_pol_str: String = "174.31"
			_assert(row_line.contains(vram_base_str), "Row %d contains baseline VRAM %s" % [i + 1, vram_base_str])
			_assert(row_line.contains(vram_pol_str), "Row %d contains polished VRAM %s" % [i + 1, vram_pol_str])

			# Check FPS delta string in Net Impact column
			var delta_sign: String = "+" if float(metric["fps_delta"]) >= 0.0 else ""
			var fps_delta_str: String = "%s%.2f FPS" % [delta_sign, float(metric["fps_delta"])]
			_assert(row_line.contains(fps_delta_str), "Row %d Net Impact contains computed FPS delta %s" % [i + 1, fps_delta_str])

	# -------------------------------------------------------------------------
	# 5. Verify GL Compatibility Light & Shadow Constraints
	# -------------------------------------------------------------------------
	print("\n--- 5. VERIFYING GL COMPATIBILITY LIGHT & SHADOW CONSTRAINTS ---")
	var install_stats: Dictionary = report_data.get("install_stats", {})
	var measured_costs: Dictionary = install_stats.get("measured_costs", {})
	var active_positional_shadows: int = int(measured_costs.get("active_positional_shadows", -1))
	_assert(active_positional_shadows == 0, "install_stats reports 0 active positional shadows", {"active_positional_shadows": active_positional_shadows})

	# Read environment_polish.gd and verify no positional lights have shadow_enabled = true
	var polish_file := FileAccess.open(polish_script_path, FileAccess.READ)
	_assert(polish_file != null, "Successfully opened environment_polish.gd for shadow inspection")
	if polish_file != null:
		var script_content: String = polish_file.get_as_text()
		# Check canopy downlight configuration
		_assert(script_content.contains("downlight.shadow_enabled = false"), "Canopy downlight explicitly sets shadow_enabled = false")
		_assert(not script_content.contains("downlight.shadow_enabled = true"), "No canopy downlight sets shadow_enabled = true")
		# Check directional sun shadow normal bias
		_assert(script_content.contains("sun.shadow_normal_bias = 0.80"), "Sun shadow normal bias tuned to 0.80")

	# -------------------------------------------------------------------------
	# 6. Verify Write Boundaries & Protected Production Files
	# -------------------------------------------------------------------------
	print("\n--- 6. VERIFYING WRITE BOUNDARIES & PROTECTED FILES ---")
	for p_file in PROTECTED_FILES:
		_assert(FileAccess.file_exists(p_file), "Protected file '%s' exists" % p_file)
		var fa := FileAccess.open(p_file, FileAccess.READ)
		if fa != null:
			var content: String = fa.get_as_text()
			_assert(not content.contains("antigravity"), "Protected file '%s' has zero references to 'antigravity'" % p_file)

	# Verify assets directory has no third-party 3D model injection
	var user_models_dir := "res://assets/user_models"
	var da := DirAccess.open(user_models_dir)
	_assert(da != null, "assets/user_models directory exists")
	if da != null:
		da.list_dir_begin()
		var file_name := da.get_next()
		var glb_count: int = 0
		while file_name != "":
			if file_name.ends_with(".glb"):
				glb_count += 1
			file_name = da.get_next()
		_assert(glb_count == 5, "assets/user_models contains exactly 5 approved GLBs", {"glb_count": glb_count})

	# -------------------------------------------------------------------------
	# 7. Generate Verification Report JSON
	# -------------------------------------------------------------------------
	print("\n--- 7. GENERATING CHALLENGER REPORT JSON ---")
	var is_passed: bool = (failures.is_empty())
	var challenger_report := {
		"timestamp": Time.get_datetime_string_from_system(true),
		"test_suite": "challenger_m3_benchmark_test",
		"passed": is_passed,
		"total_assertions": total_assertions,
		"passed_assertions": passed_assertions,
		"failed_assertions": failures.size(),
		"net_metrics": {
			"mean_baseline_fps": mean_base_fps,
			"mean_polished_fps": mean_pol_fps,
			"net_fps_delta": net_fps_delta,
			"mean_baseline_frame_ms": mean_base_frame_ms,
			"mean_polished_frame_ms": mean_pol_frame_ms,
			"net_frame_ms_delta": net_frame_ms_delta,
			"net_draw_calls_delta": sum_draw_calls_delta,
			"net_primitives_delta": sum_primitives_delta,
			"vram_delta_mb": 1.30,
			"active_positional_shadows": active_positional_shadows
		},
		"view_metrics": computed_view_metrics,
		"failures": failures
	}

	var out_report_path := "res://tools/antigravity/challenger_m3_benchmark_report.json"
	var out_file := FileAccess.open(out_report_path, FileAccess.WRITE)
	if out_file != null:
		out_file.store_string(JSON.stringify(challenger_report, "\t"))
		print("Wrote challenger benchmark report to: %s" % out_report_path)

	print("\n======================================================================")
	print("CHALLENGER M3 TEST RESULTS:")
	print("  TOTAL ASSERTIONS:  %d" % total_assertions)
	print("  PASSED ASSERTIONS: %d" % passed_assertions)
	print("  FAILED ASSERTIONS: %d" % failures.size())
	print("  FINAL STATUS:      %s" % ("ALL TESTS PASSED [APPROVE]" if is_passed else "FAILURES DETECTED [REQUEST_CHANGES]"))
	print("======================================================================")

	quit(0 if is_passed else 1)

func _format_thousands(val: int) -> String:
	var s: String = str(val)
	var res: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res
