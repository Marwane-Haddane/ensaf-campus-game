extends SceneTree
## Challenger M4 Tier 5 Adversarial Coverage Hardening Test Suite
## White-box stress testing of res://scripts/antigravity/environment_polish.gd
##
## Stresses untested branches, error recovery paths, boundary conditions:
## - Suite 1: Missing or partial scene subtrees (missing CampusRenderBatches, 0 children, non-mesh children)
## - Suite 2: Missing or altered ceiling backing node (absent from mesh_nodes, non-mesh, null material)
## - Suite 3: Missing or unusual lights / WorldEnvironment (0 suns, multiple suns, missing env, null env)
## - Suite 4: Edge case meshes & surfaces (0 surfaces, null mesh, null materials, primitive types)
## - Suite 5: Material guardrails (ShaderMaterial, unshaded, screen/display keywords, prop textures, glazing frame)
## - Suite 6: Hostile mutation & reversibility (freed nodes prior to uninstall, double install/uninstall, unready)
## - Suite 7: Full live production scene validation on res://main.tscn (batch preservation, draw calls, reversibility)

const POLISH_SCRIPT_PATH: String = "res://scripts/antigravity/environment_polish.gd"
const REPORT_PATH: String = "res://tools/antigravity/challenger_m4_coverage_report.json"

var failures: Array[Dictionary] = []
var results: Dictionary = {
	"timestamp": "",
	"passed": false,
	"total_assertions": 0,
	"passed_assertions": 0,
	"failed_assertions": 0,
	"failures": [],
	"suites": {}
}

# --- Mock Classes for Synthetic Unit Scenarios ---
class MockGame extends Node3D:
	var ready_to_play: bool = true
	var imported_props: Array = []

class MockCampus extends Node3D:
	var mesh_nodes: Array = []


func _init() -> void:
	call_deferred("_run_all_coverage_tests")


func assert_true(condition: bool, suite_name: String, check_name: String, details: Variant = "") -> bool:
	results["total_assertions"] += 1
	if not results["suites"].has(suite_name):
		results["suites"][suite_name] = {"passed": 0, "failed": 0, "checks": []}
	
	if condition:
		results["passed_assertions"] += 1
		results["suites"][suite_name]["passed"] += 1
		results["suites"][suite_name]["checks"].append({"check": check_name, "status": "PASS"})
		print("  [PASS] [%s] %s" % [suite_name, check_name])
		return true
	else:
		results["failed_assertions"] += 1
		results["suites"][suite_name]["failed"] += 1
		var failure_entry: Dictionary = {
			"suite": suite_name,
			"check": check_name,
			"details": str(details)
		}
		results["suites"][suite_name]["checks"].append({"check": check_name, "status": "FAIL", "details": str(details)})
		failures.append(failure_entry)
		push_error("  [FAIL] [%s] %s: %s" % [suite_name, check_name, str(details)])
		print("  [FAIL] [%s] %s: %s" % [suite_name, check_name, str(details)])
		return false


func _run_all_coverage_tests() -> void:
	results["timestamp"] = Time.get_datetime_string_from_system(true)
	print("=================================================================")
	print(" TIER 5 ADVERSARIAL COVERAGE HARDENING TEST SUITE STARTING")
	print(" Target: res://scripts/antigravity/environment_polish.gd (790 lines)")
	print("=================================================================")

	var PolishClass: GDScript = load(POLISH_SCRIPT_PATH) as GDScript
	if PolishClass == null:
		assert_true(false, "INIT", "Load Polish Script", "Could not load " + POLISH_SCRIPT_PATH)
		_finish()
		return
	assert_true(true, "INIT", "Load Polish Script", "Successfully loaded environment_polish.gd")

	# Execute Synthetic Hostile Scenarios (Suites 1 - 6)
	_test_suite_1_missing_or_partial_subtrees(PolishClass)
	_test_suite_2_ceiling_backing_boundary_conditions(PolishClass)
	_test_suite_3_missing_or_unusual_lights(PolishClass)
	_test_suite_4_edge_case_meshes_and_surfaces(PolishClass)
	_test_suite_5_material_guardrails(PolishClass)
	_test_suite_6_hostile_mutation_and_reversibility(PolishClass)

	# Execute Live Production Scene Integration & Batch Preservation (Suite 7)
	await _test_suite_7_live_production_scene(PolishClass)

	_finish()


# ===============================================================================
# SUITE 1: Missing or Partial Scene Subtrees
# ===============================================================================
func _test_suite_1_missing_or_partial_subtrees(PolishClass: GDScript) -> void:
	print("\n--- SUITE 1: MISSING OR PARTIAL SCENE SUBTREES ---")

	# Case 1.1: CampusRuntime completely absent from game
	var game_no_campus := MockGame.new()
	root.add_child(game_no_campus)
	var polish1: Node3D = PolishClass.new() as Node3D
	var rep1: Dictionary = polish1.call("install", game_no_campus)
	assert_true(rep1.get("installed", false) == true, "SUITE_1", "1.1 Install with missing CampusRuntime succeeds", rep1)
	assert_true(rep1.get("resource_counts", {}).get("mesh_overrides_applied", -1) == 0, "SUITE_1", "1.1 Zero mesh overrides applied when no CampusRuntime")
	var unrep1: Dictionary = polish1.call("uninstall")
	assert_true(unrep1.get("uninstalled", false) == true, "SUITE_1", "1.1 Uninstall with missing CampusRuntime clean", unrep1)
	polish1.queue_free()
	game_no_campus.queue_free()

	# Case 1.2: CampusRuntime present, but CampusRenderBatches missing
	var game_no_batches := MockGame.new()
	var campus_no_batches := MockCampus.new()
	campus_no_batches.name = "CampusRuntime"
	game_no_batches.add_child(campus_no_batches)
	root.add_child(game_no_batches)
	var polish2: Node3D = PolishClass.new() as Node3D
	var rep2: Dictionary = polish2.call("install", game_no_batches)
	assert_true(rep2.get("installed", false) == true, "SUITE_1", "1.2 Install with missing CampusRenderBatches succeeds")
	assert_true(rep2.get("measured_costs", {}).get("multimesh_batches_retained", -1) == 29, "SUITE_1", "1.2 Fallback multimesh batch count 29 used when node absent")
	assert_true(rep2.get("measured_costs", {}).get("static_surface_batches_retained", -1) == 92, "SUITE_1", "1.2 Fallback static surface batch count 92 used when node absent")
	var unrep2: Dictionary = polish2.call("uninstall")
	assert_true(unrep2.get("uninstalled", false) == true, "SUITE_1", "1.2 Uninstall with missing batches clean")
	polish2.queue_free()
	game_no_batches.queue_free()

	# Case 1.3: CampusRenderBatches present, but has 0 children
	var game_empty_batches := MockGame.new()
	var campus_empty_batches := MockCampus.new()
	campus_empty_batches.name = "CampusRuntime"
	var empty_batches := Node3D.new()
	empty_batches.name = "CampusRenderBatches"
	campus_empty_batches.add_child(empty_batches)
	game_empty_batches.add_child(campus_empty_batches)
	root.add_child(game_empty_batches)
	var polish3: Node3D = PolishClass.new() as Node3D
	var rep3: Dictionary = polish3.call("install", game_empty_batches)
	assert_true(rep3.get("installed", false) == true, "SUITE_1", "1.3 Install with 0 batches children succeeds")
	assert_true(rep3.get("measured_costs", {}).get("multimesh_batches_retained", -1) == 0, "SUITE_1", "1.3 Batch count correctly reports 0 multimesh")
	assert_true(rep3.get("measured_costs", {}).get("static_surface_batches_retained", -1) == 0, "SUITE_1", "1.3 Batch count correctly reports 0 static surfaces")
	var unrep3: Dictionary = polish3.call("uninstall")
	assert_true(unrep3.get("uninstalled", false) == true, "SUITE_1", "1.3 Uninstall with 0 batches clean")
	polish3.queue_free()
	game_empty_batches.queue_free()

	# Case 1.4: CampusRenderBatches contains non-mesh nodes (Marker3D, Timer, Node3D)
	var game_non_mesh_batches := MockGame.new()
	var campus_non_mesh := MockCampus.new()
	campus_non_mesh.name = "CampusRuntime"
	var non_mesh_batches := Node3D.new()
	non_mesh_batches.name = "CampusRenderBatches"
	non_mesh_batches.add_child(Marker3D.new())
	non_mesh_batches.add_child(Timer.new())
	non_mesh_batches.add_child(Node3D.new())
	campus_non_mesh.add_child(non_mesh_batches)
	game_non_mesh_batches.add_child(campus_non_mesh)
	root.add_child(game_non_mesh_batches)
	var polish4: Node3D = PolishClass.new() as Node3D
	var rep4: Dictionary = polish4.call("install", game_non_mesh_batches)
	assert_true(rep4.get("installed", false) == true, "SUITE_1", "1.4 Non-mesh nodes in CampusRenderBatches safely ignored")
	var unrep4: Dictionary = polish4.call("uninstall")
	assert_true(unrep4.get("uninstalled", false) == true, "SUITE_1", "1.4 Uninstall with non-mesh nodes clean")
	polish4.queue_free()
	game_non_mesh_batches.queue_free()

	# Case 1.5: game.imported_props containing malformed non-Node entries
	var game_bad_props := MockGame.new()
	game_bad_props.imported_props = [null, 12345, "invalid_string", ["nested_array"], {"dict": 1}]
	root.add_child(game_bad_props)
	var polish5: Node3D = PolishClass.new() as Node3D
	var rep5: Dictionary = polish5.call("install", game_bad_props)
	assert_true(rep5.get("installed", false) == true, "SUITE_1", "1.5 Malformed imported_props handled safely without crash")
	var unrep5: Dictionary = polish5.call("uninstall")
	assert_true(unrep5.get("uninstalled", false) == true, "SUITE_1", "1.5 Uninstall with malformed imported_props clean")
	polish5.queue_free()
	game_bad_props.queue_free()


# ===============================================================================
# SUITE 2: Ceiling Backing Boundary Conditions
# ===============================================================================
func _test_suite_2_ceiling_backing_boundary_conditions(PolishClass: GDScript) -> void:
	print("\n--- SUITE 2: CEILING BACKING BOUNDARY CONDITIONS ---")

	# Case 2.1: mesh_nodes exists on CampusRuntime, but E8 ceiling joint backing is absent
	var game := MockGame.new()
	var campus := MockCampus.new()
	campus.name = "CampusRuntime"
	var dummy_mesh := MeshInstance3D.new()
	dummy_mesh.name = "OtherMesh"
	campus.mesh_nodes = [dummy_mesh]
	campus.add_child(dummy_mesh)
	game.add_child(campus)
	root.add_child(game)

	var polish: Node3D = PolishClass.new() as Node3D
	var rep: Dictionary = polish.call("install", game)
	assert_true(rep.get("installed", false) == true, "SUITE_2", "2.1 Install succeeds when ceiling backing is absent from mesh_nodes")
	assert_true(polish.get("_ceiling_backing_node") == null, "SUITE_2", "2.1 _ceiling_backing_node remains null when absent")
	var unrep: Dictionary = polish.call("uninstall")
	assert_true(unrep.get("uninstalled", false) == true, "SUITE_2", "2.1 Uninstall succeeds cleanly without ceiling backing node")
	polish.queue_free()
	game.queue_free()

	# Case 2.2: mesh_nodes contains non-MeshInstance3D items (Node3D, Node, null)
	var game2 := MockGame.new()
	var campus2 := MockCampus.new()
	campus2.name = "CampusRuntime"
	campus2.mesh_nodes = [Node3D.new(), Node.new(), null]
	game2.add_child(campus2)
	root.add_child(game2)

	var polish2: Node3D = PolishClass.new() as Node3D
	var rep2: Dictionary = polish2.call("install", game2)
	assert_true(rep2.get("installed", false) == true, "SUITE_2", "2.2 mesh_nodes with non-MeshInstance3D items safely filtered")
	var unrep2: Dictionary = polish2.call("uninstall")
	assert_true(unrep2.get("uninstalled", false) == true, "SUITE_2", "2.2 Uninstall clean with non-mesh items in mesh_nodes")
	polish2.queue_free()
	game2.queue_free()

	# Case 2.3: E8 ceiling joint backing exists as Node3D (not MeshInstance3D)
	var game3 := MockGame.new()
	var campus3 := MockCampus.new()
	campus3.name = "CampusRuntime"
	var fake_backing := Node3D.new()
	fake_backing.name = "E8 ceiling joint backing"
	campus3.add_child(fake_backing)
	campus3.mesh_nodes = [fake_backing]
	game3.add_child(campus3)
	root.add_child(game3)

	var polish3: Node3D = PolishClass.new() as Node3D
	var rep3: Dictionary = polish3.call("install", game3)
	assert_true(rep3.get("installed", false) == true, "SUITE_2", "2.3 Non-mesh ceiling backing node safely ignored")
	assert_true(polish3.get("_ceiling_backing_node") == null, "SUITE_2", "2.3 _ceiling_backing_node remains null for non-MeshInstance3D")
	var unrep3: Dictionary = polish3.call("uninstall")
	assert_true(unrep3.get("uninstalled", false) == true, "SUITE_2", "2.3 Uninstall clean")
	polish3.queue_free()
	game3.queue_free()

	# Case 2.4: E8 ceiling joint backing exists with material_override == null, verify full restoration
	var game4 := MockGame.new()
	root.add_child(game4) # Add to root first so inside tree
	var campus4 := MockCampus.new()
	campus4.name = "CampusRuntime"
	game4.add_child(campus4)

	var backing := MeshInstance3D.new()
	backing.name = "E8 ceiling joint backing"
	campus4.add_child(backing)
	backing.visible = false
	backing.global_position = Vector3(-40.0, 6.4675, -115.0)
	backing.material_override = null
	campus4.mesh_nodes = [backing]

	var polish4: Node3D = PolishClass.new() as Node3D
	var rep4: Dictionary = polish4.call("install", game4)
	assert_true(rep4.get("installed", false) == true, "SUITE_2", "2.4 Install with real ceiling backing node succeeds")
	assert_true(backing.visible == true, "SUITE_2", "2.4 Ceiling backing unhidden after install")
	assert_true(is_equal_approx(backing.global_position.y, 6.4675 - 0.002), "SUITE_2", "2.4 Ceiling backing offset by -2mm")
	assert_true(backing.material_override != null, "SUITE_2", "2.4 Softened reveal material applied")

	var unrep4: Dictionary = polish4.call("uninstall")
	assert_true(unrep4.get("uninstalled", false) == true, "SUITE_2", "2.4 Uninstall succeeds")
	assert_true(backing.visible == false, "SUITE_2", "2.4 Original hidden visibility restored")
	assert_true(is_equal_approx(backing.global_position.y, 6.4675), "SUITE_2", "2.4 Original global_position.y restored")
	assert_true(backing.material_override == null, "SUITE_2", "2.4 Original null material_override restored")
	polish4.queue_free()
	game4.queue_free()


# ===============================================================================
# SUITE 3: Missing or Unusual Lights & WorldEnvironment
# ===============================================================================
func _test_suite_3_missing_or_unusual_lights(PolishClass: GDScript) -> void:
	print("\n--- SUITE 3: MISSING OR UNUSUAL LIGHTS & WORLDENVIRONMENT ---")

	# Case 3.1: Zero DirectionalLight3D in the tree
	var game1 := MockGame.new()
	root.add_child(game1)
	var polish1: Node3D = PolishClass.new() as Node3D
	var rep1: Dictionary = polish1.call("install", game1)
	assert_true(rep1.get("installed", false) == true, "SUITE_3", "3.1 Install succeeds with 0 DirectionalLight3D")
	assert_true(rep1.get("resource_counts", {}).get("lights_tuned", -1) == 0, "SUITE_3", "3.1 Zero lights reported tuned")
	var unrep1: Dictionary = polish1.call("uninstall")
	assert_true(unrep1.get("uninstalled", false) == true, "SUITE_3", "3.1 Uninstall clean with 0 DirectionalLight3D")
	polish1.queue_free()
	game1.queue_free()

	# Case 3.2: Multiple DirectionalLight3D nodes in the tree
	var game2 := MockGame.new()
	var sun_primary := DirectionalLight3D.new()
	sun_primary.name = "SunPrimary"
	sun_primary.shadow_normal_bias = 2.0
	sun_primary.light_energy = 0.5
	game2.add_child(sun_primary)
	var sun_secondary := DirectionalLight3D.new()
	sun_secondary.name = "SunSecondary"
	sun_secondary.shadow_normal_bias = 1.0
	sun_secondary.light_energy = 0.2
	game2.add_child(sun_secondary)
	root.add_child(game2)

	var polish2: Node3D = PolishClass.new() as Node3D
	var rep2: Dictionary = polish2.call("install", game2)
	assert_true(rep2.get("installed", false) == true, "SUITE_3", "3.2 Install succeeds with multiple DirectionalLight3Ds")
	assert_true(is_equal_approx(sun_primary.shadow_normal_bias, 0.80), "SUITE_3", "3.2 Primary sun tuned to normal bias 0.80")
	assert_true(is_equal_approx(sun_secondary.shadow_normal_bias, 1.0), "SUITE_3", "3.2 Secondary sun untouched")
	var unrep2: Dictionary = polish2.call("uninstall")
	assert_true(unrep2.get("uninstalled", false) == true, "SUITE_3", "3.2 Uninstall succeeds")
	assert_true(is_equal_approx(sun_primary.shadow_normal_bias, 2.0), "SUITE_3", "3.2 Primary sun restored to 2.0")
	polish2.queue_free()
	game2.queue_free()

	# Case 3.3: Missing WorldEnvironment node
	var game3 := MockGame.new()
	root.add_child(game3)
	var polish3: Node3D = PolishClass.new() as Node3D
	var rep3: Dictionary = polish3.call("install", game3)
	assert_true(rep3.get("installed", false) == true, "SUITE_3", "3.3 Install succeeds with missing WorldEnvironment")
	assert_true(rep3.get("resource_counts", {}).get("environments_tuned", -1) == 0, "SUITE_3", "3.3 Zero environments reported tuned")
	var unrep3: Dictionary = polish3.call("uninstall")
	assert_true(unrep3.get("uninstalled", false) == true, "SUITE_3", "3.3 Uninstall clean with missing WorldEnvironment")
	polish3.queue_free()
	game3.queue_free()

	# Case 3.4: WorldEnvironment exists, but environment property is null
	var game4 := MockGame.new()
	var wenv_null := WorldEnvironment.new()
	wenv_null.environment = null
	game4.add_child(wenv_null)
	root.add_child(game4)
	var polish4: Node3D = PolishClass.new() as Node3D
	var rep4: Dictionary = polish4.call("install", game4)
	assert_true(rep4.get("installed", false) == true, "SUITE_3", "3.4 Install succeeds when WorldEnvironment.environment is null")
	assert_true(rep4.get("resource_counts", {}).get("environments_tuned", -1) == 0, "SUITE_3", "3.4 Zero environments reported tuned when null resource")
	var unrep4: Dictionary = polish4.call("uninstall")
	assert_true(unrep4.get("uninstalled", false) == true, "SUITE_3", "3.4 Uninstall clean when WorldEnvironment.environment is null")
	polish4.queue_free()
	game4.queue_free()


# ===============================================================================
# SUITE 4: Edge Case Meshes & Surface Topologies
# ===============================================================================
func _test_suite_4_edge_case_meshes_and_surfaces(PolishClass: GDScript) -> void:
	print("\n--- SUITE 4: EDGE CASE MESHES & SURFACE TOPOLOGIES ---")

	var game := MockGame.new()
	var campus := MockCampus.new()
	campus.name = "CampusRuntime"
	game.add_child(campus)

	# 4.1: MeshInstance3D with mesh == null
	var null_mesh_node := MeshInstance3D.new()
	null_mesh_node.name = "NullMeshNode"
	null_mesh_node.mesh = null
	campus.add_child(null_mesh_node)

	# 4.2: MeshInstance3D with ArrayMesh with 0 surfaces
	var zero_surf_node := MeshInstance3D.new()
	zero_surf_node.name = "ZeroSurfNode"
	zero_surf_node.mesh = ArrayMesh.new()
	campus.add_child(zero_surf_node)

	# 4.3: MeshInstance3D with ImmediateMesh with 0 surfaces
	var imm_surf_node := MeshInstance3D.new()
	imm_surf_node.name = "ImmSurfNode"
	imm_surf_node.mesh = ImmediateMesh.new()
	campus.add_child(imm_surf_node)

	# 4.4: MeshInstance3D with BoxMesh but null active material
	var box_node := MeshInstance3D.new()
	box_node.name = "BoxMeshNullMat"
	box_node.mesh = BoxMesh.new()
	campus.add_child(box_node)

	# Batches node
	var batches_node := Node3D.new()
	batches_node.name = "CampusRenderBatches"
	campus.add_child(batches_node)

	# 4.5: MultiMeshInstance3D with BoxMesh but null material
	var mm_box := MultiMeshInstance3D.new()
	mm_box.name = "MMBoxMesh"
	mm_box.multimesh = MultiMesh.new()
	mm_box.multimesh.mesh = BoxMesh.new()
	batches_node.add_child(mm_box)

	# 4.6: StaticSurface MeshInstance3D with BoxMesh but null material
	var static_box := MeshInstance3D.new()
	static_box.name = "StaticBoxNullMat"
	static_box.mesh = BoxMesh.new()
	batches_node.add_child(static_box)

	campus.mesh_nodes = [null_mesh_node, zero_surf_node, imm_surf_node, box_node]
	root.add_child(game)

	var polish: Node3D = PolishClass.new() as Node3D
	var rep: Dictionary = polish.call("install", game)
	assert_true(rep.get("installed", false) == true, "SUITE_4", "4.0 Install succeeds with all edge case mesh configurations")
	assert_true(rep.get("resource_counts", {}).get("mesh_overrides_applied", -1) == 0, "SUITE_4", "4.0 Zero overrides applied to null/empty meshes")
	assert_true(rep.get("resource_counts", {}).get("multimesh_batches_overridden", -1) == 0, "SUITE_4", "4.0 Zero multimesh overrides on null material multimesh")
	assert_true(rep.get("resource_counts", {}).get("static_surface_batches_overridden", -1) == 0, "SUITE_4", "4.0 Zero static surface overrides on null material surface")

	var unrep: Dictionary = polish.call("uninstall")
	assert_true(unrep.get("uninstalled", false) == true, "SUITE_4", "4.0 Uninstall clean across all edge case meshes")
	polish.queue_free()
	game.queue_free()


# ===============================================================================
# SUITE 5: Material Guardrails & Exotic Material Stress
# ===============================================================================
func _test_suite_5_material_guardrails(PolishClass: GDScript) -> void:
	print("\n--- SUITE 5: MATERIAL GUARDRAILS & EXOTIC MATERIAL STRESS ---")

	var game := MockGame.new()
	var campus := MockCampus.new()
	campus.name = "CampusRuntime"
	game.add_child(campus)

	# 5.1: ShaderMaterial on a mesh (e.g. computer CRT terminal shader)
	var shader_mesh := MeshInstance3D.new()
	shader_mesh.name = "ShaderMesh"
	shader_mesh.mesh = BoxMesh.new()
	var smat := ShaderMaterial.new()
	smat.resource_name = "custom_screen_shader"
	shader_mesh.set_surface_override_material(0, smat)
	campus.add_child(shader_mesh)

	# 5.2: Unshaded StandardMaterial3D (Guardrail 1)
	var unshaded_mesh := MeshInstance3D.new()
	unshaded_mesh.name = "UnshadedMesh"
	unshaded_mesh.mesh = BoxMesh.new()
	var unshaded_mat := StandardMaterial3D.new()
	unshaded_mat.resource_name = "Blue reflective glazing 1" # Name matches glass rule!
	unshaded_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	unshaded_mesh.set_surface_override_material(0, unshaded_mat)
	campus.add_child(unshaded_mesh)

	# 5.3: Interactive PC display keywords (Guardrail 2)
	var display_mesh := MeshInstance3D.new()
	display_mesh.name = "DisplayMesh"
	display_mesh.mesh = BoxMesh.new()
	var display_mat := StandardMaterial3D.new()
	display_mat.resource_name = "powered display monitor screen"
	display_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	display_mesh.set_surface_override_material(0, display_mat)
	campus.add_child(display_mesh)

	# 5.4: Approved GLB prop texture guardrail (Guardrail 3: albedo_texture != null and no campus_material_family)
	var prop_mesh := MeshInstance3D.new()
	prop_mesh.name = "PropMesh"
	prop_mesh.mesh = BoxMesh.new()
	var prop_mat := StandardMaterial3D.new()
	prop_mat.resource_name = "chair_wood_finish" # Contains "wood"
	# Create a minimal 1x1 image texture
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.RED)
	prop_mat.albedo_texture = ImageTexture.create_from_image(img)
	prop_mesh.set_surface_override_material(0, prop_mat)
	campus.add_child(prop_mesh)

	# 5.5: Glazing framing guardrail (Guardrail 4: frames/mullions never receive transparency)
	var frame_mesh := MeshInstance3D.new()
	frame_mesh.name = "FrameMesh"
	frame_mesh.mesh = BoxMesh.new()
	var frame_mat := StandardMaterial3D.new()
	frame_mat.resource_name = "D7 blue solar control glazing frame mullion" # Contains glazing AND frame
	frame_mesh.set_surface_override_material(0, frame_mat)
	campus.add_child(frame_mesh)

	# 5.6: Unmatched standard material (Arbitrary prop)
	var unmatched_mesh := MeshInstance3D.new()
	unmatched_mesh.name = "UnmatchedMesh"
	unmatched_mesh.mesh = BoxMesh.new()
	var unmatched_mat := StandardMaterial3D.new()
	unmatched_mat.resource_name = "xyz_arbitrary_unmatched_material"
	unmatched_mesh.set_surface_override_material(0, unmatched_mat)
	campus.add_child(unmatched_mesh)

	campus.mesh_nodes = [shader_mesh, unshaded_mesh, display_mesh, prop_mesh, frame_mesh, unmatched_mesh]
	root.add_child(game)

	var polish: Node3D = PolishClass.new() as Node3D
	var rep: Dictionary = polish.call("install", game)
	assert_true(rep.get("installed", false) == true, "SUITE_5", "5.0 Install succeeds with guardrail test suite")

	# Check 5.1: ShaderMaterial completely untouched
	assert_true(shader_mesh.get_active_material(0) == smat, "SUITE_5", "5.1 ShaderMaterial completely preserved without override")

	# Check 5.2: Unshaded material completely untouched despite glass name
	assert_true(unshaded_mesh.get_active_material(0) == unshaded_mat, "SUITE_5", "5.2 Unshaded material untouched (Guardrail 1)")

	# Check 5.3: Display keyword material completely untouched
	assert_true(display_mesh.get_active_material(0) == display_mat, "SUITE_5", "5.3 Display keyword material untouched (Guardrail 2)")

	# Check 5.4: Authored texture prop without campus meta completely untouched
	assert_true(prop_mesh.get_active_material(0) == prop_mat, "SUITE_5", "5.4 Authored texture prop untouched (Guardrail 3)")

	# Check 5.5: Frame/mullion never receives transparency
	var active_frame_mat: Material = frame_mesh.get_active_material(0)
	if active_frame_mat is BaseMaterial3D:
		var base_frame: BaseMaterial3D = active_frame_mat as BaseMaterial3D
		assert_true(base_frame.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "SUITE_5", "5.5 Frame/mullion never has transparency (Guardrail 4)")
	else:
		assert_true(active_frame_mat == frame_mat, "SUITE_5", "5.5 Frame material untouched")

	# Check 5.6: Unmatched material untouched
	assert_true(unmatched_mesh.get_active_material(0) == unmatched_mat, "SUITE_5", "5.6 Unmatched material untouched")

	# Uninstall and verify
	var unrep: Dictionary = polish.call("uninstall")
	assert_true(unrep.get("uninstalled", false) == true, "SUITE_5", "5.0 Uninstall clean after guardrail verification")
	polish.queue_free()
	game.queue_free()


# ===============================================================================
# SUITE 6: Hostile Mutation & Reversibility Stress
# ===============================================================================
func _test_suite_6_hostile_mutation_and_reversibility(PolishClass: GDScript) -> void:
	print("\n--- SUITE 6: HOSTILE MUTATION & REVERSIBILITY STRESS ---")

	# 6.1: Node freed prior to uninstall (Tree mutation resilience)
	var game1 := MockGame.new()
	var campus1 := MockCampus.new()
	campus1.name = "CampusRuntime"
	var tuned_mesh := MeshInstance3D.new()
	tuned_mesh.name = "TunedTerrazzoMesh"
	tuned_mesh.mesh = BoxMesh.new()
	var terraz_mat := StandardMaterial3D.new()
	terraz_mat.resource_name = "lobby terrazzo floor"
	tuned_mesh.set_surface_override_material(0, terraz_mat)
	campus1.add_child(tuned_mesh)
	campus1.mesh_nodes = [tuned_mesh]

	var sun1 := DirectionalLight3D.new()
	sun1.name = "SunDirectional"
	game1.add_child(sun1)

	game1.add_child(campus1)
	root.add_child(game1)

	var polish1: Node3D = PolishClass.new() as Node3D
	var rep1: Dictionary = polish1.call("install", game1)
	assert_true(rep1.get("installed", false) == true, "SUITE_6", "6.1 Install succeeds before mutation")
	assert_true(rep1.get("resource_counts", {}).get("mesh_overrides_applied", 0) > 0, "SUITE_6", "6.1 Terrazzo mesh was tuned")

	# Adversarial action: Freely destroy tuned_mesh and sun1 before uninstall!
	tuned_mesh.free()
	sun1.free()

	# Call uninstall: should NOT crash! Must handle freed instances gracefully
	var unrep1: Dictionary = polish1.call("uninstall")
	assert_true(unrep1.get("uninstalled", false) == true, "SUITE_6", "6.1 Uninstall survives freed target nodes without crashing")
	assert_true(unrep1.get("errors", []).size() >= 2, "SUITE_6", "6.1 Errors reported cleanly for freed mesh and light nodes", unrep1.get("errors", []))
	polish1.queue_free()
	game1.queue_free()

	# 6.2: Injected nodes deleted externally prior to uninstall
	var game2 := MockGame.new()
	root.add_child(game2)
	var polish2: Node3D = PolishClass.new() as Node3D
	polish2.call("install", game2)
	# Destroy injected canopy downlight externally
	var downlight: Node = game2.find_child("CanopyEntranceDownlight", true, false)
	if downlight != null:
		downlight.free()
	var unrep2: Dictionary = polish2.call("uninstall")
	assert_true(unrep2.get("uninstalled", false) == true, "SUITE_6", "6.2 Uninstall survives freed injected nodes without crash")
	polish2.queue_free()
	game2.queue_free()

	# 6.3: Double installation on same instance
	var game3 := MockGame.new()
	root.add_child(game3)
	var polish3: Node3D = PolishClass.new() as Node3D
	var r_inst1: Dictionary = polish3.call("install", game3)
	assert_true(r_inst1.get("installed", false) == true, "SUITE_6", "6.3 First install returns installed: true")
	var r_inst2: Dictionary = polish3.call("install", game3)
	assert_true(r_inst2.get("already_installed", false) == true, "SUITE_6", "6.3 Second install returns already_installed: true")
	polish3.call("uninstall")
	polish3.queue_free()
	game3.queue_free()

	# 6.4: Installation with existing module meta
	var game4 := MockGame.new()
	game4.set_meta("antigravity_polish_installed", true)
	root.add_child(game4)
	var polish4: Node3D = PolishClass.new() as Node3D
	var r_inst_meta: Dictionary = polish4.call("install", game4)
	assert_true(r_inst_meta.get("already_installed", false) == true, "SUITE_6", "6.4 Detects existing metadata and rejects duplicate install")
	polish4.queue_free()
	game4.queue_free()

	# 6.5: Double uninstall
	var game5 := MockGame.new()
	root.add_child(game5)
	var polish5: Node3D = PolishClass.new() as Node3D
	polish5.call("install", game5)
	var u1: Dictionary = polish5.call("uninstall")
	assert_true(u1.get("uninstalled", false) == true, "SUITE_6", "6.5 First uninstall returns uninstalled: true")
	var u2: Dictionary = polish5.call("uninstall")
	assert_true(u2.get("uninstalled", false) == false and u2.get("status", "") == "not_installed", "SUITE_6", "6.5 Second uninstall returns not_installed")
	polish5.queue_free()
	game5.queue_free()

	# 6.6: Lifecycle precondition: game not ready
	var game6 := MockGame.new()
	game6.ready_to_play = false
	root.add_child(game6)
	var polish6: Node3D = PolishClass.new() as Node3D
	var r_unready: Dictionary = polish6.call("install", game6)
	assert_true(r_unready.get("installed", false) == false, "SUITE_6", "6.6 Install rejected when ready_to_play is false")
	assert_true(r_unready.get("errors", []).size() > 0, "SUITE_6", "6.6 Error message provided for unready game")
	polish6.queue_free()
	game6.queue_free()

	# 6.7: Null and freed game reference
	var polish7: Node3D = PolishClass.new() as Node3D
	var r_null: Dictionary = polish7.call("install", null)
	assert_true(r_null.get("installed", false) == false, "SUITE_6", "6.7 Install rejected when game is null")
	var temp_game := Node3D.new()
	temp_game.free()
	var r_freed: Dictionary = polish7.call("install", temp_game)
	assert_true(r_freed.get("installed", false) == false, "SUITE_6", "6.7 Install rejected when game is freed")
	polish7.queue_free()


# ===============================================================================
# SUITE 7: Live Production Scene Integration & Batch Preservation
# ===============================================================================
func _test_suite_7_live_production_scene(PolishClass: GDScript) -> void:
	print("\n--- SUITE 7: LIVE PRODUCTION SCENE ON res://main.tscn ---")

	var scene_res: PackedScene = load("res://main.tscn")
	if scene_res == null:
		assert_true(false, "SUITE_7", "Load res://main.tscn", "Could not load production main.tscn")
		return

	var live_game: Node3D = scene_res.instantiate() as Node3D
	root.add_child(live_game)
	live_game.set_physics_process(false)
	live_game.set_process_unhandled_input(false)

	var start_wait: int = Time.get_ticks_msec()
	while not live_game.ready_to_play and (Time.get_ticks_msec() - start_wait) < 120000:
		await process_frame

	assert_true(live_game.ready_to_play, "SUITE_7", "7.1 Live game reaches ready_to_play")
	if not live_game.ready_to_play:
		live_game.queue_free()
		return

	# Settle physics and frame
	await physics_frame
	await process_frame

	# In headless mode, main.gd deliberately skips creating lights/environment.
	# Create synthetic DirectionalLight3D and WorldEnvironment on live_game to verify full pipeline!
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.shadow_normal_bias = 2.0
	sun.shadow_bias = 0.12
	sun.shadow_blur = 1.4
	sun.directional_shadow_blend_splits = true
	sun.light_energy = 0.32
	live_game.add_child(sun)

	var wenv: WorldEnvironment = WorldEnvironment.new()
	wenv.name = "WorldEnvironment"
	var env := Environment.new()
	env.ambient_light_energy = 0.32
	env.tonemap_exposure = 0.92
	wenv.environment = env
	live_game.add_child(wenv)

	# Step 1: Snapshot baseline state
	var campus: Node = live_game.get_node_or_null("CampusRuntime")
	assert_true(campus != null, "SUITE_7", "7.2 CampusRuntime found in live scene")
	var batches_node: Node = campus.find_child("CampusRenderBatches", true, false) if campus != null else null
	assert_true(batches_node != null, "SUITE_7", "7.3 CampusRenderBatches found in live scene")

	var baseline_multimeshes: int = 0
	var baseline_statics: int = 0
	if batches_node != null:
		for child in batches_node.get_children():
			if child is MultiMeshInstance3D:
				baseline_multimeshes += 1
			elif child is MeshInstance3D:
				baseline_statics += 1

	print("  Live Scene Baseline: MultiMeshes=%d, StaticSurfaces=%d" % [baseline_multimeshes, baseline_statics])
	assert_true(baseline_multimeshes == 28, "SUITE_7", "7.4 Baseline MultiMesh count is 28", baseline_multimeshes)
	assert_true(baseline_statics == 92, "SUITE_7", "7.5 Baseline StaticSurface count is 92", baseline_statics)

	# Step 2: Install environment_polish on live scene
	var polish: Node3D = PolishClass.new() as Node3D
	var install_rep: Dictionary = polish.call("install", live_game)
	assert_true(install_rep.get("installed", false) == true, "SUITE_7", "7.8 Live install succeeds cleanly")
	assert_true(install_rep.get("errors", []).is_empty(), "SUITE_7", "7.9 Zero install errors reported")
	assert_true(install_rep.get("warnings", []).is_empty(), "SUITE_7", "7.10 Zero install warnings reported")

	# Verify 7 affected areas
	var affected: Array = install_rep.get("affected_areas", [])
	assert_true(affected.size() == 7, "SUITE_7", "7.11 All 7 campus areas listed in affected_areas", affected.size())

	# Verify measured costs
	var costs: Dictionary = install_rep.get("measured_costs", {})
	assert_true(costs.get("active_positional_shadows", -1) == 0, "SUITE_7", "7.12 Zero active positional shadows incurred")
	assert_true(costs.get("additional_draw_calls", -1) == 0, "SUITE_7", "7.13 Zero additional draw calls incurred")

	# Verify batch count preservation after install
	var post_install_multimeshes: int = 0
	var post_install_statics: int = 0
	if batches_node != null:
		for child in batches_node.get_children():
			if child is MultiMeshInstance3D:
				post_install_multimeshes += 1
			elif child is MeshInstance3D:
				post_install_statics += 1
	assert_true(post_install_multimeshes == baseline_multimeshes, "SUITE_7", "7.14 MultiMesh batches 100% preserved (28)")
	assert_true(post_install_statics == baseline_statics, "SUITE_7", "7.15 StaticSurface batches 100% preserved (92)")

	# Verify sun and environment tuning
	assert_true(is_equal_approx(sun.shadow_normal_bias, 0.80), "SUITE_7", "7.16 Sun normal bias tuned to 0.80")
	assert_true(is_equal_approx(wenv.environment.ambient_light_energy, 0.28), "SUITE_7", "7.17 Environment ambient tuned to 0.28")

	# Step 3: Uninstall on live scene
	var uninstall_rep: Dictionary = polish.call("uninstall")
	assert_true(uninstall_rep.get("uninstalled", false) == true, "SUITE_7", "7.18 Live uninstall succeeds")
	assert_true(uninstall_rep.get("status", "") == "clean", "SUITE_7", "7.19 Uninstall status is clean")
	assert_true(uninstall_rep.get("errors", []).is_empty(), "SUITE_7", "7.20 Zero uninstall errors on live scene")

	# Allow deferred queue_free() of injected nodes to execute
	await process_frame

	# Verify batch count preservation after uninstall
	var post_un_multimeshes: int = 0
	var post_un_statics: int = 0
	if batches_node != null:
		for child in batches_node.get_children():
			if child is MultiMeshInstance3D:
				post_un_multimeshes += 1
			elif child is MeshInstance3D:
				post_un_statics += 1
	assert_true(post_un_multimeshes == baseline_multimeshes, "SUITE_7", "7.21 Post-uninstall MultiMesh count intact (28)")
	assert_true(post_un_statics == baseline_statics, "SUITE_7", "7.22 Post-uninstall StaticSurface count intact (92)")

	# Verify lighting restored
	assert_true(is_equal_approx(sun.shadow_normal_bias, 2.0), "SUITE_7", "7.23 Sun normal bias restored to baseline (2.0)")
	assert_true(is_equal_approx(wenv.environment.ambient_light_energy, 0.32), "SUITE_7", "7.24 Environment ambient restored to baseline (0.32)")

	# Verify injected nodes freed
	assert_true(live_game.find_child("CanopyEntranceDownlight", true, false) == null, "SUITE_7", "7.25 Canopy downlight removed on uninstall")
	assert_true(live_game.find_child("CreamEntranceSignage", true, false) == null, "SUITE_7", "7.26 Entrance signage removed on uninstall")

	# Cleanup live game
	polish.queue_free()
	live_game.queue_free()
	await process_frame


func _finish() -> void:
	results["passed"] = (results["failed_assertions"] == 0 and failures.is_empty())
	results["failures"] = failures

	var global_path: String = ProjectSettings.globalize_path(REPORT_PATH)
	var f := FileAccess.open(global_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "\t"))
		f.close()
		print("\nCHALLENGER_REPORT_SAVED: %s" % global_path)

	print("\n=================================================================")
	print(" TIER 5 COVERAGE HARDENING FINISHED: passed=%s" % str(results["passed"]))
	print(" Assertions Total: %d | Passed: %d | Failed: %d" % [
		results["total_assertions"], results["passed_assertions"], results["failed_assertions"]
	])
	print("=================================================================")

	quit(0 if results["passed"] else 1)
