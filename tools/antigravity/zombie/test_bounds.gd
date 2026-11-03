@tool
extends SceneTree

func _init() -> void:
	var paths = [
		"res://assets/antigravity/zombie/models/pistol_hands.tscn",
		"res://assets/antigravity/zombie/models/Zombie_Basic.tscn",
		"res://assets/antigravity/zombie/models/Zombie_Chubby.tscn",
		"res://assets/antigravity/zombie/models/Characters_Shaun.tscn"
	]
	for p in paths:
		var s: PackedScene = load(p)
		var inst: Node3D = s.instantiate()
		var aabb: AABB = _get_combined_aabb(inst)
		print(p, " AABB: size=", aabb.size, " pos=", aabb.position)
		inst.queue_free()
	quit(0)

func _get_combined_aabb(node: Node) -> AABB:
	var aabb = AABB()
	var first = true
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(node, meshes)
	for m in meshes:
		if m.mesh:
			var m_aabb = m.global_transform * m.mesh.get_aabb()
			if first:
				aabb = m_aabb
				first = false
			else:
				aabb = aabb.merge(m_aabb)
	return aabb

func _find_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_find_meshes(c, out)
