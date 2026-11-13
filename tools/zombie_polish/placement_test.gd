extends SceneTree
const Placement = preload("res://scripts/antigravity/zombie/model_placement.gd")
var failed := false
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failed = true
func _init() -> void: call_deferred("run")
func run() -> void:
	var model := Node3D.new()
	model.position = Vector3(2, 6, 3)
	model.rotation.y = 0.6
	model.scale = Vector3.ONE * 1.2
	var child := MeshInstance3D.new()
	child.mesh = BoxMesh.new()
	child.position.y = 2
	model.add_child(child)
	Placement.ground(model, 1.25)
	check(absf(Placement.bounds_in_parent(model).position.y - 1.25) < 0.001, "Nested scaled model rests on floor")
	model.free()
	var game = load("res://scenes/antigravity/zombie/zombie_game.tscn").instantiate()
	game.launcher_managed = true
	root.add_child(game)
	for i in 1800:
		if game.initialization_finished: break
		await process_frame
	check(game.ready_to_play, "Zombie world initialized")
	check(is_instance_valid(game._extraction_truck), "Compressed truck registered")
	check(game._extraction_barriers.size() == 2, "Both barricades registered")
	check(is_instance_valid(game.extraction_point._vehicle), "Extraction vehicle configured")
	check(get_nodes_in_group("route_props").size() == 6, "All six route props placed")
	for prop in get_nodes_in_group("route_props"):
		print("PLACED ", prop.name, " ", prop.global_position, " bounds=", Placement.bounds_in_parent(prop))
	for npc in get_nodes_in_group("friendly_npc"):
		for mesh in npc.model_instance.find_children("*", "MeshInstance3D", true, false):
			if mesh.name in ["Axe", "Guitar", "Knife", "Pistol", "Rifle", "Shotgun", "SMG", "Spear", "WoodenBat_Barbed", "WoodenBat_Saw"]:
				check(not mesh.visible, "Unused NPC equipment hidden: " + str(mesh.name))
	var closed: Vector3 = game._extraction_barriers[0].position
	game.extraction_point.set_powered(true, false)
	check(game._extraction_barriers[0].position.distance_to(closed) > 2.5, "Power opens physical barricade")
	game.extraction_point.set_powered(false, false)
	check(game._extraction_barriers[0].position.is_equal_approx(closed), "Reset restores barricade")
	if not DisplayServer.get_name() == "headless":
		game.player.camera.current = true
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/zombie_polish/placement_preview.png")
	quit(1 if failed else 0)
