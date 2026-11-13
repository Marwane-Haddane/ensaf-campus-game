## build_loading_assets.gd — Generates and prepares 24 Zombie slides + Cyber slides
## Crops, color-grades (AAA deep-navy blue and crimson emergency lighting),
## and exports WebP assets, slide registry manifest, and destination copies.
## Completely eliminates baked-in HUDs, debug text, and rectangular box artifacts.
extends SceneTree

const INTRO_DEST_DIR := "C:/1Project/Vr --- cyber/ensaf-campus-v4-project/ENSA-Fes-Campus-v4/3D-modeling/3d models/intro"
const ZOMBIE_DEST_DIR := "C:/1Project/Vr --- cyber/ensaf-campus-v4-project/ENSA-Fes-Campus-v4/3D-modeling/3d models/zombie"

const TARGET_W := 1920
const TARGET_H := 1080

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== Building AAA Cinematic Loading Slides ===")
	_ensure_dirs()
	var zombie_slides := _get_zombie_slide_specs()
	var cyber_slides := _get_cyber_slide_specs()

	var processed_count := 0

	for spec in zombie_slides:
		var img := _process_slide_image(spec)
		if img != null:
			var webp_path: String = spec["target_webp"]
			var abs_webp: String = ProjectSettings.globalize_path(webp_path)
			var err := img.save_webp(abs_webp, false, 0.90)
			if err == OK:
				print("  ✓ Saved %s (%dx%d)" % [webp_path, img.get_width(), img.get_height()])
				# Copy to 3d models/intro
				var intro_copy := "%s/%s.webp" % [INTRO_DEST_DIR, spec["id"]]
				img.save_webp(intro_copy, false, 0.90)

				# If enemy slide, also copy to 3d models/zombie
				if spec["category"] == "enemy":
					var zombie_copy := "%s/%s.webp" % [ZOMBIE_DEST_DIR, spec["id"]]
					img.save_webp(zombie_copy, false, 0.90)

				processed_count += 1
			else:
				printerr("  ✗ Failed saving %s: error %d" % [webp_path, err])

	for spec in cyber_slides:
		var img := _process_slide_image(spec)
		if img != null:
			var webp_path: String = spec["target_webp"]
			var abs_webp: String = ProjectSettings.globalize_path(webp_path)
			var err := img.save_webp(abs_webp, false, 0.90)
			if err == OK:
				print("  ✓ Saved %s (%dx%d)" % [webp_path, img.get_width(), img.get_height()])
				var intro_copy := "%s/%s.webp" % [INTRO_DEST_DIR, spec["id"]]
				img.save_webp(intro_copy, false, 0.90)
				processed_count += 1

	# Also copy the existing 3D enemy model renders to 3d models/zombie
	_copy_enemy_model_renders()

	# Save full manifest
	_write_manifest(zombie_slides, cyber_slides)

	print("=== Asset build complete! Processed %d slides ===" % processed_count)
	quit(0)

func _ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/loading/zombie"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/loading/cyber"))
	DirAccess.make_dir_recursive_absolute(INTRO_DEST_DIR)
	DirAccess.make_dir_recursive_absolute(ZOMBIE_DEST_DIR)

func _load_image_safe(path: String) -> Image:
	var abs_p := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_p):
		if FileAccess.file_exists(path):
			abs_p = path
		else:
			return null
	var img := Image.new()
	var err := img.load(abs_p)
	if err == OK and not img.is_empty():
		return img
	return null

func _process_slide_image(spec: Dictionary) -> Image:
	var base_paths: Array = spec.get("source_candidates", [])
	var base_img: Image = null

	for p in base_paths:
		base_img = _load_image_safe(p)
		if base_img != null:
			break

	if base_img == null:
		base_img = _load_image_safe("res://assets/launcher/campus-dusk-reference.png")
		if base_img == null:
			base_img = Image.create(TARGET_W, TARGET_H, false, Image.FORMAT_RGBA8)
			base_img.fill(Color(0.04, 0.07, 0.12))

	base_img.convert(Image.FORMAT_RGBA8)

	# Crop & scale to 16:9
	var norm_crop: Rect2 = spec.get("norm_crop", Rect2())
	var img := _crop_to_16_9(base_img, TARGET_W, TARGET_H, norm_crop)

	# Composite clean overlays (chroma-keyed)
	var overlays: Array = spec.get("overlays", [])
	var single_overlay: String = spec.get("overlay_model", "")
	if single_overlay != "" and overlays.is_empty():
		overlays = [{
			"path": single_overlay,
			"pos": spec.get("overlay_pos", Vector2(0.65, 0.45)),
			"scale": spec.get("overlay_scale", 0.55),
			"rim": spec.get("rim_color", Color.TRANSPARENT),
			"tint": spec.get("silhouette_tint", Color(0.14, 0.18, 0.26, 1.0))
		}]

	for ov_spec in overlays:
		var ov := _load_image_safe(ov_spec.get("path", ""))
		if ov != null:
			ov.convert(Image.FORMAT_RGBA8)
			_composite_model_accent(
				img,
				ov,
				ov_spec.get("pos", Vector2(0.65, 0.45)),
				ov_spec.get("scale", 0.55),
				ov_spec.get("rim", Color.TRANSPARENT),
				ov_spec.get("tint", Color(0.14, 0.18, 0.26, 1.0))
			)

	# Apply cinematic atmosphere grading (cool deep-blue tint, contrast, vignette, emergency red)
	var tint: Color = spec.get("tint", Color(0.92, 0.95, 1.05))
	var red_glow: float = spec.get("emergency_red_intensity", 0.0)
	var contrast: float = spec.get("contrast", 1.06)
	_apply_cinematic_grade(img, tint, red_glow, contrast)

	return img

func _crop_to_16_9(src: Image, out_w: int, out_h: int, norm_crop: Rect2 = Rect2()) -> Image:
	var sw := src.get_width()
	var sh := src.get_height()

	var crop_x := 0
	var crop_y := 0
	var crop_w := sw
	var crop_h := sh

	if norm_crop.size.x > 0.0 and norm_crop.size.y > 0.0:
		crop_x = int(float(sw) * norm_crop.position.x)
		crop_y = int(float(sh) * norm_crop.position.y)
		crop_w = int(float(sw) * norm_crop.size.x)
		crop_h = int(float(sh) * norm_crop.size.y)
	else:
		var target_ratio := float(out_w) / float(out_h)
		var src_ratio := float(sw) / float(sh)
		if src_ratio > target_ratio:
			crop_w = int(float(sh) * target_ratio)
			crop_x = int((sw - crop_w) * 0.5)
		else:
			crop_h = int(float(sw) / target_ratio)
			crop_y = int((sh - crop_h) * 0.35)

	# Ensure strict 16:9 ratio
	var target_ratio := float(out_w) / float(out_h)
	var cur_ratio := float(crop_w) / float(crop_h)
	if cur_ratio > target_ratio:
		crop_w = int(float(crop_h) * target_ratio)
	elif cur_ratio < target_ratio:
		crop_h = int(float(crop_w) / target_ratio)

	crop_x = clampi(crop_x, 0, sw - 1)
	crop_y = clampi(crop_y, 0, sh - 1)
	crop_w = clampi(crop_w, 1, sw - crop_x)
	crop_h = clampi(crop_h, 1, sh - crop_y)

	var cropped := Image.create(crop_w, crop_h, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(src, Rect2i(crop_x, crop_y, crop_w, crop_h), Vector2i.ZERO)
	cropped.resize(out_w, out_h, Image.INTERPOLATE_LANCZOS)
	return cropped

func _composite_model_accent(base: Image, model: Image, norm_pos: Vector2, rel_scale: float, rim_color: Color = Color.TRANSPARENT, silhouette_tint: Color = Color(0.14, 0.18, 0.26, 1.0)) -> void:
	var mw := int(float(base.get_height()) * rel_scale)
	var mh := int(float(mw) * (float(model.get_height()) / float(model.get_width())))
	if mw <= 0 or mh <= 0:
		return
	var scaled_m := Image.create(model.get_width(), model.get_height(), false, Image.FORMAT_RGBA8)
	scaled_m.blit_rect(model, Rect2i(0, 0, model.get_width(), model.get_height()), Vector2i.ZERO)
	scaled_m.resize(mw, mh, Image.INTERPOLATE_LANCZOS)

	# Studio render background is uniform #161923 (0.086, 0.098, 0.137)
	var bg_r := 0.086
	var bg_g := 0.098
	var bg_b := 0.137

	var dest_x := int(float(base.get_width()) * norm_pos.x - float(mw) * 0.5)
	var dest_y := int(float(base.get_height()) * norm_pos.y - float(mh) * 0.5)

	for y in range(mh):
		var by := dest_y + y
		if by < 0 or by >= base.get_height():
			continue
		for x in range(mw):
			var bx := dest_x + x
			if bx < 0 or bx >= base.get_width():
				continue
			var mc := scaled_m.get_pixel(x, y)
			if mc.a <= 0.01:
				continue

			# Chroma-key studio background
			var dr := mc.r - bg_r
			var dg := mc.g - bg_g
			var db := mc.b - bg_b
			var dist := sqrt(dr * dr + dg * dg + db * db)
			if dist < 0.055:
				continue # Transparent studio background!

			var alpha_weight := clampf((dist - 0.055) / 0.065, 0.0, 1.0) * mc.a

			var bc := base.get_pixel(bx, by)
			# Tint into dark atmospheric infected silhouette
			var sil := Color(
				mc.r * silhouette_tint.r + 0.015,
				mc.g * silhouette_tint.g + 0.025,
				mc.b * silhouette_tint.b + 0.045,
				1.0
			)
			if rim_color.a > 0.0 and dist < 0.18:
				sil = sil.lerp(rim_color, 0.58)

			var blended := bc.lerp(sil, alpha_weight * 0.90)
			base.set_pixel(bx, by, blended)

func _apply_cinematic_grade(img: Image, tint: Color, emergency_red: float, contrast: float = 1.06) -> void:
	var w := img.get_width()
	var h := img.get_height()

	for y in range(0, h, 2):
		var ny := float(y) / float(h)
		for x in range(0, w, 2):
			var nx := float(x) / float(w)
			var c := img.get_pixel(x, y)

			# Radial vignette
			var dx := (nx - 0.5) * 1.3
			var dy := (ny - 0.5) * 1.3
			var d2 := dx * dx + dy * dy
			var vig := clampf(1.0 - d2 * 0.44, 0.42, 1.0)

			# Soft bottom-left gradient for UI safe zone
			var bl_dist := (nx * nx + (1.0 - ny) * (1.0 - ny))
			var bl_dim := clampf(smoothstep(0.0, 0.46, bl_dist), 0.52, 1.0)

			# Color grading & contrast
			var r := (c.r - 0.5) * contrast + 0.5
			var g := (c.g - 0.5) * contrast + 0.5
			var b := (c.b - 0.5) * contrast + 0.5

			r = clampf(r * tint.r * vig * bl_dim, 0.0, 1.0)
			g = clampf(g * tint.g * vig * bl_dim, 0.0, 1.0)
			b = clampf(b * tint.b * vig * bl_dim, 0.0, 1.0)

			# Red emergency glow on right-hand wall / beacon
			if emergency_red > 0.0:
				var red_dist := sqrt((nx - 0.88) * (nx - 0.88) + (ny - 0.22) * (ny - 0.22))
				var red_factor := clampf((1.0 - red_dist * 1.8) * emergency_red, 0.0, 0.6)
				r = clampf(r + red_factor * 0.45, 0.0, 1.0)
				g = clampf(g + red_factor * 0.08, 0.0, 1.0)
				b = clampf(b + red_factor * 0.08, 0.0, 1.0)

			var final_c := Color(r, g, b, 1.0)
			img.set_pixel(x, y, final_c)
			if x + 1 < w:
				img.set_pixel(x + 1, y, final_c)
			if y + 1 < h:
				img.set_pixel(x, y + 1, final_c)
				if x + 1 < w:
					img.set_pixel(x + 1, y + 1, final_c)

func _copy_enemy_model_renders() -> void:
	var enemy_renders: Array[String] = [
		"res://tools/antigravity/zombie/photos/zombie_walker_basic.png",
		"res://tools/antigravity/zombie/photos/01_zombie_walker_basic.png",
		"res://tools/antigravity/zombie/photos/zombie_brute_chubby.png",
		"res://tools/antigravity/zombie/photos/02_zombie_brute_chubby.png",
		"res://tools/antigravity/zombie/photos/zombie_crawler.png",
		"res://tools/antigravity/zombie/photos/05_female_warrior_model.png",
		"res://tools/antigravity/zombie/photos/06_winged_lion_warrior_model.png",
		"res://tools/antigravity/zombie/photos/07_shotgun_benelli_m4.png",
		"res://tools/antigravity/zombie/photos/08_scorpion_smg.png",
		"res://tools/antigravity/zombie/photos/companion_german_shepherd.png",
		"res://tools/antigravity/zombie/photos/03_survivor_shaun.png"
	]
	for p: String in enemy_renders:
		var img := _load_image_safe(p)
		if img:
			var fname: String = p.get_file()
			var dest := "%s/%s" % [ZOMBIE_DEST_DIR, fname]
			img.save_png(dest)
			print("  ✓ Copied enemy render %s to 3d models/zombie" % fname)

func _get_zombie_slide_specs() -> Array[Dictionary]:
	var atrium_gen := "C:/Users/marwa/.gemini/antigravity/brain/3b9989ed-3161-44c2-a44a-a5884afd44e0/atrium_after_dark_1793640362919.jpg"
	var wanderer_gen := "C:/Users/marwa/.gemini/antigravity/brain/3b9989ed-3161-44c2-a44a-a5884afd44e0/enemy_01_wanderer_1793640400710.jpg"
	var runner_gen := "C:/Users/marwa/.gemini/antigravity/brain/3b9989ed-3161-44c2-a44a-a5884afd44e0/enemy_02_runner_1793640420961.jpg"
	var dusk_ref := "res://assets/launcher/campus-dusk-reference.png"
	var case_workstation := "res://assets/launcher/case-workstation.png"
	var bg_campus := "res://assets/antigravity/launcher/bg_campus.png"

	return [
		# --- 12 Enemy Introductions ---
		{
			"id": "enemy_wanderer",
			"category": "enemy",
			"title": "The Wanderer",
			"subtitle": "Basic Infected Student",
			"tip": "Keep your distance and avoid becoming surrounded.",
			"enemy_type": "walker",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/enemy_wanderer.webp",
			"source_candidates": [wanderer_gen, atrium_gen],
			"tint": Color(0.95, 0.98, 1.05),
			"emergency_red_intensity": 0.4,
			"prompt": "AAA cinematic concept art of The Wanderer zombie archetype: A slow infected male university student wandering in a dim ENSA Fès modern university corridor at night. Dark blue shadows, blood splatters, wet reflective floor, red emergency lighting at the end of the hall. Clean image, NO UI, NO text."
		},
		{
			"id": "enemy_runner",
			"category": "enemy",
			"title": "The Runner",
			"subtitle": "Agile Incursion Threat",
			"tip": "Runners close distances quickly. Stay alert and keep your weapon drawn.",
			"enemy_type": "runner",
			"is_implemented": false,
			"target_webp": "res://assets/loading/zombie/enemy_runner.webp",
			"source_candidates": [runner_gen, dusk_ref],
			"tint": Color(0.92, 0.95, 1.08),
			"emergency_red_intensity": 0.45,
			"prompt": "Cinematic AAA survival horror concept art of The Runner: A terrifying, hyper-fast infected sprinter charging violently across the rain-swept exterior courtyard of ENSA Fès university campus at night. NO UI, NO text."
		},
		{
			"id": "enemy_screamer",
			"category": "enemy",
			"title": "The Screamer",
			"subtitle": "Acoustic Threat Alert",
			"tip": "Some enemies can draw attention to your position. Eliminate screamers first.",
			"enemy_type": "screamer",
			"is_implemented": false,
			"target_webp": "res://assets/loading/zombie/enemy_screamer.webp",
			"source_candidates": [atrium_gen],
			"overlay_model": "res://tools/antigravity/zombie/photos/zombie_ribcage_screamer.png",
			"overlay_pos": Vector2(0.68, 0.52),
			"overlay_scale": 0.52,
			"rim_color": Color(1.0, 0.18, 0.18, 0.85),
			"tint": Color(1.05, 0.88, 0.95),
			"emergency_red_intensity": 0.85,
			"prompt": "Cinematic AAA survival horror concept art of The Screamer: An infected figure screeching violently beneath a pulsing red emergency alarm beacon in an ENSA Fès corridor. Blood splatters, fog, deep navy blue shadows. NO UI, NO text."
		},
		{
			"id": "enemy_brute",
			"category": "enemy",
			"title": "The Brute",
			"subtitle": "Armored Heavy Infected",
			"tip": "Observe heavily armored enemies before engaging. Aim for unarmored weak points.",
			"enemy_type": "brute",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/enemy_brute.webp",
			"source_candidates": [atrium_gen, bg_campus],
			"overlay_model": "res://tools/antigravity/zombie/photos/zombie_brute_chubby.png",
			"overlay_pos": Vector2(0.64, 0.50),
			"overlay_scale": 0.72,
			"rim_color": Color(0.92, 0.25, 0.25, 0.75),
			"tint": Color(0.88, 0.92, 1.05),
			"emergency_red_intensity": 0.5,
			"prompt": "Cinematic AAA survival horror concept art of The Brute: A heavily built infected campus security worker towering in a damaged ENSA Fès entrance lobby. Shattered glass, emergency lights, heavy muscle mass and armor. NO UI, NO text."
		},
		{
			"id": "enemy_stalker",
			"category": "enemy",
			"title": "The Stalker",
			"subtitle": "Concealed Laboratory Hunter",
			"tip": "Check corners and dark rooms before entering. Stalkers strike from blind spots.",
			"enemy_type": "stalker",
			"is_implemented": false,
			"target_webp": "res://assets/loading/zombie/enemy_stalker.webp",
			"source_candidates": [case_workstation],
			"overlay_model": "res://tools/antigravity/zombie/photos/zombie_arm_stalker.png",
			"overlay_pos": Vector2(0.72, 0.48),
			"overlay_scale": 0.54,
			"rim_color": Color(0.0, 0.85, 0.95, 0.6),
			"tint": Color(0.70, 0.82, 1.15),
			"emergency_red_intensity": 0.25,
			"prompt": "Cinematic AAA survival horror concept art of The Stalker: An infected agile silhouette hiding behind overturned computer lab furniture in a dark university lab with glowing computer monitors. NO UI, NO text."
		},
		{
			"id": "enemy_crawler",
			"category": "enemy",
			"title": "The Crawling Infected",
			"subtitle": "Low-Profile Ambush Threat",
			"tip": "Threats may be closer to the floor than expected. Scan low angles.",
			"enemy_type": "crawler",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/enemy_crawler.webp",
			"source_candidates": [atrium_gen],
			"overlay_model": "res://tools/antigravity/zombie/photos/zombie_crawler.png",
			"overlay_pos": Vector2(0.56, 0.72),
			"overlay_scale": 0.42,
			"rim_color": Color(0.3, 0.6, 0.9, 0.6),
			"tint": Color(0.88, 0.92, 1.05),
			"emergency_red_intensity": 0.35,
			"prompt": "Cinematic AAA survival horror concept art of The Crawling Infected: A mutated infected crawling stealthily beneath classroom lecture desks on a wet reflective floor. Low camera angle, ominous dark atmosphere. NO UI, NO text."
		},
		{
			"id": "enemy_guard",
			"category": "enemy",
			"title": "The Guard",
			"subtitle": "Infected Campus Checkpoint Officer",
			"tip": "Not every enemy is equally vulnerable. Armored security officers require tactical spacing.",
			"enemy_type": "guard",
			"is_implemented": false,
			"target_webp": "res://assets/loading/zombie/enemy_guard.webp",
			"source_candidates": [bg_campus, dusk_ref],
			"overlay_model": "res://tools/antigravity/zombie/photos/survivor_matt_guard.png",
			"overlay_pos": Vector2(0.66, 0.48),
			"overlay_scale": 0.58,
			"rim_color": Color(0.95, 0.3, 0.3, 0.7),
			"tint": Color(0.65, 0.75, 1.10),
			"emergency_red_intensity": 0.6,
			"prompt": "Cinematic AAA survival horror concept art of The Guard: An infected campus security guard standing menacingly at the glass entrance turnstiles of ENSA Fès. Tactical vest, radio, red emergency flash. NO UI, NO text."
		},
		{
			"id": "enemy_lurker",
			"category": "enemy",
			"title": "The Lurker",
			"subtitle": "Glass Partition Silhouette",
			"tip": "Pay attention to silhouettes and movement through glass partitions.",
			"enemy_type": "lurker",
			"is_implemented": false,
			"target_webp": "res://assets/loading/zombie/enemy_lurker.webp",
			"source_candidates": [atrium_gen],
			"overlay_model": "res://tools/antigravity/zombie/photos/zombie_walker_basic.png",
			"overlay_pos": Vector2(0.24, 0.42),
			"overlay_scale": 0.38,
			"rim_color": Color(0.4, 0.7, 1.0, 0.7),
			"tint": Color(0.80, 0.88, 1.18),
			"emergency_red_intensity": 0.25,
			"prompt": "Cinematic AAA survival horror concept art of The Lurker: An eerie infected silhouette barely visible through the misted glass windows of a dark ENSA Fès corridor at night. Raindrops on glass, moonlight. NO UI, NO text."
		},
		{
			"id": "enemy_swarm",
			"category": "enemy",
			"title": "The Swarm",
			"subtitle": "Lecture Hall Convergence",
			"tip": "Avoid attracting large groups of infected in open lecture halls.",
			"enemy_type": "swarm",
			"is_implemented": false,
			"target_webp": "res://assets/loading/zombie/enemy_swarm.webp",
			"source_candidates": [atrium_gen],
			"overlays": [
				{"path": "res://tools/antigravity/zombie/photos/zombie_walker_basic.png", "pos": Vector2(0.55, 0.52), "scale": 0.38, "rim": Color(0.9, 0.3, 0.3, 0.6), "tint": Color(0.12, 0.15, 0.22, 1.0)},
				{"path": "res://tools/antigravity/zombie/photos/zombie_brute_chubby.png", "pos": Vector2(0.68, 0.50), "scale": 0.48, "rim": Color(0.9, 0.2, 0.2, 0.6), "tint": Color(0.12, 0.15, 0.22, 1.0)},
				{"path": "res://tools/antigravity/zombie/photos/zombie_crawler.png", "pos": Vector2(0.46, 0.64), "scale": 0.30, "rim": Color(0.9, 0.3, 0.3, 0.5), "tint": Color(0.12, 0.15, 0.22, 1.0)}
			],
			"tint": Color(0.92, 0.85, 0.95),
			"emergency_red_intensity": 0.7,
			"prompt": "Cinematic AAA survival horror concept art of The Swarm: A massive gathering of infected students pouring into the main amphitheater lecture hall of ENSA Fès under flickering emergency house lights. NO UI, NO text."
		},
		{
			"id": "enemy_lab_infected",
			"category": "enemy",
			"title": "The Lab Infected",
			"subtitle": "Contaminated Researcher",
			"tip": "Investigate unfamiliar threats carefully. Hazmat gear protects infected from blunt trauma.",
			"enemy_type": "lab_infected",
			"is_implemented": false,
			"target_webp": "res://assets/loading/zombie/enemy_lab_infected.webp",
			"source_candidates": [case_workstation],
			"overlay_model": "res://tools/antigravity/zombie/photos/zombie_walker_basic.png",
			"overlay_pos": Vector2(0.66, 0.46),
			"overlay_scale": 0.52,
			"rim_color": Color(0.2, 0.9, 0.6, 0.6),
			"tint": Color(0.75, 0.95, 1.10),
			"emergency_red_intensity": 0.3,
			"prompt": "Cinematic AAA survival horror concept art of The Lab Infected: A former chemistry researcher in a torn yellow hazmat suit and shattered respirator stalking through a dark university laboratory. Chemical spills glowing faintly. NO UI, NO text."
		},
		{
			"id": "enemy_night_hunter",
			"category": "enemy",
			"title": "The Night Hunter",
			"subtitle": "Predatory Nocturnal Stalker",
			"tip": "Visibility can be your greatest disadvantage outdoors after dusk.",
			"enemy_type": "night_hunter",
			"is_implemented": false,
			"target_webp": "res://assets/loading/zombie/enemy_night_hunter.webp",
			"source_candidates": [dusk_ref],
			"overlay_model": "res://tools/antigravity/zombie/photos/zombie_arm_stalker.png",
			"overlay_pos": Vector2(0.70, 0.32),
			"overlay_scale": 0.36,
			"rim_color": Color(0.5, 0.8, 1.0, 0.8),
			"tint": Color(0.62, 0.72, 1.15),
			"emergency_red_intensity": 0.2,
			"prompt": "Cinematic AAA survival horror concept art of The Night Hunter: An ominous, agile infected predator crouched atop a concrete architectural canopy outside ENSA Fès under full moonlight and heavy storm clouds. NO UI, NO text."
		},
		{
			"id": "enemy_apex",
			"category": "enemy",
			"title": "The Apex Infected",
			"subtitle": "Catastrophic Mutation Threat",
			"tip": "Some encounters require preparation, traps, and supplies rather than direct confrontation.",
			"enemy_type": "apex",
			"is_implemented": false,
			"target_webp": "res://assets/loading/zombie/enemy_apex.webp",
			"source_candidates": [atrium_gen],
			"overlay_model": "res://tools/antigravity/zombie/photos/zombie_brute_chubby.png",
			"overlay_pos": Vector2(0.65, 0.45),
			"overlay_scale": 0.85,
			"rim_color": Color(1.0, 0.15, 0.15, 0.95),
			"tint": Color(0.95, 0.82, 0.90),
			"emergency_red_intensity": 0.9,
			"prompt": "Cinematic AAA survival horror concept art of The Apex Infected: A colossal, horrifying mutated boss enemy revealed dramatically inside the two-story glass atrium of ENSA Fès. Crimson emergency flares illuminating devastation. NO UI, NO text."
		},

		# --- 6 Campus Environments ---
		{
			"id": "atrium_after_dark",
			"category": "environment",
			"title": "Atrium After Dark",
			"subtitle": "Main Reception & Central Concourse",
			"tip": "Emergency lights highlight survival supply caches left behind during evacuation.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/atrium_after_dark.webp",
			"source_candidates": [atrium_gen],
			"tint": Color(0.95, 0.98, 1.05),
			"emergency_red_intensity": 0.45,
			"prompt": "AAA cinematic concept art of ENSA Fès modern university campus dark atrium after dark. Full-height glass windows overlooking dark rainy night, red emergency light glowing, survival gear in foreground, distant zombies. NO UI, NO text."
		},
		{
			"id": "env_computer_lab",
			"category": "environment",
			"title": "Abandoned Computer Laboratory",
			"subtitle": "Department of Computer Engineering",
			"tip": "Emergency power keeps certain workstations online. Check them for campus maps and security logs.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/env_computer_lab.webp",
			"source_candidates": [case_workstation],
			"tint": Color(0.65, 0.80, 1.20),
			"emergency_red_intensity": 0.25,
			"prompt": "Cinematic AAA concept art of an abandoned computer laboratory at ENSA Fès. Overturned chairs, glowing terminal monitors, cables hanging from ceiling, blue and green ambient screen light in pitch black room. NO UI, NO text."
		},
		{
			"id": "env_library",
			"category": "environment",
			"title": "The Library",
			"subtitle": "Central Reading Room & Archives",
			"tip": "Keep quiet in the library stacks. Shamblers react immediately to dropped objects.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/env_library.webp",
			"source_candidates": [atrium_gen],
			"norm_crop": Rect2(0.25, 0.05, 0.65, 0.60),
			"tint": Color(0.75, 0.85, 1.15),
			"emergency_red_intensity": 0.2,
			"prompt": "Cinematic AAA concept art of ENSA Fès university library at night. Towering academic bookshelves, moonlit skylights, dust motes floating in cold beams, ominous infected silhouette in distance. NO UI, NO text."
		},
		{
			"id": "env_rooftop",
			"category": "environment",
			"title": "The Rooftop",
			"subtitle": "Science & Tech Wing Observational Deck",
			"tip": "Rooftop perches offer safe observation points and line-of-sight for signaling flares.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/env_rooftop.webp",
			"source_candidates": [bg_campus],
			"tint": Color(0.60, 0.70, 1.05),
			"emergency_red_intensity": 0.35,
			"prompt": "Cinematic AAA concept art: Rooftop view across ENSA Fès modern campus at night. Distant city lights of Fès, storm clouds, concrete parapet, rain puddles, solitary survivor with backpack looking out. NO UI, NO text."
		},
		{
			"id": "env_underground",
			"category": "environment",
			"title": "Underground Service Area",
			"subtitle": "Sub-Level HVAC & Utility Tunnels",
			"tip": "Flashlights reveal hidden service doors, but beware of reflected light drawing stalkers.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/env_underground.webp",
			"source_candidates": ["res://assets/user_models/server_rack_0.jpg", case_workstation],
			"tint": Color(0.75, 0.85, 1.05),
			"emergency_red_intensity": 0.55,
			"prompt": "Cinematic AAA concept art of underground service tunnels at ENSA Fès. Concrete utility corridors, overhead steam pipes, flickering industrial yellow cage lights, wet maintenance floor. NO UI, NO text."
		},
		{
			"id": "campus_courtyard",
			"category": "environment",
			"title": "The Campus Courtyard",
			"subtitle": "Central Plaza & Main Esplanade",
			"tip": "Open plazas leave you exposed from all angles. Stick close to concrete planters for cover.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/campus_courtyard.webp",
			"source_candidates": [dusk_ref],
			"tint": Color(0.68, 0.78, 1.15),
			"emergency_red_intensity": 0.45,
			"prompt": "Cinematic AAA survival horror artwork of the main exterior courtyard of ENSA Fès at dusk in heavy rain. Barricades, abandoned backpacks, glowing red emergency flares, wet stone reflections. NO UI, NO text."
		},

		# --- 4 Survival & Gameplay ---
		{
			"id": "survival_stealth",
			"category": "survival",
			"title": "Stealth & Evasion",
			"subtitle": "Low-Profile Campus Traversal",
			"tip": "Crouching reduces footstep audio. Move behind furniture to break enemy line of sight.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/survival_stealth.webp",
			"source_candidates": [case_workstation],
			"overlay_model": "res://tools/antigravity/zombie/photos/zombie_walker_basic.png",
			"overlay_pos": Vector2(0.74, 0.46),
			"overlay_scale": 0.45,
			"tint": Color(0.60, 0.72, 1.05),
			"emergency_red_intensity": 0.2,
			"prompt": "Cinematic AAA survival mechanics art: A survivor crouching quietly behind campus lockers in dark shadow while an infected walker shambles past just feet away under dim emergency light. NO UI, NO text."
		},
		{
			"id": "survival_scavenging",
			"category": "survival",
			"title": "Supply Scavenging",
			"subtitle": "Field Ration & Ammo Logistics",
			"tip": "Check supply crates and lockers for medical items, ammo, and barricade components.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/survival_scavenging.webp",
			"source_candidates": [atrium_gen],
			"norm_crop": Rect2(0.48, 0.35, 0.50, 0.60),
			"tint": Color(0.95, 0.95, 1.05),
			"emergency_red_intensity": 0.4,
			"prompt": "Cinematic AAA survival art: An abandoned campus emergency triage station on a desk with medical supplies, bandages, food rations, an open backpack, and a lit tactical flashlight. NO UI, NO text."
		},
		{
			"id": "survival_barricade",
			"category": "survival",
			"title": "Defensive Preparation",
			"subtitle": "Tactical Fortification",
			"tip": "Barricade classroom doors with pallets and furniture to buy time against incoming hordes.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/survival_barricade.webp",
			"source_candidates": [atrium_gen],
			"norm_crop": Rect2(0.12, 0.35, 0.50, 0.60),
			"tint": Color(0.90, 0.92, 1.05),
			"emergency_red_intensity": 0.5,
			"prompt": "Cinematic AAA survival art: A survivor urgently reinforcing a wooden barricade across a glass classroom door, tactical flashlight beam illuminating incoming shadows in the corridor. NO UI, NO text."
		},
		{
			"id": "survival_escape",
			"category": "survival",
			"title": "Emergency Escape",
			"subtitle": "Extraction Zone Defense",
			"tip": "Keep an extraction route planned before initiating combat inside unfamiliar corridors.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/survival_escape.webp",
			"source_candidates": [runner_gen],
			"tint": Color(0.85, 0.95, 1.05),
			"emergency_red_intensity": 0.65,
			"prompt": "Cinematic AAA gameplay climax scene: A survivor racing towards an illuminated green emergency exit door at ENSA Fès while shadows of zombies pursue in the background corridor. Dynamic motion blur. NO UI, NO text."
		},

		# --- 2 Narrative Artwork ---
		{
			"id": "story_first_night",
			"category": "story",
			"title": "The First Night",
			"subtitle": "Incident Chronology: 21:14 Lockdown",
			"tip": "When campus communications failed at 21:00, security protocol Alpha triggered full building isolation.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/story_first_night.webp",
			"source_candidates": [atrium_gen],
			"tint": Color(0.88, 0.88, 1.05),
			"emergency_red_intensity": 0.85,
			"prompt": "Cinematic AAA storytelling scene: The main entrance lobby of ENSA Fès on the night of the outbreak. Emergency vehicles flashing blue and red through the rainy glass windows, abandoned cellphones ringing on the floor. NO UI, NO text."
		},
		{
			"id": "story_unknown_signal",
			"category": "story",
			"title": "The Unknown Signal",
			"subtitle": "Automated SOS Frequency",
			"tip": "A looped radio transmission from the engineering block repeats coordinates every 15 minutes.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/zombie/story_unknown_signal.webp",
			"source_candidates": [case_workstation],
			"tint": Color(0.70, 0.90, 1.30),
			"emergency_red_intensity": 0.3,
			"prompt": "Cinematic AAA narrative art: A lonely glowing monitor in an isolated darkened campus office displaying an oscillating soundwave radio transmission, an amber emergency beacon slowly rotating on the wall. NO UI, NO text."
		}
	]

func _get_cyber_slide_specs() -> Array[Dictionary]:
	var case_workstation := "res://assets/launcher/case-workstation.png"
	var mode_cyber := "res://assets/antigravity/launcher/mode_cyber.png"
	var bg_campus := "res://assets/antigravity/launcher/bg_campus.png"
	var server_rack := "res://assets/user_models/server_rack_0.jpg"

	return [
		{
			"id": "cyber_workstation",
			"category": "forensics",
			"title": "Forensic Workstation Analysis",
			"subtitle": "Digital Evidence Preservation",
			"tip": "Verify system logs and hash signatures before modifying running processes.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/cyber/cyber_workstation.webp",
			"source_candidates": [case_workstation],
			"tint": Color(0.85, 1.05, 1.25),
			"emergency_red_intensity": 0.0,
			"prompt": "Cinematic cybersecurity loading art: High-tech incident response workstation with multiple glowing monitors showing terminal command lines, network packet graphs, and forensic memory dumps. Clean cyan and blue aesthetic. NO UI, NO text."
		},
		{
			"id": "cyber_server_room",
			"category": "network",
			"title": "Campus Datacenter Infrastructure",
			"subtitle": "Core Switch & Blade Enclosures",
			"tip": "Check network switches and patch panels for unauthorized physical taps.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/cyber/cyber_server_room.webp",
			"source_candidates": [server_rack, case_workstation],
			"tint": Color(0.82, 1.02, 1.30),
			"emergency_red_intensity": 0.0,
			"prompt": "Cinematic server room corridor with tall black rack cabinets, pulsing blue and teal LED activity lights, raised floor tiles, and cool mist air conditioning. NO UI, NO text."
		},
		{
			"id": "cyber_incident_triage",
			"category": "response",
			"title": "Incident Response Triage",
			"subtitle": "Containment & Quarantine Protocol",
			"tip": "Isolate compromised hosts from the subnet immediately to prevent lateral movement.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/cyber/cyber_incident_triage.webp",
			"source_candidates": [mode_cyber, case_workstation],
			"tint": Color(0.88, 1.00, 1.22),
			"emergency_red_intensity": 0.0,
			"prompt": "Cinematic security operations center dashboard showing campus network topology map, active intrusion alarms highlighted in amber, and response workflows. NO UI, NO text."
		},
		{
			"id": "cyber_network_monitoring",
			"category": "monitoring",
			"title": "Campus Network Gateway",
			"subtitle": "Intrusion Detection System",
			"tip": "Look for anomalous outbound beaconing intervals in border gateway traffic.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/cyber/cyber_network_monitoring.webp",
			"source_candidates": [bg_campus],
			"tint": Color(0.85, 0.98, 1.25),
			"emergency_red_intensity": 0.0,
			"prompt": "Cinematic exterior view of ENSA Fès illuminated by glowing blue data streams and network signal lines connecting the engineering buildings. NO UI, NO text."
		},
		{
			"id": "cyber_evidence_collection",
			"category": "evidence",
			"title": "Chain of Custody",
			"subtitle": "Incident Documentation Protocol",
			"tip": "Document forensic timestamps and memory dumps in strict compliance with protocol.",
			"enemy_type": "",
			"is_implemented": true,
			"target_webp": "res://assets/loading/cyber/cyber_evidence_collection.webp",
			"source_candidates": [case_workstation],
			"tint": Color(0.90, 1.05, 1.20),
			"emergency_red_intensity": 0.0,
			"prompt": "Cinematic close-up of forensic USB drive, tamper-evident evidence bag, and terminal displaying verified SHA-256 integrity hashes. NO UI, NO text."
		}
	]

func _write_manifest(zombie_slides: Array[Dictionary], cyber_slides: Array[Dictionary]) -> void:
	var manifest := {
		"version": 1,
		"system": "ENSA GAMES AAA Cinematic Loading Screen System",
		"reference_art_direction": "Design 2: Dark ENSA Fès atrium with floor-to-ceiling windows, nighttime blue lighting, red emergency lights, atmospheric fog, survival equipment, distant zombies",
		"modes": {
			"zombie_rpg": {
				"title": "Zombie RPG Survival",
				"total_slides": zombie_slides.size(),
				"primary_palette": ["#00f0ff", "#101826", "#e02020", "#b0c4de"],
				"slides": zombie_slides
			},
			"incident_response": {
				"title": "ENSA Incident Response — Cybersecurity",
				"total_slides": cyber_slides.size(),
				"primary_palette": ["#00e5ff", "#0a192f", "#48cae4", "#caf0f8"],
				"slides": cyber_slides
			}
		}
	}
	var f := FileAccess.open("res://assets/loading/slide_manifest.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(manifest, "\t"))
		f.close()
		print("  ✓ Wrote slide manifest to res://assets/loading/slide_manifest.json")
