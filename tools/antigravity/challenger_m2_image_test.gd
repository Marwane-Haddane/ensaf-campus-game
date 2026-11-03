extends SceneTree
## Adversarial Image Contract & Moiré Verification Test Harness for Milestone 2
## Developed by Challenger M2_2 (Empirical Challenger)
## Verifies 9 Polished captures against Baseline captures in tools/visual-polish/:
##   1. Dimensions & File Integrity Contract (1280x720 RGBA8)
##   2. Non-Blank / Dynamic Range / Variance Contract
##   3. Mutual Pairwise Uniqueness Contract (36 pairs)
##   4. Baseline Delta & Visual Polish Contract (MAE, RMSE, % changed)
##   5. Auditorium Ceiling Moiré / Nyquist Aliasing Reduction Contract
##   6. Cream Entrance Multi-Angle Feature & Lighting Contract

const CAPTURES: Array[String] = [
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

const REPORT_PATH: String = "res://tools/antigravity/challenger_m2_image_report.json"

var report: Dictionary = {
	"timestamp": "",
	"passed": false,
	"total_checks": 0,
	"passed_checks": 0,
	"failed_checks": 0,
	"failures": [],
	"suites": {
		"dimensions": {},
		"variance": {},
		"pairwise_uniqueness": {},
		"baseline_delta": {},
		"auditorium_ceiling_moire": {},
		"cream_entrance_features": {}
	}
}

func _init() -> void:
	call_deferred("_run_verification_suite")

func _assert_check(suite_name: String, check_name: String, condition: bool, details: String = "") -> void:
	report["total_checks"] = int(report["total_checks"]) + 1
	if condition:
		report["passed_checks"] = int(report["passed_checks"]) + 1
		print("  [PASS] [%s] %s: %s" % [suite_name, check_name, details])
	else:
		report["failed_checks"] = int(report["failed_checks"]) + 1
		var err_msg: String = "[FAIL] [%s] %s: %s" % [suite_name, check_name, details]
		(report["failures"] as Array).append(err_msg)
		push_error(err_msg)
		print("  " + err_msg)

func _run_verification_suite() -> void:
	report["timestamp"] = Time.get_datetime_string_from_system(true)
	print("=================================================================")
	print("CHALLENGER M2_2: EMPIRICAL IMAGE CONTRACT & MOIRE TEST SUITE")
	print("=================================================================")

	var polished_images: Dictionary = {}
	var baseline_images: Dictionary = {}

	# -------------------------------------------------------------
	# SUITE 1: Image Dimensions & Existence Contract
	# -------------------------------------------------------------
	print("\n--- SUITE 1: DIMENSIONS & FILE INTEGRITY CONTRACT ---")
	for cap_name: String in CAPTURES:
		var p_path := "res://tools/visual-polish/polished_%s.png" % cap_name
		var b_path := "res://tools/visual-polish/baseline_%s.png" % cap_name

		var p_img := Image.new()
		var p_err := p_img.load(p_path)
		var b_img := Image.new()
		var b_err := b_img.load(b_path)

		_assert_check("dimensions", "%s_polished_exists" % cap_name, p_err == OK, "File loaded cleanly (%s)" % p_path)
		_assert_check("dimensions", "%s_baseline_exists" % cap_name, b_err == OK, "File loaded cleanly (%s)" % b_path)

		if p_err == OK and b_err == OK:
			var p_size := p_img.get_size()
			var b_size := b_img.get_size()
			var p_exact_dims: bool = (p_size.x == 1280 and p_size.y == 720)
			var b_exact_dims: bool = (b_size.x == 1280 and b_size.y == 720)
			_assert_check("dimensions", "%s_polished_1280x720" % cap_name, p_exact_dims, "Polished resolution is %s" % str(p_size))
			_assert_check("dimensions", "%s_baseline_1280x720" % cap_name, b_exact_dims, "Baseline resolution is %s" % str(b_size))
			polished_images[cap_name] = p_img
			baseline_images[cap_name] = b_img
			(report["suites"]["dimensions"] as Dictionary)[cap_name] = {
				"polished_size": [p_size.x, p_size.y],
				"baseline_size": [b_size.x, b_size.y],
				"polished_format": p_img.get_format()
			}

	# -------------------------------------------------------------
	# SUITE 2: Non-Blank / Dynamic Range / Variance Contract
	# -------------------------------------------------------------
	print("\n--- SUITE 2: NON-BLANK & LUMINANCE VARIANCE CONTRACT ---")
	for cap_name: String in CAPTURES:
		if not polished_images.has(cap_name):
			continue
		var img: Image = polished_images[cap_name] as Image
		var total_pixels: int = img.get_width() * img.get_height()
		var lum_sum: float = 0.0

		for y: int in range(0, img.get_height()):
			for x: int in range(0, img.get_width()):
				lum_sum += img.get_pixel(x, y).get_luminance()
		var mean_lum: float = lum_sum / float(total_pixels)

		var var_sum: float = 0.0
		var min_lum: float = 1.0
		var max_lum: float = 0.0
		for y: int in range(0, img.get_height()):
			for x: int in range(0, img.get_width()):
				var l: float = img.get_pixel(x, y).get_luminance()
				var diff: float = l - mean_lum
				var_sum += diff * diff
				if l < min_lum: min_lum = l
				if l > max_lum: max_lum = l

		var std_dev: float = sqrt(var_sum / float(total_pixels))
		var dyn_range: float = max_lum - min_lum

		var non_blank: bool = (mean_lum >= 0.05 and mean_lum <= 0.95)
		var high_variance: bool = (std_dev >= 0.08)
		var full_range: bool = (dyn_range >= 0.50)

		_assert_check("variance", "%s_non_blank" % cap_name, non_blank, "Mean lum=%.3f in [0.05..0.95]" % mean_lum)
		_assert_check("variance", "%s_variance_healthy" % cap_name, high_variance, "Luminance std=%.3f >= 0.08" % std_dev)
		_assert_check("variance", "%s_dynamic_range" % cap_name, full_range, "Dyn range=%.3f (min=%.3f, max=%.3f) >= 0.50" % [dyn_range, min_lum, max_lum])

		(report["suites"]["variance"] as Dictionary)[cap_name] = {
			"mean_luminance": mean_lum,
			"std_dev": std_dev,
			"min_luminance": min_lum,
			"max_luminance": max_lum,
			"dynamic_range": dyn_range
		}

	# -------------------------------------------------------------
	# SUITE 3: Pairwise Mutual Uniqueness Contract
	# -------------------------------------------------------------
	print("\n--- SUITE 3: PAIRWISE MUTUAL UNIQUENESS CONTRACT (36 PAIRS) ---")
	var min_pairwise_mae: float = 999.0
	var min_pair_name: String = ""
	var pairwise_checks_passed: int = 0
	var total_pairs: int = 0

	for i: int in range(0, CAPTURES.size()):
		for j: int in range(i + 1, CAPTURES.size()):
			total_pairs += 1
			var name_a: String = CAPTURES[i]
			var name_b: String = CAPTURES[j]
			var img_a: Image = polished_images[name_a] as Image
			var img_b: Image = polished_images[name_b] as Image

			var diff_sum: float = 0.0
			var sample_count: int = 0
			# Subsample by stride 2 for high speed while maintaining statistical certainty
			for y: int in range(0, 720, 2):
				for x: int in range(0, 1280, 2):
					var ca: Color = img_a.get_pixel(x, y)
					var cb: Color = img_b.get_pixel(x, y)
					diff_sum += (abs(ca.r - cb.r) + abs(ca.g - cb.g) + abs(ca.b - cb.b)) / 3.0
					sample_count += 1

			var pair_mae: float = diff_sum / float(sample_count)
			if pair_mae < min_pairwise_mae:
				min_pairwise_mae = pair_mae
				min_pair_name = "%s vs %s" % [name_a, name_b]

			if pair_mae >= 0.10:
				pairwise_checks_passed += 1

	_assert_check("pairwise_uniqueness", "all_36_pairs_distinct", pairwise_checks_passed == total_pairs,
		"All %d pairs have MAE >= 0.10 (Minimum MAE = %.4f in %s)" % [total_pairs, min_pairwise_mae, min_pair_name])

	(report["suites"]["pairwise_uniqueness"] as Dictionary)["total_pairs"] = total_pairs
	(report["suites"]["pairwise_uniqueness"] as Dictionary)["min_pairwise_mae"] = min_pairwise_mae
	(report["suites"]["pairwise_uniqueness"] as Dictionary)["closest_pair"] = min_pair_name

	# -------------------------------------------------------------
	# SUITE 4: Baseline Delta & Visual Polish Contract
	# -------------------------------------------------------------
	print("\n--- SUITE 4: BASELINE DELTA & POLISH EFFECT CONTRACT ---")
	for cap_name: String in CAPTURES:
		var p_img: Image = polished_images[cap_name] as Image
		var b_img: Image = baseline_images[cap_name] as Image
		var total_pixels: int = 1280 * 720

		var mae_sum: float = 0.0
		var mse_sum: float = 0.0
		var changed_pixels: int = 0

		for y: int in range(0, 720):
			for x: int in range(0, 1280):
				var cp: Color = p_img.get_pixel(x, y)
				var cb: Color = b_img.get_pixel(x, y)
				var dr: float = abs(cp.r - cb.r)
				var dg: float = abs(cp.g - cb.g)
				var db: float = abs(cp.b - cb.b)
				mae_sum += (dr + dg + db) / 3.0
				mse_sum += (dr * dr + dg * dg + db * db) / 3.0
				if dr > 0.01 or dg > 0.01 or db > 0.01:
					changed_pixels += 1

		var mae: float = mae_sum / float(total_pixels)
		var rmse: float = sqrt(mse_sum / float(total_pixels))
		var pct_changed: float = (float(changed_pixels) / float(total_pixels)) * 100.0
		var psnr: float = 20.0 * (log(1.0 / max(0.00001, rmse)) / log(10.0))

		var delta_meaningful: bool = (mae >= 0.010 and pct_changed >= 15.0)
		_assert_check("baseline_delta", "%s_polish_effect" % cap_name, delta_meaningful,
			"MAE=%.4f (>=0.010), Changed=%.1f%% (>=15%%), RMSE=%.4f, PSNR=%.1f dB" % [mae, pct_changed, rmse, psnr])

		(report["suites"]["baseline_delta"] as Dictionary)[cap_name] = {
			"mae": mae,
			"rmse": rmse,
			"pct_changed": pct_changed,
			"psnr_db": psnr
		}

	# -------------------------------------------------------------
	# SUITE 5: Auditorium Ceiling Moiré / Nyquist Aliasing Reduction
	# -------------------------------------------------------------
	print("\n--- SUITE 5: AUDITORIUM CEILING MOIRE REDUCTION CONTRACT ---")
	var b_aud: Image = baseline_images["auditorium_rear"] as Image
	var p_aud: Image = polished_images["auditorium_rear"] as Image

	# 1. Center Ceiling Panel ROI (X:500-800, Y:40-180, N=42,000 pixels)
	var c_b_grad: float = 0.0
	var c_p_grad: float = 0.0
	var c_b_edges_08: int = 0
	var c_p_edges_08: int = 0
	var c_b_edges_15: int = 0
	var c_p_edges_15: int = 0
	var c_count: int = 0

	for y: int in range(40, 180):
		for x: int in range(500, 800):
			var b0: float = b_aud.get_pixel(x, y).get_luminance()
			var b1: float = b_aud.get_pixel(x + 1, y).get_luminance()
			var p0: float = p_aud.get_pixel(x, y).get_luminance()
			var p1: float = p_aud.get_pixel(x + 1, y).get_luminance()

			var gb: float = abs(b1 - b0)
			var gp: float = abs(p1 - p0)
			c_b_grad += gb
			c_p_grad += gp

			if gb > 0.08: c_b_edges_08 += 1
			if gp > 0.08: c_p_edges_08 += 1
			if gb > 0.15: c_b_edges_15 += 1
			if gp > 0.15: c_p_edges_15 += 1
			c_count += 1

	var c_b_grad_mean: float = c_b_grad / float(c_count)
	var c_p_grad_mean: float = c_p_grad / float(c_count)
	var c_grad_reduction: float = ((c_b_grad_mean - c_p_grad_mean) / c_b_grad_mean) * 100.0
	var c_edges_08_reduct: float = (float(c_b_edges_08 - c_p_edges_08) / float(c_b_edges_08)) * 100.0
	var c_edges_15_reduct: float = (float(c_b_edges_15 - c_p_edges_15) / float(c_b_edges_15)) * 100.0

	_assert_check("auditorium_ceiling_moire", "center_ceiling_gradient_smoothed", c_grad_reduction >= 25.0,
		"Center panel horizontal gradient reduced by %.1f%% (Baseline=%.5f, Polished=%.5f)" % [c_grad_reduction, c_b_grad_mean, c_p_grad_mean])
	_assert_check("auditorium_ceiling_moire", "center_ceiling_edge_noise_08_eliminated", c_edges_08_reduct >= 40.0,
		"Edges > 0.08 reduced by %.1f%% (Baseline=%d, Polished=%d)" % [c_edges_08_reduct, c_b_edges_08, c_p_edges_08])
	_assert_check("auditorium_ceiling_moire", "center_ceiling_nyquist_spikes_15_eliminated", c_edges_15_reduct >= 60.0,
		"High-contrast Nyquist spikes (>0.15) reduced by %.1f%% (Baseline=%d, Polished=%d)" % [c_edges_15_reduct, c_b_edges_15, c_p_edges_15])

	# 2. Right Ceiling / Aisle ROI (X:960-1240, Y:100-240, N=39,200 pixels)
	var r_b_edges_15: int = 0
	var r_p_edges_15: int = 0
	var r_b_grad: float = 0.0
	var r_p_grad: float = 0.0
	var r_count: int = 0

	for y: int in range(100, 240):
		for x: int in range(960, 1240):
			var b0: float = b_aud.get_pixel(x, y).get_luminance()
			var b1: float = b_aud.get_pixel(x + 1, y).get_luminance()
			var p0: float = p_aud.get_pixel(x, y).get_luminance()
			var p1: float = p_aud.get_pixel(x + 1, y).get_luminance()

			var gb: float = abs(b1 - b0)
			var gp: float = abs(p1 - p0)
			r_b_grad += gb
			r_p_grad += gp
			if gb > 0.15: r_b_edges_15 += 1
			if gp > 0.15: r_p_edges_15 += 1
			r_count += 1

	var r_b_grad_mean: float = r_b_grad / float(r_count)
	var r_p_grad_mean: float = r_p_grad / float(r_count)
	var r_grad_reduction: float = ((r_b_grad_mean - r_p_grad_mean) / r_b_grad_mean) * 100.0
	var r_edges_15_reduct: float = (float(r_b_edges_15 - r_p_edges_15) / float(r_b_edges_15)) * 100.0

	_assert_check("auditorium_ceiling_moire", "right_ceiling_nyquist_spikes_reduced", r_edges_15_reduct >= 25.0,
		"Right ceiling spikes >0.15 reduced by %.1f%% (Baseline=%d, Polished=%d)" % [r_edges_15_reduct, r_b_edges_15, r_p_edges_15])
	_assert_check("auditorium_ceiling_moire", "right_ceiling_gradient_smoothed", r_grad_reduction >= 10.0,
		"Right ceiling gradient reduced by %.1f%% (Baseline=%.5f, Polished=%.5f)" % [r_grad_reduction, r_b_grad_mean, r_p_grad_mean])

	(report["suites"]["auditorium_ceiling_moire"] as Dictionary)["center_panel"] = {
		"gradient_reduction_pct": c_grad_reduction,
		"edges_08_reduction_pct": c_edges_08_reduct,
		"edges_15_reduction_pct": c_edges_15_reduct
	}
	(report["suites"]["auditorium_ceiling_moire"] as Dictionary)["right_panel"] = {
		"gradient_reduction_pct": r_grad_reduction,
		"edges_15_reduction_pct": r_edges_15_reduct
	}

	# -------------------------------------------------------------
	# SUITE 6: Cream Entrance Multi-Angle Feature & Lighting Contract
	# -------------------------------------------------------------
	print("\n--- SUITE 6: CREAM ENTRANCE FEATURES & LIGHTING CONTRACT ---")
	var b_front: Image = baseline_images["cream_front"] as Image
	var p_front: Image = polished_images["cream_front"] as Image
	var b_ext45: Image = baseline_images["cream_exterior_45"] as Image
	var p_ext45: Image = polished_images["cream_exterior_45"] as Image
	var b_inout: Image = baseline_images["cream_inside_out"] as Image
	var p_inout: Image = polished_images["cream_inside_out"] as Image

	# 1. Canopy Downlight Landing Illumination (cream_front, Y:450-700, X:400-880)
	var dl_b_lum: float = 0.0
	var dl_p_lum: float = 0.0
	var dl_b_warmth: float = 0.0
	var dl_p_warmth: float = 0.0
	var dl_count: int = 0

	for y: int in range(450, 700):
		for x: int in range(400, 880):
			var cb: Color = b_front.get_pixel(x, y)
			var cp: Color = p_front.get_pixel(x, y)
			dl_b_lum += cb.get_luminance()
			dl_p_lum += cp.get_luminance()
			dl_b_warmth += (cb.r + cb.g) / max(0.01, 2.0 * cb.b)
			dl_p_warmth += (cp.r + cp.g) / max(0.01, 2.0 * cp.b)
			dl_count += 1

	var dl_b_lum_mean: float = dl_b_lum / float(dl_count)
	var dl_p_lum_mean: float = dl_p_lum / float(dl_count)
	var dl_lum_boost: float = ((dl_p_lum_mean - dl_b_lum_mean) / dl_b_lum_mean) * 100.0
	var dl_b_warm_mean: float = dl_b_warmth / float(dl_count)
	var dl_p_warm_mean: float = dl_p_warmth / float(dl_count)

	_assert_check("cream_entrance_features", "canopy_downlight_luminance_boost", dl_lum_boost >= 5.0,
		"Downlight landing luminance increased by +%.2f%% (Baseline=%.4f, Polished=%.4f)" % [dl_lum_boost, dl_b_lum_mean, dl_p_lum_mean])
	_assert_check("cream_entrance_features", "canopy_downlight_warmth", dl_p_warm_mean > dl_b_warm_mean,
		"Downlight warmth ratio enhanced (Baseline=%.3f, Polished=%.3f)" % [dl_b_warm_mean, dl_p_warm_mean])

	# 2. Architectural Entrance Signage Detection (cream_front, lintel at X:624-656, Y:288-320)
	var sign_max_delta: float = 0.0
	var sign_mean_delta: float = 0.0
	var sign_count: int = 0

	for y: int in range(288, 320):
		for x: int in range(624, 656):
			var cb: Color = b_front.get_pixel(x, y)
			var cp: Color = p_front.get_pixel(x, y)
			var d: float = (abs(cp.r - cb.r) + abs(cp.g - cb.g) + abs(cp.b - cb.b)) / 3.0
			sign_mean_delta += d
			if d > sign_max_delta:
				sign_max_delta = d
			sign_count += 1
	sign_mean_delta /= float(sign_count)

	_assert_check("cream_entrance_features", "architectural_signage_present", sign_max_delta >= 0.20,
		"Signage letters detected at lintel center (Max delta=%.4f >= 0.20, Mean delta=%.4f)" % [sign_max_delta, sign_mean_delta])

	# 3. Exterior 45-degree angle capture verification
	var ext_mae_val: float = (report["suites"]["baseline_delta"]["cream_exterior_45"]["mae"] as float)
	var ext_pct_val: float = (report["suites"]["baseline_delta"]["cream_exterior_45"]["pct_changed"] as float)
	_assert_check("cream_entrance_features", "cream_exterior_45_active", ext_mae_val >= 0.02 and ext_pct_val >= 50.0,
		"Exterior 45 view confirmed active (MAE=%.4f, Changed=%.1f%%)" % [ext_mae_val, ext_pct_val])

	# 4. Inside looking out marble specular reflection contrast (cream_inside_out, Y:420-700, X:200-1080)
	var fl_b_lum: float = 0.0
	var fl_p_lum: float = 0.0
	var fl_count: int = 0
	for y: int in range(420, 700):
		for x: int in range(200, 1080):
			fl_b_lum += b_inout.get_pixel(x, y).get_luminance()
			fl_p_lum += p_inout.get_pixel(x, y).get_luminance()
			fl_count += 1
	var fl_b_mean: float = fl_b_lum / float(fl_count)
	var fl_p_mean: float = fl_p_lum / float(fl_count)

	var fl_b_var: float = 0.0
	var fl_p_var: float = 0.0
	for y: int in range(420, 700):
		for x: int in range(200, 1080):
			var lb: float = b_inout.get_pixel(x, y).get_luminance()
			var lp: float = p_inout.get_pixel(x, y).get_luminance()
			fl_b_var += (lb - fl_b_mean) * (lb - fl_b_mean)
			fl_p_var += (lp - fl_p_mean) * (lp - fl_p_mean)
	var fl_b_std: float = sqrt(fl_b_var / float(fl_count))
	var fl_p_std: float = sqrt(fl_p_var / float(fl_count))
	var fl_contrast_increase: float = ((fl_p_std - fl_b_std) / fl_b_std) * 100.0

	_assert_check("cream_entrance_features", "inside_out_marble_specular_contrast", fl_contrast_increase >= 10.0,
		"Marble floor specular reflection contrast increased by +%.2f%% (Baseline std=%.4f, Polished std=%.4f)" % [
			fl_contrast_increase, fl_b_std, fl_p_std
		])

	(report["suites"]["cream_entrance_features"] as Dictionary)["canopy_downlight"] = {
		"luminance_boost_pct": dl_lum_boost,
		"warmth_boost": dl_p_warm_mean - dl_b_warm_mean
	}
	(report["suites"]["cream_entrance_features"] as Dictionary)["signage"] = {
		"max_delta": sign_max_delta,
		"mean_delta": sign_mean_delta
	}
	(report["suites"]["cream_entrance_features"] as Dictionary)["marble_floor"] = {
		"contrast_increase_pct": fl_contrast_increase
	}

	# -------------------------------------------------------------
	# FINAL ASSESSMENT & REPORT EXPORT
	# -------------------------------------------------------------
	var all_passed: bool = (int(report["failed_checks"]) == 0 and int(report["passed_checks"]) > 0)
	report["passed"] = all_passed

	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
		print("\nREPORT SAVED TO: %s" % REPORT_PATH)

	print("\n=================================================================")
	print("CHALLENGER M2_2 VERDICT: %s (Total: %d, Passed: %d, Failed: %d)" % [
		"PASS" if all_passed else "FAIL",
		report["total_checks"],
		report["passed_checks"],
		report["failed_checks"]
	])
	print("=================================================================")

	quit(0 if all_passed else 1)
