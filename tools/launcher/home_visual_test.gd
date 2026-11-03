extends SceneTree
var report := {"passed":false,"checks":0,"failures":[]}
func check(value: bool,label: String) -> void:
	report.checks += 1
	if not value: report.failures.append(label)
func settle(view: Control) -> void:
	if view._active_tween != null and view._active_tween.is_running(): await view._active_tween.finished
	for frame: int in range(3): await process_frame
func _init() -> void: call_deferred("run_test")
func run_test() -> void:
	var app = load("res://scenes/launcher/boot.tscn").instantiate()
	app.test_preferences_path = "user://ensagames/tests/home-visual.cfg"
	app.test_save_path = "user://ensagames/tests/home-visual.json"
	if FileAccess.file_exists(app.test_save_path):
		DirAccess.remove_absolute(app.test_save_path)
	root.add_child(app)
	while not app.initialized: await process_frame
	check(app.loader.retained_resources.is_empty(),"Reference home does not load the campus")
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540),Vector2i(1280,1024),Vector2i(1920,720)]:
		root.size = resolution
		root.content_scale_size = resolution
		app._refresh()
		await settle(app.view)
		var page: Control = app.view._pages.home
		print("REFERENCE_HOME_GEOMETRY ",JSON.stringify({"size":str(page.size),"heading":str(page._heading_label.get_global_rect()),"image":str(page._workstation_rect.get_global_rect()),"root_size":str(page._root_vbox.size),"root_scale":str(page._root_vbox.scale),"minimum":str(page._root_vbox.get_combined_minimum_size())}))
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://tools/launcher/reference-home-%dx%d.png" % [resolution.x,resolution.y])
		check(page._heading_label.get_global_rect().end.x<=page.size.x,"Heading fits the viewport")
		check(page._workstation_rect.get_global_rect().end.y<page.size.y-20,"Active case stays above footer")
		check(page._emblem_rect.texture.resource_path.ends_with("ensa-emblem-white.svg"),"Reference uses the actual white SVG")
		check(not find_available(page),"No Available badge remains on home")
		check(page._quit_btn.get_global_rect().end.y<page.size.y,"Navigation stays in the viewport")
		page._cta_play_btn.pressed.emit()
		check(app.page=="briefing" and app.state.value=="SELECT_MODE","Reference Play opens the real briefing")
		app._on_view_intent(&"back",{})
		await settle(app.view)
		page._settings_btn.pressed.emit()
		check(app.page=="settings","Reference Settings opens the actual preferences")
		app._on_view_intent(&"back",{})
		await settle(app.view)
	# Use a schema-valid initial checkpoint in this isolated test namespace.
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://design/incident.json"))
	var checkpoint := {"version":1,"mode_id":"incident_response","mission_id":"IR-2026-001","player":{"position":[-27,1.25,-85],"yaw":0.0,"pitch":0.0},"training":{"state":authored.initial_state,"points":0,"journal":[],"command_history":[],"report_answers":{},"report_preview_valid":false,"submitted_report_text":""}}
	check(app.saves.write_save(checkpoint),"Home test creates a validated checkpoint")
	root.size = Vector2i(1920,1080)
	root.content_scale_size = Vector2i(1920,1080)
	app._refresh_continue()
	app._refresh()
	await settle(app.view)
	var home: Control = app.view._pages.home
	print("REFERENCE_HOME_CONTINUE_GEOMETRY ",JSON.stringify({"page":app.page,"root_size":str(home._root_vbox.size),"minimum":str(home._root_vbox.get_combined_minimum_size()),"anchors":str(Vector2(home._root_vbox.anchor_right,home._root_vbox.anchor_bottom)),"root_position":str(home._root_vbox.position),"rail_size":str(home._left_rail.size),"quit":str(home._quit_btn.get_global_rect())}))
	check(home._continue_box.visible,"Continue reflects a valid checkpoint")
	check(home._quit_btn.get_global_rect().end.y<home.size.y,"Continue does not push Quit off-screen")
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tools/launcher/reference-home-continue-1920x1080.png")
	report.passed = report.failures.is_empty()
	FileAccess.open("res://tools/launcher/reference-home-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("REFERENCE_HOME_RESULT ",JSON.stringify(report))
	app.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
func find_available(node: Node) -> bool:
	if node is Label and node.text.strip_edges().to_upper()=="AVAILABLE": return true
	for child: Node in node.get_children():
		if find_available(child): return true
	return false
