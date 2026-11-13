extends SceneTree
var seen: Dictionary = {}
func polish(resource: Resource) -> void:
	if resource == null or seen.has(resource.get_instance_id()): return
	seen[resource.get_instance_id()] = true
	if resource is ImageTexture:
		var img: Image = resource.get_image()
		if img != null and not img.has_mipmaps() and not img.is_compressed():
			if img.generate_mipmaps() == OK: resource.set_image(img)
	if resource is BaseMaterial3D:
		resource.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for prop in resource.get_property_list():
		if int(prop.usage) & PROPERTY_USAGE_STORAGE:
			var value: Variant = resource.get(prop.name)
			if value is Resource: polish(value)
func visit(node: Node) -> void:
	for prop in node.get_property_list():
		if int(prop.usage) & PROPERTY_USAGE_STORAGE:
			var value: Variant = node.get(prop.name)
			if value is Resource: polish(value)
	for child in node.get_children(): visit(child)
func _init() -> void:
	for folder in ["res://assets/antigravity/zombie/models", "res://assets/antigravity/zombie/props"]:
		for file in DirAccess.get_files_at(folder):
			if not file.ends_with(".tscn"): continue
			var path: String = folder + "/" + file
			var packed: PackedScene = load(path)
			if packed == null: quit(1); return
			var root: Node = packed.instantiate()
			visit(root)
			var result := PackedScene.new()
			if result.pack(root) != OK: quit(2); return
			var dest := path.trim_suffix(".tscn") + ".scn"
			if ResourceSaver.save(result, dest, ResourceSaver.FLAG_COMPRESS) != OK: quit(3); return
			var verified: PackedScene = ResourceLoader.load(dest, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
			if verified == null: quit(4); return
			var check := verified.instantiate()
			if check.get_child_count() != root.get_child_count(): quit(5); return
			check.free()
			root.free()
			print("VERIFIED ", dest)
	quit()
