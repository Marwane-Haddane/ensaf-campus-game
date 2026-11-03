extends RefCounted
class_name FurnitureProps
## User-supplied GLBs. position is the floor centre; yaw is in radians and
## fronts face +Z at zero yaw. See tools/furniture_sources.json for attribution.

const MODELS := {
	"desk": {"path": "res://assets/user_models/office_desk_140x60.glb", "height": 0.75},
	"chair": {"path": "res://assets/user_models/office_chair.glb", "height": 1.10},
	"server_rack": {"path": "res://assets/user_models/server_rack.glb", "height": 2.0},
	"server_rack_1": {"path": "res://assets/user_models/server_rack_1.glb", "height": 2.0},
}

static func place(parent: Node3D, kind: String, position: Vector3, yaw: float = 0.0) -> Node3D:
	if not MODELS.has(kind):
		push_error("Unknown approved furniture kind: " + kind)
		return null
	var config: Dictionary = MODELS[kind]
	var packed := load(config.path) as PackedScene
	if packed == null:
		push_error("Approved furniture could not be loaded: " + str(config.path))
		return null
	var prop := Node3D.new()
	prop.name = "Imported_" + kind
	parent.add_child(prop)
	prop.position = position
	prop.rotation.y = yaw
	var geometry := Node3D.new()
	geometry.name = "FloorNormalisedGeometry"
	prop.add_child(geometry)
	var source := packed.instantiate() as Node3D
	geometry.add_child(source)
	# Front/rear renders show the first rack's drives on source -Z; all other
	# models have their drawers, seat or control face on source +Z already.
	if kind == "server_rack":
		geometry.rotation.y = PI
	# Source scale differs: the chair is centimetres, the other assets are metres.
	var original := _bounds(geometry)
	var factor: float = float(config.height) / original.size.y
	geometry.scale = Vector3.ONE * factor
	if kind == "desk":
		# The supplied 140 x 60 cm desk keeps its specified footprint, while its
		# 75.7 cm source height is corrected to the campus workstation's 75 cm.
		geometry.scale = Vector3(1.4 / original.size.x, factor, 0.6 / original.size.z)
	var box := _bounds(prop)
	geometry.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	box = _bounds(prop)
	var body := StaticBody3D.new()
	body.name = "FurnitureCollision"
	prop.add_child(body)
	if kind == "desk":
		# Follow the actual legs and pedestal rather than filling the knee space.
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(geometry, meshes)
		for mesh: MeshInstance3D in meshes:
			var collision := CollisionShape3D.new()
			collision.shape = mesh.mesh.create_trimesh_shape()
			collision.transform = _relative_transform(prop, mesh)
			body.add_child(collision)
	else:
		# A single footprint for chairs/racks keeps walking collision inexpensive.
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		collision.shape = shape
		collision.position = box.get_center()
		body.add_child(collision)
	prop.set_meta("source_asset", config.path)
	prop.set_meta("furniture_kind", kind)
	prop.set_meta("local_bounds", box)
	prop.set_meta("front", Vector3.BACK)
	return prop

static func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, meshes)

static func _relative_transform(ancestor: Node3D, node: Node3D) -> Transform3D:
	var tx := node.transform
	var cursor := node.get_parent()
	while cursor is Node3D and cursor != ancestor:
		tx = (cursor as Node3D).transform * tx
		cursor = cursor.get_parent()
	return tx

static func _bounds(node: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(node, meshes)
	var result := AABB()
	var first := true
	for mesh: MeshInstance3D in meshes:
		var box := _relative_transform(node, mesh) * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
