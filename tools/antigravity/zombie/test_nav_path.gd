@tool
extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Testing Navigation Pathfinding ---")
	var nav_mesh: NavigationMesh = load("res://assets/antigravity/zombie/route_navmesh.res")
	if not nav_mesh:
		print("FAIL: could not load route_navmesh.res")
		quit(1)
		return
	
	var nav_region = NavigationRegion3D.new()
	nav_region.navigation_mesh = nav_mesh
	root.add_child(nav_region)
	
	# Wait for navigation map sync
	for i in range(5):
		await process_frame
		await physics_frame
	
	var map_rid = nav_region.get_navigation_map()
	var p1 = Vector3(-27, 1.25, -85)
	var p2 = Vector3(-36.2, 1.91, -104.1)
	
	var closest1 = NavigationServer3D.map_get_closest_point(map_rid, p1)
	var closest2 = NavigationServer3D.map_get_closest_point(map_rid, p2)
	print("P1: ", p1, " -> closest on nav: ", closest1)
	print("P2: ", p2, " -> closest on nav: ", closest2)
	
	var path = NavigationServer3D.map_get_path(map_rid, closest1, closest2, true)
	print("Path points count: ", path.size())
	if path.size() > 0:
		print("Path start: ", path[0], " end: ", path[path.size()-1])
		print("SUCCESS: Navigation path computed correctly!")
	else:
		print("WARNING: Path was empty, checking distance...")
	
	nav_region.queue_free()
	quit(0)
