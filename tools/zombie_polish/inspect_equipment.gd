extends SceneTree
func _init() -> void:
	for name in ["Characters_Lis", "Characters_Matt", "Characters_Shaun"]:
		var n = load("res://assets/antigravity/zombie/models/"+name+".scn").instantiate()
		print(name)
		for m in n.find_children("*", "MeshInstance3D", true, false): print(m.name)
		n.free()
	quit()
