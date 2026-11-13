extends SceneTree
## Exercise the reviewed interior through the production player and chunk loader.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://main.tscn").instantiate()
	game.launcher_managed = true
	var chunks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime_campus/manifest.json"))
	for path: String in chunks["chunks"]:
		game.prepared_sections.append(load(path) as PackedScene)
	root.add_child(game)
	while not game.initialization_finished:
		await process_frame
	if not game.ready_to_play:
		push_error(game.initialization_error)
		quit(1)
		return

	var results: Dictionary = {}
	var stats: Dictionary = game.campus.stats["teaching_interior"]
	var scene_path := "res://assets/teaching_interior.scn"
	var interior: Node = game.campus.campus_scene.get_node("TeachingInterior")
	results["loaded"] = stats["installed"] > 0 and stats["retired"] == interior.get_meta("replaces").size()
	results["self_contained"] = ResourceLoader.get_dependencies(scene_path).is_empty()
	results["entrances"] = game.campus.door_system.doors.size() == 4
	var supplied: Node3D = game.campus.campus_scene.get_node("SuppliedHallFurniture")
	var plaza_furniture: Node3D = game.campus.campus_scene.get_node("SuppliedPlazaFurniture")
	results["supplied_models"] = supplied.get_child_count() == 14 and game.campus.stats["supplied_furniture"] == 28
	results["plaza_models"] = plaza_furniture.get_child_count() == 14 and game.campus.stats["outdoor_furniture"] == 14
	var lawn_bounds: Array[AABB] = []
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset-manifest.json"))
	for record: Dictionary in manifest["nodes"]:
		if str(record["name"]).begins_with("Campus rectangular lawn"):
			var low: Array = record["godot_min"]
			var high: Array = record["godot_max"]
			var minimum := Vector3(low[0], low[1], low[2])
			lawn_bounds.append(AABB(minimum, Vector3(high[0], high[1], high[2]) - minimum))
	for prop: Node3D in supplied.get_children() + plaza_furniture.get_children():
		var bounds: AABB = prop.global_transform * prop.get_meta("local_bounds")
		var prefix := str(prop.get_path())
		if prop.get_parent() == plaza_furniture:
			var clear_of_lawns := true
			for lawn: AABB in lawn_bounds:
				clear_of_lawns = clear_of_lawns and not bounds.intersects(lawn)
			results[prefix + "_outside_lawns"] = clear_of_lawns
		var floor_y := prop.global_position.y
		results[prefix + "_grounded"] = absf(bounds.position.y - floor_y) < .01
		var supported := true
		for x: float in [bounds.position.x + .03, bounds.end.x - .03]:
			for z: float in [bounds.position.z + .03, bounds.end.z - .03]:
				var support_query := PhysicsRayQueryParameters3D.create(Vector3(x, floor_y + .05, z), Vector3(x, floor_y - .15, z), 1)
				support_query.exclude = [prop.get_node("FurnitureCollision").get_rid()]
				var support_hit := game.get_world_3d().direct_space_state.intersect_ray(support_query)
				supported = supported and not support_hit.is_empty() and absf(support_hit["position"].y - floor_y) < .02
		results[prefix + "_floor_support"] = supported
		var center := bounds.get_center()
		var ray_offset := Vector3(0, 0, bounds.size.z / 2 + .1)
		var query := PhysicsRayQueryParameters3D.create(center + ray_offset, center - ray_offset, 1)
		var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
		results[prefix + "_collision"] = not hit.is_empty() and prop.is_ancestor_of(hit["collider"])
		var footprint := BoxShape3D.new()
		footprint.size = bounds.size - Vector3.ONE * .02
		var overlap := PhysicsShapeQueryParameters3D.new()
		overlap.shape = footprint
		overlap.transform.origin = center
		overlap.collision_mask = 1
		var clear := true
		for contact: Dictionary in game.get_world_3d().direct_space_state.intersect_shape(overlap):
			if not prop.is_ancestor_of(contact["collider"]):
				clear = false
		results[prefix + "_no_architecture_overlap"] = clear
	results["classroom_floor"] = _hit_name(game, Vector3(-29.6, 1.2, -4), Vector3(-29.6, .55, -4)).begins_with("B standard classroom tiled floor / continuous finish")
	results["lift_approach"] = _hit_name(game, Vector3(-39.2, 1.15, -16.25), Vector3(-39.2, .55, -16.25)).begins_with("B court 1")
	results["lift_closed"] = _hit_name(game, Vector3(-39.45, 1.6, -16.3), Vector3(-39.45, 1.6, -17.4)).begins_with("B lift")
	for y: float in [2.25, 4.38, 6.5]:
		var hit := _hit_name(game, Vector3(-18.8, 1.91, -y), Vector3(-19.5, 1.91, -y))
		results["window_" + str(y)] = hit.begins_with("B10 observation glazing")

	game.testing = true
	game.set_physics_process(true)
	game.player.rotation = Vector3.ZERO
	game.player.position = Vector3(-17.9, 1.62, -5)
	game.player.velocity = Vector3.ZERO
	for frame in range(20):
		await physics_frame
	game.test_axis = Vector2(0, 1)
	for frame in range(65):
		await physics_frame
	game.test_axis = Vector2.ZERO
	results["hall_passage_clear"] = game.player.position.z > -1.5 and game.player.is_on_floor()
	game.player.position = Vector3(-27, 1.22, -85)
	game.player.velocity = Vector3.ZERO
	for frame in range(20):
		await physics_frame
	game.test_axis = Vector2(1, 0)
	for frame in range(90):
		await physics_frame
	game.test_axis = Vector2.ZERO
	results["plaza_centre_clear"] = game.player.position.x > -21.5 and game.player.is_on_floor()
	for floor_y: float in [.67, 3.605, 6.755]:
		for corridor_z: float in [-10.05, -18.95]:
			game.player.position = Vector3(-28.4, floor_y + .95, corridor_z)
			game.player.velocity = Vector3.ZERO
			for frame in range(20):
				await physics_frame
			game.test_axis = Vector2(1, 0)
			for frame in range(70):
				await physics_frame
			game.test_axis = Vector2.ZERO
			var route := "gallery_passage_" + str(floor_y) + "_" + str(corridor_z)
			results[route] = game.player.position.x > -24 and game.player.is_on_floor() and absf(game.player.position.y - floor_y - .91) < .2
	game.player.position = Vector3(-19, 1.62, -21.9)
	game.player.velocity = Vector3.ZERO
	for frame in range(20):
		await physics_frame
	game.test_axis = Vector2(0, -1)
	for frame in range(62):
		await physics_frame
	game.test_axis = Vector2.ZERO
	results["stairs_climbed"] = game.player.position.y > 2.75 and game.player.position.z < -24.6
	print("TEACHING_INTERIOR_STAIR_END ", game.player.position)

	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless" and not args.is_empty():
		game.set_physics_process(false)
		for view: Array in [
			["classroom", Vector3(-20.1, 2.30, -7.6), Vector3(-28, 1.8, -3.8)],
			["hall", Vector3(-10, 2.27, -7.8), Vector3(-18, 1.9, -2.3)],
			["stairs", Vector3(-17.7, 5.25, -21.35), Vector3(-18.6, 5.25, -25.2)],
			["supplied-models", Vector3(-16.1, 1.95, -4.8), Vector3(-18.65, 1.12, -3.3)],
			["gallery-ground", Vector3(-28.2, 2.27, -10.1), Vector3(-25.5, 1.2, -9.35)],
			["gallery-first", Vector3(-28.2, 5.205, -10.1), Vector3(-25.5, 4.1, -9.35)],
			["gallery-second", Vector3(-28.2, 8.355, -18.95), Vector3(-25.5, 7.3, -19.65)],
			["plaza-seating", Vector3(-39.5, 2.0, -75.5), Vector3(-44.5, 1.0, -71)],
			["plaza-overview", Vector3(-26, 35, -115), Vector3(-26, 0, -84)],
		]:
			game.player.position = view[1] - Vector3.UP * game.camera.position.y
			game.camera.look_at(view[2])
			await process_frame
			await RenderingServer.frame_post_draw
			var capture: Image = root.get_texture().get_image()
			results["capture_" + view[0]] = capture.save_png(args[0].path_join("godot-" + view[0] + ".png")) == OK

	var passed := not results.values().has(false)
	print("TEACHING_INTERIOR_TEST ", JSON.stringify({"passed": passed, "checks": results, "stats": stats}))
	quit(0 if passed else 1)


func _hit_name(game: Node3D, start: Vector3, finish: Vector3) -> String:
	var query := PhysicsRayQueryParameters3D.create(start, finish, 1)
	var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return ""
	return str(hit["collider"].get_meta("campus_source_name", ""))
