extends RefCounted
## Bounded R2 entrance repair. Install after source collisions, before render batching.

const FLOOR_Y := 0.52
const APPROACH_Y := 0.012
const STEP_RISE := (FLOOR_Y - APPROACH_Y) / 3.0
const REPLACED: Array[String] = [
	"Entrance step", "Entrance step.001", "Entrance step.002", "Entrance step.003",
	"Stair handrail", "Stair handrail.001", "Handrail upright", "Handrail upright.001",
	"Handrail upright.002", "Handrail upright.003"
]


static func install(campus_runtime: Node3D) -> Dictionary:
	if campus_runtime.has_meta("entrance_geometry_result"):
		return campus_runtime.get_meta("entrance_geometry_result")
	var originals: Dictionary = {}
	for node: MeshInstance3D in campus_runtime.get("mesh_nodes"):
		var source := str(node.get_meta("campus_source_name", ""))
		if source in REPLACED or source in ["Site base", "Main plinth", "Entry canopy", "Canopy square column", "Canopy square column.001"]:
			originals[source] = node
	for source: String in REPLACED:
		if not originals.has(source):
			return {"installed": false, "error": "Expected exact source mesh not found: " + source}
		if originals[source].has_meta("campus_render_batch"):
			return {"installed": false, "error": "Entrance repair must run before render batching."}
	var provenance: Array[Dictionary] = []
	for source: String in REPLACED:
		var node: MeshInstance3D = originals[source]
		provenance.append({"source_name": source, "source_bounds": node.global_transform * node.mesh.get_aabb()})
		node.hide()
		node.set_meta("entrance_geometry_replaced", true)
		_disable_collisions(node)
	var repair := Node3D.new()
	repair.name = "R2EntranceGeometry"
	repair.set_meta("provenance", "Runtime replacement of ten exact R2 entrance step/handrail meshes; source GLB unchanged")
	campus_runtime.add_child(repair)
	var paving: Material = originals["Site base"].get_active_material(0) if originals.has("Site base") else _material(Color("c9c3ad"), 0.9)
	var stone := _material(Color("d0cbb8"), 0.84)
	var metal := _material(Color("728187"), 0.34, 0.72)
	# Only this small approach patch overlays the source's world-wide Site base.
	# Its 12 mm finish avoids coincident surfaces and is a negligible boundary lip.
	_box(repair, "AlignedApproachPaving", Vector3(-17.1, -0.06, 3.947), Vector3(-10.9, APPROACH_Y, 5.70), paving)
	for index in 3:
		var top := APPROACH_Y + STEP_RISE * (index + 1)
		var near_z := 3.95 - 0.45 * (index + 1)
		_box(repair, "RegularStep%02d" % (index + 1), Vector3(-16.4, 0.0, near_z - 0.003), Vector3(-11.6, top, 3.953 - 0.45 * index), stone)
		_box(repair, "StepNosing%02d" % (index + 1), Vector3(-16.4, top - 0.008, near_z + 0.41), Vector3(-11.6, top + 0.001, near_z + 0.45), paving, false)
	# The original Main plinth already visibly supplies the interior floor at .52.
	# Bridge the actual bevel up to its flat-top edge, not merely the AABB front.
	# This avoids the source's 35 mm rounded drop at the entrance threshold.
	var flat_front := _front_flat_edge(originals["Main plinth"])
	_box(repair, "LevelEntranceLanding", Vector3(-16.4, 0.0, flat_front), Vector3(-11.6, FLOOR_Y, 2.603), paving)
	# The source is a bevelled 56-vertex plinth, not an assumed closed cube.
	# Its exact triangles support the entire unchanged visible interior floor.
	_support_source_plinth(repair, originals["Main plinth"])
	# Fill the original 20 cm gap below each unchanged column; neither source
	# pillar nor its footprint moves.
	for x: float in [-16.65, -11.35]:
		_box(repair, "CanopyColumnFoot", Vector3(x - 0.125, 0.0, 2.775), Vector3(x + 0.125, 0.20, 3.025), stone)
	for x: float in [-16.25, -11.75]:
		for point: Vector2 in [Vector2(3.77, APPROACH_Y + STEP_RISE), Vector2(3.32, APPROACH_Y + STEP_RISE * 2.0), Vector2(2.87, FLOOR_Y)]:
			_box(repair, "StairRailUpright", Vector3(x - 0.022, point.y, point.x - 0.022), Vector3(x + 0.022, point.y + 0.88, point.x + 0.022), metal)
		_beam(repair, "ContinuousHandrail", Vector3(x, APPROACH_Y + STEP_RISE + 0.90, 3.80), Vector3(x, FLOOR_Y + 0.90, 2.84), 0.047, metal)
	_finish_canopy(repair)
	var opening := {
		"center": Vector3(-14.0, (FLOOR_Y + 2.79) * 0.5, 0.10),
		"width": 4.40, "height": 2.79 - FLOOR_Y, "floor_y": FLOOR_Y,
		"outward": Vector3(0, 0, 1), "normal": Vector3(0, 0, 1), "right": Vector3(1, 0, 0),
		"source_glass_names": ["Entrance door glass", "Entrance door glass.001", "Entrance door glass.002", "Entrance door glass.003"],
		"source_recess_name": "Entrance dark recess", "source_glass_floor_y": 0.385,
		"source_lintel_bottom_y": 2.79
	}
	var result := {
		"installed": true, "root": repair, "door_opening": opening,
		"bounds": AABB(Vector3(-52.0, -0.06, -33.9), Vector3(56.0, 3.10, 39.6)),
		"visual_bounds": AABB(Vector3(-17.1, -0.06, -0.20), Vector3(6.2, 3.10, 5.9)),
		"support_bounds": originals["Main plinth"].global_transform * originals["Main plinth"].mesh.get_aabb(),
		"source_plinth_flat_front_z": flat_front,
		"floor_y": FLOOR_Y, "approach_y": APPROACH_Y, "step_rise": STEP_RISE,
		"step_run": 0.45, "step_count": 3, "replaced": provenance,
		"ramp": "No R2 ramp exists in the source. D7 switchback ramps are separate and unchanged.",
		"preserved": ["Main plinth", "Entry canopy", "Canopy square column", "Canopy square column.001", "all facade/window/fence/tree meshes"],
		"threshold_collision_provenance": "Exact source Main plinth triangle collider, including its original bevels and full x[-52,4], z[-33.9,.5] footprint. Existing visible surface unchanged; no duplicate rendered floor.",
		"reception_e_rightmost_bay": {"source_name": "E5 clear door or sidelight.003", "min": Vector3(-35.12, 1.03, -102.7925), "max": Vector3(-33.56, 3.65, -102.7675), "threshold_top_y": 0.9375, "outward": Vector3(0, 0, 1)}
	}
	campus_runtime.set_meta("entrance_geometry_result", result)
	return result


static func _disable_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_disable_collisions(child)


static func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


static func _box(parent: Node3D, label: String, low: Vector3, high: Vector3, material: Material, collision: bool = true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = high - low
	mesh.material = material
	node.mesh = mesh
	node.position = (high + low) * 0.5
	node.set_meta("campus_role", "walkable" if collision else "detail")
	node.set_meta("entrance_repair", true)
	parent.add_child(node)
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("campus_source_name", "R2 repaired " + label)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = mesh.size
		shape.shape = box
		body.add_child(shape)
		node.add_child(body)
	return node


static func _support_source_plinth(parent: Node3D, original: MeshInstance3D) -> void:
	var body := StaticBody3D.new()
	body.name = "ExactVisibleMainPlinthSupport"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("campus_source_name", "Main plinth / exact full visible floor support")
	body.set_meta("campus_role", "walkable")
	var shape := CollisionShape3D.new()
	var triangles := original.mesh.create_trimesh_shape()
	triangles.backface_collision = true
	shape.shape = triangles
	body.add_child(shape)
	parent.add_child(body)
	body.global_transform = original.global_transform


static func _front_flat_edge(original: MeshInstance3D) -> float:
	var edge := -INF
	for surface in original.mesh.get_surface_count():
		var vertices: PackedVector3Array = original.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var point: Vector3 = original.to_global(vertex)
			if absf(point.y - FLOOR_Y) < 0.0002:
				edge = maxf(edge, point.z)
	return edge if is_finite(edge) else 0.364719


static func _beam(parent: Node3D, label: String, start: Vector3, end: Vector3, thickness: float, material: Material) -> void:
	var length := start.distance_to(end)
	var beam := _box(parent, label, Vector3(-thickness, -thickness, -length) * 0.5, Vector3(thickness, thickness, length) * 0.5, material)
	beam.position = (start + end) * 0.5
	beam.look_at(end, Vector3.UP)


static func _finish_canopy(parent: Node3D) -> void:
	var wood := _material(Color("74604a"), 0.87)
	var slats := MultiMeshInstance3D.new()
	slats.name = "CanopyUndersideSlats"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.135, 0.025, 2.96)
	mesh.material = wood
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = 34
	for index in 34:
		instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(-16.70 + index * 0.164, 3.015, 1.57)))
	slats.multimesh = instances
	parent.add_child(slats)
	var glow := _material(Color("ead7b5"), 0.55)
	glow.emission_enabled = true
	glow.emission = Color("ffd99b")
	glow.emission_energy_multiplier = 1.4
	for x: float in [-15.7, -14.0, -12.3]:
		var light := _box(parent, "RecessedCanopyLight", Vector3(x - 0.045, 2.991, 1.15), Vector3(x + 0.045, 3.003, 1.78), glow, false)
		light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
