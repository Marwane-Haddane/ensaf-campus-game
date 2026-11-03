@tool
extends SceneTree

func _init() -> void:
	var src_path := "C:/1Project/Vr --- cyber/ensaf-campus-v4-project/ENSA-Fes-Campus-v4/3d models/zombie/scorpion__first_person_animations_2026_remake.glb"
	var dst_path := "res://assets/antigravity/zombie/models/scorpion_hands.tscn"

	print("Converting Scorpion GLB: ", src_path)
	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	var err = doc.append_from_file(src_path, state)
	if err != OK:
		print("Failed to load scorpion: ", err)
		quit(1)
		return

	var root_node = doc.generate_scene(state)
	
	# Find and remove or hide the huge Skybox mesh
	for child in root_node.find_children("*", "MeshInstance3D"):
		var mi := child as MeshInstance3D
		if "Skybox" in mi.name or mi.name == "Object_19":
			print("Removing skybox mesh: ", mi.name)
			mi.queue_free()

	_set_owner_recursive(root_node, root_node)

	var scene = PackedScene.new()
	var pack_err = scene.pack(root_node)
	if pack_err == OK:
		var save_err = ResourceSaver.save(scene, dst_path)
		print("Saved scorpion scene: ", dst_path, " [", save_err, "]")
	else:
		print("Failed to pack scorpion: ", pack_err)

	quit(0)

func _set_owner_recursive(node: Node, r: Node) -> void:
	if node != r:
		node.owner = r
	for child in node.get_children():
		_set_owner_recursive(child, r)
