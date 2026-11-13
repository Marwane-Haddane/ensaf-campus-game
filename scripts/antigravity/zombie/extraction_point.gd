extends Area3D
## Powered exit presentation and deliberate boarding interaction.

const Geometry = preload("res://scripts/antigravity/zombie/prop_geometry.gd")
const ExtractionTruck = preload("res://scripts/antigravity/zombie/extraction_truck.gd")

signal extraction_triggered

var mission: RefCounted
var boarding := false
var driving := false
var reduced_motion := false
var _truck: Node3D
var _vehicle: ExtractionTruck
var _drive_camera: Camera3D
var _gate_center: Vector3
var _gate_forward: Vector3
var _gate_half_width := 2.0
var _rear_clearance := 2.5
var _passed_gate := false
var _previous_offset: Vector3
var _barriers: Array[Node3D] = []
var _closed_positions: Array[Vector3] = []
var _headlamps: Array[SpotLight3D] = []
var _lamp_material: StandardMaterial3D
var _tail_material: StandardMaterial3D
var _gate_tween: Tween
var _boarding_tween: Tween
var _boarding_camera: Camera3D
var _debrief_camera: Camera3D
var _fade_layer: CanvasLayer
var _boarding_player: CharacterBody3D
var _powered := false

func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	var shape := CylinderShape3D.new()
	shape.radius = 2.7
	shape.height = 2.5
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 1.1
	add_child(collision)

func setup_route(truck: Node3D, barriers: Array[Node3D]) -> void:
	_truck = truck
	_barriers = barriers
	for barrier in _barriers:
		_closed_positions.append(barrier.position)
		var mesh := barrier.get_node("TrafficBarrier_1") as MeshInstance3D
		var bounds := mesh.get_aabb()
		var blocker := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		collider.shape = shape
		collider.position = bounds.get_center()
		mesh.add_child(blocker)
		blocker.add_child(collider)
	if not is_instance_valid(_truck):
		return
	var body := _truck.get_node_or_null("Pickup_Armored") as MeshInstance3D
	if body == null:
		return
	var bounds := body.get_aabb()
	_vehicle = ExtractionTruck.new()
	add_child(_vehicle)
	_vehicle.global_transform = _truck.global_transform
	_truck.reparent(_vehicle)
	_vehicle.setup(_truck, bounds)
	_gate_forward = _vehicle.global_basis.z.normalized()
	_gate_center = _vehicle.global_position + _gate_forward * 6.0
	_rear_clearance = -bounds.position.z + 0.2
	if _barriers.size() == 2:
		_gate_center = (_barriers[0].global_position + _barriers[1].global_position) * 0.5
		_gate_half_width = _barriers[0].global_position.distance_to(_barriers[1].global_position) * 0.5
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.albedo_color = Color("504635")
	_lamp_material.emission_enabled = true
	_lamp_material.emission = Color("ffe0ad")
	_lamp_material.emission_energy_multiplier = 0.0
	for side in [-1.0, 1.0]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(
			bounds.get_center().x + side * bounds.size.x * 0.33,
			bounds.position.y + bounds.size.y * 0.42,
			bounds.end.z + 0.06)
		lamp.rotation.y = PI
		lamp.rotation.x = deg_to_rad(-12.0)
		lamp.light_color = Color("ffe0ad")
		lamp.light_energy = 0.0
		lamp.spot_range = 18.0
		lamp.spot_angle = 28.0
		_truck.add_child(lamp)
		_headlamps.append(lamp)
		var lens := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.092
		mesh.bottom_radius = 0.092
		mesh.height = 0.035
		mesh.radial_segments = 16
		lens.mesh = mesh
		lens.material_override = _lamp_material
		lens.rotation.x = PI * 0.5
		lens.position = Vector3(side * 0.96, 1.11, 2.34)
		_truck.add_child(lens)
	var dark_metal := Geometry.metal(Color("353843"))
	var cargo_shell := Geometry.metal(Color("505a39"), 0.1)
	var strap := Geometry.metal(Color("bc893c"), 0.0)
	_tail_material = Geometry.metal(Color("932a1e"), 0.0)
	_tail_material.emission_enabled = true
	_tail_material.emission = Color("ff572a")
	_tail_material.emission_energy_multiplier = 0.0
	for side in [-1.0, 1.0]:
		var x: float = side * 1.04
		Geometry.box(_truck, Vector3(0.21, 0.24, 0.075), Vector3(x, 1.12, bounds.position.z + 0.016), dark_metal)
		Geometry.box(_truck, Vector3(0.15, 0.14, 0.028), Vector3(x, 1.15, bounds.position.z - 0.027), _tail_material)
	Geometry.box(_truck, Vector3(0.92, 0.12, 0.18), Vector3(0, bounds.end.y + 0.03, 0.28), dark_metal)
	for x in [-0.32, 0.0, 0.32]:
		Geometry.box(_truck, Vector3(0.23, 0.065, 0.06),
			Vector3(x, bounds.end.y + 0.041, 0.36), _lamp_material)
	Geometry.box(_truck, Vector3(0.82, 0.35, 0.52), Vector3(0.04, 1.38, -1.35), cargo_shell)
	Geometry.box(_truck, Vector3(0.87, 0.055, 0.56), Vector3(0.04, 1.56, -1.35), dark_metal)
	for x in [-0.22, 0.30]:
		Geometry.box(_truck, Vector3(0.056, 0.018, 0.59), Vector3(x, 1.595, -1.35), strap)
		Geometry.box(_truck, Vector3(0.056, 0.37, 0.02), Vector3(x, 1.39, -1.64), strap)

func show_debrief_camera() -> void:
	if not is_instance_valid(_truck) or is_instance_valid(_debrief_camera):
		return
	_debrief_camera = Camera3D.new()
	_debrief_camera.fov = 58.0
	_debrief_camera.far = 170.0
	add_child(_debrief_camera)
	var truck_center := _truck.to_global(Vector3(0.0, 1.16, -0.15))
	_debrief_camera.global_position = _truck.to_global(Vector3(-4.8, 2.45, -6.6))
	_debrief_camera.look_at(truck_center)
	_debrief_camera.look_at(truck_center - _debrief_camera.global_basis.x * 2.65)
	_debrief_camera.make_current()
	var player = get_parent().get("player")
	if is_instance_valid(player):
		player.weapon_controller.hide()

func set_powered(powered: bool, animate: bool = false) -> void:
	if _gate_tween and _gate_tween.is_valid():
		_gate_tween.kill()
	_powered = powered
	var use_tween := animate and not reduced_motion
	if use_tween:
		_gate_tween = create_tween().set_parallel()
		_gate_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for index in range(_barriers.size()):
		var barrier := _barriers[index]
		var destination := _closed_positions[index]
		if powered:
			destination.x += -2.7 if destination.x < position.x else 2.7
		if use_tween:
			_gate_tween.tween_property(barrier, "position", destination, 1.45)
		else:
			barrier.position = destination
	for lamp in _headlamps:
		var energy := 2.0 if powered else 0.0
		if use_tween:
			_gate_tween.tween_property(lamp, "light_energy", energy, 0.55)
		else:
			lamp.light_energy = energy
	if _lamp_material:
		var glow := 0.95 if powered else 0.0
		if use_tween:
			_gate_tween.tween_property(_lamp_material, "emission_energy_multiplier", glow, 0.55)
		else:
			_lamp_material.emission_energy_multiplier = glow
	if _tail_material:
		_tail_material.emission_energy_multiplier = 0.78 if powered else 0.0

func get_interaction_prompt() -> String:
	var key := OS.get_keycode_string(KEY_E)
	var bindings := InputMap.action_get_events("interact") if InputMap.has_action("interact") else []
	for event in bindings:
		if event is InputEventKey:
			var code: Key = event.physical_keycode if event.physical_keycode else event.keycode
			if code:
				key = OS.get_keycode_string(code)
				break
	if _can_board():
		return "[%s] Board extraction truck" % key
	return "[%s] Check extraction route" % key

func _can_board() -> bool:
	return _vehicle != null and mission != null and _powered and mission.get_current_step().get("id") == "obj_extract" \
		and mission.power_restored and mission.survivor_talked and mission.boss_killed

func interact(player: Node) -> void:
	if boarding or driving or mission.extracted or not player is CharacterBody3D or not player.is_in_group("player"):
		return
	var game := get_parent()
	if not _can_board():
		game.hud.show_banner_message("Extraction locked. " + mission.get_current_objective_text(), 3.0)
		return
	if player.is_dead or not player.input_enabled:
		return
	boarding = true
	_boarding_player = player
	game._pause()
	game.hud.update_interaction_prompt("", false)
	game.hud.crosshair.hide()
	game.hud.show_banner_message("Boarding extraction truck", 2.0)
	player.weapon_controller.hide()

	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 110
	add_child(_fade_layer)
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0.025, 0.04, 0.06, 0.0)
	_fade_layer.add_child(fade)
	_boarding_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if not reduced_motion:
		var from: Transform3D = player.camera.global_transform
		_boarding_camera = Camera3D.new()
		_boarding_camera.fov = player.camera.fov
		_boarding_camera.far = player.camera.far
		add_child(_boarding_camera)
		_boarding_camera.global_transform = from
		_boarding_camera.make_current()
		var side := 1.0 if _truck.to_local(from.origin).x >= 0.0 else -1.0
		var cab := _truck.to_global(Vector3(side * 1.45, 1.8, 0.45))
		var approach := Transform3D(from.basis, cab).looking_at(_truck.to_global(Vector3(side * 0.7, 1.7, 1.25)))
		_boarding_tween.tween_property(_boarding_camera, "global_transform", approach, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_boarding_tween.parallel().tween_property(fade, "color:a", 1.0, 0.42).set_delay(0.38)
	else:
		_boarding_tween.tween_property(fade, "color:a", 1.0, 0.18)
	_boarding_tween.tween_callback(_seat_driver)
	_boarding_tween.tween_property(fade, "color:a", 0.0, 0.26)
	_boarding_tween.tween_callback(_start_driving)

func _seat_driver() -> void:
	_drive_camera = Camera3D.new()
	_drive_camera.fov = 67.0
	_drive_camera.far = _boarding_player.camera.far
	_vehicle.add_child(_drive_camera)
	_drive_camera.position = Vector3(0, 3.35, -6.0)
	_drive_camera.look_at(_vehicle.to_global(Vector3(0, 1.2, 2.5)))
	_drive_camera.make_current()

func _start_driving() -> void:
	driving = true
	_passed_gate = false
	_previous_offset = _vehicle.global_position - _gate_center
	_vehicle.start_driving(_boarding_player)
	_clear_boarding()
	var game := get_parent()
	game.hud.set_driving(true)
	game.hud.update_objective("Drive the extraction truck through the open gate.")
	game._resume()

func _physics_process(_delta: float) -> void:
	if not driving:
		return
	var offset := _vehicle.global_position - _gate_center
	var depth := offset.dot(_gate_forward)
	var last_depth := _previous_offset.dot(_gate_forward)
	if last_depth < 0.0 and depth >= 0.0:
		var crossing := _previous_offset.lerp(offset, -last_depth / (depth - last_depth))
		_passed_gate = absf(crossing.dot(_gate_forward.cross(Vector3.UP))) < _gate_half_width
	elif depth < 0.0:
		_passed_gate = false
	_previous_offset = offset
	if _passed_gate and depth >= _rear_clearance:
		driving = false
		_vehicle.stop_driving()
		get_parent().hud.set_driving(false)
		mission.on_event("reach_extraction")
		extraction_triggered.emit()

func reset_presentation() -> void:
	if _boarding_tween and _boarding_tween.is_valid():
		_boarding_tween.kill()
	if is_instance_valid(_debrief_camera):
		_debrief_camera.queue_free()
		_debrief_camera = null
	if is_instance_valid(_drive_camera):
		_drive_camera.queue_free()
		_drive_camera = null
	driving = false
	if _vehicle:
		_vehicle.reset()
	get_parent().hud.set_driving(false)
	var player = get_parent().get("player")
	if is_instance_valid(player):
		player.camera.make_current()
		player.weapon_controller.show()
	_clear_boarding()
	set_powered(mission.power_restored)

func _clear_boarding() -> void:
	if is_instance_valid(_boarding_player) and not driving and not mission.extracted:
		_boarding_player.camera.make_current()
		_boarding_player.weapon_controller.show()
	_boarding_player = null
	if is_instance_valid(_boarding_camera):
		_boarding_camera.queue_free()
		_boarding_camera = null
	if is_instance_valid(_fade_layer):
		_fade_layer.queue_free()
		_fade_layer = null
	if not driving and not mission.extracted:
		get_parent().hud.crosshair.show()
	boarding = false
