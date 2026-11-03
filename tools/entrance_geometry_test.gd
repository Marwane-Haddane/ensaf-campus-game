extends SceneTree

const BaseCampus = preload("res://scripts/campus_runtime.gd")
const Repair = preload("res://scripts/entrance_geometry.gd")

class ProbeCampus extends BaseCampus:
	var repair: Dictionary = {}
	func _batch_repeated_meshes() -> void:
		repair = Repair.install(self)
		super._batch_repeated_meshes()

var campus: ProbeCampus
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)
		print("ENTRANCE_GEOMETRY_FAIL " + text)


func _run() -> void:
	campus = ProbeCampus.new()
	root.add_child(campus)
	await campus.build()
	_check(bool(campus.repair.get("installed", false)), "Repair installs before source batching")
	for property: Dictionary in campus.get_property_list():
		if str(property.name) == "interactive_doors":
			for door in campus.get("interactive_doors"):
				if is_instance_valid(door) and door.has_method("set_open_immediate"):
					door.call("set_open_immediate", true)
		elif str(property.name) == "door_system":
			var system: Variant = campus.get("door_system")
			if is_instance_valid(system):
				for door in system.get("doors"):
					if is_instance_valid(door) and door.has_method("set_open_immediate"):
						door.call("set_open_immediate", true)
	await physics_frame
	await physics_frame
	_check(campus.repair.get("replaced", []).size() == 10, "Only ten exact step/rail source meshes are replaced")
	for node: MeshInstance3D in campus.mesh_nodes:
		var source := str(node.get_meta("campus_source_name", ""))
		if source in Repair.REPLACED:
			_check(not node.visible and bool(node.get_meta("entrance_geometry_replaced", false)), "Exact original hidden: " + source)
			for body in node.get_children():
				if body is StaticBody3D:
					_check(body.collision_layer == 0 and body.get_child(0).disabled, "Original collider disabled: " + source)
	var heights: Array[Dictionary] = []
	var last_y := Repair.APPROACH_Y
	for index in 175:
		var z := 5.5 - index * 0.05
		var query := PhysicsRayQueryParameters3D.create(Vector3(-14, 2.65, z), Vector3(-14, -0.4, z), 1)
		var hit := campus.get_world_3d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty(), "Continuous entrance ground at z=%.2f" % z)
		if hit.is_empty():
			continue
		var y: float = hit.position.y
		_check(y >= Repair.APPROACH_Y - 0.002 and y <= Repair.FLOOR_Y + 0.002, "Ground remains bounded at z=%.2f y=%.4f" % [z, y])
		_check(y >= last_y - 0.002 and y - last_y <= Repair.STEP_RISE + 0.002, "Regular ascent at z=%.2f y=%.4f last=%.4f" % [z, y, last_y])
		last_y = y
		if index % 10 == 0:
			heights.append({"z": z, "y": y, "source": str(hit.collider.get_meta("campus_source_name", ""))})
	_check(is_equal_approx(last_y, Repair.FLOOR_Y), "Interior threshold matches the visible plinth top")
	for point: Vector2 in [Vector2(-45, -20), Vector2(-30, -10), Vector2(-14, -5), Vector2(0, -25)]:
		var floor_query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 2.65, point.y), Vector3(point.x, 0.10, point.y), 1)
		var floor_hit := campus.get_world_3d().direct_space_state.intersect_ray(floor_query)
		_check(not floor_hit.is_empty() and absf(floor_hit.position.y - Repair.FLOOR_Y) < 0.002, "Full original plinth has matching floor support at " + str(point))
	await _walk_route()
	if DisplayServer.get_name() != "headless":
		await _capture_views()
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "ground_samples": heights, "door_opening": campus.repair.get("door_opening", {}), "repair": campus.repair}
	var report := FileAccess.open("res://tools/entrance_geometry_test.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(result, "\t"))
	print("ENTRANCE_GEOMETRY_TEST " + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	campus.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _walk_route() -> void:
	var player := CharacterBody3D.new()
	player.floor_snap_length = 0.45
	player.floor_max_angle = deg_to_rad(48)
	player.safe_margin = 0.02
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.78
	shape.shape = capsule
	player.add_child(shape)
	root.add_child(player)
	player.position = Vector3(-14, Repair.APPROACH_Y + 0.91, 5.2)
	for index in 300:
		await physics_frame
		var delta := 1.0 / 60.0
		player.velocity.x = 0.0
		player.velocity.z = -4.0
		if not player.is_on_floor():
			player.velocity.y -= 22.0 * delta
		if player.is_on_floor() and player.velocity.y <= 0:
			var motion := Vector3(0, 0, -4.0 * delta)
			if player.test_move(player.global_transform, motion):
				var raised := player.global_transform.translated(Vector3.UP * 0.28)
				if not player.test_move(raised, motion):
					player.position.y += 0.28
		player.move_and_slide()
		if player.position.z < -5.0:
			break
	_check(player.position.z < -5.0, "Actual standing player walks through threshold and 5 m into the building: " + str(player.position))
	_check(absf(player.position.y - (Repair.FLOOR_Y + 0.91)) < 0.12, "Walking player supported at threshold: " + str(player.position))
	player.queue_free()


func _capture_views() -> void:
	root.size = Vector2i(1280, 720)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("789fb6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d2dce5")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.92
	world.environment = environment
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_color = Color("fff0d5")
	sun.light_energy = 0.32
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	root.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 70
	camera.near = 0.08
	camera.current = true
	root.add_child(camera)
	var views := [
		["front", Vector3(-14, 1.85, 5.55), Vector3(-14, 1.6, 0.5)],
		["oblique", Vector3(-9.4, 1.75, 5.35), Vector3(-14.3, 1.5, 0.7)],
		["landing", Vector3(-14, 1.65, 0.70), Vector3(-14, 0.22, 4.6)]
	]
	for view: Array in views:
		camera.position = view[1]
		camera.look_at(view[2], Vector3.UP)
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://tools/entrance_geometry_" + str(view[0]) + ".png")
