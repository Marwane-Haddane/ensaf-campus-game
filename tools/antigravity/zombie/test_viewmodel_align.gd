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
	environment.background_color = Color(0.1, 0.12, 0.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.85, 0.9)
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
	cam.fov = 65.0
	cam.near = 0.01
	studio.add_child(cam)

	var scene_path := "res://assets/antigravity/zombie/models/pistol_hands.scn"
	var scene: PackedScene = load(scene_path)
	var inst: Node3D = scene.instantiate() as Node3D
	studio.add_child(inst)

	# Find the embedded Camera in the scene
	var orig_cam = inst.find_child("Camera", true, false) as Node3D
	print("Found orig_cam: ", orig_cam != null)
	if orig_cam:
		print("orig_cam global pos: ", orig_cam.global_position)
		print("orig_cam global rot: ", orig_cam.global_rotation_degrees)
		print("orig_cam global transform: ", orig_cam.global_transform)
		
		# If we attach inst to cam such that orig_cam aligns with cam:
		# cam.global_transform = inst.global_transform * orig_cam.transform
		# => inst.transform = orig_cam.transform.affine_inverse()
		inst.transform = orig_cam.transform.affine_inverse()
		# Re-parent under cam so it stays locked to camera
		inst.reparent(cam)
		# Scale down to reasonable units if needed, or adjust
		print("Aligned inst transform: ", inst.transform)

	var anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("Armature|A_Origin"):
		anim.play("Armature|A_Origin")

	for i in range(15):
		await process_frame

	var img = root.get_texture().get_image()
	var save_path = ProjectSettings.globalize_path("res://tools/antigravity/zombie/photos/aligned_first_person_test.png")
	img.save_png(save_path)
	print("Saved to: ", save_path)
	quit(0)
