extends SceneTree
## Regression against the actual player, original campus, and installed entrances.
var game
var report := {"passed":false,"checks":0,"failures":[],"captures":[],"ground":[]}

func _init() -> void:
	call_deferred("run_test")

func verify(value: bool, message: String, detail: Variant = null) -> void:
	report.checks+=1
	if not value:
		report.failures.append({"check":message,"detail":str(detail)})
		print("ENTRANCE_BUG_FAIL ",message," ",detail)

func run_test() -> void:
	game=load("res://main.tscn").instantiate()
	if "--runtime-sections" in OS.get_cmdline_user_args():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime_campus/manifest.json"))
		for path: String in manifest.chunks: game.prepared_sections.append(load(path) as PackedScene)
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.training.set_process_input(false)
	while not game.ready_to_play: await process_frame
	game._resume()
	var doors: Array = game.campus.door_system.doors
	verify(doors.size()==4,"Four independent entrances installed")
	verify(game.campus.stats.atrium_repair.installed,"Atrium repair installed before batching")
	var slider: Node3D=doors[0]
	var front: Node3D=doors[2]
	var side: Node3D=doors[3]
	verify(slider.get_meta("motion_kind","")=="sliding" and slider.pivots.size()==2,"Reception uses two sliding panels")
	verify(front.pivots.size()==2 and side.pivots.size()==1,"Atrium double and side single leaves remain hinged")
	front.set_open_immediate(true)
	side.set_open_immediate(true)
	for frame: int in range(3): await physics_frame
	# This grid formerly dropped 1.38 m into the sunken-hall foundation.
	for x: float in [-3.50,-3.1,-2.65,-2.30]:
		for z: float in [-104.5,-105.0,-105.6,-106.1,-106.65,-107.8,-108.3]:
			var result: Dictionary=ground(x,z)
			report.ground.append(result)
			verify(result.hit and absf(float(result.y)-1.814)<.005,"Continuous level side landing",result)
	for z: float in [-103.7,-103.9,-104.1,-104.5,-104.8]:
		var result: Dictionary=ground(-5.8,z)
		verify(result.hit and absf(float(result.y)-1.814)<.005,"Front threshold/landing flush",result)
	# Tile rectangles share edges rather than relying on invisible floor colliders.
	var repair_root: Node3D=game.campus.get_meta("atrium_repair").root
	var side_mesh := repair_root.get_node("ContinuousSideLanding") as MeshInstance3D
	verify(side_mesh.visible and side_mesh.get_child_count()>0,"Side repair includes actual visible geometry and collider")
	var source_preserved: Dictionary={}
	for mesh: MeshInstance3D in game.campus.mesh_nodes:
		var name: String=str(mesh.get_meta("campus_source_name",""))
		if name in ["D9 transparent entrance door leaf.001","D9 level access landing.001","D7 polished lower hall floor"]:
			source_preserved[name]=not bool(mesh.get_meta("replaced_by_approved_asset",false))
	for name: String in source_preserved: verify(source_preserved[name],"Unrelated upper doorway/lower hall preserved: "+name)
	front.set_open_immediate(false)
	side.set_open_immediate(false)
	await check_slider(slider)
	await check_hinged(front,Vector3(-5.8,2.72,-102.55),Vector3(-5.8,2.9,-103.975),"atrium-front")
	await check_hinged(side,Vector3(-.65,2.72,-106.65),Vector3(-2.155,2.9,-106.65),"atrium-side")
	# With the portico door open, the internal passage must stay unobstructed.
	await walk_side_route(side)
	await walk_front_stairs(front)
	verify(game.training.get_completion_count()==0,"Door and floor tests do not advance the mission")
	await view(Vector3(-3.30,3.35,-105.0),Vector3(-2.155,2.55,-106.65))
	await capture("entrance-fixed-side-landing")
	await view(Vector3(-2.8,3.4,-107.4),Vector3(-5.8,2.8,-103.5))
	await capture("entrance-fixed-atrium-inside")
	finish()

func ground(x: float,z: float) -> Dictionary:
	var ray:=PhysicsRayQueryParameters3D.create(Vector3(x,2.05,z),Vector3(x,-.5,z),1,[game.player.get_rid()])
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
	return {"x":x,"z":z,"hit":not hit.is_empty(),"y":float(hit.position.y) if not hit.is_empty() else -99.0}

func e_press() -> void:
	var event:=InputEventAction.new()
	event.action="interact"
	event.pressed=true
	game._unhandled_input(event)

func view(player_position: Vector3,target: Vector3) -> void:
	game.player.global_position=player_position
	game.player.velocity=Vector3.ZERO
	game.camera.look_at(target,Vector3.UP)
	game.player.force_update_transform()
	game.camera.force_update_transform()
	await process_frame
	await process_frame
	game._process(0)

func check_slider(door: Node3D) -> void:
	door.set_open_immediate(false)
	await view(Vector3(-37,1.85,-101.3),Vector3(-37,2.2,-102.67))
	verify(game._closest.get("node")==door,"E aims at reception slider centre seam")
	await capture("entrance-fixed-reception-closed")
	var original: Array[Vector3]=[]
	for pivot: Node3D in door.pivots: original.append(pivot.position)
	e_press()
	verify(door.is_animating,"Normal E starts reception slide")
	for frame: int in range(30): await physics_frame
	verify(absf(door.open_fraction-.5)<.08,"Sliding midpoint uses one-second easing",door.open_fraction)
	for frame: int in range(36): await physics_frame
	verify(door.is_open,"Reception sliding finishes fully open")
	verify(door.pivots[0].position.x<original[0].x-1.7 and door.pivots[1].position.x>original[1].x+1.7,"Panels slide in opposite directions")
	for pivot: Node3D in door.pivots: verify(pivot.rotation.length()<.0001,"Sliding panels do not rotate")
	game._process(0)
	verify(game._closest.get("node")==door,"Open reception remains targetable")
	await capture("entrance-fixed-reception-open")
	game.player.position=Vector3(-37,1.85,-102.67)
	verify(not door.toggle(game.player),"Sliding door cannot close on player in doorway")
	await view(Vector3(-37,1.85,-101.3),Vector3(-37,2.2,-102.67))
	e_press()
	for frame: int in range(66): await physics_frame
	verify(not door.is_open,"Second E closes reception slider")
	await walk_closed_open(door,Vector3(-37,1.85,-101.2),Vector3(0,0,-1),Vector3(-37,1.85,-104.2))
	await view(Vector3(-37,1.85,-99.0),Vector3(-37,2.2,-102.67))
	verify(game._closest.get("node")!=door,"Reception prompt hidden outside two metres")

func check_hinged(door: Node3D,approach: Vector3,target: Vector3,name: String) -> void:
	door.set_open_immediate(false)
	await view(approach,target)
	verify(game._closest.get("node")==door,name+" exact E targeting")
	verify(game.focus_overlay._title.text=="Press E to open",name+" correct open prompt")
	await capture("entrance-fixed-"+name+"-closed")
	var anchors: Array[Vector3]=[]
	for pivot: Node3D in door.pivots: anchors.append(pivot.global_position)
	e_press()
	verify(door.is_animating,name+" normal E starts smooth animation")
	for frame: int in range(12): await physics_frame
	var paused: float=door.open_fraction
	game._show_menu("PAUSED / CAMPUS EXPLORATION","",false)
	for frame: int in range(12): await physics_frame
	verify(is_equal_approx(paused,door.open_fraction),name+" freezes with pause menu")
	game._resume()
	for frame: int in range(66): await physics_frame
	verify(door.is_open and not door.is_animating,name+" fully opens after resume")
	for i: int in range(door.pivots.size()):
		verify(door.pivots[i].global_position.is_equal_approx(anchors[i]),name+" hinges remain fixed")
		verify(absf(absf(door.pivots[i].rotation.y)-PI*.5)<.0001,name+" ninety degree rotation")
	await capture("entrance-fixed-"+name+"-open")
	game._process(0)
	e_press()
	for frame: int in range(66): await physics_frame
	verify(not door.is_open,name+" closes with another E")
	var direction: Vector3=Vector3(0,0,-1) if door.pivots.size()==2 else Vector3(-1,0,0)
	# The side route turns along the landing after entry; the far safety rail
	# correctly prevents continuing straight off its edge into the stairs.
	await walk_closed_open(door,approach,direction,approach+direction*(3.2 if door.pivots.size()==2 else 2.4))

func walk_closed_open(door: Node3D,start: Vector3,direction: Vector3,finish: Vector3) -> void:
	game.player.position=start
	game.player.velocity=Vector3.ZERO
	door.set_open_immediate(false)
	for frame: int in range(80):
		await physics_frame
		step(direction)
	var closed_distance: float=(game.player.position-start).dot(direction)
	verify(closed_distance<2.1,door.door_name+" closed collision blocks player",game.player.position)
	game.player.position=start
	game.player.velocity=Vector3.ZERO
	door.set_open_immediate(true)
	for frame: int in range(125):
		await physics_frame
		step(direction)
	var expected_distance: float=(finish-start).dot(direction)
	verify((game.player.position-start).dot(direction)>expected_distance-.3,door.door_name+" open passage is walkable",game.player.position)
	verify(game.player.position.y>1.4,door.door_name+" player remains on landing",game.player.position)

func step(direction: Vector3) -> void:
	game.player.velocity=direction*2.0+Vector3.DOWN*2.0
	var motion: Vector3=direction*2.0/60.0
	if game.player.is_on_floor() and game.player.test_move(game.player.global_transform,motion):
		var raised: Transform3D=game.player.global_transform.translated(Vector3.UP*.28)
		if not game.player.test_move(raised,motion): game.player.position.y+=.28
	game.player.move_and_slide()

func walk_side_route(door: Node3D) -> void:
	door.set_open_immediate(true)
	game.player.position=Vector3(-3.0,2.72,-104.7)
	for frame: int in range(98):
		await physics_frame
		step(Vector3(0,0,-1))
	verify(game.player.position.z<-107.7,"Side corridor stays clear with door open",game.player.position)
	verify(absf(game.player.position.y-2.704)<.06,"Crossing former floor gap never falls to sunken hall",game.player.position)

func walk_front_stairs(door: Node3D) -> void:
	door.set_open_immediate(true)
	game.player.position=Vector3(-4.6,2.72,-104.5)
	for frame: int in range(165):
		await physics_frame
		step(Vector3(0,0,-1))
	verify(game.player.position.z<-109.3,"Original adjacent stair remains traversable",game.player.position)
	verify(game.player.position.y>.95 and game.player.position.y<1.55,"Stairs still reach original sunken floor",game.player.position)

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame: int in range(3): await process_frame
	RenderingServer.force_draw(false)
	var path: String="res://tools/"+name+".png"
	root.get_texture().get_image().save_png(path)
	report.captures.append(path)

func finish() -> void:
	report.passed=report.failures.is_empty()
	FileAccess.open("res://tools/entrance_bugfix_test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ENTRANCE_BUGFIX ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
