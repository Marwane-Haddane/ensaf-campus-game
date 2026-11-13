extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var instance: Node3D = load("res://assets/antigravity/zombie/models/pistol_hands.scn").instantiate()
	root.add_child(instance)
	var anim: AnimationPlayer = instance.find_child("AnimationPlayer",true,false)
	var skel: Skeleton3D = instance.find_child("Skeleton3D",true,false)
	for clip: String in ["Armature|A_Origin","Armature|A_Aim"]:
		anim.play(clip)
		anim.advance(anim.get_animation(clip).length)
		skel.force_update_all_bone_transforms()
		for index: int in range(skel.get_bone_count()):
			var title: String = skel.get_bone_name(index)
			if clip == "Armature|A_Origin":
				print(clip," / ",title," ",skel.global_transform * skel.get_bone_global_pose(index).origin)
	instance.queue_free()
	await process_frame
	quit()
