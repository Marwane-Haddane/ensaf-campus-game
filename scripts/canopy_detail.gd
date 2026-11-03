extends RefCounted
## Bounded runtime refinement for the owned plaza/R3 trees. Call before render
## batching. Only the four explicitly named crown materials are subdivided;
## the bark surface, original Mesh, transforms and collision bodies are untouched.

const CROWN_MATERIALS: Array[String] = [
	"R3 - Leaf shade 0", "R3 - Leaf shade 1",
	"R3 - Leaf shade 2", "R3 - Leaf shade 3",
]
static var _mesh_cache: Dictionary = {}


static func enhance(mesh_node: MeshInstance3D, source_name: String) -> bool:
	if not (source_name.begins_with("Campus plaza shade tree") or source_name.begins_with("R3 Garden tree ")):
		return false
	var original: Mesh = mesh_node.mesh
	if original == null or bool(original.get_meta("canopy_refined", false)):
		return false
	var key: int = original.get_instance_id()
	if _mesh_cache.has(key):
		mesh_node.mesh = _mesh_cache[key] as ArrayMesh
		return true
	if original.get_blend_shape_count() != 0:
		return false
	var replacement := ArrayMesh.new()
	replacement.resource_name = original.resource_name + " / smooth crown detail"
	var refined_surfaces: int = 0
	for surface: int in range(original.get_surface_count()):
		var material: Material = original.surface_get_material(surface)
		var arrays: Array = original.surface_get_arrays(surface)
		if material != null and str(material.resource_name) in CROWN_MATERIALS and original.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
			var refined: Array = _subdivide_crowns(arrays)
			if not refined.is_empty():
				arrays = refined
				refined_surfaces += 1
		replacement.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays)
		replacement.surface_set_material(surface, material)
	if refined_surfaces == 0:
		return false
	# Explicitly retain the original culling bounds: each new midpoint is inside
	# its original lobe AABB and all original vertices remain unchanged.
	replacement.custom_aabb = original.get_aabb()
	replacement.set_meta("canopy_refined", true)
	replacement.set_meta("canopy_source_mesh_id", key)
	replacement.set_meta("canopy_refined_surfaces", refined_surfaces)
	_mesh_cache[key] = replacement
	mesh_node.mesh = replacement
	return true


static func _subdivide_crowns(arrays: Array) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty() or normals.size() != vertices.size() or indices.is_empty() or indices.size() % 3 != 0:
		return []
	# These source crowns have POSITION/NORMAL streams only. Optional ordinary
	# UVs, colors and tangents are supported; unknown/skinned streams are skipped.
	for slot: int in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		if arrays[slot] != null and arrays[slot].size() != 0:
			return []
	var topology: Dictionary = _lobe_bounds(vertices, indices)
	if topology.is_empty():
		return []
	var streams: Dictionary = {"vertices": [], "normals": [], "uv": [], "uv2": [], "colors": [], "tangents": []}
	for vertex: Vector3 in vertices:
		streams.vertices.append(vertex)
	for normal: Vector3 in normals:
		streams.normals.append(normal)
	for entry: Array in [[Mesh.ARRAY_TEX_UV, "uv"], [Mesh.ARRAY_TEX_UV2, "uv2"], [Mesh.ARRAY_COLOR, "colors"], [Mesh.ARRAY_TANGENT, "tangents"]]:
		if arrays[entry[0]] != null:
			for value: Variant in arrays[entry[0]]:
				streams[entry[1]].append(value)
	var new_indices := PackedInt32Array()
	var edges: Dictionary = {}
	for offset: int in range(0, indices.size(), 3):
		var a: int = indices[offset]
		var b: int = indices[offset + 1]
		var c: int = indices[offset + 2]
		var ab: int = _midpoint(a, b, topology, streams, edges)
		var bc: int = _midpoint(b, c, topology, streams, edges)
		var ca: int = _midpoint(c, a, topology, streams, edges)
		new_indices.append_array(PackedInt32Array([a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca]))
	var result: Array = arrays.duplicate()
	result[Mesh.ARRAY_VERTEX] = PackedVector3Array(streams.vertices)
	result[Mesh.ARRAY_NORMAL] = PackedVector3Array(streams.normals)
	result[Mesh.ARRAY_INDEX] = new_indices
	if not streams.uv.is_empty():
		result[Mesh.ARRAY_TEX_UV] = PackedVector2Array(streams.uv)
	if not streams.uv2.is_empty():
		result[Mesh.ARRAY_TEX_UV2] = PackedVector2Array(streams.uv2)
	if not streams.colors.is_empty():
		result[Mesh.ARRAY_COLOR] = PackedColorArray(streams.colors)
	if not streams.tangents.is_empty():
		result[Mesh.ARRAY_TANGENT] = PackedFloat32Array(streams.tangents)
	return result


static func _lobe_bounds(vertices: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var neighbors: Array = []
	var membership := PackedInt32Array()
	membership.resize(vertices.size())
	# Imported meshes also store unused duplicate vertices for generated LODs.
	# Only the base surface indices define the connected 42-vertex lobes.
	membership.fill(-2)
	for _index: int in range(vertices.size()):
		neighbors.append([])
	for offset: int in range(0, indices.size(), 3):
		var a: int = indices[offset]
		var b: int = indices[offset + 1]
		var c: int = indices[offset + 2]
		if mini(a, mini(b, c)) < 0 or maxi(a, maxi(b, c)) >= vertices.size():
			return {}
		membership[a] = -1
		membership[b] = -1
		membership[c] = -1
		neighbors[a].append_array([b, c])
		neighbors[b].append_array([a, c])
		neighbors[c].append_array([a, b])
	var boxes: Array[AABB] = []
	for seed: int in range(vertices.size()):
		if membership[seed] != -1:
			continue
		var lobe: int = boxes.size()
		var stack: Array[int] = [seed]
		var count: int = 0
		var box := AABB(vertices[seed], Vector3.ZERO)
		membership[seed] = lobe
		while not stack.is_empty():
			var current: int = stack.pop_back()
			count += 1
			box = box.expand(vertices[current])
			for neighbor: int in neighbors[current]:
				if membership[neighbor] < 0:
					membership[neighbor] = lobe
					stack.append(neighbor)
		# Inspection confirms every intended crown lobe is a connected 42-vertex
		# icosphere. Refuse unknown geometry instead of rounding trunks or leaves.
		if count != 42 or minf(box.size.x, minf(box.size.y, box.size.z)) < 0.0001:
			return {}
		boxes.append(box)
	return {"membership": membership, "boxes": boxes}


static func _midpoint(a: int, b: int, topology: Dictionary, streams: Dictionary, edges: Dictionary) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if edges.has(key):
		return int(edges[key])
	var vertices: Array = streams.vertices
	var normals: Array = streams.normals
	var point: Vector3 = (vertices[a] + vertices[b]) * 0.5
	var box: AABB = topology.boxes[topology.membership[a]]
	var center: Vector3 = box.get_center()
	var radii: Vector3 = box.size * 0.5
	var offset: Vector3 = point - center
	var unit: Vector3 = offset / radii
	if unit.length_squared() > 0.000001:
		# Project the new edge vertex onto the original lobe's fitted ellipsoid.
		# This changes its silhouette rather than merely adding flat triangles.
		point = center + offset / unit.length()
	point = point.clamp(box.position, box.end)
	var index: int = vertices.size()
	vertices.append(point)
	var normal: Vector3 = (normals[a] + normals[b]).normalized()
	normals.append(normal)
	for channel: String in ["uv", "uv2", "colors"]:
		var values: Array = streams[channel]
		if not values.is_empty():
			values.append(values[a].lerp(values[b], 0.5))
	var tangents: Array = streams.tangents
	if not tangents.is_empty():
		var tangent_a := Vector3(tangents[a * 4], tangents[a * 4 + 1], tangents[a * 4 + 2])
		var tangent_b := Vector3(tangents[b * 4], tangents[b * 4 + 1], tangents[b * 4 + 2])
		var tangent: Vector3 = (tangent_a + tangent_b).normalized()
		tangents.append_array([tangent.x, tangent.y, tangent.z, tangents[a * 4 + 3]])
	edges[key] = index
	return index
