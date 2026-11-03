extends RefCounted
class_name ComputerProp
## Reuses the named components of the user-provided Gamer Setup_pack GLB.
## `base` is a world-space desk-top point. Default width produces a 0.72 m
## monitor and a roughly 0.94 m workstation; the supplied 2 m desk is omitted.
## Source: Phuc, CC BY 4.0. See the GLB's embedded asset.extras attribution.

const ASSET := "res://assets/user_models/gamer_setup_pack.glb"
const NATIVE_MONITOR_WIDTH := 0.8012037873268127

static func create(parent: Node3D, base: Vector3, width: float = 1.0) -> Dictionary:
	var packed := load(ASSET) as PackedScene
	if packed == null:
		push_error("The approved computer asset could not be loaded: " + ASSET)
		return {}
	var source := packed.instantiate() as Node3D
	var station := Node3D.new()
	station.name = "ImportedResponseComputer"
	parent.add_child(station)
	# Keep the physical display front facing world +Z, including rotated parents.
	station.transform = _world_transform(parent).affine_inverse() * Transform3D(Basis.IDENTITY, base)
	var monitor_width := clampf(0.72 * width, 0.60, 0.80)
	var factor := monitor_width / NATIVE_MONITOR_WIDTH
	var spacing := monitor_width / 0.72
	var components: Dictionary = {}
	# Component geometry/materials come from the GLB. Only placement is adapted.
	components["monitor"] = _mount(source, "sm_monitor", station, factor, Vector3(0, 0, -0.09) * spacing)
	components["mousepad"] = _mount(source, "sm_mousepad", station, factor, Vector3(-0.02, 0.001, 0.10) * spacing)
	components["keyboard"] = _mount(source, "sm_keyboard", station, factor, Vector3(-0.10, 0.006, 0.19) * spacing)
	components["mouse"] = _mount(source, "sm_mouse", station, factor, Vector3(0.235, 0.006, 0.18) * spacing)
	components["tower"] = _mount(source, "sm_pc", station, factor, Vector3(0.47, 0, -0.025) * spacing)
	# The original desk and speakers remain in the source file, not this assembly.
	source.free()
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(station, meshes)
	for mesh: MeshInstance3D in meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			if original != null and original.resource_name.to_lower() == "mt_pc_led":
				var restrained: StandardMaterial3D = original.duplicate() as StandardMaterial3D
				restrained.albedo_color = Color("0c1723")
				restrained.emission = Color("0b5570")
				restrained.emission_energy_multiplier = 0.30
				restrained.roughness = 0.44
				mesh.set_surface_override_material(surface,restrained)
			elif original != null and original.resource_name.to_lower() == "mt_case_boxmetal":
				# The visible blue inner plate uses a separate non-emissive material.
				# Duplicate it so the supplied model and other mapped parts stay intact.
				var panel: StandardMaterial3D = original.duplicate() as StandardMaterial3D
				panel.albedo_color = Color("18383e")
				panel.roughness = 0.72
				mesh.set_surface_override_material(surface, panel)
	var screen_mesh := station.find_child("sm_monitor_mt_monitor_screen_0", true, false) as MeshInstance3D
	if screen_mesh == null:
		push_error("The approved computer model has no monitor screen.")
		station.free()
		return {}
	var powered_display := StandardMaterial3D.new()
	powered_display.resource_name = "ENSA powered display (imported screen)"
	powered_display.albedo_color = Color("08252f")
	powered_display.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	powered_display.cull_mode = BaseMaterial3D.CULL_DISABLED
	screen_mesh.material_override = powered_display
	var screen_local := _screen_center(station, screen_mesh)
	var display_text := Label3D.new()
	display_text.name = "TrainingDisplayText"
	display_text.text = ">_"
	display_text.font_size = 72
	display_text.pixel_size = 0.001 * spacing
	display_text.position = screen_local + Vector3(0, 0, 0.016 * spacing)
	display_text.modulate = Color("91e9d8")
	display_text.outline_size = 0
	display_text.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	station.add_child(display_text)
	var bounds := _bounds(station)
	var component_bounds: Dictionary = {}
	for key: String in components:
		var part := components[key] as Node3D
		if part != null:
			component_bounds[key] = _bounds(part, part.transform)
	var station_world := _world_transform(station)
	station.set_meta("source_asset", ASSET)
	station.set_meta("monitor_width_m", monitor_width)
	return {
		"root": station,
		"screen": station_world * screen_local,
		"screen_mesh": screen_mesh,
		"label_position": station_world * Vector3(0, bounds.end.y + 0.20 * spacing, -0.09 * spacing),
		"meshes": meshes,
		"components": components,
		"collision_bounds": bounds,
		"component_bounds": component_bounds,
		"world_bounds": station_world * bounds,
		"monitor_width": monitor_width,
		"facing": Vector3.BACK,
	}

static func _mount(source: Node3D, part_name: String, station: Node3D, factor: float, target: Vector3) -> Node3D:
	var part := source.find_child(part_name, true, false) as Node3D
	if part == null:
		push_error("Missing supplied computer component: " + part_name)
		return null
	var imported_transform := _relative_transform(source, part)
	_clear_owners(part)
	part.get_parent().remove_child(part)
	station.add_child(part)
	part.transform = Transform3D(Basis.from_scale(Vector3.ONE * factor), Vector3.ZERO) * imported_transform
	var bounds := _bounds(part, part.transform)
	part.position += Vector3(target.x - bounds.get_center().x, target.y - bounds.position.y, target.z - bounds.get_center().z)
	return part

static func _relative_transform(ancestor: Node3D, node: Node3D) -> Transform3D:
	var tx := node.transform
	var cursor := node.get_parent()
	while cursor is Node3D:
		tx = (cursor as Node3D).transform * tx
		if cursor == ancestor:
			break
		cursor = cursor.get_parent()
	return tx

static func _world_transform(node: Node3D) -> Transform3D:
	var tx := node.transform
	var cursor := node.get_parent()
	while cursor is Node3D:
		tx = (cursor as Node3D).transform * tx
		cursor = cursor.get_parent()
	return tx

static func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, meshes)

static func _bounds(node: Node3D, tx: Transform3D = Transform3D.IDENTITY) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(node, meshes)
	var result := AABB()
	var first := true
	for mesh: MeshInstance3D in meshes:
		var mesh_tx := tx
		if mesh != node:
			# _relative_transform includes node.transform; callers pass the desired
			# transform for node separately, so remove its original transform.
			mesh_tx = tx * node.transform.affine_inverse() * _relative_transform(node, mesh)
		var box := mesh_tx * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

static func _screen_center(station: Node3D, screen_mesh: MeshInstance3D) -> Vector3:
	var tx := station.transform.affine_inverse() * _relative_transform(station, screen_mesh)
	var box := tx * screen_mesh.get_aabb()
	var center := box.get_center()
	# The supplied display is curved. At x=0 its actual front is the minimum
	# Z of the curved surface, rather than the AABB's center or front edge.
	var best_x := INF
	var center_z := center.z
	for surface: int in range(screen_mesh.mesh.get_surface_count()):
		var vertices: PackedVector3Array = screen_mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var point := tx * vertex
			var distance_x := absf(point.x - center.x)
			if distance_x < best_x:
				best_x = distance_x
				center_z = point.z
	return Vector3(center.x, center.y, center_z)

static func _clear_owners(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owners(child)
