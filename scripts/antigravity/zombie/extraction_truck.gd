extends CharacterBody3D
## Low-speed arcade handling for the extraction route. The model faces local +Z.

const FORWARD_SPEED := 8.0
const REVERSE_SPEED := 3.2
const ACCELERATION := 5.0
const BRAKING := 9.0

var max_forward_speed := FORWARD_SPEED
var max_reverse_speed := REVERSE_SPEED
var acceleration := ACCELERATION
var coast_deceleration := BRAKING
var max_turn_rate := INF
var curb_height := 0.0

var _parked_pose: Transform3D
var _driver: CharacterBody3D
var _speed := 0.0
var _steering := 0.0
var _roll := 0.0
var _wheel_pivots: Array[Node3D] = []
var _wheel_radii: Array[float] = []

func setup(model: Node3D, body_bounds: AABB) -> void:
	_parked_pose = global_transform
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.35
	var rear := model.get_node("BackWheels") as MeshInstance3D
	var bottom := rear.get_aabb().position.y
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(body_bounds.size.x * 0.91, body_bounds.end.y - bottom, body_bounds.size.z * 0.96)
	collider.shape = shape
	collider.position = Vector3(body_bounds.get_center().x, bottom + shape.size.y * 0.5, body_bounds.get_center().z)
	add_child(collider)
	for name_in_model in ["BackWheels", "FrontWheel_R", "FrontWheel_L"]:
		var wheel := model.get_node(name_in_model) as MeshInstance3D
		var bounds := wheel.get_aabb()
		var pivot := Node3D.new()
		pivot.position = wheel.position + bounds.get_center()
		model.add_child(pivot)
		wheel.reparent(pivot)
		_wheel_pivots.append(pivot)
		_wheel_radii.append(maxf(0.1, bounds.size.y * 0.5))
	set_physics_process(false)

func start_driving(driver: CharacterBody3D) -> void:
	_driver = driver
	set_physics_process(true)

func stop_driving() -> void:
	set_physics_process(false)
	_driver = null
	_speed = 0.0
	velocity = Vector3.ZERO

func reset() -> void:
	stop_driving()
	global_transform = _parked_pose
	_steering = 0.0
	_roll = 0.0
	for pivot in _wheel_pivots:
		pivot.rotation = Vector3.ZERO

func _physics_process(delta: float) -> void:
	var controls: Vector2 = _driver._movement_input()
	var throttle := -controls.y
	var target := throttle * (max_forward_speed if throttle >= 0.0 else max_reverse_speed)
	var rate := acceleration if _speed * target >= 0.0 else BRAKING
	if _brake_held():
		target = 0.0
		rate = BRAKING * 2.0
	elif is_zero_approx(throttle):
		rate = coast_deceleration
	_speed = move_toward(_speed, target, rate * delta)
	_steering = move_toward(_steering, controls.x, 5.0 * delta)
	var yaw_speed := clampf(_speed * 0.25, -max_turn_rate, max_turn_rate)
	rotate_y(-_steering * yaw_speed * delta)
	var forward := global_basis.z
	var requested := Vector3(forward.x * _speed, velocity.y - 18.0 * delta, forward.z * _speed)
	velocity = _limit_drive_velocity(requested, delta)
	if curb_height > 0.0 and is_on_floor():
		_try_climb_curb(Vector3(velocity.x, 0.0, velocity.z) * delta)
	move_and_slide()
	var traveled_speed := get_real_velocity().dot(forward)
	if absf(traveled_speed) + 0.2 < absf(_speed) and is_on_wall():
		_speed = traveled_speed
	_roll += traveled_speed * delta
	for i in range(_wheel_pivots.size()):
		var pivot := _wheel_pivots[i]
		pivot.rotation_order = EULER_ORDER_YXZ
		pivot.rotation = Vector3(_roll / _wheel_radii[i], -_steering * 0.45 if i > 0 else 0.0, 0.0)

func _brake_held() -> bool:
	return false

func _limit_drive_velocity(requested: Vector3, _delta: float) -> Vector3:
	return requested

func _try_climb_curb(motion: Vector3) -> void:
	if motion.length_squared() < 0.0001 or not test_move(global_transform, motion):
		return
	var lift := Vector3.UP * curb_height
	var raised := global_transform.translated(lift)
	if not test_move(global_transform, lift) and not test_move(raised, motion):
		global_transform = raised
