extends SceneTree

func _init() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file("res://assets/user_models/gamer_setup_pack.glb", state)
	if err != OK:
		push_error("GLB read failed: %s" % err)
		quit(1)
		return
	var source := doc.generate_scene(state)
	inspect(source, Transform3D.IDENTITY)
	source.free()
	quit()

func inspect(node: Node, parent_transform: Transform3D) -> void:
	var tx := parent_transform
	if node is Node3D:
		tx = parent_transform * (node as Node3D).transform
	if node is Node3D and (str(node.name).begins_with("sm_") or node is MeshInstance3D):
		print(node.name," global=",tx)
		if node is MeshInstance3D:
			var mesh := node as MeshInstance3D
			print("  BOUNDS ",tx * mesh.get_aabb())
			if "monitor_screen" in str(node.name):
				var arrays := mesh.mesh.surface_get_arrays(0)
				print("  SCREEN FIRST WORLD NORMALS ",tx.basis * arrays[Mesh.ARRAY_NORMAL][0])
	for child in node.get_children():
		inspect(child,tx)
