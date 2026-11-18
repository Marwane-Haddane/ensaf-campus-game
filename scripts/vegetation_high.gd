extends RefCounted
## High preset only: swaps the source blob trees, flat palms and shrubs for the
## Blender vegetation kit (tools/vegetation_kit_high.py, assets/vegetation_high/).
## The originals have no collision (role "landscape"), so hiding them changes no
## gameplay. Replacements are fitted to each original's bounds and drawn as one
## MultiMesh per template under "HighVegetation" (outside CampusRenderBatches,
## so the polish pass keeps their alpha-cut materials).

const KIT_DIR := "res://assets/vegetation_high/"
const KIT_SCENE := KIT_DIR + "vegetation_high.glb"
## [source-name prefix, template(s), fit]. fit: whole plant, or "trunk" = the
## source is only the trunk and the template's trunk height is matched.
const RULES: Array = [
	["Campus plaza shade tree", ["SM_VEG_ShadeTree_A", "SM_VEG_ShadeTree_B"], "plant"],
	["R3 Garden tree", ["SM_VEG_ShadeTree_A", "SM_VEG_ShadeTree_B"], "plant"],
	["Courtyard planting", ["SM_VEG_ShadeTree_B"], "plant"],
	["R3 low garden shrub", ["SM_VEG_Shrub"], "plant"],
	["Low garden shrub", ["SM_VEG_Shrub"], "plant"],
	["Campus fan palm", ["SM_VEG_FanPalm"], "plant"],
	["Palm trunk", ["SM_VEG_SmallPalm"], "trunk"],
]
## Parts of replaced plants that have no own replacement.
const HIDE_ONLY: Array[String] = ["Palm frond"]


static func available() -> bool:
	return ResourceLoader.exists(KIT_SCENE) and FileAccess.file_exists(KIT_DIR + "manifest.json")


static func install(runtime: Node3D, mesh_nodes: Array[MeshInstance3D]) -> Dictionary:
	var result := {"installed": false, "replaced": 0, "hidden": 0, "instances": {}}
	if not available():
		return result
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KIT_DIR + "manifest.json"))
	var templates: Dictionary = manifest.get("templates", {})
	var meshes: Dictionary = _load_meshes()
	if meshes.is_empty():
		return result
	var transforms: Dictionary = {}
	for mesh_node: MeshInstance3D in mesh_nodes:
		if not mesh_node.visible or mesh_node.mesh == null:
			continue
		var source: String = str(mesh_node.get_meta("campus_source_name", mesh_node.name))
		if _hide_only(source):
			mesh_node.visible = false
			mesh_node.set_meta("replaced_by_high_vegetation", true)
			result.hidden += 1
			continue
		var rule: Array = _rule_for(source)
		if rule.is_empty():
			continue
		var bounds: AABB = mesh_node.global_transform * mesh_node.mesh.get_aabb()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector3i(bounds.get_center() * 10.0))
		var names: Array = rule[1]
		var template: String = names[rng.randi() % names.size()]
		if not meshes.has(template) or not templates.has(template):
			continue
		var info: Dictionary = templates[template]
		var fit_height: float = float(info.get("trunk_height", info.height)) if rule[2] == "trunk" else float(info.height)
		var scale_y: float = bounds.size.y / fit_height
		var scale_xz: float = clampf(maxf(bounds.size.x, bounds.size.z) / float(info.width), scale_y * 0.8, scale_y * 1.25)
		if rule[2] == "trunk":
			scale_xz = scale_y
		var base := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale_xz, scale_y, scale_xz))
		if not transforms.has(template):
			transforms[template] = []
		transforms[template].append(Transform3D(basis, base))
		mesh_node.visible = false
		mesh_node.set_meta("replaced_by_high_vegetation", true)
		result.replaced += 1
	if transforms.is_empty():
		return result
	var holder := Node3D.new()
	holder.name = "HighVegetation"
	runtime.add_child(holder)
	for template: String in transforms:
		var list: Array = transforms[template]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = meshes[template]
		multimesh.instance_count = list.size()
		for i: int in range(list.size()):
			multimesh.set_instance_transform(i, list[i])
		var node := MultiMeshInstance3D.new()
		node.name = template
		node.multimesh = multimesh
		holder.add_child(node)
		result.instances[template] = list.size()
	result.installed = true
	return result


static func _rule_for(source: String) -> Array:
	for rule: Array in RULES:
		if source.begins_with(rule[0]):
			return rule
	return []


static func _hide_only(source: String) -> bool:
	for prefix: String in HIDE_ONLY:
		if source.begins_with(prefix):
			return true
	return false


static func _load_meshes() -> Dictionary:
	var packed := load(KIT_SCENE) as PackedScene
	if packed == null:
		return {}
	var scene := packed.instantiate()
	var materials := {
		"Foliage": _material("leaf_atlas", true),
		"Bark": _material("bark", false),
		"PalmTrunk": _material("palm_trunk", false),
	}
	var meshes := {}
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh := (node as MeshInstance3D).mesh.duplicate() as Mesh
			for surface: int in range(mesh.get_surface_count()):
				var source: Material = mesh.surface_get_material(surface)
				var label: String = source.resource_name if source else ""
				for key: String in materials:
					if label.ends_with(key):
						mesh.surface_set_material(surface, materials[key])
			meshes[str(node.name)] = mesh
	scene.free()
	return meshes


static func _material(prefix: String, foliage: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "VEG_" + prefix
	material.albedo_texture = load(KIT_DIR + prefix + "_albedo.png")
	material.normal_enabled = true
	material.normal_texture = load(KIT_DIR + prefix + "_normal.png")
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.78 if foliage else 0.92
	material.metallic_specular = 0.35
	if foliage:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.42
		# Smooth cut-out edges with the preset's MSAA (High = 4x).
		material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.normal_scale = 0.7
	material.set_meta("campus_high_vegetation", true)
	return material
