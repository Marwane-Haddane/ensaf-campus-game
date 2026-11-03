extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var source := (load("res://assets/campus.glb") as PackedScene).instantiate()
	root.add_child(source)
	_scan(source)
	source.queue_free()
	await process_frame
	quit()

func _scan(node: Node) -> void:
	if node is MeshInstance3D and str(node.name).replace(" ", "") == "Mainplinth":
		var mesh_node := node as MeshInstance3D
		var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var pairs: Dictionary = {}
		for vertex in vertices:
			var point: Vector3 = mesh_node.to_global(vertex)
			if point.y > 0.39 and point.z > 0.2:
				pairs["y=%.6f z=%.6f" % [point.y, point.z]] = true
		print("MAIN_PLINTH_EDGE ", pairs.keys())
	for child in node.get_children():
		_scan(child)
