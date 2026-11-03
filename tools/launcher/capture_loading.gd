extends SceneTree

var root_node: Node

func _init() -> void:
	root_node = preload("res://scenes/launcher/boot.tscn").instantiate()
	root.add_child(root_node)
	_wait_and_load()

func _wait_and_load() -> void:
	for i in range(60):
		await process_frame
	# Trigger loading mission
	root_node.call("_start_mission")
	for i in range(30):
		await process_frame
	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("tools/launcher/current-loading-capture.png")
		print("LOADING_CAPTURED")
	quit(0)
