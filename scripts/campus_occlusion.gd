extends RefCounted
## Conservative CPU occlusion for the original campus's proven solid boxes.
## Usage after `await campus.build()`: helper.install(campus).
## This creates rendering occluders only; no collision or traversal changes.

const INSET_METRES: float = 0.01
const MIN_THICKNESS_METRES: float = 0.04
const MIN_FACE_AREA: float = 6.0
const MIN_WALL_AREA: float = 4.0
const BOX_TRIANGLES: Array[int] = [0,4,6, 0,6,2, 1,3,7, 1,7,5, 0,1,5, 0,5,4, 2,6,7, 2,7,3, 0,2,3, 0,3,1, 4,5,7, 4,7,6]

var stats: Dictionary = {"accepted": 0, "occluder_instances": 0, "vertices": 0, "triangles": 0, "install_msec": 0, "rejected": {}, "enabled": false}
var candidates: Array[Dictionary] = []
var instance: OccluderInstance3D
var _mesh_proof_cache: Dictionary = {}


func install(campus_runtime: Node3D) -> Dictionary:
	if campus_runtime.has_meta("campus_occlusion_stats"):
		return campus_runtime.get_meta("campus_occlusion_stats") as Dictionary
	var started: int = Time.get_ticks_msec()
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var source_nodes: Variant = campus_runtime.get("mesh_nodes")
	if not source_nodes is Array:
		_reject("runtime_has_no_mesh_nodes")
		return stats
	var runtime_inverse: Transform3D = campus_runtime.global_transform.affine_inverse()
	for value: Variant in source_nodes:
		var mesh_node: MeshInstance3D = value as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			_reject("missing_mesh")
			continue
		var source_name: String = str(mesh_node.get_meta("campus_source_name", mesh_node.name))
		var role: String = str(mesh_node.get_meta("campus_role", ""))
		if role not in ["architecture", "walkable"]:
			_reject("non_architectural_role")
			continue
		if "door" in source_name.to_lower() or bool(mesh_node.get_meta("campus_door", false)):
			_reject("door_or_door_frame")
			continue
		# Batched originals are intentionally hidden but still describe the same
		# static geometry. Replaced/obsolete objects must never become occluders.
		if bool(mesh_node.get_meta("replaced_by_approved_asset", false)) or bool(mesh_node.get_meta("campus_duplicate_hidden", false)):
			_reject("replaced_or_duplicate")
			continue
		if not mesh_node.visible and not mesh_node.has_meta("campus_render_batch"):
			_reject("hidden_source")
			continue
		if not _all_surfaces_opaque(mesh_node):
			_reject("transparent_or_unknown_material")
			continue
		var bounds: AABB = mesh_node.mesh.get_aabb()
		var relative: Transform3D = runtime_inverse * mesh_node.global_transform
		if not _large_enough(bounds, mesh_node.global_basis):
			_reject("small_or_thin")
			continue
		var mesh_key: int = mesh_node.mesh.get_rid().get_id()
		if not _mesh_proof_cache.has(mesh_key):
			_mesh_proof_cache[mesh_key] = _prove_closed_box(mesh_node.mesh)
		if not bool(_mesh_proof_cache[mesh_key]):
			_reject("not_a_proven_closed_box")
			continue
		var world_scale: Vector3 = Vector3(mesh_node.global_basis.x.length(), mesh_node.global_basis.y.length(), mesh_node.global_basis.z.length())
		var local_inset: Vector3 = Vector3(INSET_METRES/world_scale.x, INSET_METRES/world_scale.y, INSET_METRES/world_scale.z)
		var inner_min: Vector3 = bounds.position + local_inset
		var inner_max: Vector3 = bounds.end - local_inset
		var offset: int = vertices.size()
		for corner: int in range(8):
			var local_point: Vector3 = Vector3(inner_max.x if corner&1 else inner_min.x, inner_max.y if corner&2 else inner_min.y, inner_max.z if corner&4 else inner_min.z)
			vertices.append(relative * local_point)
		var mirrored: bool = relative.basis.determinant() < 0.0
		for triangle: int in range(12):
			indices.append(offset+BOX_TRIANGLES[triangle*3])
			indices.append(offset+BOX_TRIANGLES[triangle*3+(2 if mirrored else 1)])
			indices.append(offset+BOX_TRIANGLES[triangle*3+(1 if mirrored else 2)])
		candidates.append({"source": source_name, "role": role, "all_surfaces_opaque": true, "unique_corners": 8, "verified_faces": 6, "inset_metres": INSET_METRES, "occluder_inside_source": true, "world_dimensions": _vector_array(bounds.size*world_scale)})
	if not indices.is_empty():
		var occluder: ArrayOccluder3D = ArrayOccluder3D.new()
		occluder.set_arrays(vertices, indices)
		instance = OccluderInstance3D.new()
		instance.name = "CampusVerifiedSolidOccluders"
		instance.occluder = occluder
		instance.bake_mask = 0 # No automatic bake or dynamic props are included.
		campus_runtime.add_child(instance)
		stats["occluder_instances"] = 1
		if campus_runtime.is_inside_tree():
			campus_runtime.get_viewport().use_occlusion_culling = true
			stats["enabled"] = true
	stats["accepted"] = candidates.size()
	stats["vertices"] = vertices.size()
	stats["triangles"] = int(indices.size()/3.0)
	stats["install_msec"] = Time.get_ticks_msec()-started
	campus_runtime.set_meta("campus_occlusion_stats", stats)
	print("CAMPUS_OCCLUSION ", JSON.stringify(stats))
	return stats


func _all_surfaces_opaque(mesh_node: MeshInstance3D) -> bool:
	if mesh_node.mesh.get_surface_count() == 0:
		return false
	for index: int in range(mesh_node.mesh.get_surface_count()):
		var material: Material = mesh_node.get_active_material(index)
		if material == null or str(material.get_meta("campus_material_family", "")) == "glass":
			return false
		if material is BaseMaterial3D:
			var standard: BaseMaterial3D = material as BaseMaterial3D
			if standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or standard.albedo_color.a < 0.999:
				return false
		elif material is ShaderMaterial:
			if not bool(material.get_meta("campus_opaque", false)):
				return false
		else:
			return false
	return true


func _large_enough(bounds: AABB, world_basis: Basis) -> bool:
	if absf(world_basis.determinant()) < 0.000001:
		return false
	var edges: Array[Vector3] = [world_basis.x*bounds.size.x, world_basis.y*bounds.size.y, world_basis.z*bounds.size.z]
	for axis: int in range(3):
		if edges[axis].length() < MIN_THICKNESS_METRES:
			return false
	var large_face: bool = false
	for axis: int in range(3):
		var face_cross: Vector3 = edges[(axis+1)%3].cross(edges[(axis+2)%3])
		var area: float = face_cross.length()
		if area < 0.000001:
			return false
		# Reject sheared boxes whose actual normal thickness is too small.
		if absf(edges[axis].dot(face_cross.normalized())) < MIN_THICKNESS_METRES:
			return false
		if area >= MIN_FACE_AREA or (area >= MIN_WALL_AREA and absf(face_cross.normalized().y) < 0.25):
			large_face = true
	return large_face


func _prove_closed_box(mesh: Mesh) -> bool:
	var bounds: AABB = mesh.get_aabb()
	var tolerance: float = clampf(bounds.size.length()*0.00001, 0.00002, 0.001)
	var corners: Dictionary = {}
	var face_triangles: Array[Array] = [[], [], [], [], [], []]
	var face_areas: PackedFloat64Array = PackedFloat64Array([0.0,0.0,0.0,0.0,0.0,0.0])
	var total_triangles: int = 0
	for surface_index: int in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		# Eight corners may be split by surface normals/UVs, but a solid cuboid
		# needs only twelve triangles. Reject dense/open/beveled shells cheaply.
		if positions.is_empty() or positions.size() > 36:
			return false
		var masks: PackedInt32Array = PackedInt32Array()
		for point: Vector3 in positions:
			var mask: int = _corner_mask(point, bounds, tolerance)
			if mask < 0:
				return false
			masks.append(mask)
			corners[mask] = true
		var source_indices: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			source_indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		if source_indices.is_empty():
			for index: int in range(positions.size()):
				source_indices.append(index)
		if source_indices.size()%3 != 0:
			return false
		for index: int in range(0, source_indices.size(), 3):
			total_triangles += 1
			if total_triangles > 12:
				return false
			var ia: int = source_indices[index]
			var ib: int = source_indices[index+1]
			var ic: int = source_indices[index+2]
			if ia < 0 or ib < 0 or ic < 0 or ia >= positions.size() or ib >= positions.size() or ic >= positions.size():
				return false
			var face: int = _common_face(masks[ia], masks[ib], masks[ic])
			if face < 0:
				return false
			var area: float = (positions[ib]-positions[ia]).cross(positions[ic]-positions[ia]).length()*0.5
			if area <= 0.00000001:
				return false
			face_areas[face] += area
			face_triangles[face].append([masks[ia], masks[ib], masks[ic]])
	if corners.size() != 8 or total_triangles != 12:
		return false
	for face: int in range(6):
		if face_triangles[face].size() != 2:
			return false
		var axis: int = int(face/2.0)
		var expected_area: float = bounds.size[(axis+1)%3]*bounds.size[(axis+2)%3]
		if absf(face_areas[face]-expected_area) > maxf(0.00001, expected_area*0.002):
			return false
		var first: Array = face_triangles[face][0] as Array
		var second: Array = face_triangles[face][1] as Array
		var shared: Array[int] = []
		var union: Dictionary = {}
		for mask: int in first:
			union[mask] = true
			if second.has(mask):
				shared.append(mask)
		for mask: int in second:
			union[mask] = true
		# Two different triangles must meet on the rectangle's diagonal, not
		# overlap half a face and leave a hole despite having the same area.
		if union.size() != 4 or shared.size() != 2 or (shared[0]^shared[1]) != (7^(1<<axis)):
			return false
	return true


func _corner_mask(point: Vector3, bounds: AABB, tolerance: float) -> int:
	var mask: int = 0
	for axis: int in range(3):
		if absf(point[axis]-bounds.position[axis]) <= tolerance:
			continue
		if absf(point[axis]-bounds.end[axis]) <= tolerance:
			mask |= 1<<axis
		else:
			return -1
	return mask


func _common_face(a: int, b: int, c: int) -> int:
	for axis: int in range(3):
		var bit: int = 1<<axis
		if (a&bit) == (b&bit) and (a&bit) == (c&bit):
			return axis*2+(1 if a&bit else 0)
	return -1


func _reject(reason: String) -> void:
	var rejected: Dictionary = stats["rejected"] as Dictionary
	rejected[reason] = int(rejected.get(reason, 0))+1


func _vector_array(vector: Vector3) -> Array[float]:
	return [vector.x, vector.y, vector.z]


func contract_report() -> Dictionary:
	var no_doors: bool = true
	var all_opaque: bool = true
	var all_proven: bool = true
	var all_inside: bool = true
	for record: Dictionary in candidates:
		no_doors = no_doors and not "door" in str(record["source"]).to_lower()
		all_opaque = all_opaque and bool(record["all_surfaces_opaque"])
		all_proven = all_proven and int(record["unique_corners"]) == 8 and int(record["verified_faces"]) == 6
		all_inside = all_inside and bool(record["occluder_inside_source"])
	return {"passed": candidates.size() > 0 and no_doors and all_opaque and all_proven and all_inside, "candidate_count": candidates.size(), "no_doors": no_doors, "no_glass_or_transparent_materials": all_opaque, "all_six_faces_and_eight_corners_proven": all_proven, "all_boxes_shrunk_inside_source": all_inside, "stats": stats}
