extends Node3D
## Independent glass leaves. Their actual mesh and solid collider share a hinge.
## All supplied openings face local +Z; opening rotates each leaf inward to -Z.

signal state_changed(open: bool)

const DURATION: float = 1.0
const LEAF_DEPTH: float = 0.045
var is_open: bool = false
var is_animating: bool = false
var pivots: Array[Node3D] = []
var colliders: Array[CollisionShape3D] = []
var bodies: Array[AnimatableBody3D] = []
var leaves: Array[Dictionary] = []
var opening_width: float = 1.5
var opening_height: float = 2.68
var door_name: String = "Glass entrance"
var opening_bounds: AABB
var open_fraction: float = 0.0
var feedback: String = ""
var _target: float = 0.0
var _from: float = 0.0
var _elapsed: float = 0.0
var _player: CharacterBody3D
var _feedback_until: int = 0
var _black: StandardMaterial3D
var _steel: StandardMaterial3D
var _glass: StandardMaterial3D
var _outlines: Array[MeshInstance3D] = []


func configure(title: String, centre: Vector3, width: float, height: float, double_leaf: bool = false) -> void:
	door_name = title
	name = title.replace(" ", "")
	position = centre
	opening_width = width
	opening_height = height
	opening_bounds = AABB(Vector3(-width*0.5,0,-0.09),Vector3(width,height,0.18))
	_black = StandardMaterial3D.new()
	_black.resource_name = "Entrance slim black aluminium"
	_black.albedo_color = Color("172026")
	_black.metallic = 0.72
	_black.roughness = 0.32
	_steel = StandardMaterial3D.new()
	_steel.resource_name = "Entrance satin stainless steel"
	_steel.albedo_color = Color("a9b5bd")
	_steel.metallic = 0.88
	_steel.roughness = 0.25
	_glass = StandardMaterial3D.new()
	_glass.resource_name = "Entrance clear blue-grey tempered glass"
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.albedo_color = Color(0.68,0.84,0.91,0.15)
	_glass.roughness = 0.12
	_glass.metallic = 0.04
	_glass.metallic_specular = 0.68
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	if double_leaf:
		_add_leaf("LeftHinge",-width*0.5,1.0,width*0.5-0.010,1.0)
		_add_leaf("RightHinge",width*0.5,-1.0,width*0.5-0.010,-1.0)
	else:
		_add_leaf("RightHinge",width*0.5,-1.0,width,-1.0)
	set_meta("campus_interactive_door",true)
	set_meta("hinge_duration_seconds",DURATION)
	set_meta("opening_direction","inward -Z")
	set_meta("opening_angle_degrees",90.0)
	set_meta("local_bounds",opening_bounds)


func _add_leaf(title: String, hinge_x: float, direction: float, width: float, angle_sign: float) -> void:
	var pivot := Node3D.new()
	pivot.name = title
	pivot.position.x = hinge_x
	add_child(pivot)
	pivots.append(pivot)
	# AnimatableBody follows its exact pivot, including while rotating. No solid
	# collider is ever toggled off merely because the leaf is open.
	var body := AnimatableBody3D.new()
	body.name = "MovingGlassDoorLeaf"
	body.sync_to_physics = false
	body.collision_layer = 1
	body.collision_mask = 1
	pivot.add_child(body)
	bodies.append(body)
	var centre_x: float = direction*width*0.5
	_box(body,"ClearGlass",Vector3(width-0.090,opening_height-0.100,0.012),Vector3(centre_x,opening_height*0.5,0),_glass,false)
	for x: float in [direction*0.025,direction*(width-0.025)]:
		_box(body,"BlackVerticalStile",Vector3(0.045,opening_height,LEAF_DEPTH),Vector3(x,opening_height*0.5,0),_black)
	for y: float in [0.025,opening_height-0.025]:
		_box(body,"BlackHorizontalRail",Vector3(width,0.050,LEAF_DEPTH),Vector3(centre_x,y,0),_black)
	var handle_x: float = direction*(width-0.15)
	for side: float in [-1.0,1.0]:
		_cylinder(body,"VerticalSteelPull",0.014,0.57,Vector3(handle_x,1.14,side*0.079),_steel)
		for y: float in [0.91,1.37]:
			var mount := _cylinder(body,"SteelPullMount",0.012,0.059,Vector3(handle_x,y,side*0.049),_steel)
			mount.rotation.x = PI*0.5
	for y: float in [0.23,opening_height*0.5,opening_height-0.23]:
		_cylinder(body,"OuterHingeBarrel",0.015,0.085,Vector3(0,y,0),_steel)
	var collision := CollisionShape3D.new()
	collision.name = "SolidMovingLeaf"
	var shape := BoxShape3D.new()
	shape.size = Vector3(width,opening_height,LEAF_DEPTH)
	collision.shape = shape
	collision.position = Vector3(centre_x,opening_height*0.5,0)
	body.add_child(collision)
	colliders.append(collision)
	leaves.append({"pivot":pivot,"direction":direction,"width":width,"angle_sign":angle_sign,"body":body,"collision":collision})
	var outline_material := StandardMaterial3D.new()
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.albedo_color = Color("4bdfd5")
	var outline_mesh := ImmediateMesh.new()
	outline_mesh.surface_begin(Mesh.PRIMITIVE_LINES,outline_material)
	for z: float in [-0.026,0.026]:
		var corners: Array[Vector3] = [Vector3(direction*0.01,0.01,z),Vector3(direction*(width-0.01),0.01,z),Vector3(direction*(width-0.01),opening_height-0.01,z),Vector3(direction*0.01,opening_height-0.01,z)]
		for edge: int in range(4):
			outline_mesh.surface_add_vertex(corners[edge])
			outline_mesh.surface_add_vertex(corners[(edge+1)%4])
	outline_mesh.surface_end()
	var outline := MeshInstance3D.new()
	outline.name = "ContextualDoorOutline"
	outline.mesh = outline_mesh
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.hide()
	body.add_child(outline)
	_outlines.append(outline)


func _box(parent: Node3D, title: String, dimensions: Vector3, at: Vector3, material: Material, casts_shadow: bool = true) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = title
	var box := BoxMesh.new()
	box.size = dimensions
	box.material = material
	mesh_node.mesh = box
	mesh_node.position = at
	if not casts_shadow: mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_node)
	return mesh_node


func _cylinder(parent: Node3D, title: String, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 12
	cylinder.material = material
	node.mesh = cylinder
	node.position = at
	parent.add_child(node)
	return node


func toggle(player: CharacterBody3D = null) -> bool:
	if is_animating:
		return false
	if is_instance_valid(player) and _player_in_sweep(player):
		feedback = "Step clear of the swinging door"
		_feedback_until = Time.get_ticks_msec()+1800
		return false
	_player = player
	feedback = ""
	_from = open_fraction
	_target = 0.0 if is_open else 1.0
	_elapsed = 0.0
	is_animating = true
	return true


func get_prompt() -> String:
	if Time.get_ticks_msec() < _feedback_until: return feedback
	if is_animating: return "Opening…" if _target > open_fraction else "Closing…"
	return "Press E to close" if is_open else "Press E to open"


func set_focused(focused: bool) -> void:
	for outline: MeshInstance3D in _outlines: outline.visible = focused


func _physics_process(delta: float) -> void:
	if not is_animating: return
	# Stop safely if the player enters the complete swing footprint mid-motion.
	# Stepping clear resumes the same motion; the door never pushes through them.
	if is_instance_valid(_player) and _player_in_sweep(_player):
		feedback = "Step clear to continue"
		_feedback_until = Time.get_ticks_msec()+250
		return
	_elapsed = minf(_elapsed+delta,DURATION)
	var progress: float = _elapsed/DURATION
	var eased: float = progress*progress*(3.0-2.0*progress)
	open_fraction = lerpf(_from,_target,eased)
	_apply_fraction()
	if _elapsed >= DURATION:
		is_animating = false
		is_open = _target > 0.5
		state_changed.emit(is_open)


func set_open_immediate(open: bool) -> void:
	is_animating = false
	is_open = open
	open_fraction = 1.0 if open else 0.0
	_target = open_fraction
	_apply_fraction()


func _apply_fraction() -> void:
	for leaf: Dictionary in leaves:
		(leaf.pivot as Node3D).rotation.y = float(leaf.angle_sign)*PI*0.5*open_fraction


func _player_in_sweep(player: CharacterBody3D) -> bool:
	var point: Vector3 = to_local(player.global_position)
	# The character's centre sits 0.89 m above its feet. Reject only the same
	# vertical storey and the inward quadrant swept by an individual door leaf.
	if point.y < -0.9 or point.y > opening_height+0.9: return false
	for leaf: Dictionary in leaves:
		var hinge_x: float = (leaf.pivot as Node3D).position.x
		var width: float = float(leaf.width)
		var far_x: float = hinge_x+float(leaf.direction)*width
		if point.x >= minf(hinge_x,far_x)-0.31 and point.x <= maxf(hinge_x,far_x)+0.31 and point.z >= -width-0.31 and point.z <= 0.25:
			return true
	return false


func target_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for leaf: Dictionary in leaves:
		var pivot: Node3D = leaf.pivot
		points.append(pivot.to_global(Vector3(float(leaf.direction)*float(leaf.width)*0.5,opening_height*0.5,0)))
	return points


func hit_distance(origin: Vector3, direction: Vector3, maximum: float = 2.0) -> float:
	var nearest: float = maximum+1.0
	for leaf: Dictionary in leaves:
		var pivot: Node3D = leaf.pivot
		var inverse: Transform3D = pivot.global_transform.affine_inverse()
		var width: float = float(leaf.width)
		var low_x: float = minf(0,float(leaf.direction)*width)
		var bounds := AABB(Vector3(low_x,0,-0.09),Vector3(width,opening_height,0.18))
		# Include the narrow meeting seam and slim frame edges in hover targeting.
		var local_hit: Variant = bounds.grow(0.016).intersects_ray(inverse*origin,(inverse.basis*direction).normalized())
		if local_hit == null: continue
		var point: Vector3 = pivot.global_transform*(local_hit as Vector3)
		if (point-origin).dot(direction) <= 0: continue
		nearest = minf(nearest,origin.distance_to(point))
	# Once open, aiming through the empty opening still offers a way to close it.
	if is_open or is_animating:
		var inverse := global_transform.affine_inverse()
		var opening_hit: Variant = opening_bounds.intersects_ray(inverse*origin,(inverse.basis*direction).normalized())
		if opening_hit != null:
			var point: Vector3 = global_transform*(opening_hit as Vector3)
			if (point-origin).dot(direction)>0: nearest=minf(nearest,origin.distance_to(point))
	return nearest
