extends RefCounted
## Photo reference detail for the east elevation of the D teaching block.

const WALL_X := 5.07
const REAR := -140.0
const FRONT := -104.0

var root: Node3D
var batches: Dictionary = {}
var finish: Material
var trim: StandardMaterial3D
var frame: StandardMaterial3D
var glazing: StandardMaterial3D
var glazing_light: StandardMaterial3D
var grille: StandardMaterial3D
var casework: StandardMaterial3D
var stone: Material
var disc := CylinderMesh.new()
var cube := BoxMesh.new()

static func install(campus: Node3D) -> void:
	var wall: MeshInstance3D
	var landing: MeshInstance3D
	for mesh: MeshInstance3D in campus.mesh_nodes:
		match str(mesh.get_meta("campus_source_name", "")):
			"D7 rear building wall": wall = mesh
			"D7 main entrance level landing": landing = mesh
	if not is_instance_valid(wall) or not is_instance_valid(landing):
		return
	var detail = new()
	detail.build(campus, wall, landing)

func build(campus: Node3D, wall: MeshInstance3D, landing: MeshInstance3D) -> void:
	root = Node3D.new()
	root.name = "GlazedSideFacade"
	campus.add_child(root)
	finish = wall.get_active_material(0)
	stone = landing.get_active_material(0)
	trim = _material("Warm concrete surrounds", "d2cbbc")
	frame = _material("Dark aluminium frames", "26333b", 0.48)
	glazing = _material("Recessed blue-grey glazing", "223543", 0.27)
	glazing_light = _material("Blue-grey glazing with interior blinds", "394e5a", 0.32)
	grille = _material("Painted steel grilles", "b1b4ae", 0.45)
	casework = _material("Powder coated equipment", "aaa89c")
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 1.0
	disc.radial_segments = 20

	# Retain the inside wall face and its existing collision. The exterior
	# replacement is segmented around the actual window reveals.
	wall.hide()
	_box(Vector3(4.88, 6.04, -122), Vector3(0.06, 11.25, 36), finish)
	var rows: Array[Dictionary] = [
		{"low":0.66,"high":1.48,"spans":[Vector2(-138.0,-133.5), Vector2(-130.8,-126.0), Vector2(-123.7,-113.0), Vector2(-110.5,-109.3)],"security":true},
		{"low":2.67,"high":3.98,"spans":[Vector2(-138.0,-133.5), Vector2(-130.8,-126.0), Vector2(-123.7,-113.0), Vector2(-111.7,-110.5), Vector2(-109.8,-108.6)],"security":true},
		{"low":5.95,"high":6.97,"spans":[Vector2(-138.0,-133.5), Vector2(-130.8,-126.0), Vector2(-123.7,-113.0), Vector2(-111.7,-110.5), Vector2(-109.8,-108.6)],"security":false},
		{"low":9.64,"high":10.72,"spans":[Vector2(-138.0,-133.5), Vector2(-130.8,-126.0), Vector2(-123.7,-113.25)],"security":false},
	]
	var bottom := 0.415
	for row in rows:
		_wall_panel(bottom, row.low, REAR, FRONT)
		var start := REAR
		for span: Vector2 in row.spans:
			_wall_panel(row.low, row.high, start, span.x)
			_window(4.97, row.low, row.high, span, row.security)
			start = span.y
		_wall_panel(row.low, row.high, start, FRONT)
		bottom = row.high
	_wall_panel(bottom, 11.665, REAR, FRONT)
	for height in [4.88, 11.38]:
		_box(Vector3(5.14, height, -123.2), Vector3(0.32, 0.29, 33.6), trim)
	for z in [-139.7, -132.25, -124.9, -112.9]:
		_box(Vector3(5.12, 8.26, z), Vector3(0.15, 6.03, 0.32), finish)
	_projecting_upper_window()
	_portico_details()
	for z in [-112.0, -110.94, -109.88]:
		_ac_unit(2.18, z)
	_ac_unit(5.49, -111.13)
	_service_cabinet()
	_side_steps()
	_flush()

func _wall_panel(low: float, high: float, start: float, end: float) -> void:
	if end <= start or high <= low:
		return
	_box(Vector3(4.99, (low + high) * 0.5, (start + end) * 0.5),
		Vector3(0.16, high - low, end - start), finish)

func _window(x: float, low: float, high: float, span: Vector2, security: bool, mount := Transform3D.IDENTITY) -> void:
	var width := span.y - span.x
	var height := high - low
	var y := (low + high) * 0.5
	var z := (span.x + span.y) * 0.5
	var count := maxi(1, roundi(width / 0.71))
	var pitch := width / count
	for index in range(count):
		var pane_z := span.x + (index + 0.5) * pitch
		var glass: Material = glazing_light if index % 4 == 1 or index % 4 == 2 else glazing
		_box(Vector3(x, y, pane_z), Vector3(0.025, height - 0.055, pitch - 0.035), glass, mount)
	for index in range(count + 1):
		_box(Vector3(x + 0.02, y, span.x + index * pitch), Vector3(0.052, height, 0.038), frame, mount)
	for edge in [low, high]:
		_box(Vector3(x + 0.02, edge, z), Vector3(0.052, 0.05, width), frame, mount)
	if security:
		_security_grille(WALL_X + 0.058, low + 0.045, high - 0.045, span)

func _security_grille(x: float, low: float, high: float, span: Vector2) -> void:
	var width := span.y - span.x
	var height := high - low
	for edge in [low, high]:
		_box(Vector3(x, edge, (span.x + span.y) * 0.5), Vector3(0.035, 0.024, width), grille)
	for edge in [span.x, span.y]:
		_box(Vector3(x, (low + high) * 0.5, edge), Vector3(0.035, height, 0.024), grille)
	# Clip both diagonal families to the inside of the rectangular grille.
	var spacing := 0.24
	for index in range(ceili((width + height) / spacing) + 1):
		var start := index * spacing - height
		var a := maxf(0.0, -start)
		var b := minf(height, width - start)
		if b <= a:
			continue
		var z0 := span.x + start + a
		var z1 := span.x + start + b
		_rod(Vector3(x, low + a, z0), Vector3(x, low + b, z1), 0.015, grille)
		_rod(Vector3(x, high - a, z0), Vector3(x, high - b, z1), 0.015, grille)

func _projecting_upper_window() -> void:
	# The cantilever's east face slopes out by 1.1 m from base to roof.
	var slope := Basis(Vector3.BACK, -atan2(1.1, 3.8))
	var mount := Transform3D(slope, Vector3(5.20, 8.14, 0.0))
	var span := Vector2(-107.24, -102.86)
	_window(0.031, 1.72, 2.76, span, false, mount)
	for edge in [1.62, 2.86]:
		_box(Vector3(0.10, edge, -105.05), Vector3(0.18, 0.20, 4.78), trim, mount)
	for edge in [-107.35, -102.75]:
		_box(Vector3(0.10, 2.24, edge), Vector3(0.18, 1.07, 0.22), trim, mount)

func _portico_details() -> void:
	# Low solid balcony apron with the original steel rails above it.
	_box(Vector3(1.67, 5.18, -102.75), Vector3(7.73, 0.46, 0.18), finish)
	_box(Vector3(5.54, 5.18, -105.07), Vector3(0.18, 0.46, 4.64), finish)
	for height in [8.12, 4.87]:
		for x in [0.55, 3.65]:
			_box(Vector3(x, height - 0.012, -104.73), Vector3(0.41, 0.028, 0.41), frame)
			_box(Vector3(x, height - 0.029, -104.73), Vector3(0.34, 0.012, 0.34), casework)

func _ac_unit(y: float, z: float) -> void:
	_box(Vector3(5.28, y, z), Vector3(0.35, 0.54, 0.82), casework)
	_box(Vector3(5.464, y, z), Vector3(0.025, 0.475, 0.75), trim)
	var face := Basis(Vector3.BACK, PI * 0.5)
	_stamp(disc, Vector3(5.487, y, z - 0.10), Vector3(0.40, 0.025, 0.40), frame, face)
	_stamp(disc, Vector3(5.505, y, z - 0.10), Vector3(0.10, 0.018, 0.10), casework, face)
	for index in range(7):
		_box(Vector3(5.512, y + (index - 3) * 0.042, z - 0.10), Vector3(0.018, 0.014, 0.31), grille)
	for index in range(5):
		_box(Vector3(5.483, y + (index - 2) * 0.075, z + 0.26), Vector3(0.015, 0.026, 0.14), frame)
	for edge in [-0.28, 0.28]:
		_box(Vector3(5.27, y - 0.30, z + edge), Vector3(0.45, 0.05, 0.045), frame)
		_rod(Vector3(5.10, y - 0.48, z + edge), Vector3(5.43, y - 0.30, z + edge), 0.032, frame)

func _side_steps() -> void:
	const COUNT := 9
	const START := 7.15
	const TOP := 1.8
	const GROUND := 0.31
	const RUN := 0.29
	const Z := -103.27
	const WIDTH := 1.19
	var body := StaticBody3D.new()
	body.name = "SideStairCollision"
	root.add_child(body)
	for index in range(COUNT):
		var height := lerpf(TOP, GROUND, float(index + 1) / (COUNT + 1))
		var size := Vector3(RUN, height - GROUND, WIDTH)
		var position := Vector3(START + (index + 0.5) * RUN, (height + GROUND) * 0.5, Z)
		_box(position, size, stone)
		var tread := BoxShape3D.new()
		tread.size = size
		var collider := CollisionShape3D.new()
		collider.shape = tread
		collider.position = position
		body.add_child(collider)
		_box(Vector3(position.x + RUN * 0.5 - 0.012, height + 0.004, Z), Vector3(0.024, 0.012, WIDTH), trim)
	for z in [Z - WIDTH * 0.46, Z + WIDTH * 0.46]:
		var top := Vector3(START - 0.04, TOP, z)
		var foot := Vector3(START + COUNT * RUN, GROUND + 0.15, z)
		for index in range(5):
			var base := top.lerp(foot, index / 4.0)
			_rod(base, base + Vector3.UP * 0.96, 0.036, grille)
		for height in [0.18, 0.48, 0.94]:
			_rod(top + Vector3.UP * height, foot + Vector3.UP * height, 0.029, grille)
		for index in range(4):
			var a := top.lerp(foot, index / 4.0)
			var b := top.lerp(foot, (index + 1) / 4.0)
			_rod(a + Vector3.UP * 0.19, b + Vector3.UP * 0.72, 0.021, grille)
			_rod(a + Vector3.UP * 0.72, b + Vector3.UP * 0.19, 0.021, grille)

func _service_cabinet() -> void:
	var housing := _material("Dark utility cabinet", "303b36")
	var access := _material("Red utility access panel", "774035")
	_box(Vector3(6.03, 0.91, -117.2), Vector3(0.64, 1.08, 1.82), housing)
	_box(Vector3(6.03, 0.35, -117.2), Vector3(0.72, 0.12, 1.9), trim)
	_box(Vector3(6.03, 1.47, -117.2), Vector3(0.70, 0.06, 1.88), housing)
	_box(Vector3(6.36, 0.93, -116.88), Vector3(0.028, 0.72, 0.55), access)
	_box(Vector3(6.38, 0.93, -117.08), Vector3(0.024, 0.12, 0.027), grille)

func _box(position: Vector3, size: Vector3, material: Material, mount := Transform3D.IDENTITY) -> void:
	_stamp(cube, position, size, material, Basis.IDENTITY, mount)

func _rod(a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var delta := b - a
	var basis := Basis(Quaternion(Vector3.UP, delta.normalized()))
	_stamp(cube, (a + b) * 0.5, Vector3(width, delta.length(), width), material, basis)

func _stamp(mesh: PrimitiveMesh, position: Vector3, size: Vector3, material: Material,
		basis := Basis.IDENTITY, mount := Transform3D.IDENTITY) -> void:
	var key := "%s:%s" % [mesh.get_instance_id(), material.get_instance_id()]
	if not batches.has(key):
		batches[key] = {"mesh": mesh, "material": material, "pieces": []}
	batches[key].pieces.append(mount * Transform3D(basis * Basis.from_scale(size), position))

func _flush() -> void:
	for batch in batches.values():
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = batch.mesh
		multimesh.instance_count = batch.pieces.size()
		for index in range(batch.pieces.size()):
			multimesh.set_instance_transform(index, batch.pieces[index])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = batch.material
		root.add_child(instance)

func _material(label: String, hex: String, roughness := 0.75) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = label
	material.albedo_color = Color(hex)
	material.roughness = roughness
	return material
