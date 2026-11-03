extends SceneTree
const Furniture = preload("res://scripts/furniture_props.gd")

func _init() -> void:
	call_deferred("run_preview")

func run_preview() -> void:
	root.size = Vector2i(1000, 800)
	# Import into memory for inspection; the main agent owns the editor import.
	var imported_scenes: Array[PackedScene] = []
	for kind: String in Furniture.MODELS:
		var path: String = Furniture.MODELS[kind].path
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(path, state)
		assert(err == OK)
		var source := doc.generate_scene(state)
		var packed := PackedScene.new()
		packed.pack(source)
		packed.take_over_path(path)
		imported_scenes.append(packed)
		source.free()
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("c2d2df")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.75
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -28, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(10, 0.08, 10)
	floor_mesh.mesh = floor_box
	floor_mesh.position.y = -0.04
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("9eabb4")
	floor_material.roughness = 0.85
	floor_mesh.material_override = floor_material
	stage.add_child(floor_mesh)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 38
	camera.current = true
	var results: Dictionary = {}
	for kind: String in Furniture.MODELS:
		var prop := Furniture.place(stage, kind, Vector3.ZERO)
		assert(prop != null)
		var box: AABB = prop.get_meta("local_bounds")
		assert(absf(box.position.y) < 0.0001, "Furniture must meet the floor")
		assert(absf(box.get_center().x) < 0.0001 and absf(box.get_center().z) < 0.0001)
		var measure := {"floor_min": box.position.y, "size": [box.size.x, box.size.y, box.size.z]}
		var meshes: Array[MeshInstance3D] = []
		Furniture._collect_meshes(prop, meshes)
		var materials: Dictionary = {}
		var textures: Dictionary = {}
		for mesh: MeshInstance3D in meshes:
			for surface: int in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as BaseMaterial3D
				if material != null:
					materials[material.get_instance_id()] = true
					for slot: int in range(BaseMaterial3D.TEXTURE_MAX):
						var texture := material.get_texture(slot)
						if texture != null:
							textures[texture.get_instance_id()] = true
		measure["meshes"] = meshes.size()
		measure["materials"] = materials.size()
		measure["textures"] = textures.size()
		await physics_frame
		await physics_frame
		var space := stage.get_world_3d().direct_space_state
		if kind == "desk":
			var tabletop := PhysicsRayQueryParameters3D.create(Vector3(-0.25, 1.3, 0), Vector3(-0.25, 0.5, 0))
			var top_hit := space.intersect_ray(tabletop)
			assert(not top_hit.is_empty() and absf(top_hit.position.y - 0.75) < 0.01, "Desk collider must match tabletop")
			var knees := PhysicsRayQueryParameters3D.create(Vector3(-0.25, 0.4, 1), Vector3(-0.25, 0.4, 0))
			assert(space.intersect_ray(knees).is_empty(), "Desk knee space must remain open")
			measure["collision_check"] = "tabletop at 0.75m; knee space clear"
		else:
			var front_ray := PhysicsRayQueryParameters3D.create(Vector3(0, box.size.y * 0.5, 2), Vector3(0, box.size.y * 0.5, 0))
			var front_hit := space.intersect_ray(front_ray)
			assert(not front_hit.is_empty() and absf(front_hit.position.z - box.end.z) < 0.001, "Footprint collision must match geometry bounds")
			measure["collision_check"] = "front collision matches visible AABB"
		print("FURNITURE ", kind, " ", JSON.stringify(measure))
		results[kind] = measure
		var distance := maxf(box.size.x, box.size.y) * 2.65
		for direction: String in ["front", "rear"]:
			var sign_z := 1.0 if direction == "front" else -1.0
			camera.position = Vector3(distance * 0.46, box.size.y * 0.72 + distance * 0.22, distance * sign_z)
			camera.look_at(Vector3(0, box.size.y * 0.48, 0), Vector3.UP)
			await process_frame
			await process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://tools/furniture_" + kind + "_" + direction + ".png")
		prop.queue_free()
		await process_frame
	var file := FileAccess.open("res://tools/furniture_dimensions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	quit()
