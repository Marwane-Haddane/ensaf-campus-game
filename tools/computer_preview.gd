extends SceneTree
const Computer = preload("res://scripts/computer_prop.gd")

func _init() -> void:
	call_deferred("run_preview")

func run_preview() -> void:
	# Inspect directly, without waiting for or touching the editor import cache.
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file("res://assets/user_models/gamer_setup_pack.glb", state)
	if err != OK:
		quit(1)
		return
	var source := doc.generate_scene(state)
	var packed := PackedScene.new()
	packed.pack(source)
	packed.take_over_path("res://assets/user_models/gamer_setup_pack.glb")
	source.free()
	var stage := Node3D.new()
	root.add_child(stage)
	var result := Computer.create(stage, Vector3(0, 0.78, 0))
	if result.is_empty():
		quit(2)
		return
	print("COMPUTER_RESULT monitor_width=",result.monitor_width," bounds=",result.collision_bounds," screen=",result.screen," label=",result.label_position," meshes=",result.meshes.size())
	print("COMPONENT_BOUNDS ",result.component_bounds)
	assert(is_equal_approx(result.component_bounds.monitor.position.y, 0.0), "Monitor stand must sit on desk")
	assert(is_equal_approx(result.component_bounds.tower.position.y, 0.0), "Tower must sit on desk")
	assert(result.monitor_width >= 0.6 and result.monitor_width <= 0.8)
	assert(result.meshes.size() == 37, "Only supplied computer components should be retained")
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("c2d2df")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	stage.add_child(sun)
	var desk := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.28, 0.05, 0.70)
	desk.mesh = box
	desk.position = Vector3(0.06, 0.755, 0.01)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("b19873")
	mat.roughness = 0.8
	desk.material_override = mat
	stage.add_child(desk)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0.86, 1.42, 1.75)
	camera.look_at(Vector3(0.09, 0.98, 0.02), Vector3.UP)
	camera.fov = 43
	camera.current = true
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var preview := root.get_texture().get_image()
		preview.save_png("res://tools/computer_preview.png")
	quit()
