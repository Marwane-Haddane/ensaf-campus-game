extends SceneTree
const Door = preload("res://scripts/interactive_door.gd")
const DoorSystem = preload("res://scripts/campus_doors.gd")
var report := {"checks":0,"failures":[],"passed":false,"animation_samples":[],"source_install":{}}
var world: Node3D
var player: CharacterBody3D
var camera: Camera3D

func _init() -> void:
	call_deferred("run_test")

func check(value: bool, message: String, details: Variant = null) -> void:
	report.checks += 1
	if not value:
		report.failures.append({"check":message,"details":str(details)})
		print("DOOR_FAIL ",message," ",details)

func run_test() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	world.add_child(floor)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20,0.2,20)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.1
	floor.add_child(floor_shape)
	player = CharacterBody3D.new()
	player.safe_margin = 0.02
	world.add_child(player)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.78
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	player.add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 0.65
	player.add_child(camera)
	var double_door := Door.new()
	world.add_child(double_door)
	double_door.configure("Test double glass door",Vector3(0,0.014,0),2.20,2.23,true)
	player.position = Vector3(0,0.91,1.2)
	await physics_frame
	await physics_frame
	check(double_door.pivots.size()==2,"two independent outer hinges")
	check(double_door.colliders.size()==2,"each leaf keeps its own solid collision")
	check(not double_door.is_open and not double_door.is_animating,"starts closed")
	check(double_door.get_prompt()=="Press E to open","closed prompt")
	var hinges: Array[Vector3] = []
	for pivot: Node3D in double_door.pivots: hinges.append(pivot.global_position)
	await walk(Vector3(0,0,-1),65)
	check(player.position.z>=0.25,"closed double door physically blocks capsule",player.position)
	player.position = Vector3(0,0.91,1.2)
	check(double_door.toggle(player),"outside approach starts opening")
	for frame: int in range(10): await physics_frame
	var first_fraction: float = double_door.open_fraction
	check(first_fraction>0.01 and first_fraction<0.15,"smooth ease-in rather than immediate/full rotation",first_fraction)
	for frame: int in range(20): await physics_frame
	check(double_door.open_fraction>0.40 and double_door.open_fraction<0.60,"one-second midpoint around half open",double_door.open_fraction)
	report.animation_samples.append({"frame":30,"fraction":double_door.open_fraction})
	player.position = Vector3(0,0.91,-0.4)
	var paused_fraction: float = double_door.open_fraction
	for frame: int in range(8): await physics_frame
	check(is_equal_approx(paused_fraction,double_door.open_fraction),"motion pauses when player enters sweep")
	player.position = Vector3(0,0.91,1.2)
	for frame: int in range(40): await physics_frame
	check(double_door.is_open and not double_door.is_animating,"one-second motion completes once sweep clears")
	check(double_door.get_prompt()=="Press E to close","open prompt")
	for i: int in range(2):
		check(double_door.pivots[i].global_position.is_equal_approx(hinges[i]),"hinge position stays fixed",i)
		check(is_equal_approx(absf(double_door.pivots[i].rotation.y),PI*0.5),"leaf reaches exactly inward 90 degrees",i)
		check(not double_door.colliders[i].disabled,"open leaf remains solid rather than disabling physics",i)
		var leaf: Dictionary = double_door.leaves[i]
		var point: Vector3 = double_door.pivots[i].to_global(Vector3(float(leaf.direction)*float(leaf.width),1,0))
		check(point.z < -1.0,"double leaf swings inward, never out onto stairs",point)
	await walk(Vector3(0,0,-1),100)
	check(player.position.z < -1.9,"open double doorway lets capsule pass",player.position)
	player.position = Vector3(0,0.91,-0.5)
	check(not double_door.toggle(player),"closing refuses to crush player in doorway")
	check(double_door.is_open,"blocked close leaves door open")
	player.position = Vector3(0,0.91,1.2)
	check(double_door.toggle(player),"clear opening permits close")
	for frame: int in range(65): await physics_frame
	check(not double_door.is_open and is_zero_approx(double_door.open_fraction),"close returns exact original pose")
	player.position = Vector3(0,0.91,-0.6)
	check(not double_door.toggle(player),"opening refuses if player occupies inward swing")
	var single := Door.new()
	world.add_child(single)
	single.configure("Test right hinge",Vector3(4,0.014,0),1.50,2.68,false)
	check(single.pivots.size()==1 and is_equal_approx(single.pivots[0].position.x,0.75),"single door hinge is exactly on right edge")
	single.set_open_immediate(true)
	var free_edge: Vector3 = single.pivots[0].to_global(Vector3(-1.50,1,0))
	check(free_edge.z < -1.49,"right-hinged single leaf swings inward -Z",free_edge)
	check(is_equal_approx(single.pivots[0].rotation.y,-PI*0.5),"right hinge has correct rotation sign")
	await source_install_test()
	report.passed = report.failures.is_empty()
	FileAccess.open("res://tools/door_physics_test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DOOR_PHYSICS_TEST ",JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit(0 if report.passed else 1)

func walk(direction: Vector3, frames: int) -> void:
	for frame: int in range(frames):
		await physics_frame
		player.velocity = direction*2.0+Vector3.DOWN*1.0
		player.move_and_slide()

func source_install_test() -> void:
	var campus = load("res://scripts/campus_runtime.gd").new()
	world.add_child(campus)
	await campus.build()
	var system: Node3D = campus.get("door_system")
	if system==null:
		system=DoorSystem.new()
		campus.add_child(system)
		system.install(campus)
	report.source_install = system.stats
	check(system.doors.size()==4,"all four requested entrances installed")
	check(int(system.stats.moving_leaves)==7,"seven separate leaves across four entrances")
	check(int(system.stats.fixed_glazing_colliders)==4,"reception and atrium sidelights stay fixed and solid")
	check(int(system.stats.replaced_meshes)>=27,"old target panels/handles/backing/sill removed",system.stats.replaced_meshes)
	var reception: Node3D = system.doors[0]
	var cream: Node3D = system.doors[1]
	check(reception.get_meta("motion_kind","")=="sliding" and reception.pivots.size()==2,"reception uses separate sliding leaves")
	check(is_equal_approx(cream.global_position.y,0.534),"cream door clearance matches repaired .52 landing")
	var fixed_visible := 0
	var replaced_hidden := 0
	for mesh: MeshInstance3D in campus.mesh_nodes:
		var source: String = str(mesh.get_meta("campus_source_name",""))
		if source.begins_with("E5 clear upper transom"): fixed_visible+=1 if not mesh.get_meta("replaced_by_interactive_door",false) else 0
		if mesh.get_meta("replaced_by_interactive_door",false):
			if not mesh.visible: replaced_hidden+=1
	check(fixed_visible==4,"all original upper façade transoms preserved")
	check(replaced_hidden==int(system.stats.replaced_meshes),"all replaced originals hidden before rendering")
	await physics_frame
	await physics_frame
	player.global_position = Vector3(-37,1.85,-101.3)
	camera.look_at(Vector3(-37,2.20,-102.57),Vector3.UP)
	await physics_frame
	var near: Dictionary = system.get_target(camera,player,2.0)
	check(not near.is_empty() and near.get("node")==reception,"crosshair hover finds nearby reception door",near)
	player.global_position.z = -99.4
	await physics_frame
	check(system.get_target(camera,player,2.0).is_empty(),"door prompt hidden beyond two metres")
	player.global_position = Vector3(-37,1.85,-101.3)
	camera.look_at(Vector3(-37,2.20,-102.57),Vector3.UP)
	var wall := StaticBody3D.new()
	world.add_child(wall)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(2.0,3.0,0.1)
	collider.shape=box
	collider.position=Vector3(-37,2.0,-102.1)
	wall.add_child(collider)
	await physics_frame
	check(system.get_target(camera,player,2.0).is_empty(),"obstructing wall suppresses prompt")
	wall.queue_free()
