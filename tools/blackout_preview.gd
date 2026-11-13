extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	var ui = load("res://scripts/training_ui.gd").new()
	root.add_child(ui)
	await process_frame
	ui.open_terminal()
	ui._desktop.submit_command("mission start blackout")
	ui._desktop.submit_command("nano ~/Documents/candidates.py")
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/1Project/Vr --- cyber/output/blackout-editor.png")
	print("BLACKOUT_EDITOR_PREVIEW_OK")
	ui.free()
	quit()
