extends "res://scripts/antigravity/zombie/extraction_truck.gd"
## The exploration pickup shares the extraction truck's arcade handling.

signal entry_requested(player: CharacterBody3D)

const PICKUP_MODEL = preload("res://assets/antigravity/zombie/props/Vehicle_Pickup.scn")
const OBSTACLE_MASK := 1 | 4

var driving := false
## World-space X/Z range for the pickup center. An empty rectangle is unrestricted.
var driving_bounds := Rect2()
var _chase_camera: Camera3D
var _pickup_bounds: AABB

func setup_pickup() -> void:
	if is_instance_valid(_chase_camera):
		return
	var model := PICKUP_MODEL.instantiate() as Node3D
	add_child(model)
	var body_mesh := model.get_node("Pickup") as MeshInstance3D
	_pickup_bounds = body_mesh.get_aabb()
	setup(model, _pickup_bounds)
	collision_layer = 4 | 8
	max_forward_speed = 16.0
	max_reverse_speed = 5.0
	acceleration = 6.4
	coast_deceleration = 3.3
	max_turn_rate = 1.50
	curb_height = 0.24

	_chase_camera = Camera3D.new()
	_chase_camera.name = "PickupCamera"
	_chase_camera.top_level = true
	_chase_camera.fov = 68.0
	_chase_camera.near = 0.08
	add_child(_chase_camera)

func get_interaction_prompt() -> String:
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey:
			var key: Key = event.physical_keycode if event.physical_keycode else event.keycode
			if key != 0:
				return "[%s] Drive pickup" % OS.get_keycode_string(key)
	return "[E] Drive pickup"

func interact(player: Node) -> void:
	if not driving and player is CharacterBody3D and player.is_in_group("player"):
		entry_requested.emit(player)

func start_driving(driver: CharacterBody3D) -> void:
	driving = true
	super.start_driving(driver)
	var player_camera := driver.get("camera") as Camera3D
	if is_instance_valid(player_camera):
		_chase_camera.far = player_camera.far
	_update_chase_camera(1.0)
	_chase_camera.make_current()

func stop_driving() -> void:
	driving = false
	super.stop_driving()

func forward_speed() -> float:
	return get_real_velocity().dot(global_basis.z) if driving else 0.0

func speed_kph() -> float:
	return absf(forward_speed()) * 3.6

func bumper_position() -> Vector3:
	var center := _pickup_bounds.get_center()
	var travel := forward_speed()
	center.y = _pickup_bounds.position.y + _pickup_bounds.size.y * 0.24
	center.z = _pickup_bounds.position.z if travel < -0.01 else _pickup_bounds.end.z
	return to_global(center)

func bumper_half_width() -> float:
	return _pickup_bounds.size.x * 0.455

func find_exit_position(player: CharacterBody3D) -> Variant:
	var player_shape := player.get_node_or_null("PlayerCollision") as CollisionShape3D
	if not is_instance_valid(player_shape):
		return null
	var space := get_world_3d().direct_space_state
	var side_distance := _pickup_bounds.size.x * 0.5 + 0.75
	var exit_offsets := [
		Vector3(-side_distance, 0.0, 0.0),
		Vector3(side_distance, 0.0, 0.0),
		Vector3(0.0, 0.0, _pickup_bounds.position.z - 0.75),
		Vector3(0.0, 0.0, _pickup_bounds.end.z + 0.75),
	]
	for offset: Vector3 in exit_offsets:
		var candidate := to_global(offset)
		var floor_ray := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 0.8,
			candidate - Vector3.UP * 1.4, 1, [get_rid(), player.get_rid()])
		var floor_hit := space.intersect_ray(floor_ray)
		if floor_hit.is_empty() or (floor_hit.normal as Vector3).y < 0.7:
			continue
		var exit_at: Vector3 = floor_hit.position + Vector3.UP * 0.035
		var step_ray := PhysicsRayQueryParameters3D.create(to_global(Vector3.UP),
			exit_at + Vector3.UP, OBSTACLE_MASK, [get_rid(), player.get_rid()])
		if not space.intersect_ray(step_ray).is_empty():
			continue
		var clearance := PhysicsShapeQueryParameters3D.new()
		clearance.shape = player_shape.shape
		clearance.transform = Transform3D(Basis.IDENTITY, exit_at + player_shape.position)
		clearance.collision_mask = OBSTACLE_MASK
		clearance.exclude = [player.get_rid()]
		if space.intersect_shape(clearance, 1).is_empty():
			return exit_at
	return null

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_driver):
		stop_driving()
		return
	super._physics_process(delta)
	_update_chase_camera(1.0 - exp(-8.0 * delta))

func _brake_held() -> bool:
	return Input.is_action_pressed("jump") if InputMap.has_action("jump") else Input.is_physical_key_pressed(KEY_SPACE)

func _limit_drive_velocity(requested: Vector3, delta: float) -> Vector3:
	if not driving_bounds.has_area():
		return requested
	var origin := Vector2(global_position.x, global_position.z)
	var motion := Vector2(requested.x, requested.z) * delta
	var limit := 1.0
	for axis in [Vector2.AXIS_X, Vector2.AXIS_Y]:
		if motion[axis] > 0.0:
			limit = minf(limit, (driving_bounds.end[axis] - origin[axis]) / motion[axis])
		elif motion[axis] < 0.0:
			limit = minf(limit, (driving_bounds.position[axis] - origin[axis]) / motion[axis])
	limit = maxf(0.0, limit)
	_speed *= limit
	return Vector3(requested.x * limit, requested.y, requested.z * limit)

func _update_chase_camera(blend: float) -> void:
	var focus := to_global(Vector3(0.0, 1.66, 0.45))
	var ideal := to_global(Vector3(-0.70, 3.28, -6.45))
	var desired := _chase_camera.global_position.lerp(ideal, blend)
	var ray := PhysicsRayQueryParameters3D.create(focus, desired, 1, [get_rid(), _driver.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var direction := focus.direction_to(desired)
		var hit_position: Vector3 = hit.position
		desired = focus + direction * maxf(0.12, focus.distance_to(hit_position) - 0.20)
	_chase_camera.global_position = desired
	_chase_camera.look_at(to_global(Vector3(0.0, 1.42, 3.60)))
