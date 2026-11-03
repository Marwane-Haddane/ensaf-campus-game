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
	environment.background_color = Color(0.12, 0.14, 0.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.75, 0.8)
	environment.ambient_light_energy = 1.0
	env.environment = environment
	studio.add_child(env)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 45, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.2
	studio.add_child(sun)

	var cam = Camera3D.new()
	cam.current = true
	cam.fov = 70.0
	studio.add_child(cam)

	var scn: PackedScene = load("res://assets/antigravity/zombie/models/scorpion_hands.tscn")
	var inst: Node3D = scn.instantiate() as Node3D
	cam.add_child(inst)

	# Tuned position for natural first-person view
	var s: float = 0.82
	inst.scale = Vector3(s, s, s)
	inst.position = Vector3(0.04, -1.18, -0.68)

	var anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("rig|Idle"):
		anim.play("rig|Idle")

	for i in range(15):
		await process_frame

	var img = root.get_texture().get_image()
	var save_path = ProjectSettings.globalize_path("res://tools/antigravity/zombie/photos/scorpion_first_person_tuned.png")
	img.save_png(save_path)
	print("Saved to: ", save_path)
	quit(0)
