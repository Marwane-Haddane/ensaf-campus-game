extends SceneTree

func _init() -> void:
	var root_node = preload("res://scenes/launcher/boot.tscn").instantiate()
	root.add_child(root_node)
	_wait_and_capture()

func _wait_and_capture() -> void:
	for i in range(120):
		await process_frame
	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("tools/launcher/live-boot-capture.png")
		print("BOOT_CAPTURED")
	quit(0)
