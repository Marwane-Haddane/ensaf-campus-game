@tool
extends SceneTree

func _init() -> void:
	var base_extracted = "C:/1Project/Vr --- cyber/ensaf-campus-v4-project/ENSA-Fes-Campus-v4/3D-modeling/3d models/zombie/extracted/Zombie Apocalypse Kit - March 2024/"
	var models = [
		{"src": base_extracted + "Characters/glTF/Zombie_Ribcage.gltf", "dst": "res://assets/antigravity/zombie/models/Zombie_Ribcage.scn"},
		{"src": base_extracted + "Characters/glTF/Zombie_Arm.gltf", "dst": "res://assets/antigravity/zombie/models/Zombie_Arm.scn"},
		{"src": base_extracted + "Characters/glTF/Characters_Matt.gltf", "dst": "res://assets/antigravity/zombie/models/Characters_Matt.scn"},
		{"src": base_extracted + "Characters/glTF/Characters_Lis.gltf", "dst": "res://assets/antigravity/zombie/models/Characters_Lis.scn"},
		{"src": base_extracted + "Weapons/glTF/WoodenBat_Barbed.gltf", "dst": "res://assets/antigravity/zombie/models/WoodenBat_Barbed.scn"},
		{"src": base_extracted + "Vehicles/glTF/Vehicle_Pickup_Armored.gltf", "dst": "res://assets/antigravity/zombie/props/Vehicle_Pickup_Armored.scn"},
	]

	for item in models:
		print("Converting ", item.src, " -> ", item.dst)
		var doc = GLTFDocument.new()
		var state = GLTFState.new()
		var err = doc.append_from_file(item.src, state)
		if err != OK:
			print("Error loading ", item.src, ": ", err)
			continue
		var root_node = doc.generate_scene(state)
		_set_owner_recursive(root_node, root_node)
		var scene = PackedScene.new()
		var pack_err = scene.pack(root_node)
		if pack_err != OK:
			print("Error packing ", item.dst, ": ", pack_err)
			root_node.queue_free()
			continue
		var save_err = ResourceSaver.save(scene, item.dst)
		print("Saved ", item.dst, " result: ", save_err)
		root_node.queue_free()
	
	quit(0)

func _set_owner_recursive(node: Node, root: Node) -> void:
	if node != root:
		node.owner = root
	for child in node.get_children():
		_set_owner_recursive(child, root)
