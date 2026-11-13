extends Node3D
## Loads the original campus as a playable static world without moving its objects.
## Call `await build()` after adding this node to the scene tree.

const CAMPUS_PATH: String = "res://assets/campus.glb"
const TeachingInterior = preload("res://assets/teaching_interior.scn")
const SuppliedFurniture = preload("res://scripts/furniture_props.gd")
const MANIFEST_PATH: String = "res://assets/asset-manifest.json"
const BATCH_THRESHOLD: int = 8
const WORLD_COLLISION_LAYER: int = 1
const CampusMaterials = preload("res://scripts/campus_materials.gd")
const CanopyDetail = preload("res://scripts/canopy_detail.gd")
const EntranceGeometry = preload("res://scripts/entrance_geometry.gd")
const AtriumRepair = preload("res://scripts/atrium_entrance_repair.gd")
const GlazedSideFacade = preload("res://scripts/glazed_side_facade.gd")
const CampusDoors = preload("res://scripts/campus_doors.gd")
const D7RearFacade = preload("res://scripts/d7_rear_facade.gd")
const AuditoriumRearFacade = preload("res://scripts/auditorium_rear_facade.gd")

var campus_scene: Node3D
var mesh_nodes: Array[MeshInstance3D] = []
var doors: Array[MeshInstance3D] = []
var door_system: Node3D
var material_library = CampusMaterials.new()
var stats: Dictionary = {
	"ready": false,
	"mesh_nodes": 0,
	"collision_bodies": 0,
	"unique_collision_shapes": 0,
	"collision_cache_hits": 0,
	"furniture_bodies": 0,
	"chair_boxes": 0,
	"multimesh_batches": 0,
	"batched_instances": 0,
	"static_surface_batches": 0,
	"merged_static_instances": 0,
	"passable_door_meshes": 0,
	"transparent_meshes_without_shadows": 0,
	"build_seconds": 0.0,
}

var _building: bool = false
var _manifest_by_name: Dictionary = {}
var _manifest_by_normalized_name: Dictionary = {}
var _shape_cache: Dictionary = {}
var _split_shape_cache: Dictionary = {}
var _chair_shape_cache: Dictionary = {}
var _render_batches: Node3D
signal build_progress(label: String, stage: String, completed: Variant, total: Variant)
var prepared_asset: PackedScene
var prepared_sections: Array[PackedScene] = []
var cancelled := false
var build_error := ""
var stage_timings: Dictionary = {}
var _budget_started: int = 0

func _budget_due() -> bool:
	return is_inside_tree() and Time.get_ticks_usec()-_budget_started > 4000

func _yield_budget() -> void:
	await get_tree().process_frame
	_budget_started = Time.get_ticks_usec()


func _exit_tree() -> void:
	# Release batch resources while their source Mesh resources are still alive.
	# This also avoids a Godot 4.3 dummy-renderer shutdown ordering warning.
	if is_instance_valid(_render_batches):
		for child: Node in _render_batches.get_children():
			if child is MultiMeshInstance3D:
				(child as MultiMeshInstance3D).multimesh = null
			elif child is MeshInstance3D:
				(child as MeshInstance3D).mesh = null


func build() -> void:
	if bool(stats["ready"]) or _building:
		return
	_building = true
	_budget_started = Time.get_ticks_usec()
	var started_msec: int = Time.get_ticks_msec()
	_load_manifest()
	build_progress.emit("Loading campus resource","campus_resource",null,null)
	var packed: PackedScene = prepared_asset
	if packed == null and prepared_sections.is_empty(): packed = load(CAMPUS_PATH) as PackedScene
	if packed == null and prepared_sections.is_empty():
		push_error("Campus asset could not be loaded: " + CAMPUS_PATH)
		build_error = "Campus asset could not be loaded: " + CAMPUS_PATH
		_building = false
		return
	build_progress.emit("Creating campus geometry","instantiate",null,null)
	await _yield_budget()
	if cancelled:
		_building = false
		return
	var instance_started := Time.get_ticks_usec()
	if prepared_sections.is_empty():
		campus_scene = packed.instantiate() as Node3D
	else:
		campus_scene = Node3D.new()
		campus_scene.name = "CampusSource"
		add_child(campus_scene)
		var canonical_meshes: Dictionary = {}
		var canonical_materials: Dictionary = {}
		var count := 0
		for section: PackedScene in prepared_sections:
			if cancelled:
				_building = false
				return
			var chunk_started := Time.get_ticks_usec()
			var chunk := section.instantiate() as Node3D
			_canonicalize_section(chunk,canonical_meshes,canonical_materials)
			campus_scene.add_child(chunk)
			stage_timings["largest_section_ms"] = maxf(float(stage_timings.get("largest_section_ms",0.0)),(Time.get_ticks_usec()-chunk_started)/1000.0)
			count += 1
			build_progress.emit("Creating campus sections","instantiate",count,prepared_sections.size())
			await _yield_budget()
	stage_timings["instantiate_ms"] = (Time.get_ticks_usec()-instance_started)/1000.0
	if campus_scene == null:
		push_error("Campus scene must have a Node3D root.")
		build_error = "Campus scene must have a Node3D root."
		_building = false
		return
	campus_scene.name = "CampusSource"
	if campus_scene.get_parent() == null: add_child(campus_scene)
	_collect_meshes(campus_scene)
	_install_teaching_interior()
	stats["mesh_nodes"] = mesh_nodes.size()
	var processed: int = 0
	for mesh_node: MeshInstance3D in mesh_nodes:
		if cancelled:
			_building = false
			return
		var mesh_started := Time.get_ticks_usec()
		var record: Dictionary = _record_for(mesh_node)
		var source_name: String = str(record.get("name", mesh_node.name))
		if source_name.begins_with("E6 detailed black mesh office chair"):
			mesh_node.visible = false
			mesh_node.set_meta("replaced_by_approved_asset", true)
			continue
		if source_name == "D7 short facade fine mullion.006":
			# QA confirmed this is exactly coincident with mullion .005.
			mesh_node.visible = false
			mesh_node.set_meta("campus_duplicate_hidden", true)
			continue
		var classification: String = str(record.get("role", "detail"))
		mesh_node.set_meta("campus_source_name", source_name)
		mesh_node.set_meta("campus_role", classification)
		mesh_node.set_meta("campus_walkable", classification == "walkable")
		# Layer 2 receives the small workstation key lights. The rest of the
		# campus is excluded from their extra lighting/shadow pass.
		if classification == "walkable": mesh_node.layers = 3
		mesh_node.lod_bias = 0.30
		if source_name.begins_with("Campus plaza shade tree") or source_name.begins_with("R3 Garden tree"):
			mesh_node.lod_bias = 1.5
		if "grass" in source_name.to_lower() or "lawn blades" in source_name.to_lower():
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lowered_source: String = source_name.to_lower()
		if classification == "walkable" and ("plaza" in lowered_source or "paved" in lowered_source or "site base" in lowered_source or "road" in lowered_source):
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		CanopyDetail.enhance(mesh_node, source_name)
		var canopy_done := Time.get_ticks_usec()
		_tune_materials(mesh_node, source_name)
		var materials_done := Time.get_ticks_usec()
		_disable_glass_shadow(mesh_node)
		var is_door: bool = _is_passable_door(source_name, classification)
		if is_door:
			doors.append(mesh_node)
			mesh_node.set_meta("campus_door", true)
			mesh_node.add_to_group("campus_doors")
		elif classification in ["architecture", "walkable", "glass"]:
			await _add_triangle_collision(mesh_node, source_name)
		elif classification == "furniture":
			_add_furniture_collision(mesh_node, source_name)
		processed += 1
		var elapsed: float = (Time.get_ticks_usec()-mesh_started)/1000.0
		if elapsed>float(stage_timings.get("largest_mesh_ms",0.0)):
			stage_timings["largest_mesh_ms"] = elapsed
			stage_timings["largest_mesh_name"] = source_name
			stage_timings["largest_mesh_parts_ms"] = {"canopy":(canopy_done-mesh_started)/1000.0,"materials":(materials_done-canopy_done)/1000.0,"collision":(Time.get_ticks_usec()-materials_done)/1000.0,"precomputed_shape":mesh_node.has_meta("derived_triangle_shapes")}
		# Time-bounded batches reflect actual processed meshes, not synthetic %.
		if _budget_due():
			build_progress.emit("Preparing surfaces and collision","collision",processed,mesh_nodes.size())
			await _yield_budget()
	stats["passable_door_meshes"] = doors.size()
	build_progress.emit("Aligning landings and interactive entrances","entrances",null,null)
	await _yield_budget()
	if cancelled:
		_building = false
		return
	var entrance_result: Dictionary = EntranceGeometry.install(self)
	stats["entrance_repair"] = {"installed":entrance_result.get("installed",false),"step_count":entrance_result.get("step_count",0),"floor_y":entrance_result.get("floor_y",0.0)}
	var atrium_result: Dictionary = AtriumRepair.install(self)
	GlazedSideFacade.install(self)
	stats["atrium_repair"] = {"installed":atrium_result.get("installed",false),"floor_y":atrium_result.get("floor_y",0.0)}
	door_system = CampusDoors.new()
	add_child(door_system)
	stats["interactive_doors"] = door_system.install(self)
	D7RearFacade.install(self, mesh_nodes, material_library)
	AuditoriumRearFacade.install(self)
	build_progress.emit("Preparing repeated render batches","batches",null,null)
	await _batch_repeated_meshes()
	if cancelled:
		_building = false
		return
	build_progress.emit("Merging small architectural surfaces","merges",null,null)
	await _merge_small_static_meshes()
	if cancelled:
		_building = false
		return
	await _install_supplied_furniture()
	stats["unique_collision_shapes"] = _shape_cache.size() + _split_shape_cache.size() + _chair_shape_cache.size()
	stats["materials"] = material_library.stats
	stats["build_seconds"] = float(Time.get_ticks_msec() - started_msec) / 1000.0
	stats["stage_timings"] = stage_timings
	stats["ready"] = true
	_building = false
	print("CAMPUS_READY ", JSON.stringify(stats))


func _load_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_warning("Campus manifest unavailable; using imported metadata.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Campus manifest is not a JSON object.")
		return
	var manifest: Dictionary = parsed as Dictionary
	material_library.configure_manifest(manifest.get("materials", []) as Array)
	var records: Array = manifest.get("nodes", []) as Array
	for item: Variant in records:
		if item is Dictionary:
			var record: Dictionary = item as Dictionary
			var source_name: String = str(record.get("name", ""))
			_manifest_by_name[source_name] = record
			_manifest_by_normalized_name[_normalize_name(source_name)] = record


func _normalize_name(source_name: String) -> String:
	# Imported Node names cannot contain periods; the manifest keeps Blender labels.
	return source_name.replace(".", "").replace("_", "").replace(":", "").replace("@", "").replace("/", "").replace("\"", "").replace("%", "")


func _record_for(mesh_node: MeshInstance3D) -> Dictionary:
	if mesh_node.has_meta("teaching_interior"):
		return {"name": mesh_node.get_meta("campus_source_name"), "role": mesh_node.get_meta("campus_role")}
	var extras_value: Variant = mesh_node.get_meta("extras", {})
	var extras: Dictionary = extras_value as Dictionary if extras_value is Dictionary else {}
	var source_name: String = str(mesh_node.get_meta("campus_source_name", extras.get("campus_source_name", mesh_node.name)))
	if _manifest_by_name.has(source_name):
		return _manifest_by_name[source_name] as Dictionary
	var normalized_name: String = _normalize_name(source_name)
	if _manifest_by_normalized_name.has(normalized_name):
		return _manifest_by_normalized_name[normalized_name] as Dictionary
	var classification: String = str(mesh_node.get_meta("campus_role", extras.get("campus_role", "detail")))
	return {"name": source_name, "role": classification}


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node.mesh != null:
			mesh_nodes.append(mesh_node)
	for child: Node in node.get_children():
		_collect_meshes(child)


func _install_teaching_interior() -> void:
	var interior := TeachingInterior.instantiate() as Node3D
	var replaced: Dictionary = {}
	for source_name: String in interior.get_meta("replaces"):
		replaced[source_name] = true
	var retained: Array[MeshInstance3D] = []
	for mesh_node: MeshInstance3D in mesh_nodes:
		var source_name := str(_record_for(mesh_node)["name"])
		if replaced.has(source_name):
			# Retire the old mesh before the collision and render batches are built.
			# Keep its transform in case an imported child is parented to it.
			mesh_node.mesh = null
		else:
			retained.append(mesh_node)
	var retired := mesh_nodes.size() - retained.size()
	mesh_nodes = retained
	var existing := mesh_nodes.size()
	campus_scene.add_child(interior)
	_collect_meshes(interior)
	stats["teaching_interior"] = {"installed": mesh_nodes.size() - existing, "retired": retired}


func _install_supplied_furniture() -> void:
	var furniture := Node3D.new()
	furniture.name = "SuppliedHallFurniture"
	campus_scene.add_child(furniture)
	# The bench backs onto the classroom partition and faces the open hall.
	# Both footprints stay outside the door, stair, and lift approaches.
	var bench := SuppliedFurniture.place(furniture, "supplied_bench", Vector3(-18.65, .67, -3.75), PI / 2)
	var bin := SuppliedFurniture.place(furniture, "supplied_bin", Vector3(-18.65, .67, -2.3))
	var installed := int(bench != null) + int(bin != null)
	# Waiting areas on both galleries at every level. Benches face the courtyard,
	# preserving the gallery walking routes and keeping the room doors free.
	for floor_y: float in [.67, 3.605, 6.755]:
		for gallery: Array in [[-9.35, PI], [-19.65, 0.0]]:
			var bench_position := Vector3(-25.5, floor_y, gallery[0])
			var bin_position := Vector3(-27.1, floor_y, gallery[0])
			bench = SuppliedFurniture.place(furniture, "supplied_bench", bench_position, gallery[1])
			bin = SuppliedFurniture.place(furniture, "supplied_bin", bin_position)
			installed += int(bench != null) + int(bin != null)
	# Match the marked open plaza with perimeter seating facing the clear centre.
	# Let the physics server register the campus before sampling each paving height.
	await get_tree().physics_frame
	var plaza_furniture := Node3D.new()
	plaza_furniture.name = "SuppliedPlazaFurniture"
	campus_scene.add_child(plaza_furniture)
	var plaza_setups: Array = [
		[Vector3(-44.5, 0, -71), Vector3(-42.9, 0, -71), PI],
		[Vector3(-32, 0, -71), Vector3(-30.4, 0, -71), PI],
		[Vector3(-12, 0, -71), Vector3(-10.4, 0, -71), PI],
		[Vector3(-55, 0, -80), Vector3(-55, 0, -78.4), PI / 2],
		[Vector3(-55, 0, -91), Vector3(-55, 0, -89.4), PI / 2],
		[Vector3(1, 0, -80), Vector3(1, 0, -78.4), -PI / 2],
		[Vector3(1, 0, -90), Vector3(1, 0, -88.4), -PI / 2],
	]
	var outdoor_installed := 0
	for setup: Array in plaza_setups:
		for index: int in range(2):
			var position: Vector3 = setup[index]
			var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 2, position - Vector3.UP, WORLD_COLLISION_LAYER)
			var ground := get_world_3d().direct_space_state.intersect_ray(query)
			if ground.is_empty():
				push_warning("No plaza paving beneath supplied furniture at " + str(position))
				continue
			position.y = ground["position"].y
			var kind := "supplied_bench" if index == 0 else "supplied_bin"
			var yaw: float = setup[2] if index == 0 else 0.0
			var prop := SuppliedFurniture.place(plaza_furniture, kind, position, yaw)
			outdoor_installed += int(prop != null)
	stats["outdoor_furniture"] = outdoor_installed
	stats["supplied_furniture"] = installed + outdoor_installed


func _is_passable_door(source_name: String, classification: String) -> bool:
	var lowered: String = source_name.to_lower()
	if classification == "door":
		return true
	# D's four entry panels and the E main glazed entry are deliberately operable.
	# Frames/lintels retain exact triangle collisions; individual leaves are exposed.
	if "door glass" in lowered or "door leaf" in lowered:
		return true
	if "entrance" in lowered and ("glass" in lowered or "glazing" in lowered):
		return true
	if "front" in lowered and "door" in lowered:
		return true
	if "open" in lowered and "door" in lowered:
		return true
	return false


func _add_triangle_collision(mesh_node: MeshInstance3D, source_name: String) -> void:
	var mesh: Mesh = mesh_node.mesh
	var mesh_key: int = mesh.get_rid().get_id()
	var pieces: Array = mesh_node.get_meta("derived_triangle_shapes",[])
	if not pieces.is_empty():
		if _split_shape_cache.has(mesh_key): pieces = _split_shape_cache[mesh_key]
		else: _split_shape_cache[mesh_key] = pieces
		var body := StaticBody3D.new()
		body.name = "CampusCollision"
		body.collision_layer = WORLD_COLLISION_LAYER
		body.collision_mask = 0
		body.set_meta("campus_source_name",source_name)
		body.set_meta("campus_role",mesh_node.get_meta("campus_role","architecture"))
		body.add_to_group("campus_static")
		mesh_node.add_child(body)
		for piece: ConcavePolygonShape3D in pieces:
			var collision := CollisionShape3D.new()
			collision.shape = piece
			body.add_child(collision)
			if _budget_due(): await _yield_budget()
		stats["collision_bodies"] = int(stats["collision_bodies"])+1
		return
	var shape: ConcavePolygonShape3D
	if _shape_cache.has(mesh_key):
		shape = _shape_cache[mesh_key] as ConcavePolygonShape3D
		stats["collision_cache_hits"] = int(stats["collision_cache_hits"]) + 1
	else:
		if mesh_node.has_meta("derived_triangle_shape"):
			shape = mesh_node.get_meta("derived_triangle_shape") as ConcavePolygonShape3D
		if shape == null: shape = mesh.create_trimesh_shape()
		if shape == null:
			return
		# Floors and open architectural surfaces remain solid from both directions.
		shape.backface_collision = true
		_shape_cache[mesh_key] = shape
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "CampusCollision"
	body.collision_layer = WORLD_COLLISION_LAYER
	body.collision_mask = 0
	body.set_meta("campus_source_name", source_name)
	body.set_meta("campus_role", mesh_node.get_meta("campus_role", "architecture"))
	body.add_to_group("campus_static")
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "ExactTriangles"
	collision.shape = shape
	body.add_child(collision)
	# Identity child transforms preserve every source object's local scale/rotation.
	mesh_node.add_child(body)
	stats["collision_bodies"] = int(stats["collision_bodies"]) + 1

func _canonicalize_section(node: Node, meshes: Dictionary, materials: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var key: String = str(node.get_meta("derived_mesh_key",""))
		if meshes.has(key): node.mesh = meshes[key]
		else:
			meshes[key] = node.mesh
			for index: int in range(node.mesh.get_surface_count()):
				var source: Material = node.mesh.surface_get_material(index)
				if source == null: continue
				var mat_key: String = str(source.get_meta("derived_material_key",source.resource_name))
				if materials.has(mat_key): node.mesh.surface_set_material(index,materials[mat_key])
				else: materials[mat_key] = source
	for child: Node in node.get_children(): _canonicalize_section(child,meshes,materials)


func _add_furniture_collision(mesh_node: MeshInstance3D, source_name: String) -> void:
	var lowered: String = source_name.to_lower()
	if lowered.begins_with("e9 auditorium row "):
		var mesh_key: int = mesh_node.mesh.get_rid().get_id()
		var shape: BoxShape3D
		var local_bounds: AABB = mesh_node.mesh.get_aabb()
		if _chair_shape_cache.has(mesh_key):
			shape = _chair_shape_cache[mesh_key] as BoxShape3D
		else:
			shape = BoxShape3D.new()
			shape.size = local_bounds.size.max(Vector3.ONE * 0.02)
			_chair_shape_cache[mesh_key] = shape
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "SeatCollision"
		body.collision_layer = WORLD_COLLISION_LAYER
		body.collision_mask = 0
		body.set_meta("campus_source_name", source_name)
		body.set_meta("campus_role", "furniture")
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		collision.position = local_bounds.get_center()
		body.add_child(collision)
		mesh_node.add_child(body)
		stats["collision_bodies"] = int(stats["collision_bodies"]) + 1
		stats["furniture_bodies"] = int(stats["furniture_bodies"]) + 1
		stats["chair_boxes"] = int(stats["chair_boxes"]) + 1
	elif "desk" in lowered or "counter" in lowered or "table" in lowered:
		# Preserve gaps under/around individual counter components without cooking
		# expensive upholstered furniture or tiny decorative accessories.
		var triangle_count: int = 0
		for surface_index: int in range(mesh_node.mesh.get_surface_count()):
			triangle_count += int(mesh_node.mesh.surface_get_array_index_len(surface_index) / 3.0)
		if triangle_count <= 12000:
			_add_triangle_collision(mesh_node, source_name)
			stats["furniture_bodies"] = int(stats["furniture_bodies"]) + 1


func _tune_materials(mesh_node: MeshInstance3D, source_name: String) -> void:
	material_library.apply_to_mesh(mesh_node, source_name)


func _disable_glass_shadow(mesh_node: MeshInstance3D) -> void:
	# Exported node roles also call opaque glazing frames "glass". Decide from
	# every actual surface material so only genuinely transparent meshes stop
	# casting opaque window-shaped shadows; mixed frame/pane meshes stay solid.
	if mesh_node.mesh.get_surface_count() == 0:
		return
	for index: int in range(mesh_node.mesh.get_surface_count()):
		var material: Material = mesh_node.get_active_material(index)
		if material == null:
			return
		if str(material.get_meta("campus_material_family", "")) == "glass":
			continue
		if material is BaseMaterial3D:
			var standard: BaseMaterial3D = material as BaseMaterial3D
			if standard.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]:
				continue
		return
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stats["transparent_meshes_without_shadows"] = int(stats["transparent_meshes_without_shadows"]) + 1


func _batchable_opaque(material: Material) -> bool:
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	if material is ShaderMaterial:
		return bool(material.get_meta("campus_opaque", false))
	return false


func _batch_repeated_meshes() -> void:
	var groups: Dictionary = {}
	for mesh_node: MeshInstance3D in mesh_nodes:
		if cancelled: return
		if _budget_due(): await _yield_budget()
		# Door leaves stay independent so the main controller can animate them.
		if not mesh_node.visible:
			continue
		if bool(mesh_node.get_meta("campus_door", false)):
			continue
		var material_signature: String = ""
		for surface_index: int in range(mesh_node.mesh.get_surface_count()):
			var material: Material = mesh_node.get_active_material(surface_index)
			material_signature += ":" + str(material.get_instance_id() if material != null else 0)
		var center: Vector3 = to_local(mesh_node.to_global(mesh_node.mesh.get_aabb().get_center()))
		var cell: String = ":" + str(floori(center.x / 40.0)) + ":" + str(floori(center.z / 40.0))
		var key: String = str(mesh_node.mesh.get_rid().get_id()) + material_signature + cell + ":" + str(mesh_node.layers)
		if not groups.has(key):
			groups[key] = []
		var group: Array = groups[key] as Array
		group.append(mesh_node)
	_render_batches = Node3D.new()
	_render_batches.name = "CampusRenderBatches"
	add_child(_render_batches)
	for key: Variant in groups:
		if cancelled: return
		if _budget_due(): await _yield_budget()
		var group: Array = groups[key] as Array
		if group.size() <= BATCH_THRESHOLD:
			continue
		var first: MeshInstance3D = group[0] as MeshInstance3D
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = first.mesh
		multimesh.instance_count = group.size()
		var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
		batch.name = "Instances_" + str(stats["multimesh_batches"])
		batch.multimesh = multimesh
		batch.cast_shadow = first.cast_shadow
		batch.layers = first.layers
		batch.lod_bias = first.lod_bias
		batch.material_override = first.material_override
		_render_batches.add_child(batch)
		for index: int in range(group.size()):
			var original: MeshInstance3D = group[index] as MeshInstance3D
			multimesh.set_instance_transform(index, batch.global_transform.affine_inverse() * original.global_transform)
			# Visibility affects rendering only; the exact static bodies remain active.
			original.visible = false
			original.set_meta("campus_render_batch", batch.get_path())
		stats["multimesh_batches"] = int(stats["multimesh_batches"]) + 1
		stats["batched_instances"] = int(stats["batched_instances"]) + group.size()


func _merge_small_static_meshes() -> void:
	# The architectural source models thousands of unique pickets and trim bars.
	# Merge their render surfaces by material in 40 m cells; the original named
	# nodes and their already-built collision bodies remain in the source tree.
	var groups: Dictionary = {}
	for original: MeshInstance3D in mesh_nodes:
		if cancelled: return
		if _budget_due(): await _yield_budget()
		if not original.visible or bool(original.get_meta("campus_door", false)):
			continue
		if original.mesh.get_surface_count() != 1:
			continue
		var material: Material = original.get_active_material(0)
		if material == null or not _batchable_opaque(material):
			continue
		var triangle_count: int = int(original.mesh.surface_get_array_index_len(0) / 3.0)
		if triangle_count == 0 or triangle_count > 1200:
			continue
		var local_center: Vector3 = to_local(original.to_global(original.mesh.get_aabb().get_center()))
		var key: String = str(material.get_instance_id()) + ":" + str(floori(local_center.x / 40.0)) + ":" + str(floori(local_center.z / 40.0)) + ":" + str(original.cast_shadow) + ":" + str(original.layers)
		if not groups.has(key):
			groups[key] = []
		var group: Array = groups[key] as Array
		group.append(original)
	for key: Variant in groups:
		if cancelled: return
		if _budget_due(): await _yield_budget()
		var group: Array = groups[key] as Array
		if group.size() < 5:
			continue
		var first: MeshInstance3D = group[0] as MeshInstance3D
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for item: Variant in group:
			var original: MeshInstance3D = item as MeshInstance3D
			surface.append_from(original.mesh, 0, global_transform.affine_inverse() * original.global_transform)
			if cancelled: return
			if _budget_due(): await _yield_budget()
		surface.set_material(first.get_active_material(0))
		var merged_mesh: ArrayMesh = surface.commit()
		if merged_mesh == null:
			continue
		var merged: MeshInstance3D = MeshInstance3D.new()
		merged.name = "StaticSurface_" + str(stats["static_surface_batches"])
		merged.mesh = merged_mesh
		merged.cast_shadow = first.cast_shadow
		merged.layers = first.layers
		merged.lod_bias = 0.30
		_render_batches.add_child(merged)
		for item: Variant in group:
			var original: MeshInstance3D = item as MeshInstance3D
			original.visible = false
			original.set_meta("campus_render_batch", merged.get_path())
		stats["static_surface_batches"] = int(stats["static_surface_batches"]) + 1
		stats["merged_static_instances"] = int(stats["merged_static_instances"]) + group.size()


func sample_ground_hits() -> Dictionary:
	# Run after a physics frame, once initial bodies are registered with the world.
	var results: Dictionary = {}
	if not is_inside_tree():
		return results
	var probes: Dictionary = {
		"plaza": Vector3(-27.0, 1.25, -85.0),
		"e_foyer": Vector3(-36.0, 1.91, -104.5),
		"e_rear_aisle": Vector3(-37.0, 1.924, -107.95),
		"d_entrance": Vector3(-5.8, 2.8, -102.9),
	}
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for key: Variant in probes:
		var origin: Vector3 = probes[key]
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 4.0, WORLD_COLLISION_LAYER)
		var hit: Dictionary = space.intersect_ray(query)
		results[key] = {"hit": not hit.is_empty()}
		if not hit.is_empty():
			var collider: Object = hit["collider"] as Object
			var position_value: Vector3 = hit["position"]
			results[key]["height"] = position_value.y
			results[key]["source"] = str(collider.get_meta("campus_source_name", ""))
	return results
