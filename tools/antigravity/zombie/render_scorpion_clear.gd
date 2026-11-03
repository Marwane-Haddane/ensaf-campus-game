extends SceneTree

func _init() -> void:
	call_deferred("_start")

func _start() -> void:
	root.size = Vector2i(1280, 720)
	var studio = Node3D.new()
	root.add_child(studio)

	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.10, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.75, 0.82)
	environment.ambient_light_energy = 1.1
	env.environment = environment
	studio.add_child(env)

	var key_light = DirectionalLight3D.new()
	key_light.position = Vector3(5, 8, 5)
	key_light.rotation_degrees = Vector3(-35, 30, 0)
	key_light.light_color = Color(1.0, 0.96, 0.9)
	key_light.light_energy = 1.8
	studio.add_child(key_light)

	var fill_light = DirectionalLight3D.new()
	fill_light.position = Vector3(-5, 4, 3)
	fill_light.rotation_degrees = Vector3(-20, -45, 0)
	fill_light.light_color = Color(0.5, 0.7, 0.9)
	fill_light.light_energy = 1.2
	studio.add_child(fill_light)

	var rim_light = DirectionalLight3D.new()
	rim_light.position = Vector3(0, 4, -5)
	rim_light.rotation_degrees = Vector3(-20, 180, 0)
	rim_light.light_color = Color(0.4, 0.7, 1.0)
	rim_light.light_energy = 1.4
	studio.add_child(rim_light)

	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	var glb_path := "C:/1Project/Vr --- cyber/ensaf-campus-v4-project/ENSA-Fes-Campus-v4/3d models/zombie/scorpion__first_person_animations_2026_remake.glb"
	var err = doc.append_from_file(glb_path, state)
	if err != OK:
		quit(1)
		return

	var inst = doc.generate_scene(state) as Node3D
	studio.add_child(inst)

	for child in inst.find_children("*", "MeshInstance3D"):
		var mi := child as MeshInstance3D
		if "Skybox" in mi.name or mi.name == "Object_19":
			mi.visible = false

	var cam = Camera3D.new()
	cam.current = true
	cam.fov = 50.0
	studio.add_child(cam)

	# 3/4 angle showing the full weapon body, magazine, ejection port, and hands
	cam.position = Vector3(0.55, 1.40, 0.85)
	cam.look_at(Vector3(-0.05, 1.22, 0.05), Vector3.UP)

	var anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("rig|Idle"):
		anim.play("rig|Idle")

	for i in range(15):
		await process_frame

	var img = root.get_texture().get_image()
	var save_path = ProjectSettings.globalize_path("res://tools/antigravity/zombie/photos/player_hands_scorpion_angled.png")
	img.save_png(save_path)
	print("Saved to: ", save_path)
	quit(0)
