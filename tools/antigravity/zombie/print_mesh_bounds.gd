extends SceneTree

func _init() -> void:
	var scn: PackedScene = load("res://assets/antigravity/zombie/models/pistol_hands.scn")
	var node = scn.instantiate()
	for child in node.find_children("*", "MeshInstance3D"):
		var mi := child as MeshInstance3D
		if mi.mesh:
			var aabb := mi.mesh.get_aabb()
			print(mi.name, " parent=", mi.get_parent().name, " aabb=", aabb, " global_pos=", mi.global_position)
	quit(0)
