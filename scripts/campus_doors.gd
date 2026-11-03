extends Node3D
## Installs the reception slider and three independent hinged entrances before batching.
## Original façades/transoms remain fixed; source downloads and Blender stay intact.

const InteractiveDoor = preload("res://scripts/interactive_door.gd")
const SlidingDoor = preload("res://scripts/sliding_door.gd")
var doors: Array[Node3D] = []
var stats: Dictionary = {"doors":0,"moving_leaves":0,"replaced_meshes":0,"fixed_glazing_colliders":0,"source_names":[]}


func install(campus: Node3D) -> Dictionary:
	if not doors.is_empty(): return stats
	name = "InteractiveCampusEntrances"
	var source_meshes: Array = campus.get("mesh_nodes")
	var cream_prefixes: Array[String] = ["Entrance dark recess","Entrance door glass","Door stile","Door rail","Door pull"]
	for value: Variant in source_meshes:
		var node: MeshInstance3D = value
		var source: String = str(node.get_meta("campus_source_name",node.name))
		var bounds: AABB = node.global_transform*node.get_aabb()
		var is_cream: bool = bounds.position.x >= -16.7 and bounds.end.x <= -11.3 and bounds.position.z >= -0.3 and bounds.end.z <= 0.3 and bounds.position.y < 3.0
		var replace_cream: bool = false
		for prefix: String in cream_prefixes:
			if source == prefix or source.begins_with(prefix+"."): replace_cream = is_cream
		var replace_reception: bool = source in ["E5 clear door or sidelight.001","E5 clear door or sidelight.002","E5 horizontal glazing frame","E5 dark full-height glazing mullion.002"] or source.begins_with("E5 door push bar") or source.begins_with("E5 push bar mount")
		var replace_atrium: bool = source in ["D7 short facade door glass.001","D7 short facade door glass.002","D7 short facade fine mullion.008","D7 entrance pull handle","D7 entrance pull handle.001"]
		var replace_side: bool = source in ["D9 transparent entrance door leaf","D9 access door leaf stile","D9 access door leaf stile.001","D9 access door leaf rail","D9 access door leaf rail.001","D9 satin steel entrance pull handles"]
		if replace_cream or replace_reception or replace_atrium or replace_side:
			_hide_source(node,source)
		elif source in ["E5 clear door or sidelight","E5 clear door or sidelight.003","D7 short facade door glass","D7 short facade door glass.003"]:
			_solid_box("FixedReceptionGlazing",bounds,_glass_material(),false)
			stats["fixed_glazing_colliders"] = int(stats.fixed_glazing_colliders)+1
	# Two central sliding leaves stack in front of the fixed outer sidelights.
	# The separate track plane clears both the glass and the rear handle depth.
	_box("FixedReceptionSillLeft",Vector3(1.76,0.105,0.14),Vector3(-39.66,0.960,-102.77),_frame_material())
	_box("FixedReceptionSillRight",Vector3(1.76,0.105,0.14),Vector3(-34.34,0.960,-102.77),_frame_material())
	_box("ReceptionUpperMullion",Vector3(.105,.8075,.14),Vector3(-37,4.15625,-102.77),_frame_material())
	_box("ReceptionSlidingTrack",Vector3(7.04,.075,.18),Vector3(-37,3.70,-102.615),_frame_material())
	var reception := SlidingDoor.new()
	add_child(reception)
	reception.configure_sliding("Reception entrance",Vector3(-37,0.9515,-102.57),3.50,2.68)
	doors.append(reception)
	# The original cream opening is 4.4 m wide. Its central double doorway is
	# 2.2 m wide; the original outer bays become fixed transparent sidelights.
	var cream := InteractiveDoor.new()
	add_child(cream)
	cream.configure("Main building entrance",Vector3(-14.0,0.534,0.04),2.20,2.230,true)
	doors.append(cream)
	var frame := _frame_material()
	var glass := _glass_material()
	for x: float in [-16.205,-15.15,-12.85,-11.795]:
		_solid_box("FixedBlackEntranceJamb",AABB(Vector3(x-0.0225,0.52,0.0175),Vector3(0.045,2.27,0.045)),frame)
	for x: float in [-15.6775,-12.3225]:
		_solid_box("FixedCreamEntranceSidelight",AABB(Vector3(x-0.505,0.545,0.034),Vector3(1.01,2.22,0.012)),glass)
		_box("FixedSidelightBottomRail",Vector3(1.055,0.045,0.045),Vector3(x,0.5425,0.04),frame)
	_box("FixedCreamEntranceHead",Vector3(4.455,0.045,0.045),Vector3(-14,2.7925,0.04),frame)
	_install_atrium_front()
	_install_atrium_side()
	stats["doors"] = doors.size()
	stats["moving_leaves"] = 7
	stats["sliding_entrances"] = 1
	stats["hinged_entrances"] = 3
	print("CAMPUS_DOORS ",JSON.stringify(stats))
	return stats


func _install_atrium_front() -> void:
	var frame := _frame_material()
	# Only the lower central divider is removed; its upper transom stays fixed.
	_box("AtriumUpperCentreMullion",Vector3(.045,1.005,.095),Vector3(-5.8,4.4825,-103.945),frame)
	for x: float in [-6.25,-5.35]:
		_solid_box("AtriumFixedUpperDoorGlass",AABB(Vector3(x-.426,4.001,-103.9855),Vector3(.852,.959,.021)),_glass_material())
	var door := InteractiveDoor.new()
	add_child(door)
	door.configure("Atrium entrance",Vector3(-5.8,1.828,-103.975),1.74,2.11,true)
	doors.append(door)

func _install_atrium_side() -> void:
	var door := InteractiveDoor.new()
	add_child(door)
	door.configure("Atrium side entrance",Vector3(-2.155,1.828,-106.65),1.04,2.28,false)
	# Open onto the broad portico so the leaf cannot obstruct the narrow hall route.
	door.rotation.y=-PI*.5
	door.set_meta("world_opening_direction","onto exterior portico +X")
	doors.append(door)


func _hide_source(node: MeshInstance3D, source: String) -> void:
	node.hide()
	node.set_meta("replaced_by_interactive_door",true)
	node.set_meta("replaced_by_approved_asset",true)
	_disable_collision(node)
	(stats.source_names as Array).append(source)
	stats.replaced_meshes = int(stats.replaced_meshes)+1


func _disable_collision(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child: Node in node.get_children(): _disable_collision(child)


func _frame_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("172026")
	material.metallic = 0.72
	material.roughness = 0.32
	return material


func _glass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.68,0.84,0.91,0.15)
	material.roughness = 0.12
	material.metallic = 0.04
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _box(title: String, size: Vector3, centre: Vector3, material: Material) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = title
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_node.mesh = mesh
	mesh_node.position = centre
	if material is BaseMaterial3D and (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_node)
	return mesh_node


func _solid_box(title: String, bounds: AABB, material: Material, visible_mesh: bool = true) -> Node3D:
	var holder := Node3D.new()
	holder.name = title
	add_child(holder)
	if visible_mesh:
		var mesh := _box(title+"Mesh",bounds.size,bounds.get_center(),material)
		mesh.reparent(holder,true)
	var body := StaticBody3D.new()
	body.name = "FixedGlazingCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	holder.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bounds.size.max(Vector3(0.012,0.012,0.012))
	collision.shape = shape
	collision.position = bounds.get_center()
	body.add_child(collision)
	return holder


func get_target(camera: Camera3D, player: CharacterBody3D, maximum: float = 2.0) -> Dictionary:
	var nearest: float = maximum
	var result: Dictionary = {}
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_basis.z
	for door: Node3D in doors:
		var distance: float = door.hit_distance(origin,direction,maximum)
		if distance > nearest: continue
		var point: Vector3 = origin+direction*distance
		var ray := PhysicsRayQueryParameters3D.create(origin,point,1,[player.get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			var collider: Node = hit.collider
			var is_own_leaf: bool = door.is_ancestor_of(collider)
			if not is_own_leaf and origin.distance_to(hit.position) < distance-0.10: continue
		nearest = distance
		result = {"node":door,"screen":point,"name":door.door_name,"kind":"door","distance":distance,"prompt":door.get_prompt()}
	return result
