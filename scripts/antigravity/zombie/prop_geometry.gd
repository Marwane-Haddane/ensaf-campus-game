extends RefCounted

static func metal(tint: Color, metallic: float = 0.35) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = metallic
	material.roughness = 0.56
	return material

static func box(parent: Node3D, dimensions: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _place(parent, mesh, center, material)

static func cylinder(parent: Node3D, radius: float, height: float, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _place(parent, mesh, center, material)

static func _place(parent: Node3D, mesh: Mesh, center: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = center
	parent.add_child(part)
	return part
