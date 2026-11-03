extends RefCounted
## Local atrium thresholds and the missing side-landing section. No layout changes.
const FLOOR_Y: float = 1.814
const REPLACED: Array[String] = ["D7 entrance threshold","D7 short white floor band","D9 low door threshold","D9 level access landing","D9 inside access landing balustrade","D9 glazed access horizontal frame"]

static func install(campus: Node3D) -> Dictionary:
	if campus.has_meta("atrium_repair"): return campus.get_meta("atrium_repair")
	var sources: Dictionary = {}
	for mesh: MeshInstance3D in campus.get("mesh_nodes"):
		var title: String = str(mesh.get_meta("campus_source_name",""))
		if title in REPLACED or title in ["D7 raised entrance landing","D9 continuous portico landing stone finish"]: sources[title]=mesh
	for title: String in REPLACED:
		if not sources.has(title): return {"installed":false,"missing":title}
	var root := Node3D.new()
	root.name = "AtriumEntranceRepairs"
	campus.add_child(root)
	var source_stone: Material = sources["D7 raised entrance landing"].get_active_material(0)
	var stone: StandardMaterial3D = source_stone.duplicate() as StandardMaterial3D
	var tile := Image.create(128,128,false,Image.FORMAT_RGB8)
	tile.fill(Color(.985,.985,.985))
	for pixel: int in range(128):
		tile.set_pixel(0,pixel,Color(.82,.82,.82))
		tile.set_pixel(pixel,0,Color(.82,.82,.82))
	tile.generate_mipmaps()
	stone.albedo_texture=ImageTexture.create_from_image(tile)
	stone.uv1_triplanar=true
	stone.uv1_world_triplanar=true
	stone.uv1_scale=Vector3.ONE/.60
	stone.roughness=.46
	# Shared world coordinates keep the repaired tiles aligned with the portico.
	var portico: MeshInstance3D=sources["D9 continuous portico landing stone finish"]
	portico.mesh.surface_set_material(0,stone)
	var white: Material = sources["D7 short white floor band"].get_active_material(0)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("8d9ba3")
	metal.metallic = 0.80
	metal.roughness = 0.30
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("172026")
	black.metallic = 0.65
	black.roughness = 0.34
	for title: String in REPLACED:
		var source: MeshInstance3D = sources[title]
		source.hide()
		source.set_meta("replaced_by_approved_asset",true)
		_disable(source)
	# Keep the original facade base under fixed glass, cut only the actual doorway.
	_box(root,"FixedFrontBaseLeft",Vector3(-13.275,1.655,-104.03),Vector3(-6.72,1.865,-103.67),white)
	_box(root,"FixedFrontBaseRight",Vector3(-4.88,1.655,-104.03),Vector3(-3.825,1.865,-103.67),white)
	# Disjoint finish rectangles meet at shared edges; no coplanar overlays.
	_box(root,"FrontLandingFinish",Vector3(-13.0,1.800,-104.87),Vector3(-2.5,FLOOR_Y,-104.03),stone)
	_box(root,"FlushFrontDoorThreshold",Vector3(-6.72,1.790,-104.03),Vector3(-4.88,FLOOR_Y,-103.67),stone)
	_box(root,"ContinuousSideLanding",Vector3(-3.69,1.594,-108.50),Vector3(-2.2,FLOOR_Y,-104.87),stone)
	_box(root,"FrontSideConnection",Vector3(-2.5,1.594,-104.87),Vector3(-2.2,FLOOR_Y,-104.03),stone)
	# The source bottom rail crossed the old side doorway; retain only fixed spans.
	_box(root,"SideFixedSillBack",Vector3(-2.1925,1.8115,-107.30),Vector3(-2.1175,1.8665,-107.22),black)
	_box(root,"SideFixedSillFront",Vector3(-2.1925,1.8115,-106.08),Vector3(-2.1175,1.8665,-102.90),black)
	_box(root,"LowSideThreshold",Vector3(-2.23,1.790,-107.22),Vector3(-2.08,1.817,-106.08),metal)
	# Anchor a continuous 1.05 m rail along the open stair side, never across a route.
	for z: float in [-108.40,-107.30,-106.20,-105.10]:
		_box(root,"RailFoot",Vector3(-3.70,FLOOR_Y,z-.050),Vector3(-3.60,FLOOR_Y+.012,z+.050),metal)
		_box(root,"RailPost",Vector3(-3.672,FLOOR_Y,z-.022),Vector3(-3.628,FLOOR_Y+1.05,z+.022),metal)
	for offset: float in [0.35,0.69,1.05]:
		_box(root,"SideLandingHandrail",Vector3(-3.672,FLOOR_Y+offset-.018,-108.44),Vector3(-3.628,FLOOR_Y+offset+.018,-105.05),metal)
	_repair_reception_floor(campus,root)
	var result := {"installed":true,"replaced":REPLACED,"floor_y":FLOOR_Y,"side_landing":AABB(Vector3(-3.69,1.594,-108.50),Vector3(1.49,.22,3.63)),"root":root}
	campus.set_meta("atrium_repair",result)
	return result

static func _repair_reception_floor(campus: Node3D,parent: Node3D) -> void:
	var threshold_material: Material
	for mesh: MeshInstance3D in campus.get("mesh_nodes"):
		var title: String=str(mesh.get_meta("campus_source_name",""))
		if title=="E5 limestone flush entrance threshold": threshold_material=mesh.get_active_material(0)
		if title not in ["Campus plaza broad terrace step.006","Campus plaza broad terrace step.007","Campus plaza broad terrace step.008"]: continue
		var bounds: AABB=mesh.global_transform*mesh.mesh.get_aabb()
		var material: Material=mesh.get_active_material(0)
		mesh.hide()
		mesh.set_meta("replaced_by_approved_asset",true)
		_disable(mesh)
		# Keep the plaza stair everywhere outside the original reception frontage.
		var left := _box(parent,title+"Left",bounds.position,Vector3(-40.60,bounds.end.y,bounds.end.z),material)
		var right := _box(parent,title+"Right",Vector3(-33.40,bounds.position.y,bounds.position.z),bounds.end,material)
		left.cast_shadow=mesh.cast_shadow
		right.cast_shadow=mesh.cast_shadow
	# Fill only the original 20 cm strip behind the existing threshold. The source
	# reception finish and threshold meet this strip at its exact edges.
	_box(parent,"ReceptionThresholdConnection",Vector3(-40.60,.910,-103.1525),Vector3(-33.40,.9375,-102.950),threshold_material)

static func _disable(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer=0
		(node as CollisionObject3D).collision_mask=0
	for child: Node in node.get_children(): _disable(child)

static func _box(parent: Node3D,title: String,low: Vector3,high: Vector3,material: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.name=title
	var mesh:=BoxMesh.new()
	mesh.size=high-low
	mesh.material=material
	node.mesh=mesh
	node.position=(low+high)*.5
	node.layers=3
	node.set_meta("campus_source_name","Atrium repair / "+title)
	parent.add_child(node)
	var body:=StaticBody3D.new()
	body.set_meta("campus_source_name","Atrium repair / "+title)
	body.set_meta("campus_role","walkable")
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=high-low
	shape.shape=box
	body.add_child(shape)
	node.add_child(body)
	return node
