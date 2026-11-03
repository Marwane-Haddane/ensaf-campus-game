extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime: Node3D = load("res://scripts/campus_runtime.gd").new()
	root.add_child(runtime)
	await runtime.build()
	await physics_frame
	await physics_frame
	var ground: Dictionary = runtime.sample_ground_hits()
	var passed: bool = bool(runtime.stats.get("ready", false))
	for hit: Dictionary in ground.values():
		passed = passed and bool(hit.get("hit", false))
	var material_library: RefCounted = runtime.material_library
	var material_stats: Dictionary = material_library.stats
	passed = passed and int(material_stats.get("texture_sets", 0)) >= 10
	material_library.save_debug_textures("res://tools/polish_material_textures")
	var report: Dictionary = {"passed": passed, "ground": ground, "runtime": runtime.stats}
	var output: FileAccess = FileAccess.open("res://tools/polish_material_runtime_test.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	print("POLISH_MATERIAL_RUNTIME ", JSON.stringify(report))
	quit(0 if passed else 1)
