extends SceneTree
const Computer = preload("res://scripts/computer_prop.gd")

func _init() -> void:
	call_deferred("run_validation")

func run_validation() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(Computer.ASSET, state) == OK)
	var source := doc.generate_scene(state)
	var packed := PackedScene.new()
	assert(packed.pack(source) == OK)
	packed.take_over_path(Computer.ASSET)
	source.free()
	var parent := Node3D.new()
	parent.transform = Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3(1.2, 1.2, 1.2)), Vector3(4, 2, -3))
	root.add_child(parent)
	for width: float in [0.5, 1.0, 2.0]:
		var base := Vector3(10, 1.5, 20)
		var result := Computer.create(parent, base, width)
		assert(not result.is_empty())
		var station := result.root as Node3D
		assert(station.global_position.is_equal_approx(base), "base must be world-space")
		assert(station.global_basis.is_equal_approx(Basis.IDENTITY), "display must face world +Z")
		assert(is_equal_approx(result.component_bounds.monitor.size.x, result.monitor_width))
		assert(result.monitor_width >= 0.60 and result.monitor_width <= 0.80)
		assert(absf(result.component_bounds.monitor.position.y) < 0.00001)
		assert(absf(result.component_bounds.tower.position.y) < 0.00001)
		assert(result.screen.distance_to(base + Vector3(0, 0.241399, -0.062372) * (result.monitor_width / 0.72)) < 0.00001)
		assert(station.find_child("sm_table_2m", true, false) == null)
		assert(station.find_child("sm_soundbox", true, false) == null)
		assert(result.meshes.size() == 37)
		print("PASS computer width=",width," monitor=",result.monitor_width," screen=",result.screen)
		station.queue_free()
	await process_frame
	quit()
