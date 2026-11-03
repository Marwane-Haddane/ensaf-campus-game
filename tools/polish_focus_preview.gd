extends SceneTree
const Computer = preload("res://scripts/computer_prop.gd")
const Furniture = preload("res://scripts/furniture_props.gd")
const Focus = preload("res://scripts/interaction_focus.gd")
const Training = preload("res://scripts/training_ui.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("run_preview")

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("FOCUS_FAIL ",message)

func run_preview() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var stage := Node3D.new()
	root.add_child(stage)
	var computer := Computer.create(stage, Vector3(0, 0.75, 0))
	Furniture.place(stage, "desk", Vector3.ZERO)
	var text := computer.root.find_child("TrainingDisplayText", true, false) as Label3D
	text.text = ">_"
	text.font_size = 38
	text.pixel_size = 0.0018
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("a4b7bf")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("dbe9eb")
	env.environment.ambient_light_energy = 0.65
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_energy = 1.1
	stage.add_child(sun)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0.65, 1.38, 2.35)
	camera.look_at(Vector3(0.06, 0.99, 0), Vector3.UP)
	camera.fov = 43
	camera.current = true
	var training := Training.new()
	root.add_child(training)
	var focus := Focus.new()
	root.add_child(focus)
	var screen := computer.screen_mesh as MeshInstance3D
	var material_before := screen.material_override
	var station := {"name":"Campus security PC", "node":computer.root, "screen":computer.screen, "kind":"pc", "asset":computer}
	focus.update_target(camera, station, camera.global_position.distance_to(computer.screen), true)
	await process_frame
	focus.update_target(camera, station, 2.4, true)
	await process_frame
	verify(focus._canvas.visible, "focused card is visible")
	verify(focus._title.text == "Inspect workstation", "workstation copy")
	verify(focus._subtitle.text == "Access console & timeline", "workstation subtitle")
	verify(focus._tag.visible, "monitor tag projects on screen")
	verify(is_instance_valid(focus._outline), "native monitor outline created")
	var segments: int = focus._outline.mesh.get_meta("boundary_segments", 0)
	verify(segments >= 4 and segments <= 90, "outline contains perimeter segments rather than filled surface")
	verify(screen.material_override == material_before, "screen material remains untouched during focus")
	verify(focus._card.size.x <= 274 and focus._card.size.y <= 66, "bottom card stays compact")
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://tools/polish_focus_preview.png")
	var layouts: Array[Dictionary] = []
	for resolution: Vector2i in [Vector2i(1280,720), Vector2i(960,540), Vector2i(640,480), Vector2i(480,320), Vector2i(320,240)]:
		root.size = resolution
		await process_frame
		focus.update_target(camera, station, 2.4, true)
		await process_frame
		focus.update_target(camera, station, 2.4, true)
		var viewport_size := root.get_visible_rect().size
		var card_rect: Rect2 = focus._card.get_global_rect()
		verify(card_rect.position.x >= 0 and card_rect.end.x <= viewport_size.x + 1, "card horizontal bounds at %s" % resolution)
		verify(card_rect.position.y >= 0 and card_rect.end.y <= viewport_size.y + 1, "card vertical bounds at %s" % resolution)
		if focus._tag.visible:
			var tag_rect: Rect2 = focus._tag.get_global_rect()
			verify(tag_rect.position.x >= 292 and tag_rect.end.x <= viewport_size.x + 1, "projected label avoids left HUD and right edge at %s" % resolution)
			verify(tag_rect.position.y >= 70 and tag_rect.end.y < card_rect.position.y, "projected label avoids header and interaction card at %s" % resolution)
		layouts.append({"resolution":str(resolution), "viewport":str(viewport_size), "card":str(card_rect), "tag_visible":focus._tag.visible, "tag":str(focus._tag.get_global_rect())})
		if resolution == Vector2i(640,480) and DisplayServer.get_name() != "headless":
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://tools/polish_focus_640.png")
	focus.clear_target()
	verify(not focus._canvas.visible, "clear hides all focus UI")
	verify(not focus._outline.visible, "clear hides native outline")
	verify(screen.material_override == material_before, "clear preserves source material")
	root.size = Vector2i(1280,720)
	await process_frame
	var server := {"name":"Lab services rack", "node":computer.root, "screen":computer.screen, "kind":"server", "model":"server_rack"}
	focus.update_target(camera, server, 1.8, true)
	await process_frame
	verify(focus._title.text == "Inspect server", "server-specific title")
	verify(focus._subtitle.text == "Review role & status", "server-specific subtitle")
	verify(focus._tag_title.text == "CAMPUS SERVER", "server-specific projected tag")
	verify(not is_instance_valid(focus._outline), "server has no unrelated monitor outline")
	focus.update_target(camera, station, 2.4, false)
	verify(not focus._canvas.visible, "caller visibility gate clears focus")
	focus.update_target(camera, {}, 0, true)
	verify(not focus._canvas.visible, "empty target clears focus")
	verify(screen.material_override == material_before, "material retained after switching target types")
	var report := {"passed": failures.is_empty(), "checks":checks, "failures":failures, "perimeter_segments":segments, "layouts":layouts}
	FileAccess.open("res://tools/polish_focus_test.json", FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FOCUS_TEST ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
