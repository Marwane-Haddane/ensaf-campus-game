extends SceneTree
## Offline bake of the existing deterministic campus surface generator.
func _init() -> void:
	var library = load("res://scripts/campus_materials.gd").new()
	var folder := "res://assets/runtime_surfaces"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var manifest: Dictionary = {"provenance":"Derived from the existing campus_materials.gd deterministic surface generator; no external assets.","textures":[]}
	for kind: String in ["asphalt","bark","carpet","fabric","floor_stone","foliage","lawn","limestone","mineral","paving","slate","soil","terrazzo","wood","wood_horizontal"]:
		var textures: Dictionary = library._get_texture_set(kind)
		for channel: String in textures:
			var path := folder.path_join(kind+"_"+channel+".png")
			var image: Image = textures[channel].get_image()
			var result := image.save_png(path)
			if result != OK:
				push_error("Surface bake failed: "+path)
				quit(1)
				return
			manifest.textures.append(path)
	FileAccess.open(folder.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
	print("SURFACE_BAKE_READY ",manifest.textures.size())
	quit()
