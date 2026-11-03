extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var ui_script: Script = load("res://scripts/training_ui.gd")
	var ui: CanvasLayer = ui_script.new()
	root.add_child(ui)
	await process_frame
	var result: Dictionary = ui.call("run_self_test")
	print("TRAINING_SELF_TEST " + JSON.stringify(result))
	if DisplayServer.get_name() != "headless":
		ui.call("open_terminal")
		await process_frame
		await RenderingServer.frame_post_draw
		var preview := root.get_texture().get_image()
		var preview_path := ProjectSettings.globalize_path("user://training-ui-preview.png")
		preview.save_png(preview_path)
		print("TRAINING_UI_PREVIEW " + preview_path)
	ui.queue_free()
	quit(0 if bool(result.get("passed", false)) else 1)
