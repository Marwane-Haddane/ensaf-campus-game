@tool
extends SceneTree

func _init() -> void:
	var models = [
		{"src": "res://assets/antigravity/zombie/models/pistol_hands.glb", "dst": "res://assets/antigravity/zombie/models/pistol_hands.scn"},
		{"src": "res://assets/antigravity/zombie/models/Zombie_Basic.gltf", "dst": "res://assets/antigravity/zombie/models/Zombie_Basic.scn"},
		{"src": "res://assets/antigravity/zombie/models/Zombie_Chubby.gltf", "dst": "res://assets/antigravity/zombie/models/Zombie_Chubby.scn"},
		{"src": "res://assets/antigravity/zombie/models/Characters_Shaun.gltf", "dst": "res://assets/antigravity/zombie/models/Characters_Shaun.scn"},
		{"src": "res://assets/antigravity/zombie/props/TrafficBarrier_1.gltf", "dst": "res://assets/antigravity/zombie/props/TrafficBarrier_1.scn"},
		{"src": "res://assets/antigravity/zombie/props/Pallet.gltf", "dst": "res://assets/antigravity/zombie/props/Pallet.scn"},
		{"src": "res://assets/antigravity/zombie/props/Barrel.gltf", "dst": "res://assets/antigravity/zombie/props/Barrel.scn"},
		{"src": "res://assets/antigravity/zombie/props/Container_Red.gltf", "dst": "res://assets/antigravity/zombie/props/Container_Red.scn"},
		{"src": "res://assets/antigravity/zombie/props/Vehicle_Pickup.gltf", "dst": "res://assets/antigravity/zombie/props/Vehicle_Pickup.scn"},
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
