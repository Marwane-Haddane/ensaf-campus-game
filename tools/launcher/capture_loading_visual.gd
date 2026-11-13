extends SceneTree

func _init() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	# Set 1080p viewport
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)

	var page_script = load("res://scripts/antigravity/launcher/loading_page.gd")
	var page = page_script.new()
	root.add_child(page)

	# Update model matching Reference 2:
	# "ENSA GAMES", "Zombie RPG Survival", "Loading assets... 62%", progress bar 62%
	var model = {
		"selected_mode_id": "zombie_rpg",
		"loading": {
			"stage_id": "assets",
			"stage_label": "Loading assets",
			"resource_progress": 0.62,
			"can_cancel": false,
			"still_preparing": false,
			"elapsed_seconds": 1.4
		},
		"preferences": {
			"reduced_motion": false,
			"master_volume": 80.0,
			"music_volume": 80.0
		}
	}
	page.update_from_model(model)

	for frame in range(10):
		await process_frame

	RenderingServer.force_draw(false)
	var vp = root.get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img and not img.is_empty():
				img.save_png("res://tools/launcher/loading-screen-qa-1080p.png")
				img.save_png("res://tools/launcher/current-loading-capture.png")
				print("LOADING_SCREEN_CAPTURED_SUCCESSFULLY size=", img.get_size())

	# Print UI geometry for validation
	print("UI_METRICS: ", JSON.stringify({
		"title": page._deployment._brand.text,
		"mode": page._deployment._title.text,
		"stage": page._stage_label.text,
		"progress_visible": page._progress_bar.visible,
		"progress_value": page._progress_bar.value,
		"tip": page._tip_label.text,
		"slide_index": page._current_slide_idx + 1,
		"current_slide_texture": page._bg_current.texture.resource_path if page._bg_current.texture else "none"
	}))

	await process_frame
	page.queue_free()
	await process_frame
	quit(0)
