extends RefCounted
## Bounds include nested imported transforms, so off-centre model origins are safe.
static func bounds_in_parent(root: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect(root, root.transform, boxes)
	var result := AABB()
	for i in boxes.size(): result = boxes[i] if i == 0 else result.merge(boxes[i])
	return result
static func _collect(node: Node, transform: Transform3D, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(transform * node.get_aabb())
	for child in node.get_children():
		_collect(child, transform * child.transform if child is Node3D else transform, boxes)
static func ground(root: Node3D, floor_y: float) -> void:
	var bounds := bounds_in_parent(root)
	if bounds.size.y > 0.0001:
		root.position.y += floor_y - bounds.position.y
static func add_static_collision(root: Node3D) -> void:
	# Static mesh collision preserves gaps and slopes; built only once at loading.
	if root is CollisionObject3D: return
	if root is MeshInstance3D and root.mesh != null:
		var body := StaticBody3D.new()
		body.name = "RoutePropCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		collider.shape = root.mesh.create_trimesh_shape()
		body.add_child(collider)
		root.add_child(body)
	for child in root.get_children():
		if child is Node3D: add_static_collision(child)
