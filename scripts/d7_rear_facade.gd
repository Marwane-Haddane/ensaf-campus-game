extends Node3D
## The glazed building's rear elevation, in metres from the left corner as seen from the road.

var _surfaces: Dictionary = {}
var _cube := BoxMesh.new()
var _tube := CylinderMesh.new()
var _plaster: Material
var _stone := _finish("c5bdad")
var _reveal := _finish("a19e90")
var _frame := _finish("343b3d", 0.35)
var _glass := _finish("526066", 0.22)
var _white_steel := _finish("e1e2d6", 0.22)
var _asphalt := _finish("454b4a")
var _blue := _finish("6c9baa")
var _lawn := _finish("77794c")
var _curtain_fabric := [_finish("a8afb0"), _finish("8c969a"), _finish("757f85")]

static func install(campus: Node3D, source: Array[MeshInstance3D], materials: RefCounted) -> void:
	var wall: MeshInstance3D
	var grass: MeshInstance3D
	for mesh in source:
		match mesh.get_meta("campus_source_name", ""):
			"D7 service block end": wall = mesh
			"D7 fine lawn grass geometry": grass = mesh
	if wall == null:
		return
	var detail := new()
	detail.name = "D7RearFacade"
	detail.position = Vector3(5.0, 0.0, -140.04)
	detail.rotation.y = PI
	campus.add_child(detail)
	detail._build(wall.get_active_material(0), grass, materials)
	# The facade carries its own collision, including the closed windows.
	wall.hide()

func _build(plaster: Material, grass: MeshInstance3D, materials: RefCounted) -> void:
	_plaster = plaster if plaster != null else _finish("e0ded4")
	_stone.resource_name = "Rear limestone"
	_asphalt.resource_name = "Rear asphalt"
	_lawn.resource_name = "Rear lawn"
	_stone = materials.material_for(_stone)
	_asphalt = materials.material_for(_asphalt)
	_lawn = materials.material_for(_lawn)
	_tube.top_radius = 0.5
	_tube.bottom_radius = 0.5
	_tube.height = 1.0
	_tube.radial_segments = 8
	_tube.rings = 1

	# The lower roof on the left and the offset central pier divide three bays.
	_bay(0.0, 5.05, 0.06, 11.46, [
		Rect2(0.65, 0.82, 0.52, 0.65), Rect2(1.46, 0.82, 0.52, 0.65), Rect2(2.29, 0.82, 0.52, 0.65),
		Rect2(0.90, 3.78, 0.56, 0.65), Rect2(0.98, 6.10, 0.50, 0.75),
		Rect2(0.72, 8.91, 3.09, 1.42), Rect2(4.36, 8.98, 0.43, 1.37),
	])
	_bay(5.05, 9.8, 0.33, 11.61, [
		Rect2(5.58, 0.55, 2.73, 1.39),
		Rect2(6.05, 6.18, 0.65, 0.84),
		Rect2(6.22, 8.95, 2.95, 1.48),
	])
	_bay(9.8, 18.0, 0.22, 11.61, [
		Rect2(10.22, 0.55, 6.88, 1.45),
		Rect2(11.08, 3.73, 6.02, 1.38),
		Rect2(10.63, 6.35, 6.45, 1.43),
		Rect2(10.92, 8.99, 6.43, 1.52),
	])
	_box(Vector3(2.52, 11.29, 0.23), Vector3(5.05, 0.21, 0.50), _stone)
	_box(Vector3(11.52, 11.53, 0.26), Vector3(13.0, 0.19, 0.58), _stone)
	_box(Vector3(9.0, 0.29, 0.055), Vector3(18.0, 0.18, 0.33), _stone)

	# Service conduit and a compact floodlight beneath the left eave.
	var conduit := _finish("827d6d", 0.15)
	_rod(Vector3(0.18, 0.46, 0.13), Vector3(0.18, 1.98, 0.13), 0.033, conduit)
	_rod(Vector3(0.18, 1.98, 0.13), Vector3(5.02, 1.98, 0.13), 0.033, conduit)
	_rod(Vector3(0.18, 0.46, 0.13), Vector3(3.73, 0.46, 0.13), 0.033, conduit)
	_box(Vector3(0.38, 10.98, 0.26), Vector3(0.20, 0.16, 0.21), _frame)
	_box(Vector3(0.38, 10.93, 0.37), Vector3(0.15, 0.10, 0.025), _white_steel)

	_ground(grass)
	_tree()
	_steps()
	_bicycle()
	for material: Material in _surfaces:
		var part := MeshInstance3D.new()
		part.mesh = (_surfaces[material] as SurfaceTool).commit()
		add_child(part)
	_surfaces.clear()

func _bay(left: float, right: float, depth: float, top: float, windows: Array) -> void:
	_collision_box(Vector3((left + right) * 0.5, top * 0.5, depth - 0.055),
		Vector3(right - left, top, 0.11))
	var levels: Array[float] = [0.38, top]
	for opening: Rect2 in windows:
		levels.append(opening.position.y)
		levels.append(opening.end.y)
		_window(opening, depth)
	levels.sort()
	for band in range(levels.size() - 1):
		var bottom := levels[band]
		var height := levels[band + 1] - bottom
		if height < 0.001:
			continue
		var cursor := left
		for opening: Rect2 in windows:
			if bottom >= opening.position.y and bottom < opening.end.y:
				_wall_band(cursor, opening.position.x, bottom, height, depth)
				cursor = opening.end.x
		_wall_band(cursor, right, bottom, height, depth)
func _wall_band(left: float, right: float, bottom: float, height: float, depth: float) -> void:
	if right <= left:
		return
	var thickness := depth + 0.26
	_box(Vector3((left + right) * 0.5, bottom + height * 0.5, depth - thickness * 0.5),
		Vector3(right - left, height, thickness), _plaster)

func _window(rect: Rect2, depth: float) -> void:
	var center := rect.get_center()
	var window_z := depth - 0.19
	_box(Vector3(center.x, center.y, window_z - 0.06),
		Vector3(rect.size.x, rect.size.y, 0.07), _glass)
	_border(rect, window_z, 0.055, _frame)
	var panes := maxi(1, roundi(rect.size.x / 1.05))
	for pane in range(1, panes):
		var x := rect.position.x + rect.size.x * float(pane) / panes
		_box(Vector3(x, center.y, window_z), Vector3(0.047, rect.size.y, 0.05), _frame)
	if rect.position.y >= 6.0 and rect.size.x > 1.0:
		_curtains(rect, window_z - 0.007, panes)
	_box(Vector3(center.x, rect.position.y + 0.015, depth - 0.08),
		Vector3(rect.size.x, 0.03, 0.22), _reveal)
	if rect.position.y < 6.0:
		_grille(rect, depth + 0.018)

func _curtains(rect: Rect2, depth: float, panes: int) -> void:
	var pane_width := rect.size.x / panes
	for pane in range(panes):
		var start := rect.position.x + pane * pane_width + 0.04
		var pleats := maxi(4, roundi((pane_width - 0.08) / 0.065))
		var width := (pane_width - 0.08) / pleats
		for fold in range(pleats):
			var z := depth - 0.009 * (fold % 3)
			_box(Vector3(start + (fold + 0.5) * width, rect.get_center().y, z),
				Vector3(width, rect.size.y - 0.14, 0.011), _curtain_fabric[fold % 3])

func _grille(rect: Rect2, depth: float) -> void:
	var opening := rect.grow(-0.035)
	_border(opening, depth, 0.03, _white_steel)
	var bays := maxi(1, ceili(opening.size.x / 2.15))
	for index in range(bays):
		var w := opening.size.x / bays
		var left := opening.position.x + index * w
		var right := left + w
		var low := opening.position.y
		var high := opening.end.y
		if index > 0:
			_rod(Vector3(left, low, depth), Vector3(left, high, depth), 0.029, _white_steel)
		_rod(Vector3(left, low, depth), Vector3(right, high, depth), 0.023, _white_steel)
		_rod(Vector3(left, high, depth), Vector3(right, low, depth), 0.023, _white_steel)
		_rod(Vector3(left + w * 0.27, high, depth), Vector3(right, lerpf(low, high, 0.28), depth), 0.019, _white_steel)
		_rod(Vector3(left, lerpf(low, high, 0.62), depth), Vector3(right - w * 0.19, low, depth), 0.019, _white_steel)
		_rod(Vector3(left + w * 0.30, low, depth), Vector3(right - w * 0.12, high, depth), 0.019, _white_steel)

func _border(rect: Rect2, depth: float, thickness: float, material: Material) -> void:
	for x in [rect.position.x, rect.end.x]:
		_box(Vector3(x, rect.get_center().y, depth), Vector3(thickness, rect.size.y, thickness), material)
	for y in [rect.position.y, rect.end.y]:
		_box(Vector3(rect.get_center().x, y, depth), Vector3(rect.size.x, thickness, thickness), material)

func _ground(grass: MeshInstance3D) -> void:
	_walkable_box(Vector3(9.0, 0.10, 0.91), Vector3(18.5, 0.20, 1.82), _stone)
	_walkable_box(Vector3(9.0, 0.065, 3.10), Vector3(18.5, 0.13, 2.56), _lawn)
	_walkable_box(Vector3(9.0, 0.018, 7.32), Vector3(21.5, 0.036, 5.86), _asphalt)
	for i in range(14):
		_box(Vector3(0.41 + i * 1.32, 0.092, 4.39),
			Vector3(1.318, 0.17, 0.16), _blue if i % 2 == 0 else _white_steel)
	for i in range(19):
		_box(Vector3(i, 0.201, 1.08), Vector3(0.011, 0.002, 1.46), _reveal)
	if grass:
		var blades := MeshInstance3D.new()
		blades.name = "Rear verge grass"
		blades.mesh = grass.mesh
		blades.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in range(grass.mesh.get_surface_count()):
			blades.set_surface_override_material(surface, grass.get_active_material(surface))
		var orientation := Basis(Vector3.UP, PI * 0.5) * grass.global_basis
		var bounds := Transform3D(orientation, Vector3.ZERO) * blades.mesh.get_aabb()
		var stretch := Vector3(18.2 / bounds.size.x, 1.28, 2.44 / bounds.size.z)
		blades.basis = orientation.scaled(stretch)
		var bottom := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		blades.position = Vector3(9.0, 0.13, 3.10) - bottom * stretch
		add_child(blades)

func _tree() -> void:
	var trunk := Vector3(7.1, 0.13, 3.53)
	var bark := _finish("77796a")
	var foliage := [_finish("50542a"), _finish("67672f"), _finish("7c7437"), _finish("928151")]
	for material: StandardMaterial3D in foliage:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var leaf := SurfaceTool.new()
	leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := [
		Vector3(0, -0.48, 0), Vector3(-0.36, -0.21, 0), Vector3(-0.20, -0.08, 0),
		Vector3(-0.47, 0.22, 0), Vector3(-0.17, 0.18, 0), Vector3(0, 0.52, 0),
		Vector3(0.20, 0.19, 0), Vector3(0.43, 0.26, 0), Vector3(0.22, -0.08, 0), Vector3(0.33, -0.24, 0),
	]
	for i in range(outline.size()):
		leaf.add_vertex(Vector3(0, 0, 0.10))
		leaf.add_vertex(outline[i])
		leaf.add_vertex(outline[(i + 1) % outline.size()])
	leaf.generate_normals()
	var leaf_mesh := leaf.commit()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7803
	var crown := trunk + Vector3(0.12, 4.75, -0.09)
	_rod(trunk, trunk + Vector3(0.03, 2.8, 0.03), 0.15, bark)
	_rod(trunk + Vector3(0.03, 2.8, 0.03), crown, 0.095, bark)
	for i in range(24):
		var level := float(i) / 23.0
		var angle := i * 2.4
		var spread := sin(lerpf(0.42, 2.97, level)) * rng.randf_range(1.14, 2.05)
		var base := trunk.lerp(crown, lerpf(0.45, 0.96, level))
		var tip := base + Vector3(cos(angle) * spread, rng.randf_range(0.50, 0.94), sin(angle) * spread * 0.8)
		_rod(base, tip, lerpf(0.064, 0.021, level), bark)
		for twig in range(4):
			var twig_base := base.lerp(tip, lerpf(0.48, 0.91, twig / 3.0))
			var cluster := twig_base + Vector3(rng.randf_range(-0.47, 0.47), rng.randf_range(0.28, 0.63), rng.randf_range(-0.45, 0.45))
			_rod(twig_base, cluster, 0.016, bark)
			for j in range(23):
				var jitter := Vector3(rng.randfn(0.0, 0.21), rng.randfn(0.0, 0.20), rng.randfn(0.0, 0.22)).limit_length(0.53)
				var rotation := Basis.from_euler(Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-PI, PI), rng.randf_range(-1.5, 1.5)))
				var size := rng.randf_range(0.12, 0.29)
				_surface(foliage[rng.randi_range(0, 3)]).append_from(leaf_mesh, 0,
					Transform3D(rotation.scaled(Vector3.ONE * size), cluster + jitter))

func _steps() -> void:
	var foot := 3.89
	var top := 5.61
	var front := 1.67
	var back := 0.58
	for i in range(5):
		var rise := 0.20 + (i + 1) * 0.15
		var length := (top - foot) / 5.0
		_walkable_box(Vector3(foot + (i + 0.5) * length, rise * 0.5, (front + back) * 0.5),
			Vector3(length, rise, front - back), _stone)
	_walkable_box(Vector3(6.35, 0.475, (front + back) * 0.5), Vector3(1.48, 0.95, front - back), _stone)
	for z in [back, front]:
		for x in [foot, top, 7.09]:
			var y := 0.20 if x == foot else 0.95
			_rod(Vector3(x, y, z), Vector3(x, y + 0.90, z), 0.045, _white_steel)
		for height in [0.25, 0.53, 0.90]:
			_rod(Vector3(foot, 0.20 + height, z), Vector3(top, 0.95 + height, z), 0.035, _white_steel)
			_rod(Vector3(top, 0.95 + height, z), Vector3(7.09, 0.95 + height, z), 0.035, _white_steel)
		_rod(Vector3(top, 1.14, z), Vector3(7.09, 1.82, z), 0.025, _white_steel)
		_rod(Vector3(top, 1.82, z), Vector3(7.09, 1.14, z), 0.025, _white_steel)
	_rod(Vector3(7.09, 1.85, back), Vector3(7.09, 1.85, front), 0.04, _white_steel)

func _bicycle() -> void:
	var tire := _finish("23292a")
	var rim := _finish("798384", 0.55)
	var paint := _finish("2c414c", 0.4)
	var axle_left := Vector3(14.49, 0.55, 0.88)
	var axle_right := axle_left + Vector3(1.09, 0.0, 0.0)
	var pedal := axle_left + Vector3(0.48, -0.05, 0.0)
	var seat := axle_left + Vector3(0.37, 0.60, -0.04)
	var fork := axle_right + Vector3(-0.18, 0.56, -0.06)
	for axle in [axle_left, axle_right]:
		var wheel := TorusMesh.new()
		wheel.inner_radius = 0.302
		wheel.outer_radius = 0.35
		wheel.rings = 28
		wheel.ring_segments = 8
		_surface(tire).append_from(wheel, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), axle))
		for spoke in range(12):
			var angle := spoke * TAU / 12.0
			_rod(axle, axle + Vector3(cos(angle), sin(angle), 0.0) * 0.31, 0.006, rim)
	for segment in [[axle_left, seat], [axle_left, pedal], [pedal, seat], [seat, fork], [pedal, fork], [fork, axle_right]]:
		_rod(segment[0], segment[1], 0.035, paint)
	_box(seat + Vector3(-0.025, 0.025, 0.0), Vector3(0.23, 0.04, 0.12), tire)
	_rod(fork, fork + Vector3(0.02, 0.13, 0.0), 0.026, rim)
	_rod(fork + Vector3(0.02, 0.13, -0.23), fork + Vector3(0.02, 0.13, 0.23), 0.032, tire)

func _walkable_box(center: Vector3, size: Vector3, material: Material) -> void:
	_box(center, size, material)
	_collision_box(center, size)

func _collision_box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	body.position = center
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _box(center: Vector3, size: Vector3, material: Material) -> void:
	_surface(material).append_from(_cube, 0, Transform3D(Basis.from_scale(size), center))

func _rod(start: Vector3, end: Vector3, width: float, material: Material) -> void:
	var direction := end - start
	var along := direction.normalized()
	var reference := Vector3.UP if absf(along.z) > 0.9 else Vector3.FORWARD
	var right := along.cross(reference).normalized()
	_surface(material).append_from(_tube, 0, Transform3D(
		Basis(right * width, direction, right.cross(along) * width), (start + end) * 0.5))

func _surface(material: Material) -> SurfaceTool:
	if not _surfaces.has(material):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(material)
		_surfaces[material] = surface
	return _surfaces[material]

static func _finish(color: String, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.metallic = metallic
	material.roughness = 0.78
	return material
