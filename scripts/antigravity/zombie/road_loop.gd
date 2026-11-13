extends Node3D
## Connects the two campus access roads around the site in After Hours.

const ASPHALT := preload("res://assets/runtime_surfaces/asphalt_albedo.png")
const ROAD_Y := 0.14
const JUNCTION_Y := 0.335
const WEST_X := -82.0
const EAST_X := 45.0
const CROSS_Z := -61.0
const RETURN_Z := -154.0
const HALF_WIDTH := 3.0

func _ready() -> void:
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_texture = ASPHALT
	asphalt.albedo_color = Color("5b6065")
	asphalt.roughness = 0.96
	asphalt.uv1_triplanar = true
	asphalt.uv1_world_triplanar = true
	asphalt.uv1_scale = Vector3.ONE * 3.0
	asphalt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var road := _surface(asphalt)

	# The new asphalt stays on the existing site base. A flush east extension
	# reaches the end of the original access road behind the campus buildings.
	_flat(road, WEST_X - HALF_WIDTH, WEST_X + HALF_WIDTH, RETURN_Z + HALF_WIDTH, -66.9, ROAD_Y)
	_flat(road, WEST_X - HALF_WIDTH, EAST_X + HALF_WIDTH, RETURN_Z - HALF_WIDTH, RETURN_Z + HALF_WIDTH, ROAD_Y)
	_flat(road, EAST_X - HALF_WIDTH, EAST_X + HALF_WIDTH, RETURN_Z + HALF_WIDTH, -143.495, ROAD_Y)

	# Low raised junctions carry the new lanes over the original campus curbs.
	_flat(road, -85.1, -78.9, -65.1, -63.7, JUNCTION_Y)
	_patch(road, -85.0, -79.0, -66.9, -65.1, ROAD_Y, ROAD_Y, JUNCTION_Y, JUNCTION_Y)
	_patch(road, -85.1, -78.9, -63.7, -61.9, JUNCTION_Y, JUNCTION_Y, ROAD_Y + 0.004, ROAD_Y + 0.004)
	_flat(road, 41.50, 48.50, -64.65, -57.35, JUNCTION_Y)
	_patch(road, 42.0, 48.0, -66.45, -64.65, ROAD_Y + 0.004, ROAD_Y + 0.004, JUNCTION_Y, JUNCTION_Y)
	_patch(road, 42.0, 48.0, -57.35, -55.55, JUNCTION_Y, JUNCTION_Y, 0.120, 0.120)
	_patch(road, 39.7, 41.5, -64.25, -57.75, ROAD_Y + 0.004, JUNCTION_Y, JUNCTION_Y, ROAD_Y + 0.004)
	_patch(road, 48.5, 50.3, -64.25, -57.75, JUNCTION_Y, ROAD_Y + 0.004, ROAD_Y + 0.004, JUNCTION_Y)

	# The plaza approach meets the pickup road at the existing raised curb.
	_patch(road, -29.4, -25.4, -66.4, -64.7, 0.005, 0.005, JUNCTION_Y, JUNCTION_Y)
	_flat(road, -29.4, -25.4, -64.7, -64.05, JUNCTION_Y)
	_patch(road, -29.4, -25.4, -64.05, -62.7, JUNCTION_Y, JUNCTION_Y, ROAD_Y + 0.004, ROAD_Y + 0.004)
	var asphalt_mesh := _add_mesh(road, "ReturnRoadAndJunctions")
	var body := StaticBody3D.new()
	body.name = "RoadSurface"
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = asphalt_mesh.create_trimesh_shape()
	body.add_child(collider)
	add_child(body)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("c5af75")
	paint.roughness = 0.95
	var dashes := _surface(paint)
	var paint_y := ROAD_Y + 0.007
	for x in range(-76, 39, 6):
		_flat(dashes, x - 1.25, x + 1.25, CROSS_Z - 0.057, CROSS_Z + 0.057, paint_y)
	for x in range(-76, 40, 6):
		_flat(dashes, x - 1.25, x + 1.25, RETURN_Z - 0.057, RETURN_Z + 0.057, paint_y)
	for z in range(-148, -68, 6):
		_flat(dashes, WEST_X - 0.057, WEST_X + 0.057, z - 1.25, z + 1.25, paint_y)
		_flat(dashes, EAST_X - 0.057, EAST_X + 0.057, z - 1.25, z + 1.25, paint_y)
	_add_mesh(dashes, "CenterLanePaint")

func is_near_road(position: Vector3) -> bool:
	var circuit := Rect2(WEST_X, RETURN_Z, EAST_X - WEST_X, CROSS_Z - RETURN_Z)
	var point := Vector2(position.x, position.z)
	return circuit.grow(12.0).has_point(point) and not circuit.grow(-12.0).has_point(point)

func encounter_points() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-71, ROAD_Y, -62.2), Vector3(-52, ROAD_Y, -59.3),
		Vector3(-5, ROAD_Y, -62.6), Vector3(16, ROAD_Y, -59.5), Vector3(36, ROAD_Y, -62.4),
		Vector3(46.7, ROAD_Y, -76), Vector3(43.2, ROAD_Y, -95),
		Vector3(46.6, ROAD_Y, -116), Vector3(43.4, ROAD_Y, -138),
		Vector3(35, ROAD_Y, -152.5), Vector3(14, ROAD_Y, -155.7),
		Vector3(-7, ROAD_Y, -152.6), Vector3(-28, ROAD_Y, -155.6),
		Vector3(-48, ROAD_Y, -152.5), Vector3(-70, ROAD_Y, -155.5),
		Vector3(-83.6, ROAD_Y, -140), Vector3(-80.3, ROAD_Y, -118),
		Vector3(-83.7, ROAD_Y, -97), Vector3(-80.3, ROAD_Y, -76),
	])

func _surface(material: Material) -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	return surface

func _flat(surface: SurfaceTool, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	_patch(surface, x0, x1, z0, z1, y, y, y, y)

func _patch(surface: SurfaceTool, x0: float, x1: float, z0: float, z1: float,
	y00: float, y10: float, y11: float, y01: float) -> void:
	var a := Vector3(x0, y00, z0)
	var b := Vector3(x1, y10, z0)
	var c := Vector3(x1, y11, z1)
	var d := Vector3(x0, y01, z1)
	var normal := (c - a).cross(b - a).normalized()
	for vertex: Vector3 in [a, b, c, a, c, d]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)

func _add_mesh(surface: SurfaceTool, label: String) -> ArrayMesh:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var resource := surface.commit()
	mesh.mesh = resource
	add_child(mesh)
	return resource
