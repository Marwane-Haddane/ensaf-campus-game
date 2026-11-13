extends SceneTree
## Converts the reviewed GLB and replacement list into one self-contained scene.

var _mipmapped_textures: Dictionary = {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("Expected the staged GLB, replacement JSON, and destination scene.")
		quit(1)
		return
	var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if not spec is Dictionary or document.append_from_file(args[0], state) != OK:
		push_error("Could not read the teaching interior export.")
		quit(1)
		return
	var interior := document.generate_scene(state)
	if interior == null:
		push_error("The teaching interior GLB did not produce a scene.")
		quit(1)
		return
	interior.name = "TeachingInterior"
	interior.set_meta("replaces", PackedStringArray(spec["replaces"]))
	var seen: Dictionary = {}
	# Godot 4.3's standalone glTF loader does not copy arbitrary extras.
	var gltf := FileAccess.open(args[0], FileAccess.READ)
	gltf.seek(12)
	var json_length := gltf.get_32()
	gltf.get_32() # Chunk type.
	var gltf_json: Dictionary = JSON.parse_string(gltf.get_buffer(json_length).get_string_from_utf8())
	var names: Dictionary = {}
	for entry: Dictionary in gltf_json["nodes"]:
		names[entry["name"]] = entry.get("extras", {}).get("campus_source_name", "")
	_prepare(interior, interior, names, spec["nodes"], seen)
	for fixture: Dictionary in spec["lights"]:
		var light := SpotLight3D.new()
		light.name = "InteriorFixtureLight"
		var position_data: Array = fixture["position"]
		light.position = Vector3(position_data[0], position_data[1], position_data[2])
		light.rotation_degrees.x = -90
		light.spot_range = 4.8
		light.spot_angle = 64
		light.light_color = Color("fff2df")
		light.light_energy = fixture["energy"]
		light.shadow_enabled = false
		interior.add_child(light, true)
		light.owner = interior
	var packed := PackedScene.new()
	var result := ERR_INVALID_DATA
	if seen.size() == spec["nodes"].size():
		result = packed.pack(interior)
	if result == OK:
		result = ResourceSaver.save(packed, args[2], ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES)
	interior.free()
	print("TEACHING_INTERIOR_PACKED ", seen.size(), "/", spec["nodes"].size(), " result=", result)
	quit(0 if result == OK else 1)


func _prepare(node: Node, interior: Node, names: Dictionary, roles: Dictionary, seen: Dictionary) -> void:
	if node != interior:
		node.owner = interior
	if node is MeshInstance3D:
		var source_name := str(names.get(str(node.name), ""))
		if roles.has(source_name):
			node.set_meta("campus_source_name", source_name)
			node.set_meta("campus_role", roles[source_name])
			node.set_meta("teaching_interior", true)
			seen[source_name] = true
			_prepare_textures(node)
	for child: Node in node.get_children():
		_prepare(child, interior, names, roles, seen)


func _prepare_textures(node: MeshInstance3D) -> void:
	for index: int in range(node.mesh.get_surface_count()):
		var material := node.mesh.surface_get_material(index) as StandardMaterial3D
		if material == null or material.albedo_texture == null:
			continue
		var source := material.albedo_texture
		if not _mipmapped_textures.has(source):
			var image := source.get_image()
			if not image.has_mipmaps():
				image.generate_mipmaps()
			var texture := ImageTexture.create_from_image(image)
			_mipmapped_textures[source] = texture
			_mipmapped_textures[texture] = texture
		material.albedo_texture = _mipmapped_textures[source]
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
