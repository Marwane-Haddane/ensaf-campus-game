extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var out_dir = "res://tools/antigravity/zombie/photos/"
	var brain_dir = "C:/Users/marwa/.gemini/antigravity/brain/739e62fe-b07b-44e5-a79e-efc11cd9c30c/"

	var targets = [
		{"path": "res://assets/antigravity/zombie/models/Zombie_Ribcage.tscn", "name": "zombie_ribcage_screamer", "cam_pos": Vector3(0, 1.1, 2.5), "look_at": Vector3(0, 0.9, 0)},
		{"path": "res://assets/antigravity/zombie/models/Zombie_Arm.tscn", "name": "zombie_arm_stalker", "cam_pos": Vector3(0, 1.2, 2.6), "look_at": Vector3(0, 0.9, 0)},
		{"path": "res://assets/antigravity/zombie/models/Characters_Matt.tscn", "name": "survivor_matt_guard", "cam_pos": Vector3(0, 1.2, 2.5), "look_at": Vector3(0, 1.0, 0)},
		{"path": "res://assets/antigravity/zombie/models/Characters_Lis.tscn", "name": "survivor_lis_medic", "cam_pos": Vector3(0, 1.1, 2.5), "look_at": Vector3(0, 0.9, 0)},
		{"path": "res://assets/antigravity/zombie/models/WoodenBat_Barbed.tscn", "name": "weapon_bat_barbed", "cam_pos": Vector3(0, 0.4, 1.2), "look_at": Vector3(0, 0.3, 0)},
	]

	for target in targets:
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
		cam.fov = 38.0
		cam.position = target.cam_pos
		cam.look_at(target.look_at, Vector3.UP)
		studio.add_child(cam)

		var scene_res = load(target.path) as PackedScene
		if scene_res:
			var inst = scene_res.instantiate() as Node3D
			studio.add_child(inst)
			inst.position = Vector3.ZERO
			inst.rotation_degrees = Vector3(0, 15, 0)

			for i in range(8):
				await process_frame

			RenderingServer.force_draw(false)
			var img = root.get_texture().get_image()
			var file_name = target.name + ".png"
			img.save_png(ProjectSettings.globalize_path(out_dir + file_name))
			img.save_png(brain_dir + file_name)
			print("Rendered and saved: ", file_name)

		studio.queue_free()
		await process_frame

	quit(0)
