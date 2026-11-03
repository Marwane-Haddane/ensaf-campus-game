extends SceneTree
## Runtime integration checks against the actual campus collision world.
## Does not advance or replace the incident training state.

var game
var report := {"passed": false, "checks": 0, "failures": [], "stations": [], "training_unchanged": false}
var initial_state: Dictionary
var initial_points: int
var initial_journal: Array

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String, details: Variant = null) -> void:
	report.checks += 1
	if not condition:
		report.failures.append({"check": message, "details": str(details)})
		print("INTEGRATION_FAIL ", message, " ", details)

func run_test() -> void:
	var scene := load("res://main.tscn") as PackedScene
	check(scene != null, "main scene loads")
	if scene == null:
		finish()
		return
	game = scene.instantiate()
	if "--runtime-sections" in OS.get_cmdline_user_args():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime_campus/manifest.json"))
		for path: String in manifest.chunks: game.prepared_sections.append(load(path) as PackedScene)
	root.add_child(game)
	# The test positions a standing capsule explicitly; game gravity stays off.
	game.set_physics_process(false)
	game.set_process(false)
	var started := Time.get_ticks_msec()
	while not game.ready_to_play and Time.get_ticks_msec() - started < 120000:
		await process_frame
	check(game.ready_to_play, "campus ready within 120 seconds")
	if not game.ready_to_play:
		finish()
		return
	await physics_frame
	await physics_frame
	initial_state = game.training.state.duplicate(true)
	initial_points = game.training.points
	initial_journal = game.training.journal.duplicate()
	check(game.stations.size() == 5, "three PCs plus two rack stations", game.stations.size())
	check(game.SPAWNS.size() == 6, "six destinations", game.SPAWNS.size())
	var all_source_roots: Array[Node3D] = []
	collect_source_roots(game, all_source_roots)
	check(all_source_roots.size() == 3, "three actual approved computer assemblies", all_source_roots.size())
	var approaches := {
		"Reception response PC": Vector3(-36.2, 0, -104.1),
		"Campus security PC": Vector3(0.90, 0, -110.5),
		"Auditorium teaching PC": Vector3(-43.0, 0, -121.4),
		"Lab services rack": Vector3(1.10, 0, -111.9),
		"Recovery storage rack": Vector3(2.30, 0, -111.9),
	}
	for station: Dictionary in game.stations:
		await test_station(station, approaches.get(station.name, Vector3.ZERO))
	check(game.training.state == initial_state, "incident state remains unchanged")
	check(game.training.points == initial_points, "points remain unchanged")
	check(game.training.journal == initial_journal, "evidence journal remains unchanged")
	check(game.training.get_completion_count() == 0, "no mission steps completed by interaction test")
	report.training_unchanged = game.training.state == initial_state and game.training.points == initial_points and game.training.journal == initial_journal
	report.campus_stats = game.campus.stats
	finish()

func test_station(station: Dictionary, approach: Vector3) -> void:
	var name: String = station.name
	var kind: String = station.get("kind", "pc")
	var target: Vector3 = station.screen
	var node := station.node as Node3D
	var floor_ray := PhysicsRayQueryParameters3D.create(Vector3(approach.x, node.global_position.y + 0.35, approach.z), Vector3(approach.x, node.global_position.y - 3.0, approach.z), 1, [game.player.get_rid()])
	var floor_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(floor_ray)
	check(not floor_hit.is_empty(), name + " has floor at approach", approach)
	if floor_hit.is_empty():
		return
	var floor_body := floor_hit.collider as Node
	var floor_role: String = floor_body.get_meta("campus_role", "")
	check(floor_role != "furniture", name + " approach stands on floor, not a seat/desk", floor_body.get_meta("campus_source_name", floor_body.name))
	approach.y = floor_hit.position.y + 0.89 + 0.02
	game.player.global_position = approach
	game.player.velocity = Vector3.ZERO
	game.camera.look_at(target, Vector3.UP)
	game._resume()
	await physics_frame
	await process_frame
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = game.player.get_child(0).shape
	shape_query.transform = game.player.global_transform
	shape_query.collision_mask = 1
	shape_query.exclude = [game.player.get_rid()]
	var overlaps: Array[Dictionary] = game.get_world_3d().direct_space_state.intersect_shape(shape_query)
	var overlap_names: Array[String] = []
	for overlap: Dictionary in overlaps:
		var body := overlap.collider as Node
		overlap_names.append(str(body.get_meta("campus_source_name", body.get_path())))
	check(overlaps.is_empty(), name + " standing capsule clears desks, chairs and walls", overlap_names)
	game._process(0)
	var selected: String = str(game._closest.get("name", ""))
	var direct_ray := PhysicsRayQueryParameters3D.create(game.camera.global_position, target, 1, [game.player.get_rid()])
	var direct_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(direct_ray)
	var hit_name := "none"
	var hit_distance := -1.0
	if not direct_hit.is_empty():
		var hit_body := direct_hit.collider as Node
		hit_name = str(hit_body.get_meta("campus_source_name", hit_body.get_path()))
		hit_distance = game.camera.global_position.distance_to(direct_hit.position)
	var row := {"name": name, "kind": kind, "position": str(approach), "floor_y": floor_hit.position.y, "floor": str(floor_body.get_meta("campus_source_name", floor_body.name)), "capsule_overlaps": overlap_names, "target": str(target), "distance": game.camera.global_position.distance_to(target), "selected": selected, "ray_hit": hit_name, "ray_distance": hit_distance}
	check(selected == name, name + " selected in range with actual campus line of sight", row)
	check(game.focus_overlay._canvas.visible, name + " interaction card visible")
	if kind == "pc":
		var asset: Dictionary = station.asset
		var mesh_count := 0
		var primitives := 0
		for mesh: MeshInstance3D in asset.meshes:
			mesh_count += 1
			if mesh.mesh is PrimitiveMesh:
				primitives += 1
		check(mesh_count == 37 and primitives == 0, name + " uses supplied meshes without primitive PC", {"meshes":mesh_count,"primitives":primitives})
		check(node.get_meta("source_asset", "") == "res://assets/user_models/gamer_setup_pack.glb", name + " source metadata matches approved model")
		var screen_mesh := asset.screen_mesh as MeshInstance3D
		check(screen_mesh != null and str(screen_mesh.name) == "sm_monitor_mt_monitor_screen_0", name + " interaction targets native display")
		check(is_equal_approx(float(asset.monitor_width), 0.72), name + " monitor width is realistic")
		check(node.global_basis.is_equal_approx(Basis.IDENTITY), name + " display faces +Z")
		row.meshes = mesh_count
		row.primitives = primitives
	# Exercise the exact InputEventAction handlers used by the engine input path.
	var interact := action("interact")
	game._unhandled_input(interact)
	if kind == "pc":
		row.opened = game.training.terminal_open and game.training._terminal.visible
		check(row.opened, name + " E opens training UI")
		game.training._input(action("ui_cancel"))
		row.escaped = not game.training.terminal_open and game.moving
		check(row.escaped, name + " Escape closes console and resumes exploration")
	else:
		row.opened = game.menu.visible and game.menu_title.text == name.to_upper() and not game.training.terminal_open
		check(row.opened, name + " E opens rack inspection menu", game.menu_title.text)
		check("lab-ws-07" in game.menu_body.text, name + " inspection retains incident context")
		game._unhandled_input(action("ui_cancel"))
		row.escaped = not game.menu.visible and game.moving
		check(row.escaped, name + " Escape closes inspection and resumes")
	# Verify that aiming away and moving beyond the use radius suppress selection.
	game.camera.look_at(game.camera.global_position + Vector3.BACK, Vector3.UP)
	game._process(0)
	row.looking_away_rejected = game._closest.get("name", "") != name
	check(row.looking_away_rejected, name + " cannot activate while looking away")
	game.player.global_position = Vector3(target.x, approach.y, target.z + 4.0)
	game.camera.look_at(target, Vector3.UP)
	game._process(0)
	row.out_of_range_rejected = game._closest.get("name", "") != name
	check(row.out_of_range_rejected, name + " cannot activate beyond 2.8 m")
	# A temporary collision-only occluder proves the line-of-sight guard works.
	game.player.global_position = approach
	game.camera.look_at(target, Vector3.UP)
	var blocker := StaticBody3D.new()
	blocker.name = "IntegrationTestOccluder"
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.45, 0.45)
	collision.shape = box
	blocker.add_child(collision)
	game.add_child(blocker)
	blocker.global_position = (game.camera.global_position + target) * 0.5
	await physics_frame
	await physics_frame
	game._process(0)
	row.occluded_rejected = game._closest.get("name", "") != name
	check(row.occluded_rejected, name + " cannot activate through blocking geometry")
	blocker.queue_free()
	await process_frame
	await physics_frame
	game._process(0)
	row.visible_restored = game._closest.get("name", "") == name
	check(row.visible_restored, name + " selection returns when obstruction is removed")
	report.stations.append(row)
	print("INTEGRATION_STATION ", JSON.stringify(row))

func action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

func collect_source_roots(node: Node, results: Array[Node3D]) -> void:
	if node is Node3D and node.get_meta("source_asset", "") == "res://assets/user_models/gamer_setup_pack.glb":
		results.append(node as Node3D)
	for child in node.get_children():
		collect_source_roots(child, results)

func finish() -> void:
	report.passed = report.failures.is_empty()
	var file := FileAccess.open("res://tools/computer_integration_test.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("COMPUTER_INTEGRATION ", JSON.stringify(report))
	quit(0 if report.passed else 1)


