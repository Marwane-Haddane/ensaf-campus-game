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
	cam.near = 0.05
	studio.add_child(cam)

	var scn: PackedScene = load("res://assets/antigravity/zombie/models/pistol_hands.tscn")
	var inst: Node3D = scn.instantiate() as Node3D
	cam.add_child(inst)

	# In pistol_hands.tscn:
	# Armature is inside Sketchfab_model/...
	# Let's test scale and position
	var s: float = 0.0025
	inst.scale = Vector3(s, s, s)
	# The pistol is at Z~10, arms at Z~300.
	# We want the arms at player's shoulders (Z ~ 0, Y ~ -0.3, X ~ 0)
	# and pistol forward at (Z ~ -0.6, Y ~ -0.2, X ~ 0.1)
	# Since arms are at Z = +300 in model, if model Z is aligned with Godot:
	# Model +Z is backward, -Z is forward.
	# Model X is right/left.
	inst.position = Vector3(0.12, -0.22, -0.15)
	inst.rotation_degrees = Vector3(0, 180, 0)

	var anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("Armature|A_Origin"):
		anim.play("Armature|A_Origin")

	for i in range(10):
		await process_frame

	var img = root.get_texture().get_image()
	var save_path = ProjectSettings.globalize_path("res://tools/antigravity/zombie/photos/hands_test_scale.png")
	img.save_png(save_path)
	print("Saved to: ", save_path)
	quit(0)
