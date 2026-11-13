extends Node3D
## Photo-matched south elevation of the auditorium, measured from its east corner.

const WALL_NAME := "E rear perimeter"
const COURSE := 0.115
const SIDE_CLADDING := 0.1575
const LEFT_BAY := Vector2(1.52, 2.94)
const RIGHT_BAY := Vector2(16.28, 17.74)
const WING_HEIGHT := 3.14
const WING_DEPTH := 1.30
const WING_RADIUS := 0.42

var _batches: Dictionary = {}
var _cube := BoxMesh.new()
var _round := CylinderMesh.new()
var _gravel := SphereMesh.new()
var _random := RandomNumberGenerator.new()
var _joint := _material("8d9187")
var _masonry := [_material("b7b9af"), _material("bfc0b6"), _material("b3b6ae")]
var _concrete := _material("c7b9a3")
var _infill := _material("c4c2b8")
var _walk := _material("bcb19e")
var _shadow := _material("252c2c")
var _wood := _material("92633f")
var _door_panel := _material("aa7950")
var _steel := _material("e5e4da", 0.25)
var _soil := _material("514b39")
var _grass := _material("647342")
var _gravel_light := _material("dfdcd0")
var _gravel_dark := _material("4a4e47")
var _bark := _material("635d46")
var _cactus := _material("47603e")
var _leaves := [_material("566c39"), _material("697e43"), _material("829455")]

static func install(campus: Node3D) -> void:
	for mesh: MeshInstance3D in campus.mesh_nodes:
		if str(mesh.get_meta("campus_source_name", "")) != WALL_NAME:
			continue
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		var facade := new()
		facade.name = "AuditoriumRearFacade"
		campus.add_child(facade)
		facade.global_position = Vector3(bounds.end.x, 0, bounds.position.z)
		facade.global_rotation.y = PI
		facade._build(bounds.size.x, bounds.end.y)
		return

func _build(width: float, top: float) -> void:
	_random.seed = 202601
	_round.top_radius = 0.5
	_round.bottom_radius = 0.5
	_round.height = 1.0
	_round.radial_segments = 8
	_round.rings = 1
	_gravel.radius = 0.5
	_gravel.height = 1.0
	_gravel.radial_segments = 6
	_gravel.rings = 3
	_texture(_concrete, "mineral", Vector3(0.9, 0.36, 0.9))
	_texture(_walk, "limestone", Vector3.ONE * 1.1)
	_texture(_wood, "wood", Vector3(1.3, 0.65, 1.3))
	_texture(_door_panel, "wood", Vector3(1.3, 0.65, 1.3))
	_texture(_grass, "lawn", Vector3.ONE * 1.8)
	for leaf: StandardMaterial3D in _leaves:
		leaf.cull_mode = BaseMaterial3D.CULL_DISABLED

	_clad_wall(width, top)
	_service_bays(width, top)
	_service_wing()
	_landscape(width)

	for material: Material in _batches:
		var mesh := MeshInstance3D.new()
		mesh.mesh = (_batches[material] as SurfaceTool).commit()
		add_child(mesh)
	_batches.clear()

func _clad_wall(width: float, top: float) -> void:
	var base := 0.20
	var roof_line := top - 0.22
	_box(Vector3(width * 0.5, (base + roof_line) * 0.5, 0.011),
		Vector3(width + 2.0 * SIDE_CLADDING, roof_line - base, 0.022), _joint)
	var courses := floori((roof_line - base) / COURSE)
	for row in range(courses):
		var y := base + (row + 0.5) * COURSE
		var height := COURSE - 0.005
		var left_edge := -SIDE_CLADDING
		if row == 38:
			_course(left_edge, 0.57, y, height, row)
			_box(Vector3(0.82, y, 0.046), Vector3(0.50, height, 0.045), _shadow)
			left_edge = 1.07
		_course(left_edge, LEFT_BAY.x, y, height, row)
		_course(LEFT_BAY.y, RIGHT_BAY.x, y, height, row)
		_course(RIGHT_BAY.y, width + SIDE_CLADDING, y, height, row)

func _course(left: float, right: float, y: float, height: float, row: int) -> void:
	var x := left
	var block := 0
	while x < right - 0.006:
		var length := minf(right - x, 0.82 if block == 0 and row % 2 == 0 else 1.63)
		var tint: StandardMaterial3D = _masonry[(row + block * 7) % _masonry.size()]
		_box(Vector3(x + length * 0.5, y, 0.096),
			Vector3(length - 0.006, height, 0.182), tint)
		x += length
		block += 1

func _service_bays(width: float, top: float) -> void:
	var roof_line := top - 0.22
	for bay: Vector2 in [LEFT_BAY, RIGHT_BAY]:
		var x := (bay.x + bay.y) * 0.5
		_box(Vector3(x, (roof_line + 0.20) * 0.5, 0.033),
			Vector3(bay.y - bay.x, roof_line - 0.20, 0.026), _shadow)
		_door(x, 0.45, 0.067)
		_box(Vector3(x, 0.33, 0.65), Vector3(bay.y - bay.x, 0.24, 1.30), _walk, true)

	# Both bands meet the existing side plinths.
	_planter(Vector2(-0.40, 2.48), 0.90)
	_planter(Vector2(17.46, width + 0.40), 1.21)

func _planter(span: Vector2, face: float) -> void:
	var x := (span.x + span.y) * 0.5
	var width := span.y - span.x
	_box(Vector3(x, 0.70, (face - 0.25) * 0.5), Vector3(width - 0.14, 1.02, face - 0.25), _joint, true)
	for row in range(8):
		_box(Vector3(x, 0.25 + (row + 0.5) * 0.12, face - 0.25),
			Vector3(width - 0.14, 0.114, 0.035), _masonry[row % 3])
	_box(Vector3(x, 1.43, (face - 0.17) * 0.5), Vector3(width, 0.43, face + 0.17), _concrete, true)
	_box(Vector3(x, 1.65, face * 0.45), Vector3(width - 0.25, 0.02, face - 0.19), _soil)
	for offset in [-0.52, 0.52]:
		_yucca(Vector3(x + offset, 1.66, face * 0.45), 0.62)

func _service_wing() -> void:
	var left := LEFT_BAY.y
	var right := RIGHT_BAY.x
	var vent_left := 6.62
	var vent_right := 14.89
	var vent_bottom := 1.61
	var vent_top := 2.29
	var shoulder := WING_HEIGHT - WING_RADIUS
	var bottom := 0.20
	var face_depth := 0.20
	var face_z := WING_DEPTH - face_depth * 0.5
	_box(Vector3((left + right) * 0.5, (bottom + vent_bottom) * 0.5, face_z),
		Vector3(right - left, vent_bottom - bottom, face_depth), _concrete)
	_box(Vector3((left + right) * 0.5, (vent_top + shoulder) * 0.5, face_z),
		Vector3(right - left, shoulder - vent_top, face_depth), _concrete)
	for section in [Vector2(left, vent_left), Vector2(vent_right, right)]:
		_box(Vector3((section.x + section.y) * 0.5, (vent_bottom + vent_top) * 0.5, face_z),
			Vector3(section.y - section.x, vent_top - vent_bottom, face_depth), _concrete)
	_box(Vector3((vent_left + vent_right) * 0.5, (vent_bottom + vent_top) * 0.5, WING_DEPTH - 0.28),
		Vector3(vent_right - vent_left, vent_top - vent_bottom, 0.06), _shadow)
	var slat := _material("52463e")
	for i in range(85):
		var x := lerpf(vent_left + 0.05, vent_right - 0.05, i / 84.0)
		_box(Vector3(x, (vent_bottom + vent_top) * 0.5, WING_DEPTH - 0.16),
			Vector3(0.039, vent_top - vent_bottom, 0.11), slat)
	for x in [4.80, 8.85, 12.74, 15.56]:
		_box(Vector3(x, (vent_top + shoulder) * 0.5, WING_DEPTH),
			Vector3(0.009, shoulder - vent_top, 0.004), _joint)
		_box(Vector3(x, (bottom + vent_bottom) * 0.5, WING_DEPTH),
			Vector3(0.009, vent_bottom - bottom, 0.004), _joint)

	# One low roof profile across the wing. The rounded shoulder also defines the end panels.
	var outline := PackedVector2Array([Vector2(0.10, bottom), Vector2(WING_DEPTH, bottom)])
	for i in range(13):
		var angle := i * PI / 24.0
		outline.append(Vector2(WING_DEPTH - WING_RADIUS + cos(angle) * WING_RADIUS,
			shoulder + sin(angle) * WING_RADIUS))
	outline.append(Vector2(0.10, WING_HEIGHT))
	for i in range(2, outline.size() - 1):
		var a := outline[i]
		var b := outline[i + 1]
		var normal := Vector3(0.0, a.x - b.x, b.y - a.y).normalized()
		_triangle(_concrete, Vector3(left, a.y, a.x), Vector3(left, b.y, b.x),
			Vector3(right, b.y, b.x), normal)
		_triangle(_concrete, Vector3(left, a.y, a.x), Vector3(right, b.y, b.x),
			Vector3(right, a.y, a.x), normal)
	for i in range(1, outline.size() - 1):
		var origin := outline[0]
		var a := outline[i]
		var b := outline[i + 1]
		_triangle(_concrete, Vector3(left, origin.y, origin.x), Vector3(left, a.y, a.x),
			Vector3(left, b.y, b.x), Vector3.LEFT)
		_triangle(_infill, Vector3(right, origin.y, origin.x), Vector3(right, b.y, b.x),
			Vector3(right, a.y, a.x), Vector3.RIGHT)

	# The cream edge follows the front and roof around the pale return panel.
	var rim_x := right + 0.003
	var inside := PackedVector2Array([outline[1] - Vector2(0.12, 0)])
	var center := Vector2(WING_DEPTH - WING_RADIUS, shoulder)
	for i in range(2, outline.size() - 1):
		inside.append(outline[i] - (outline[i] - center).normalized() * 0.12)
	inside.append(outline[-1] - Vector2(0, 0.12))
	for i in range(inside.size() - 1):
		var a := outline[i + 1]
		var b := outline[i + 2]
		var inner_a := inside[i]
		var inner_b := inside[i + 1]
		_triangle(_concrete, Vector3(rim_x, a.y, a.x), Vector3(rim_x, inner_a.y, inner_a.x),
			Vector3(rim_x, inner_b.y, inner_b.x), Vector3.RIGHT)
		_triangle(_concrete, Vector3(rim_x, a.y, a.x), Vector3(rim_x, inner_b.y, inner_b.x),
			Vector3(rim_x, b.y, b.x), Vector3.RIGHT)

	var body := StaticBody3D.new()
	body.name = "ServiceWingCollision"
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for point in outline:
		points.append(Vector3(left, point.y, point.x))
		points.append(Vector3(right, point.y, point.x))
	shape.points = points
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _triangle(material: Material, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var surface := _surface(material)
	# Godot expects clockwise front faces.
	if (c - a).cross(b - a).dot(normal) < 0.0:
		var swap := b
		b = c
		c = swap
	for vertex in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)

func _door(x: float, floor: float, depth: float) -> void:
	var center := Vector3(x, floor + 1.02, depth)
	_box(center, Vector3(0.99, 2.10, 0.08), _shadow)
	_box(center + Vector3(0.0, 0.0, 0.052), Vector3(0.86, 1.99, 0.045), _wood)
	for y in [-0.50, 0.47]:
		_box(center + Vector3(0.0, y, 0.078), Vector3(0.69, 0.88, 0.012), _door_panel)
	_box(center + Vector3(0.31, -0.03, 0.102), Vector3(0.097, 0.025, 0.035), _steel)

func _landscape(width: float) -> void:
	_box(Vector3(width * 0.5, 0.115, 1.63), Vector3(width + 0.20, 0.17, 1.43), _walk, true)
	_box(Vector3(width * 0.5, 0.135, 3.53), Vector3(width + 0.25, 0.19, 2.38), _grass, true)
	_box(Vector3(width * 0.5, 0.20, 4.70), Vector3(width + 0.25, 0.20, 0.13), _concrete, true)
	for x in range(1, int(width)):
		_box(Vector3(x, 0.202, 1.67), Vector3(0.012, 0.004, 1.34), _joint)
	_gravel_bed(3.85, 3.50)
	_gravel_bed(18.52, 2.60)
	_cacti(Vector3(3.47, 0.24, 3.35), 1.30)
	_cacti(Vector3(18.26, 0.24, 3.59), 1.17)
	for point in [Vector3(2.15, 0.24, 3.58), Vector3(5.10, 0.24, 3.18),
		Vector3(10.80, 0.24, 3.35), Vector3(13.72, 0.24, 3.68), Vector3(19.45, 0.24, 3.42)]:
		_yucca(point, _random.randf_range(0.64, 1.04))
	for pair in [Vector2(1.10, 3.79), Vector2(5.65, 3.57), Vector2(11.80, 4.12)]:
		_tree(Vector3(pair.x, 0.24, pair.y), _random.randf_range(2.75, 3.82))
	for i in range(440):
		var x := _random.randf_range(0.06, width - 0.06)
		var z := _random.randf_range(3.98, 4.59)
		var point := Vector3(x, 0.23, z)
		_leaf(point, point + Vector3(_random.randf_range(-0.08, 0.08), _random.randf_range(0.055, 0.15), 0.01),
			0.026, _leaves[i % 3])

func _gravel_bed(x: float, width: float) -> void:
	_box(Vector3(x, 0.235, 3.47), Vector3(width, 0.024, 0.97), _gravel_dark)
	for i in range(94):
		var z := _random.randf_range(-0.44, 0.44)
		var size := _random.randf_range(0.038, 0.092)
		_surface(_gravel_light if absf(z) > 0.29 or i % 7 == 0 else _gravel_dark).append_from(
			_gravel, 0, Transform3D(Basis.from_scale(Vector3(size, size * 0.50, size * 0.85)),
				Vector3(x + _random.randf_range(-width / 2.0, width / 2.0), 0.259, 3.47 + z)))

func _yucca(base: Vector3, size: float) -> void:
	var crown := base + Vector3.UP * (size * 0.43)
	_rod(base, crown, size * 0.16, _bark)
	for i in range(22):
		var angle := i * 2.4
		var width := _random.randf_range(0.22, 0.52) * size
		var tip := crown + Vector3(cos(angle) * width, _random.randf_range(0.15, 0.65) * size, sin(angle) * width)
		_leaf(crown, tip, size * 0.075, _leaves[i % 3])

func _cacti(base: Vector3, size: float) -> void:
	_rod(base, base + Vector3.UP * size, size * 0.10, _cactus)
	for side in [-1.0, 1.0]:
		var join := base + Vector3.UP * (size * (0.46 if side < 0 else 0.61))
		var bend := join + Vector3(side * size * 0.24, size * 0.12, 0)
		_rod(join, bend, size * 0.075, _cactus)
		_rod(bend, bend + Vector3.UP * size * 0.29, size * 0.073, _cactus)

func _tree(base: Vector3, height: float) -> void:
	var fork := base + Vector3(0.08, height * 0.61, -0.06)
	_rod(base, fork, 0.092, _bark)
	_rod(fork, base + Vector3.UP * height * 0.9, 0.057, _bark)
	for i in range(11):
		var angle := i * 2.4
		var spread := _random.randf_range(0.38, 0.93)
		var tip := base + Vector3(cos(angle) * spread, height * _random.randf_range(0.68, 1.00), sin(angle) * spread)
		_rod(fork.lerp(base, _random.randf_range(0.0, 0.28)), tip, 0.025, _bark)
		for j in range(40):
			var start := tip + Vector3(_random.randfn(0, 0.22), _random.randfn(0, 0.20), _random.randfn(0, 0.22))
			var end := start + Vector3(_random.randf_range(-0.26, 0.26), _random.randf_range(-0.09, 0.13), _random.randf_range(-0.25, 0.25))
			_leaf(start, end, _random.randf_range(0.064, 0.142), _leaves[(i + j) % 3])

func _leaf(start: Vector3, tip: Vector3, width: float, material: Material) -> void:
	var side := (tip - start).cross(Vector3.UP).normalized() * width
	var mid := start.lerp(tip, 0.43)
	var ridge := mid + Vector3.UP * width * 0.30
	var surface := _surface(material)
	for triangle in [[start, mid - side, ridge], [start, ridge, mid + side],
		[ridge, mid - side, tip], [ridge, tip, mid + side]]:
		var normal: Vector3 = (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).normalized()
		for vertex: Vector3 in triangle:
			surface.set_normal(normal)
			surface.add_vertex(vertex)

func _box(center: Vector3, dimensions: Vector3, material: Material, solid: bool = false) -> void:
	_surface(material).append_from(_cube, 0, Transform3D(Basis.from_scale(dimensions), center))
	if solid:
		var body := StaticBody3D.new()
		body.position = center
		body.collision_mask = 0
		add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		body.add_child(collision)

func _rod(start: Vector3, end: Vector3, width: float, material: Material) -> void:
	var line := end - start
	var up := line.normalized()
	var cross := up.cross(Vector3.RIGHT if absf(up.z) > 0.90 else Vector3.FORWARD).normalized()
	_surface(material).append_from(_round, 0, Transform3D(Basis(cross * width, line,
		cross.cross(up) * width), (start + end) * 0.5))

func _surface(material: Material) -> SurfaceTool:
	if not _batches.has(material):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(material)
		_batches[material] = surface
	return _batches[material]

static func _material(hex: String, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.metallic = metallic
	material.roughness = 0.91
	return material

func _texture(material: StandardMaterial3D, kind: String, scale: Vector3) -> void:
	material.albedo_texture = load("res://assets/runtime_surfaces/%s_albedo.png" % kind) as Texture2D
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
