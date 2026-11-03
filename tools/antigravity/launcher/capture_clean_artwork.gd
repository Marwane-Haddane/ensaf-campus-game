extends SceneTree
## capture_clean_artwork.gd — Generates clean native scene captures without any gameplay HUD,
## crosshairs, prompts, outlines, or markers, for launcher artwork assets.
##
## PROVENANCE & LICENSING ATTRIBUTION:
## 1. res://assets/antigravity/launcher/bg_campus.png (Campus Plaza)
##    - Depicts: ENSA Fès main architectural plaza and campus buildings.
##    - Source: assets/campus.glb (User-owned digital twin 3D model).
## 2. res://assets/antigravity/launcher/mode_cyber.png (Cybersecurity Training Lab)
##    - Depicts: Incident response workstation lab and server racks.
##    - Source 3D Models & Attributions:
##      • "Gamer Setup_pack" (gamer_setup_pack.glb) by Phuc (CC BY 4.0)
##      • "Server Rack" (server_rack.glb / server_rack_1.glb) by Spellkaze (CC BY 4.0)
##      • "Office Desk 140x60" (office_desk_140x60.glb) by AleixoAlonso (CC BY 4.0)
##      • "Office Chair" (office_chair.glb) by Tomaso (CC BY 4.0)
## 3. res://assets/antigravity/launcher/mode_zombie.png (Cream Main Entrance)
##    - Depicts: Campus courtyard and main entrance exterior.
##    - Source: assets/campus.glb (User-owned digital twin 3D model).
##
## All captures are rendered natively at 1280x720 (2x MSAA) with 2D CanvasLayers,
## Label3D markers, door focus outlines, and HUD elements suppressed prior to buffer grab.

var game: Node3D = null

func _init() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_2X

	print("[ARTWORK CAPTURE] Loading res://main.tscn...")
	var scene_res: PackedScene = load("res://main.tscn")
	if scene_res == null:
		print("ERROR: Could not load main.tscn")
		quit(1)
		return

	game = scene_res.instantiate() as Node3D
	root.add_child(game)

	game.set_physics_process(false)
	game.set_process_unhandled_input(false)

	# Wait for campus to finish building
	var started := Time.get_ticks_msec()
	while not game.ready_to_play and (Time.get_ticks_msec() - started) < 120000:
		await process_frame

	if not game.ready_to_play:
		print("ERROR: Campus failed to become ready")
		quit(1)
		return

	print("[ARTWORK CAPTURE] Campus ready. Suppressing all 2D HUD, CanvasLayers, and markers...")

	# Ensure launcher_managed suppresses UI
	game.launcher_managed = true
	game._set_capture(false)

	# Explicitly hide all HUD and UI nodes
	if is_instance_valid(game.menu): game.menu.hide()
	if is_instance_valid(game.pause_menu): game.pause_menu.hide_menu()
	if is_instance_valid(game.menu_shade): game.menu_shade.hide()
	if is_instance_valid(game.overlay): game.overlay.hide()
	if is_instance_valid(game.training):
		game.training.hide()
		game.training.set_exploration_visible(false)
	if is_instance_valid(game.focus_overlay):
		game.focus_overlay.hide()
		game.focus_overlay.clear_target()

	for child in game.get_children():
		if child is CanvasLayer or child is Control:
			child.visible = false
		if child is Label3D:
			child.visible = false

	# Hide any station 3D labels or door focus outlines
	for station in game.stations:
		if station.has("label") and is_instance_valid(station["label"]):
			station["label"].visible = false

	if is_instance_valid(game.campus) and is_instance_valid(game.campus.door_system):
		for door in game.campus.door_system.doors:
			door.set_focused(false)

	await _process_frames(5)

	# 1. Capture Campus Plaza (bg_campus.png)
	print("[ARTWORK CAPTURE] Capturing Campus Plaza -> bg_campus.png...")
	game._spawn("Campus plaza")
	game.player.velocity = Vector3.ZERO
	await _process_frames(6)
	_save_viewport("res://assets/antigravity/launcher/bg_campus.png")

	# 2. Capture Security Training Area (mode_cyber.png)
	print("[ARTWORK CAPTURE] Capturing Security Training Area -> mode_cyber.png...")
	game._spawn("Security training area")
	game.player.velocity = Vector3.ZERO
	await _process_frames(6)
	_save_viewport("res://assets/antigravity/launcher/mode_cyber.png")

	# 3. Capture Cream Main Entrance (mode_zombie.png)
	print("[ARTWORK CAPTURE] Capturing Cream Main Entrance -> mode_zombie.png...")
	var eye := Vector3(-14.0, 2.06, 1.8)
	var target := Vector3(-14.0, 1.75, 0.04)
	game.player.global_position = eye - Vector3(0.0, 0.65, 0.0)
	game.player.velocity = Vector3.ZERO
	game.player.transform.basis = Basis.IDENTITY
	game.pitch = 0.0
	game.camera.transform.basis = Basis.IDENTITY
	game.camera.rotation = Vector3.ZERO
	game.camera.look_at(target, Vector3.UP)
	await _process_frames(6)
	_save_viewport("res://assets/antigravity/launcher/mode_zombie.png")

	print("[ARTWORK CAPTURE] All clean artwork assets captured successfully!")
	game.queue_free()
	await process_frame
	quit(0)

func _process_frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _save_viewport(res_path: String) -> void:
	RenderingServer.force_draw(false)
	var img: Image = root.get_texture().get_image()
	var global_path: String = ProjectSettings.globalize_path(res_path)
	var err := img.save_png(global_path)
	if err == OK:
		print("  ✓ Saved: %s (%dx%d)" % [res_path, img.get_width(), img.get_height()])
	else:
		print("  ✗ Failed to save %s: error %d" % [res_path, err])
