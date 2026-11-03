@tool
extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Testing Navigation Mesh Bake ---")
	var game_root = Node3D.new()
	root.add_child(game_root)
	
	var cr_script = load("res://scripts/campus_runtime.gd")
	var cr = cr_script.new()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime_campus/manifest.json"))
	for path: String in manifest.chunks:
		cr.prepared_sections.append(load(path) as PackedScene)
	game_root.add_child(cr)
	await cr.build()
	print("Campus ready!")
	
	var nav_region = NavigationRegion3D.new()
	game_root.add_child(nav_region)
	var nav_mesh = NavigationMesh.new()
	# Configure navmesh for character agent
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_max_climb = 0.35
	nav_mesh.agent_max_slope = 45.0
	# Set filter bounds for the bounded episode route
	nav_mesh.filter_baking_aabb = AABB(Vector3(-55.0, -1.0, -135.0), Vector3(65.0, 10.0, 80.0))
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1 # Static campus geometry
	
	nav_region.navigation_mesh = nav_mesh
	print("Baking navigation mesh on bounded route...")
	var t0 = Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, NavigationMeshSourceGeometryData3D.new())
	# Alternatively, bake using NavigationRegion3D.bake_navigation_mesh
	# In Godot 4.3, bake_navigation_mesh(false) bakes on thread
	# Or NavigationServer3D.parse_source_geometry_data
	var parse_data = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, parse_data, game_root)
	print("Parsed source geometry in ", Time.get_ticks_msec() - t0, " ms. Vertices: ", parse_data.get_vertices().size())
	var t_bake = Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, parse_data)
	print("Bake completed in ", Time.get_ticks_msec() - t_bake, " ms! Polygons: ", nav_mesh.get_polygon_count())
	
	if nav_mesh.get_polygon_count() > 0:
		var save_err = ResourceSaver.save(nav_mesh, "res://assets/antigravity/zombie/route_navmesh.res")
		print("Saved route_navmesh.res with err: ", save_err)
	
	game_root.queue_free()
	quit(0)
