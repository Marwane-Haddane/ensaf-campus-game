extends SceneTree
var game
func _init() -> void:
	call_deferred("run")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	while not game.ready_to_play: await process_frame
	game._resume()
	var views: Array = [
		["front",Vector3(-5.8,3.4,-102.5),Vector3(-5.8,3.2,-104.1)],
		["side_inside",Vector3(-3.3,3.35,-105.05),Vector3(-2.0,2.4,-106.7)],
		["side_outside",Vector3(-0.4,3.35,-105.4),Vector3(-2.7,2.6,-106.6)],
		["upper_inside",Vector3(-3.3,6.65,-105.05),Vector3(-2,5.6,-106.7)]]
	for view: Array in views:
		game.player.position=view[1]-Vector3(0,.65,0)
		game.camera.look_at(view[2],Vector3.UP)
		game.player.force_update_transform()
		game.camera.force_update_transform()
		for frame: int in range(5): await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://tools/atrium-before-"+str(view[0])+".png")
	var rays: Array = []
	for x: float in [-3.55,-3.0,-2.6,-2.3,-2.1]:
		for z: float in [-104.5,-105.0,-105.6,-106.1,-106.65,-107.5,-108.2]:
			var q:=PhysicsRayQueryParameters3D.create(Vector3(x,2.0,z),Vector3(x,-.5,z),1)
			var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(q)
			rays.append({"x":x,"z":z,"y":hit.position.y if not hit.is_empty() else null,"source":str(hit.collider.get_meta("campus_source_name","")) if not hit.is_empty() else "NONE"})
	FileAccess.open("res://tools/atrium-before-rays.json",FileAccess.WRITE).store_string(JSON.stringify(rays,"  "))
	game.queue_free()
	await process_frame
	quit()
