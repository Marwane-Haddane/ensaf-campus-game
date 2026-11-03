@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var studio = Node3D.new()
	root.add_child(studio)

	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.15, 0.2)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.85, 0.9)
	environment.ambient_light_energy = 1.0
	env.environment = environment
	studio.add_child(env)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 45, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.5
	studio.add_child(sun)

	var cam = Camera3D.new()
	cam.current = true
	cam.fov = 70.0
	cam.near = 0.05
	studio.add_child(cam)

	var scn = load("res://assets/antigravity/zombie/models/pistol_hands.tscn")
	var inst: Node3D = scn.instantiate()
	cam.add_child(inst)

	var anim: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var b_weap = skel.find_bone("weapon_050")
	var b_tip = skel.find_bone("weapon_end_066")

	var s = 0.28
	inst.scale = Vector3(s, s, s)

	if anim: anim.play("Armature|A_Aim")

	inst.rotation_degrees = Vector3(0.0, 182.0, 0.0)
	inst.position = Vector3(-0.025, -0.235, 0.22)

	for i in range(15): await process_frame

	var pw = skel.global_transform * skel.get_bone_global_pose(b_weap).origin
	var pt = skel.global_transform * skel.get_bone_global_pose(b_tip).origin
	print("AIM: weap screen=", cam.unproject_position(pw), " tip screen=", cam.unproject_position(pt))

	var img_aim = root.get_texture().get_image()
	img_aim.save_png(ProjectSettings.globalize_path("res://tools/antigravity/zombie/photos/perfect_aim_clean.png"))
	print("Saved perfect_aim_clean.png")

	quit(0)
