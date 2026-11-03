extends SceneTree
## Production installation, multi-surface preservation and exact material rollback.
const Polish = preload("res://scripts/antigravity/environment_polish.gd")
class MockGame extends Node3D:
	var ready_to_play := true
	var imported_props: Array = []
class MockCampus extends Node3D:
	var mesh_nodes: Array = []

var report := {"passed":false,"checks":0,"failures":[],"production":{}}

func _init() -> void:
	call_deferred("run_test")

func verify(condition: bool, message: String) -> void:
	report.checks += 1
	if not condition:
		report.failures.append(message)
		print("POLISH_INTEGRATION_FAIL ", message)

func material(label: String, color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.resource_name = label
	result.albedo_color = color
	return result

func run_test() -> void:
	var fixture := MockGame.new()
	root.add_child(fixture)
	var campus := MockCampus.new()
	campus.name = "CampusRuntime"
	fixture.add_child(campus)
	var batches := Node3D.new()
	batches.name = "CampusRenderBatches"
	campus.add_child(batches)
	var leaves := material("Campus foliage", Color("3f6724"))
	var wood := material("Campus oak wood", Color("8a5931"))
	var protected := material("Powered display", Color("12dddd"))
	protected.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var source_mesh := ArrayMesh.new()
	var box := BoxMesh.new()
	for mat: Material in [leaves, wood, protected]:
		source_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.surface_get_arrays(0))
		source_mesh.surface_set_material(source_mesh.get_surface_count()-1, mat)
	var original := MultiMesh.new()
	original.transform_format = MultiMesh.TRANSFORM_3D
	original.mesh = source_mesh
	original.instance_count = 2
	original.set_instance_transform(0, Transform3D.IDENTITY)
	original.set_instance_transform(1, Transform3D(Basis.IDENTITY,Vector3(2,0,0)))
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = original
	batches.add_child(batch)
	var repairs := Node3D.new()
	repairs.name = "AtriumEntranceRepairs"
	campus.add_child(repairs)
	var overridden := MeshInstance3D.new()
	overridden.mesh = BoxMesh.new()
	overridden.material_override = wood
	repairs.add_child(overridden)
	var polish := Polish.new()
	fixture.add_child(polish)
	verify(polish.install(fixture).installed, "Synthetic installation succeeds")
	verify(batch.material_override == null, "Multi-surface batch keeps separate surface materials")
	verify(batch.multimesh != original, "MultiMesh resource copied before changing its mesh")
	verify(batch.multimesh.mesh != source_mesh, "Shared source mesh preserved")
	verify(batch.multimesh.mesh.surface_get_material(0).resource_name == leaves.resource_name, "Foliage retains its own finish")
	verify(batch.multimesh.mesh.surface_get_material(1).resource_name == wood.resource_name, "Wood retains its own finish")
	verify(batch.multimesh.mesh.surface_get_material(2) == protected, "Unshaded screen surface untouched")
	verify(source_mesh.surface_get_material(0) == leaves and source_mesh.surface_get_material(1) == wood, "Original multi-surface materials unchanged")
	verify(batch.multimesh.get_instance_transform(1) == original.get_instance_transform(1), "Instance transforms retained")
	verify(overridden.material_override != wood and overridden.material_override.get_meta("antigravity_polished",false), "Repair material_override is actually tuned")
	verify(polish.install(fixture).already_installed, "Repeated install is idempotent")
	verify(polish.uninstall().errors.is_empty(), "Synthetic rollback succeeds")
	verify(batch.multimesh == original and batch.material_override == null, "Exact original batch resource restored")
	verify(overridden.material_override == wood, "Exact original repair override restored")
	fixture.queue_free()
	await process_frame

	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	var started := Time.get_ticks_msec()
	while not game.ready_to_play and Time.get_ticks_msec()-started < 120000:
		await process_frame
	verify(game.ready_to_play, "Actual production game reaches readiness")
	if game.ready_to_play:
		var disabled := "--no-polish" in OS.get_cmdline_user_args()
		verify(bool(game.polish_stats.get("installed",false)) == not disabled, "Production respects the --no-polish opt-out")
		if not disabled:
			verify(is_instance_valid(game.environment_polish) and game.environment_polish.is_installed(), "Production retains one installed module")
			var original_node: Node = game.environment_polish
			game._install_environment_polish()
			verify(game.environment_polish == original_node, "Production initializer cannot duplicate the module")
			var rollback: Dictionary = game.environment_polish.uninstall()
			verify(rollback.errors.is_empty(), "Actual production rollback restores target resources")
			await process_frame
			var screens: Array = []
			var physics: Array = []
			var batches_snapshot: Array = []
			collect_snapshot(game,screens,physics,batches_snapshot)
			var reinstall: Dictionary = game.environment_polish.install(game)
			verify(reinstall.installed and not reinstall.already_installed, "Production overlay reinstalls cleanly")
			for entry: Dictionary in screens:
				verify(entry.node.get_active_material(entry.surface) == entry.material, "Authored display preserved: " + str(entry.node.name))
			for entry: Dictionary in physics:
				verify(entry.node.global_transform == entry.transform and entry.node.disabled == entry.disabled and entry.node.shape == entry.shape, "Visual overlay leaves collider unchanged")
			for entry: Dictionary in batches_snapshot:
				var actual: MultiMesh = entry.node.multimesh
				verify(actual.instance_count == entry.resource.instance_count and actual.mesh.get_surface_count() == entry.resource.mesh.get_surface_count(), "Batch surface/instance counts retained")
				if entry.resource.mesh.get_surface_count() > 1 and entry.node.material_override == null:
					for idx: int in range(actual.mesh.get_surface_count()):
						var before: Material = entry.resource.mesh.surface_get_material(idx)
						var after: Material = actual.mesh.surface_get_material(idx)
						verify(before == after or before.resource_name == after.resource_name, "Distinct batch surface finish retained")
			report.production = {"screens_checked":screens.size(),"colliders_checked":physics.size(),"batches_checked":batches_snapshot.size(),"resource_counts":reinstall.resource_counts}
		verify(game.campus.door_system.doors.size()==4 and game.stations.size()==5, "All four entrances and five response stations retained")
	game.queue_free()
	await process_frame
	report.passed = report.failures.is_empty()
	var suffix := "-disabled" if "--no-polish" in OS.get_cmdline_user_args() else ""
	FileAccess.open("res://tools/polish_integration_test%s.json" % suffix,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("POLISH_INTEGRATION_RESULT ",JSON.stringify(report))
	quit(0 if report.passed else 1)

func collect_snapshot(node: Node, screens: Array, physics: Array, batches_snapshot: Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for idx: int in range(node.mesh.get_surface_count()):
			var mat: Material = node.get_active_material(idx)
			if mat is BaseMaterial3D and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				screens.append({"node":node,"surface":idx,"material":mat})
	if node is CollisionShape3D:
		physics.append({"node":node,"transform":node.global_transform,"disabled":node.disabled,"shape":node.shape})
	if node is MultiMeshInstance3D:
		batches_snapshot.append({"node":node,"resource":node.multimesh})
	for child: Node in node.get_children():
		collect_snapshot(child,screens,physics,batches_snapshot)
