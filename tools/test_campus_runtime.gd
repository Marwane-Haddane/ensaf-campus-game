extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime: Node3D = load("res://scripts/campus_runtime.gd").new()
	root.add_child(runtime)
	await runtime.build()
	await physics_frame
	await physics_frame
	var ground: Dictionary = runtime.sample_ground_hits()
	var passed: bool = bool(runtime.stats.get("ready", false))
	for hit: Dictionary in ground.values():
		passed = passed and bool(hit.get("hit", false))
	var seat_blocked: bool = false
	for mesh_node: MeshInstance3D in runtime.mesh_nodes:
		if str(mesh_node.get_meta("campus_source_name", "")).begins_with("E9 auditorium row 01 seat 001"):
			var center: Vector3 = mesh_node.mesh.get_aabb().get_center()
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(mesh_node.to_global(center+Vector3(0,0,0.9)), mesh_node.to_global(center-Vector3(0,0,0.9)), 1)
			var seat_hit: Dictionary = runtime.get_world_3d().direct_space_state.intersect_ray(query)
			seat_blocked = not seat_hit.is_empty()
			break
	passed = passed and seat_blocked
	var report: Dictionary = {"passed": passed, "ground": ground, "seat_blocked": seat_blocked, "runtime": runtime.stats}
	var output: FileAccess = FileAccess.open("res://tools/runtime-ground-test.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	print("RUNTIME_GROUND_TEST ", JSON.stringify(report))
	quit(0 if passed else 1)
