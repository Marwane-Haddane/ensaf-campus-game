extends Node3D
## Streams a small number of walkers around the road circuit.
signal enemy_died(enemy_id: String)

const EnemyController = preload("res://scripts/antigravity/zombie/enemy_controller.gd")
const MAX_ACTIVE := 6
const SCAN_INTERVAL := 0.35
const MIN_SPAWN_DISTANCE := 17.0
const MAX_SPAWN_DISTANCE := 52.0
const DESPAWN_DISTANCE := 76.0
const RETURN_COOLDOWN := 24.0
const DEFEATED_COOLDOWN := 90.0
const CORPSE_LIFETIME := 4.0

var _points := PackedVector3Array()
var _cooldown_until := PackedFloat32Array()
var _active: Dictionary = {}
var _elapsed := 0.0
var _scan_remaining := SCAN_INTERVAL
var _last_focus := Vector3.INF
var _frozen := false
var _road_navigation_map: RID
var _clearance := CapsuleShape3D.new()

func _ready() -> void:
	_clearance.radius = 0.38
	_clearance.height = 1.75
	# These open roads are outside the mission navmesh. An empty map lets the
	# existing controller steer directly and rely on sight checks and collision.
	_road_navigation_map = NavigationServer3D.map_create()

func _exit_tree() -> void:
	NavigationServer3D.free_rid(_road_navigation_map)

func configure(route_points: PackedVector3Array) -> void:
	_points = route_points.duplicate()
	clear()

func clear() -> void:
	for enemy: Variant in _active.values():
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active.clear()
	_cooldown_until.resize(_points.size())
	_cooldown_until.fill(0.0)
	_elapsed = 0.0
	_scan_remaining = SCAN_INTERVAL
	_last_focus = Vector3.INF

func set_frozen(frozen: bool) -> void:
	_frozen = frozen
	_last_focus = Vector3.INF
	for enemy: Variant in _active.values():
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.set_physics_process(not frozen)
			enemy.set_process(not frozen)

func get_active_enemies() -> Array[Node3D]:
	var enemies: Array[Node3D] = []
	for enemy: Variant in _active.values():
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.is_dead():
			enemies.append(enemy)
	return enemies

func update(delta: float, focus: Vector3, allow_spawn: bool = true) -> void:
	if _frozen or _points.is_empty() or not focus.is_finite():
		return
	_elapsed += delta
	_scan_remaining -= delta
	if _scan_remaining > 0.0:
		return
	_scan_remaining = SCAN_INTERVAL
	var heading := Vector2.ZERO
	if _last_focus.is_finite():
		var travel := Vector2(focus.x - _last_focus.x, focus.z - _last_focus.z)
		if travel.length_squared() > 0.25:
			heading = travel.normalized()
	_last_focus = focus

	for slot: int in _active.keys():
		var enemy: Variant = _active[slot]
		if not is_instance_valid(enemy):
			_active.erase(slot)
			continue
		if enemy.is_queued_for_deletion():
			continue
		if enemy.is_dead():
			if enemy.death_timer >= CORPSE_LIFETIME:
				enemy.queue_free()
		elif _planar_offset(focus, enemy.global_position).length_squared() > DESPAWN_DISTANCE * DESPAWN_DISTANCE:
			_cooldown_until[slot] = _elapsed + RETURN_COOLDOWN
			enemy.queue_free()
	if not allow_spawn or _active.size() >= MAX_ACTIVE:
		return

	var best_slot := -1
	var best_score := INF
	for slot in _points.size():
		if _active.has(slot) or _cooldown_until[slot] > _elapsed or not _points[slot].is_finite():
			continue
		var offset := _planar_offset(focus, _points[slot])
		var distance := offset.length()
		if distance < MIN_SPAWN_DISTANCE or distance > MAX_SPAWN_DISTANCE:
			continue
		var score := distance - offset.normalized().dot(heading) * 16.0
		if score < best_score:
			best_score = score
			best_slot = slot
	if best_slot < 0:
		return
	var grounded := _find_spawn_position(_points[best_slot])
	if not grounded.is_finite():
		_cooldown_until[best_slot] = _elapsed + 8.0
		return
	_spawn(best_slot, grounded, focus)

func _find_spawn_position(point: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.8, point - Vector3.UP * 3.0, 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.72:
		return Vector3.INF
	var support: Vector3 = hit.position + Vector3.UP * 0.06
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = _clearance
	clearance.transform.origin = support + Vector3.UP * (_clearance.height * 0.5)
	clearance.collision_mask = 1 | 2 | 4
	if not space.intersect_shape(clearance, 1).is_empty():
		return Vector3.INF
	return support

func _spawn(slot: int, point: Vector3, focus: Vector3) -> void:
	var enemy := EnemyController.new()
	enemy.enemy_id = "road_walker_%02d" % slot
	enemy.position = to_local(point)
	add_child(enemy)
	enemy.look_at(Vector3(focus.x, point.y, focus.z), Vector3.UP)
	enemy.add_to_group("road_enemies")
	enemy.nav_agent.set_navigation_map(_road_navigation_map)
	enemy.enemy_died.connect(_on_enemy_died.bind(slot))
	_active[slot] = enemy

func _on_enemy_died(id: String, _boss: bool, slot: int) -> void:
	_cooldown_until[slot] = _elapsed + DEFEATED_COOLDOWN
	enemy_died.emit(id)

func _planar_offset(from: Vector3, to: Vector3) -> Vector2:
	return Vector2(to.x - from.x, to.z - from.z)
