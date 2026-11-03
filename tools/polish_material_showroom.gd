extends SceneTree

var library = preload("res://scripts/campus_materials.gd").new()
var world: Node3D

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440, 1000)
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset-manifest.json")) as Dictionary
	library.configure_manifest(parsed["materials"] as Array)
	var originals: Dictionary = {}
	for record: Dictionary in parsed["materials"]:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.resource_name = str(record["name"])
		var color: Array = record["color_linear"] as Array
		material.albedo_color = Color(float(color[0]), float(color[1]), float(color[2]), 1.0).linear_to_srgb()
		material.albedo_color.a = float(record["alpha"])
		material.roughness = float(record["roughness"])
		material.metallic = float(record["metallic"])
		originals[material.resource_name] = material
	world = Node3D.new()
	root.add_child(world)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("253344")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9e6f0")
	environment.ambient_light_energy = 0.24
	environment.ambient_light_sky_contribution = 0.0
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-25,0)
	sun.light_energy = 0.40
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.position = Vector3(1.0,4.0,3.0)
	fill.omni_range = 20.0
	fill.light_energy = 1.2
	world.add_child(fill)
	var specs: Array[Dictionary] = [
		{"label":"MINERAL RENDER", "match":"D7 warm white mineral render"},
		{"label":"LIMESTONE", "match":"E5 warm ivory limestone - subtle horizontal pores"},
		{"label":"SLATE", "match":"D7 slate grey tone 0"},
		{"label":"TERRAZZO", "match":"R4 speckled terrazzo tile 0"},
		{"label":"HONED FLOOR", "match":"D7 honed cream interior stone"},
		{"label":"EXTERIOR PAVING", "match":"D7 sandstone approach paving"},
		{"label":"OAK VENEER", "match":"E6 oak vertical panel grain"},
		{"label":"CHERRY PLYWOOD", "match":"E9 satin dark cherry bent plywood"},
		{"label":"WOVEN FABRIC", "match":"E9 fine woven crimson upholstery"},
		{"label":"LAWN", "match":"D7 varied green lawn"},
		{"label":"TREE BARK", "match":"D7 natural rough tree bark"},
		{"label":"STAINLESS", "match":"D7 satin stainless rails"},
	]
	for index: int in range(specs.size()):
		var spec: Dictionary = specs[index]
		var source: Material = originals.get(str(spec["match"])) as Material
		if source == null:
			push_warning("Showroom source absent: " + str(spec["match"]))
			continue
		var location: Vector3 = Vector3(float(index%4)*2.0,0.0,-float(floori(float(index)/4.0))*2.25)
		var surface: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(1.72,0.08,1.75)
		surface.mesh = box
		surface.position = location
		surface.material_override = library.material_for(source)
		world.add_child(surface)
		var sphere: MeshInstance3D = MeshInstance3D.new()
		var sphere_mesh: SphereMesh = SphereMesh.new()
		sphere_mesh.radius = 0.42
		sphere_mesh.height = 0.84
		sphere_mesh.radial_segments = 32
		sphere_mesh.rings = 16
		sphere.mesh = sphere_mesh
		sphere.position = location + Vector3(0.0,0.48,-0.1)
		sphere.material_override = surface.material_override
		world.add_child(sphere)
		var label: Label3D = Label3D.new()
		label.text = str(spec["label"])
		label.font_size = 28
		label.pixel_size = 0.0065
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = location+Vector3(0.0,0.16,0.85)
		world.add_child(label)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(8.6,8.8,9.4)
	world.add_child(camera)
	camera.look_at(Vector3(2.8,0.1,-2.0))
	camera.fov = 48.0
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.5
	camera.current = true
	for _frame: int in range(20):
		await process_frame
	RenderingServer.force_draw(false)
	var image: Image = root.get_texture().get_image()
	image.save_png("res://tools/polish_material_showroom.png")
	library.save_debug_textures("res://tools/polish_material_textures")
	print("POLISH_MATERIAL_SHOWROOM ", JSON.stringify(library.stats))
	quit()
