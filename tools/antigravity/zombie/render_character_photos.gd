extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var out_dir = "res://tools/antigravity/zombie/photos/"

	var studio = Node3D.new()
	root.add_child(studio)

	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.10, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.8, 0.85)
	environment.ambient_light_energy = 1.1
	env.environment = environment
	studio.add_child(env)

	var key_light = DirectionalLight3D.new()
	key_light.position = Vector3(20, 30, 20)
	key_light.rotation_degrees = Vector3(-35, 30, 0)
	key_light.light_color = Color(1.0, 0.96, 0.9)
	key_light.light_energy = 1.4
	studio.add_child(key_light)

	var fill_light = DirectionalLight3D.new()
	fill_light.position = Vector3(-20, 15, 15)
	fill_light.rotation_degrees = Vector3(-20, -45, 0)
	fill_light.light_color = Color(0.4, 0.65, 0.9)
	fill_light.light_energy = 0.8
	studio.add_child(fill_light)

	var cam = Camera3D.new()
	cam.current = true
	cam.fov = 35.0
	studio.add_child(cam)

	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	var err = doc.append_from_file("C:/1Project/Vr --- cyber/ensaf-campus-v4-project/ENSA-Fes-Campus-v4/3D-modeling/3d models/zombie/pistol_animation_wip__really_stiff.glb", state)
	if err == OK:
		var inst = doc.generate_scene(state) as Node3D
		studio.add_child(inst)
		inst.position = Vector3.ZERO
		inst.rotation_degrees = Vector3(0, -30, 0)
		
		# Close up on the pistol
		cam.position = Vector3(-10, 8, 35)
		cam.look_at(Vector3(-15, 0, 5), Vector3.UP)

		for i in range(12):
			await process_frame

		var img = root.get_texture().get_image()
		var save_path = ProjectSettings.globalize_path(out_dir + "04_player_pistol.png")
		img.save_png(save_path)
		print("Pistol photo saved: ", save_path)

	quit(0)
