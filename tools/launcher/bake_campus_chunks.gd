extends SceneTree
## Offline derivative of the exact campus. Small scene chunks and pre-cooked
## triangle shapes avoid one large main-thread instantiation/collision job.
const Runtime = preload("res://scripts/campus_runtime.gd")
func _init() -> void: call_deferred("bake")
func bake() -> void:
	var runtime = Runtime.new()
	runtime._load_manifest()
	var packed := load("res://assets/campus.glb") as PackedScene
	var source := packed.instantiate() as Node3D
	var meshes: Array[MeshInstance3D] = []
	collect(source,meshes)
	var shape_cache: Dictionary = {}
	for mesh: MeshInstance3D in meshes:
		var key: String = str(mesh.mesh.get_instance_id())
		mesh.set_meta("derived_mesh_key",key)
		for idx: int in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(idx)
			if material != null: material.set_meta("derived_material_key",str(material.get_instance_id()))
		var record: Dictionary = runtime._record_for(mesh)
		var name: String = str(record.get("name",mesh.name))
		var role: String = str(record.get("role","detail"))
		if role in ["architecture","walkable","glass"] and not runtime._is_passable_door(name,role):
			if not shape_cache.has(key):
				var faces := mesh.mesh.get_faces()
				var pieces: Array[ConcavePolygonShape3D] = []
				for offset: int in range(0,faces.size(),6144):
					var shape := ConcavePolygonShape3D.new()
					shape.set_faces(faces.slice(offset,mini(offset+6144,faces.size())))
					shape.backface_collision = true
					pieces.append(shape)
				shape_cache[key] = pieces
			mesh.set_meta("derived_triangle_shapes",shape_cache[key])
	var folder := "res://assets/runtime_campus"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var manifest := {"version":1,"source_sha256":FileAccess.get_sha256("res://assets/campus.glb"),"source_meshes":meshes.size(),"chunks":[],"triangle_shapes":shape_cache.size()}
	# The imported scene is a flat collection of campus objects. Group complete
	# top-level subtrees, preserving all local transforms and original names.
	var index := 0
	while source.get_child_count()>0:
		var chunk := Node3D.new()
		chunk.name = "CampusSection%03d" % index
		chunk.transform = source.transform
		for count: int in range(64):
			if source.get_child_count()==0: break
			var child: Node = source.get_child(0)
			source.remove_child(child)
			chunk.add_child(child)
			set_owners(child,chunk)
		var scene := PackedScene.new()
		var result := scene.pack(chunk)
		var path := folder.path_join("section_%03d.scn" % index)
		if result == OK: result = ResourceSaver.save(scene,path,ResourceSaver.FLAG_BUNDLE_RESOURCES|ResourceSaver.FLAG_COMPRESS)
		if result != OK:
			push_error("Campus chunk bake failed: "+path)
			quit(1)
			return
		manifest.chunks.append(path)
		chunk.free()
		index += 1
	FileAccess.open(folder.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
	print("CAMPUS_CHUNKS_BAKED ",JSON.stringify(manifest))
	source.free()
	runtime.free()
	quit()
func collect(node: Node,result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null: result.append(node)
	for child: Node in node.get_children(): collect(child,result)
func set_owners(node: Node,owner_node: Node) -> void:
	node.owner = owner_node
	for child: Node in node.get_children(): set_owners(child,owner_node)
