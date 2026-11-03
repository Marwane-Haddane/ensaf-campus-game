extends SceneTree
## Exact centre-crosshair targeting regression against the real campus scene.
## Physics stays frozen and no incident response actions are executed.
var game
var selector
var report := {"passed":false,"checks":0,"failures":[],"stations":[],"training_unchanged":false}
var state_before: Dictionary
var points_before: int
var journal_before: Array

func _init() -> void:
	call_deferred("run_test")

func verify(value: bool, message: String, details: Variant = null) -> void:
	report.checks += 1
	if not value:
		report.failures.append({"check":message,"details":str(details)})
		print("HOVER_FAIL ",message," ",details)

func run_test() -> void:
	selector = load("res://scripts/interaction_target.gd")
	verify(selector != null, "targeting helper loads")
	if selector == null:
		finish()
		return
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	var started := Time.get_ticks_msec()
	while not game.ready_to_play and Time.get_ticks_msec() - started < 120000:
		await process_frame
	verify(game.ready_to_play, "campus becomes ready")
	if not game.ready_to_play:
		finish()
		return
	await physics_frame
	await physics_frame
	game.training.set_process_input(false)
	state_before = game.training.state.duplicate(true)
	points_before = game.training.points
	journal_before = game.training.journal.duplicate()
	var approaches := {
		"Reception response PC":Vector3(-36.2,1.832,-104.1),
		"Campus security PC":Vector3(0.90,2.71,-110.5),
		"Auditorium teaching PC":Vector3(-43.0,1.0,-121.4)
	}
	for station: Dictionary in game.stations:
		if station.get("kind","pc") == "pc":
			await test_pc(station, approaches[station.name])
	verify(game.training.state == state_before, "training flags remain unchanged")
	verify(game.training.points == points_before, "training points remain unchanged")
	verify(game.training.journal == journal_before, "evidence journal remains unchanged")
	verify(game.training.get_completion_count() == 0, "hover test completes no mission actions")
	report.training_unchanged = game.training.state == state_before and game.training.points == points_before and game.training.journal == journal_before
	finish()

func selected_name() -> String:
	var station: Dictionary = selector.find(game.camera, game.player, game.stations, 2.8)
	return str(station.get("name",""))

func focus_visible() -> bool:
	return game.focus_overlay._canvas.visible and game.focus_overlay._card.is_visible_in_tree()

func verify_focus_hidden(reason: String) -> void:
	# Looking away from this PC can now legitimately aim at the reception door.
	# Its own E card may replace the PC card, while all PC-specific cues must hide.
	var door_selected: bool=game.focus_overlay._target.get("kind","")=="door"
	if door_selected:
		verify(focus_visible() and game.focus_overlay._title.text==game._closest.node.get_prompt(),reason+" replaces PC card with the aimed door prompt")
	else:
		verify(not focus_visible(), reason + " hides interaction card")
	verify(not game.focus_overlay._tag.is_visible_in_tree(), reason + " hides projected tag")
	verify(not is_instance_valid(game.focus_overlay._outline) or not game.focus_overlay._outline.visible, reason + " hides cyan screen outline")

func focus_pc(station: Dictionary, approach: Vector3) -> void:
	game.player.global_position = approach
	game.player.velocity = Vector3.ZERO
	game.camera.look_at(station.screen, Vector3.UP)
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game._process(0)

func test_pc(station: Dictionary, approach: Vector3) -> void:
	var name: String = station.name
	var target: Vector3 = station.screen
	focus_pc(station, approach)
	await process_frame
	game._process(0)
	var row := {"name":name,"position":str(approach),"screen":str(target)}
	row.screen_selected = selected_name() == name
	verify(row.screen_selected, name + " accepts crosshair on native monitor")
	verify(game._closest.get("name","") == name, name + " main uses exact hover selection")
	verify(focus_visible(), name + " shows interaction card while hovered")
	verify(game.focus_overlay._tag.is_visible_in_tree(), name + " shows projected tag while hovered")
	verify(is_instance_valid(game.focus_overlay._outline) and game.focus_overlay._outline.visible, name + " shows cyan outline while hovered")
	if name == "Campus security PC":
		await capture_case("hover_target_hovered.png")
	var plate := station.node.find_child("sm_pc_mt_case_boxmetal_0",true,false) as MeshInstance3D
	verify(plate != null and plate.get_active_material(0).albedo_color.is_equal_approx(Color("18383e")), name + " runtime blue plate is dark teal")
	verify(plate.mesh.surface_get_material(0).albedo_color.b > 0.8, name + " underlying imported blue material is preserved")
	# These nearby blank points would pass the old 0.64 dot-product cone.
	var bounds: AABB = station.asset.world_bounds
	var adjacent := Vector3(bounds.end.x + 0.25, target.y, target.z)
	game.camera.look_at(adjacent,Vector3.UP)
	var old_cone_dot: float = (-game.camera.global_basis.z).dot((target-game.camera.global_position).normalized())
	verify(old_cone_dot > 0.64, name + " adjacent point exercises former broad cone", old_cone_dot)
	row.adjacent_dot = old_cone_dot
	row.adjacent_rejected = selected_name() != name
	verify(row.adjacent_rejected, name + " rejects adjacent background outside PC silhouette")
	game._process(0)
	verify(game._closest.is_empty(), name + " clears main target beside computer", game._closest.get("name",""))
	verify_focus_hidden(name + " adjacent aim")
	if name == "Campus security PC":
		await capture_case("hover_target_lookaway.png")
	game.camera.look_at(Vector3(bounds.position.x - 0.25,target.y,target.z),Vector3.UP)
	row.opposite_side_rejected = selected_name() != name
	verify(row.opposite_side_rejected, name + " rejects background past opposite PC edge")
	game._process(0)
	verify_focus_hidden(name + " opposite-edge aim")
	game.camera.look_at(game.camera.global_position+Vector3.BACK,Vector3.UP)
	row.look_away_rejected = selected_name() != name
	verify(row.look_away_rejected, name + " rejects looking away")
	game._process(0)
	verify_focus_hidden(name + " look away")
	game.player.global_position = Vector3(target.x,approach.y,target.z+4.0)
	game.camera.look_at(target,Vector3.UP)
	row.range_rejected = selected_name() != name
	verify(row.range_rejected, name + " rejects hover beyond 2.8 metres")
	game._process(0)
	verify_focus_hidden(name + " out of range")
	focus_pc(station, approach)
	var blocker := StaticBody3D.new()
	blocker.name = "HoverRegressionOccluder"
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45,0.45,0.45)
	collision.shape = box
	blocker.add_child(collision)
	game.add_child(blocker)
	blocker.global_position = (game.camera.global_position+target)*0.5
	await physics_frame
	await physics_frame
	row.occlusion_rejected = selected_name() != name
	verify(row.occlusion_rejected, name + " rejects PC behind blocking wall")
	game._process(0)
	verify_focus_hidden(name + " occluded")
	blocker.queue_free()
	await process_frame
	await physics_frame
	focus_pc(station, approach)
	verify(selected_name() == name and focus_visible(), name + " hover returns after wall removal")
	game.training.open_terminal()
	game._process(0)
	verify_focus_hidden(name + " terminal open")
	game.training.close_terminal()
	game._process(0)
	verify(focus_visible(), name + " hover returns after terminal closes")
	game.training.toggle_plan()
	game._process(0)
	verify(game.training.is_plan_open(), name + " response plan opens")
	verify_focus_hidden(name + " response plan open")
	game.training.toggle_plan()
	game._process(0)
	verify(focus_visible(), name + " hover returns after response plan closes")
	game._show_menu("HOVER REGRESSION", "Temporary pause for focus visibility validation.", false)
	game._process(0)
	verify_focus_hidden(name + " pause menu open")
	game._resume()
	game._process(0)
	verify(focus_visible(), name + " hover returns after pause menu closes")
	row.modal_visibility_passed = true
	report.stations.append(row)
	print("HOVER_STATION ",JSON.stringify(row))

func capture_case(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.player.force_update_transform()
	game.camera.force_update_transform()
	await process_frame
	await process_frame
	game.camera.force_update_transform()
	game._process(0)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tools/" + filename)

func finish() -> void:
	report.passed = report.failures.is_empty()
	FileAccess.open("res://tools/hover_target_test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("HOVER_TEST ",JSON.stringify(report))
	quit(0 if report.passed else 1)
