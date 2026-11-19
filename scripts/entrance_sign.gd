extends RefCounted
## Cream entrance lettering (roadmap item #6). In the source model the second line
## ("DES SCIENCES APPLIQUEES") sits behind the canopy roof edge (top 3.30 m), so
## from the plaza the canopy hides it. Low and High re-lay the two upper lines
## into the free wall band between canopy and window sills (3.30-4.26 m):
##   high -> the original 3D letters are moved (relief kept)
##   low  -> the 3D letters (63k triangles) become flat baked images
##           (tools/sign_decals_low.py, assets/runtime_signs_low/)
## Medium keeps the original layout untouched.

const DECAL_DIR := "res://assets/runtime_signs_low/"
## source name -> [new centre height (m), uniform scale in the wall plane]
const LAYOUT := {
	"School sign large": [4.10, 1.0],
	"School sign second": [3.84, 0.8],
	"School sign affiliation": [-1.0, 1.0],  # under the canopy: keep where it is
}


static func install(runtime: Node3D, mesh_nodes: Array[MeshInstance3D], preset: String) -> Dictionary:
	var result := {"moved": 0, "decals": 0, "hidden_triangles": 0}
	if preset not in ["low", "high"]:
		return result
	var manifest: Dictionary = {}
	if preset == "low" and FileAccess.file_exists(DECAL_DIR + "manifest.json"):
		manifest = JSON.parse_string(FileAccess.get_file_as_string(DECAL_DIR + "manifest.json")).get("signs", {})
	for mesh_node: MeshInstance3D in mesh_nodes:
		var source: String = str(mesh_node.get_meta("campus_source_name", mesh_node.name))
		if not LAYOUT.has(source) or mesh_node.mesh == null or not mesh_node.visible:
			continue
		var target_y: float = LAYOUT[source][0]
		var scale: float = LAYOUT[source][1]
		var bounds: AABB = mesh_node.global_transform * mesh_node.mesh.get_aabb()
		var center: Vector3 = bounds.get_center()
		var new_center := Vector3(center.x, center.y if target_y < 0.0 else target_y, center.z)
		if preset == "high":
			if target_y < 0.0:
				continue
			var place := Transform3D(Basis().scaled(Vector3(scale, scale, 1.0)), new_center) * Transform3D(Basis(), -center)
			mesh_node.global_transform = place * mesh_node.global_transform
			result.moved += 1
			continue
		if not manifest.has(source):
			continue
		var info: Dictionary = manifest[source]
		var texture := load(DECAL_DIR + str(info.image)) as Texture2D
		if texture == null:
			continue
		var quad := QuadMesh.new()
		quad.size = Vector2(float(info.width_m), float(info.height_m)) * scale
		var material := StandardMaterial3D.new()
		material.resource_name = "Entrance sign decal"
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		# Revision 10: white letters on the blue university sign panel (photos 12-14).
		material.albedo_color = Color(0.97, 0.97, 0.98)
		material.roughness = 0.45
		material.metallic = 0.3
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		quad.material = material
		var decal := MeshInstance3D.new()
		decal.name = "EntranceSignDecal_" + source.get_slice(" ", 2)
		decal.mesh = quad
		decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Front face of the original lettering, a few millimetres proud of it.
		runtime.add_child(decal)
		decal.global_position = Vector3(float(info.godot_center[0]), new_center.y, float(info.godot_center[2]) + 0.003)
		var tris: int = 0
		for surface: int in range(mesh_node.mesh.get_surface_count()):
			var indices: Variant = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
			tris += (indices as PackedInt32Array).size() / 3 if indices != null else 0
		mesh_node.visible = false
		mesh_node.set_meta("replaced_by_sign_decal", true)
		result.decals += 1
		result.hidden_triangles += tris
	return result
