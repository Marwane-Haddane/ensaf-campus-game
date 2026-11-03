extends SceneTree

func _init() -> void:
	var light := DirectionalLight3D.new()
	for entry: Dictionary in light.get_property_list():
		var key: String = str(entry.name)
		if "shadow" in key or "angular" in key:
			print(key, " = ", light.get(key))
	light.free()
	var camera := Camera3D.new()
	print("camera defaults near=", camera.near, " far=", camera.far)
	camera.free()
	quit()
