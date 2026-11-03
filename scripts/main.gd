extends Node3D
signal initialization_progress(label: String, stage: String, completed: Variant, total: Variant)
signal launcher_return_requested
signal launcher_settings_requested

const CampusRuntime = preload("res://scripts/campus_runtime.gd")
const TrainingUI = preload("res://scripts/training_ui.gd")
const ApprovedComputer = preload("res://scripts/computer_prop.gd")
const ApprovedFurniture = preload("res://scripts/furniture_props.gd")
const FocusOverlay = preload("res://scripts/interaction_focus.gd")
const InteractionTarget = preload("res://scripts/interaction_target.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const CampusOcclusion = preload("res://scripts/campus_occlusion.gd")
const SPAWNS: Dictionary = {
	"Campus plaza": Vector3(-27, 1.25, -85),
	"Reception / response desk": Vector3(-36.2, 1.91, -104.1),
	"Auditorium rear aisle": Vector3(-37, 1.924, -107.95),
	"Glazed building entrance": Vector3(-5.8, 2.80, -102.9),
	"Security training area": Vector3(0.90, 2.80, -110.5),
	"Auditorium teaching desk": Vector3(-43, 1.09, -121.4)
}
var campus: Node3D
var training: CanvasLayer
var player: CharacterBody3D
var camera: Camera3D
var stations: Array[Dictionary] = []
var imported_props: Array[Node3D] = []
var ready_to_play: bool = false
var moving: bool = false
var testing: bool = false
var test_axis: Vector2 = Vector2.ZERO
var pitch: float = 0.0
var overlay: CanvasLayer
var menu: PanelContainer
var pause_menu: Control
var menu_title: Label
var menu_body: Label
var menu_buttons: VBoxContainer
var prompt: Label
var loading: Label
var _closest: Dictionary = {}
var _screenshot_pending: bool = false
var focus_overlay: CanvasLayer
var contact_lights: Array[SpotLight3D] = []
var menu_shade: ColorRect
var preview_mode: bool = false
var environment_polish: Node3D
var polish_stats: Dictionary = {}
var launcher_managed := false
var runtime_preferences: Dictionary = {}
var prepared_campus: PackedScene
var prepared_sections: Array[PackedScene] = []
var initialization_finished := false
var initialization_error := ""
var initialization_cancelled := false
var mouse_sensitivity := 1.0

func _ready() -> void:
	initialization_progress.emit("Configuring the game session","game_services",null,null)
	_setup_inputs()
	_setup_environment()
	_build_player()
	if launcher_managed: _spawn("Campus plaza")
	if launcher_managed: await get_tree().process_frame
	initialization_progress.emit("Preparing the incident-response interface","incident_ui",null,null)
	var ui_started := Time.get_ticks_usec()
	training = TrainingUI.new()
	training.name = "TrainingUI"
	add_child(training)
	print("ENSA_UI_BUILD_MS ",(Time.get_ticks_usec()-ui_started)/1000.0)
	training.capture_changed.connect(_set_capture)
	if launcher_managed: await get_tree().process_frame
	initialization_progress.emit("Preparing campus navigation controls","navigation_ui",null,null)
	_build_overlay()
	focus_overlay = FocusOverlay.new()
	add_child(focus_overlay)
	if launcher_managed: await get_tree().process_frame
	_show_menu("ENSA / INCIDENT RESPONSE", "A fictional cyberattack has disrupted a campus workstation.\nExplore the campus, find a response PC, and investigate before taking action.\n\nWASD or ZQSD / arrows: move  ·  Mouse: look\nShift: run  ·  Space: jump  ·  E: inspect target\nTab: campus destinations  ·  J: response plan\nEsc: pause / release mouse\n\nPreserve evidence → contain → recover → report.", false)
	loading.text = "Preparing campus…"
	pause_menu.set_loading(loading.text)
	campus = CampusRuntime.new()
	campus.name = "CampusRuntime"
	campus.prepared_asset = prepared_campus
	campus.prepared_sections = prepared_sections
	campus.build_progress.connect(func(label: String,stage: String,done: Variant,total: Variant): initialization_progress.emit(label,stage,done,total))
	add_child(campus)
	await campus.build()
	if not bool(campus.stats.get("ready", false)):
		initialization_finished = true
		initialization_error = campus.build_error if not campus.build_error.is_empty() else "Campus preparation was cancelled."
		loading.text = "Campus could not load. See the project README for recovery."
		pause_menu.set_loading(loading.text)
		return
	initialization_progress.emit("Preparing hidden-geometry culling","occlusion",null,null)
	await get_tree().process_frame
	if initialization_cancelled:
		initialization_finished = true
		return
	var occlusion = CampusOcclusion.new()
	campus.stats["occlusion"] = occlusion.install(campus)
	initialization_progress.emit("Placing the response workstations","stations",null,null)
	await _add_response_stations()
	for prop: Node3D in imported_props:
		_set_prop_light_layers(prop)
	print("APPROVED_PROPS_READY ", imported_props.size(), " stations=", stations.size())
	initialization_progress.emit("Applying campus visual finishes","polish",null,null)
	await get_tree().process_frame
	if initialization_cancelled:
		initialization_finished = true
		return
	ready_to_play = true
	_install_environment_polish()
	apply_runtime_preferences(runtime_preferences)
	pause_menu.set_ready(true)
	DisplayServer.window_set_title("ENSA | Incident Response")
	loading.text = "Campus ready / choose Start exploration"
	_spawn("Campus plaza")
	initialization_finished = true
	if launcher_managed:
		_set_capture(false)
		overlay.hide()
		training.hide()
		focus_overlay.hide()
		set_physics_process(false)
		set_process_unhandled_input(false)
		training.set_process_input(false)
	if "--smoke-test" in OS.get_cmdline_user_args():
		await _smoke_test()
	elif "--preview" in OS.get_cmdline_user_args():
		preview_mode = true
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		_capture_preview("start-menu-preview.png")
		menu.hide()
		pause_menu.hide_menu()
		menu_shade.hide()
		training.set_exploration_visible(true)
		await _preview_destination("Reception / response desk", "campus-preview.png")
		await _preview_destination("Auditorium rear aisle", "auditorium-preview.png")
		await _preview_destination("Glazed building entrance", "glazed-building-preview.png")
		await _preview_destination("Security training area", "security-assets-preview.png")
		_show_server_info(stations[4])
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		_capture_preview("server-inspection-preview.png")
		menu.hide()
		pause_menu.hide_menu()
		menu_shade.hide()
		training.set_exploration_visible(true)
		await _preview_destination("Auditorium teaching desk", "teaching-assets-preview.png")
		await _preview_destination("Campus plaza", "plaza-preview.png")
		await _preview_destination("Reception / response desk", "campus-preview.png")
		training.open_terminal()
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		_capture_preview("training-preview.png")
		get_tree().quit()

func _install_environment_polish() -> void:
	# Optional: absence/failure leaves the original campus available for play.
	if "--no-polish" in OS.get_cmdline_args() or "--no-polish" in OS.get_cmdline_user_args():
		polish_stats = {"installed": false, "disabled_by_argument": true}
		return
	if is_instance_valid(environment_polish) and environment_polish.call("is_installed"):
		return
	var path := "res://scripts/antigravity/environment_polish.gd"
	if not ResourceLoader.exists(path):
		return
	var polish_script := load(path) as GDScript
	if polish_script == null or not polish_script.can_instantiate():
		push_warning("Optional environment polish could not load; using original campus finishes.")
		return
	var candidate: Object = polish_script.new()
	if not candidate is Node3D or not candidate.has_method("install") or not candidate.has_method("uninstall") or not candidate.has_method("is_installed"):
		candidate.free()
		push_warning("Optional environment polish has an incompatible interface.")
		return
	environment_polish = candidate as Node3D
	environment_polish.name = "AntigravityEnvironmentPolish"
	add_child(environment_polish)
	polish_stats = environment_polish.call("install", self)
	if not bool(polish_stats.get("installed", false)):
		environment_polish.call("uninstall")
		environment_polish.queue_free()
		environment_polish = null
		push_warning("Optional environment polish declined installation: " + str(polish_stats.get("errors", [])))
	print("ANTIGRAVITY_POLISH_READY: ", polish_stats.get("installed", false))

func _setup_inputs() -> void:
	if not runtime_preferences.is_empty(): return
	var keys: Dictionary = {"move_forward": [KEY_W, KEY_Z, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_Q, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "run": [KEY_SHIFT], "jump": [KEY_SPACE], "interact": [KEY_E], "destinations": [KEY_TAB], "response_plan":[KEY_J],"pause":[KEY_ESCAPE]}
	for action: String in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for code: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

func _setup_environment() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4d82a9")
	sky_material.sky_horizon_color = Color("c0d2da")
	sky_material.ground_horizon_color = Color("c0c8c4")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d3e3ed")
	environment.ambient_light_energy = 0.32
	environment.ambient_light_sky_contribution = 0.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.92
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_color = Color("fff0d5")
	sun.light_energy = 0.32
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 2.0
	sun.shadow_blur = 1.4
	sun.shadow_opacity = 0.88
	add_child(sun)
	for p: Vector3 in [Vector3(-37, 5.4, -110), Vector3(-37, 5.4, -120), Vector3(-8, 10, -116)]:
		var light := OmniLight3D.new()
		light.position = p
		light.omni_range = 15
		light.light_energy = 1.2 if p.x < -30.0 else 0.65
		light.light_color = Color("fff4df")
		add_child(light)
	# Local, shaded key lights ground desks/chairs without shadowing six cube faces.
	for setup: Array in [
		[Vector3(-36.2,4.08,-105.0),Vector3(-36.2,1.3,-105.5),5.2,0.36],
		[Vector3(0.6,4.75,-112.0),Vector3(0.5,2.0,-112.0),5.8,0.40],
		[Vector3(-42.5,5.2,-121.5),Vector3(-43,0.5,-122),6.5,0.50]]:
		var key := SpotLight3D.new()
		key.position = setup[0]
		key.spot_range = setup[2]
		key.spot_angle = 50.0
		key.spot_attenuation = 0.65
		key.light_energy = setup[3]
		key.light_color = Color("f5eddf")
		key.shadow_bias = 0.06
		key.shadow_normal_bias = 0.55
		key.shadow_blur = 1.8
		key.light_cull_mask = 2
		key.shadow_enabled = false
		add_child(key)
		key.look_at(setup[1],Vector3.UP)
		contact_lights.append(key)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.floor_snap_length = 0.45
	player.floor_max_angle = deg_to_rad(48)
	player.safe_margin = 0.02
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.78
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	player.add_child(collision)
	add_child(player)
	camera = Camera3D.new()
	camera.name = "Eyes"
	camera.position.y = 0.65
	camera.fov = 78
	camera.near = 0.1
	camera.far = 220
	camera.current = true
	player.add_child(camera)

func _physics_process(delta: float) -> void:
	if not ready_to_play: return
	var axis := Vector2.ZERO
	if testing:
		axis = test_axis
	elif moving and not training.terminal_open:
		axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := player.global_basis * Vector3(axis.x, 0, axis.y)
	direction.y = 0
	direction = direction.normalized()
	var speed: float = 7.0 if Input.is_action_pressed("run") else 4.0
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor(): player.velocity.y -= 22.0 * delta
	if moving and player.is_on_floor() and Input.is_action_just_pressed("jump"): player.velocity.y = 6.3
	if axis.length() > 0.01 and player.is_on_floor() and player.velocity.y <= 0:
		var motion := Vector3(player.velocity.x, 0, player.velocity.z) * delta
		if player.test_move(player.global_transform, motion):
			var raised := player.global_transform.translated(Vector3.UP * 0.28)
			if not player.test_move(raised, motion): player.position.y += 0.28
	player.move_and_slide()
	if player.position.y < -10: _spawn("Campus plaza")

func _process(_delta: float) -> void:
	if not ready_to_play: return
	_closest = InteractionTarget.find(camera, player, stations)
	var door_target: Dictionary = campus.door_system.get_target(camera,player,2.0)
	if not door_target.is_empty() and (_closest.is_empty() or camera.global_position.distance_to(door_target.screen) < camera.global_position.distance_to(_closest.screen)):
		_closest = door_target
	for station: Dictionary in stations:
		var label: Label3D = station["label"]
		label.visible = false
	prompt.visible = false
	var show_focus: bool = (moving or preview_mode) and not training.terminal_open and not training.is_plan_open() and not _menu_visible() and not _closest.is_empty()
	for door: Node3D in campus.door_system.doors:
		door.set_focused(show_focus and _closest.get("node")==door)
	var focus_distance: float = camera.global_position.distance_to(_closest["screen"]) if not _closest.is_empty() else 0.0
	focus_overlay.update_target(camera,_closest,focus_distance,show_focus)
	var nearest_light: SpotLight3D
	var light_distance: float = 7.0
	for key: SpotLight3D in contact_lights:
		var distance: float = player.position.distance_to(key.position)
		if distance<light_distance:
			nearest_light=key
			light_distance=distance
	for key: SpotLight3D in contact_lights:
		key.shadow_enabled = key == nearest_light and runtime_preferences.get("graphics_preset","medium") != "low"

func cancel_initialization() -> void:
	initialization_cancelled = true
	if is_instance_valid(campus): campus.cancelled = true

func apply_runtime_preferences(data: Dictionary) -> void:
	if data.is_empty(): return
	runtime_preferences = data.duplicate(true)
	mouse_sensitivity = clampf(float(data.get("mouse_sensitivity",1.0)),.5,3.0)
	for child: Node in get_children():
		if child is DirectionalLight3D:
			child.directional_shadow_max_distance = {"low":24.0,"medium":45.0,"high":60.0}.get(data.get("graphics_preset","medium"),45.0)
	var labels := {"E":"interact","J":"response_plan","Tab":"destinations"}
	_update_key_labels(self,labels,data.get("bindings",{}))

func _update_key_labels(node: Node, labels: Dictionary, bindings: Dictionary) -> void:
	if node is Label:
		if not node.has_meta("original_key_hint") and labels.has(node.text): node.set_meta("original_key_hint",node.text)
		var original: String = str(node.get_meta("original_key_hint",""))
		if labels.has(original) and bindings.has(labels[original]):
			node.text = OS.get_keycode_string(int(bindings[labels[original]][0]))
	for child: Node in node.get_children(): _update_key_labels(child,labels,bindings)

func restore_safe_pose(data: Dictionary) -> void:
	var coordinates: Array = data.get("position",[])
	if coordinates.size()!=3: return
	var wanted := Vector3(float(coordinates[0]),float(coordinates[1]),float(coordinates[2]))
	var query := PhysicsRayQueryParameters3D.create(wanted+Vector3.UP*.3,wanted-Vector3.UP*1.7,1,[player.get_rid()])
	var ground: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if ground.is_empty(): return # _spawn already placed the player at a safe destination.
	wanted.y = ground.position.y+.92
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = (player.get_child(0) as CollisionShape3D).shape
	shape.transform = Transform3D(Basis.IDENTITY,wanted)
	shape.exclude = [player.get_rid()]
	shape.collision_mask = 1
	if not get_world_3d().direct_space_state.intersect_shape(shape).is_empty(): return
	player.global_position = wanted
	player.rotation.y = float(data.get("yaw",0.0))
	pitch = clampf(float(data.get("pitch",0.0)),-1.35,1.35)
	camera.rotation.x = pitch

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and moving and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.0024 * mouse_sensitivity)
		pitch = clampf(pitch-event.relative.y*0.0024*mouse_sensitivity, -1.35, 1.35)
		camera.rotation.x = pitch
	if training.terminal_open: return
	if training.is_plan_open(): return
	if event.is_action_pressed("interact") and moving and not _closest.is_empty():
		if _closest.get("kind", "pc") == "door":
			_closest.node.toggle(player)
		elif _closest.get("kind", "pc") == "server":
			_show_server_info(_closest)
		else:
			training.open_terminal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("destinations"):
		_show_destinations()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if _menu_visible() and ready_to_play:
			_resume()
		else:
			_show_menu("PAUSED / CAMPUS EXPLORATION", "Take your time. Your investigation stays in this session.\nFind a marked PC and press E to inspect the incident.\nTab opens the campus destination guide.", false)

func _set_capture(captured: bool) -> void:
	moving = captured and ready_to_play and not _menu_visible()
	training.set_exploration_visible(not _menu_visible())
	if is_instance_valid(menu_shade): menu_shade.visible = menu.visible
	if is_instance_valid(focus_overlay) and not moving: focus_overlay.clear_target()
	if not moving and is_instance_valid(campus) and is_instance_valid(campus.door_system):
		for door: Node3D in campus.door_system.doors: door.set_focused(false)
	if is_instance_valid(campus) and is_instance_valid(campus.door_system):
		campus.door_system.process_mode = Node.PROCESS_MODE_DISABLED if _menu_visible() or training.terminal_open else Node.PROCESS_MODE_INHERIT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if moving else Input.MOUSE_MODE_VISIBLE

func _resume() -> void:
	if not ready_to_play: return
	menu.hide()
	pause_menu.hide_menu()
	_set_capture(true)

func _spawn(destination: String) -> void:
	player.global_position = SPAWNS[destination]
	player.velocity = Vector3.ZERO
	pitch = 0
	camera.rotation.x = 0
	var target: Vector3 = Vector3(-37, player.position.y, -104)
	if destination == "Reception / response desk": target = Vector3(-36.2, player.position.y, -106)
	elif destination == "Auditorium rear aisle": target = Vector3(-37, player.position.y, -122)
	elif destination == "Glazed building entrance": target = Vector3(-8, player.position.y, -107)
	elif destination == "Security training area": target = Vector3(0, player.position.y, -112)
	elif destination == "Auditorium teaching desk": target = Vector3(-43, player.position.y, -122)
	player.look_at(target, Vector3.UP)
	if destination in ["Reception / response desk", "Security training area", "Auditorium teaching desk"]:
		pitch = -0.23
		if destination == "Auditorium teaching desk": pitch = -0.55
		camera.rotation.x = pitch

func _add_response_stations() -> void:
	_add_imported_pc("Reception response PC", Vector3(-36.2, 1.735, -105.52))
	await get_tree().process_frame
	imported_props.append(ApprovedFurniture.place(self, "desk", Vector3(0, 1.80, -112)))
	imported_props.append(ApprovedFurniture.place(self, "chair", Vector3(0, 1.80, -111.15), PI))
	_add_imported_pc("Campus security PC", Vector3(0, 2.55, -112))
	await get_tree().process_frame
	imported_props.append(ApprovedFurniture.place(self, "desk", Vector3(-43, 0.09, -122)))
	_add_imported_pc("Auditorium teaching PC", Vector3(-43, 0.84, -122))
	await get_tree().process_frame
	for x: float in [-38.0, -35.35]:
		imported_props.append(ApprovedFurniture.place(self, "chair", Vector3(x, 0.922, -106.17)))
	_add_imported_server("Lab services rack", "server_rack", Vector3(1.10, 1.80, -113.5))
	await get_tree().process_frame
	_add_imported_server("Recovery storage rack", "server_rack_1", Vector3(2.30, 1.80, -113.5))

func _add_imported_pc(title: String, base: Vector3) -> void:
	var asset: Dictionary = ApprovedComputer.create(self, base)
	if asset.is_empty(): return
	var station: Node3D = asset["root"]
	station.name = title.replace(" ", "")
	imported_props.append(station)
	var marker := _station_marker(station, title + "\n[E] TRAINING CONSOLE", asset["label_position"])
	stations.append({"name":title,"node":station,"screen":asset["screen"],"label":marker,"kind":"pc","asset":asset})

func _station_marker(parent: Node3D, title: String, world_position: Vector3) -> Label3D:
	var marker := Label3D.new()
	marker.text = title
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 30
	marker.pixel_size = 0.004
	marker.modulate = Color("69efd0")
	parent.add_child(marker)
	marker.global_position = world_position
	return marker

func _set_prop_light_layers(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = 3
	for child: Node in node.get_children():
		_set_prop_light_layers(child)

func _add_imported_server(title: String, kind: String, floor_position: Vector3) -> void:
	var prop: Node3D = ApprovedFurniture.place(self, kind, floor_position)
	imported_props.append(prop)
	var bounds: AABB = prop.get_meta("local_bounds")
	var target := prop.to_global(Vector3(0, 1.15, bounds.end.z+0.04))
	var marker := _station_marker(prop, title + "\n[E] INSPECT", floor_position + Vector3(0, 2.25, 0))
	stations.append({"name":title,"node":prop,"screen":target,"label":marker,"kind":"server","model":kind})

func _show_server_info(station: Dictionary) -> void:
	var isolated: bool = bool(training.state.get("host_isolated",false))
	var revoked: bool = bool(training.state.get("session_revoked",false))
	var role: String = "Hosts the fictional lab services used in this case." if station["model"] == "server_rack" else "Stores the fictional approved recovery baseline and evidence archive."
	var body: String = role + "\n\nThe alert concerns one workstation, lab-ws-07. The rack is not the affected endpoint.\nIsolate the affected host rather than shutting down every campus service.\n\nWorkstation: " + ("isolated" if isolated else "connected") + "\nReused session: " + ("revoked" if revoked else "not yet revoked") + "\n\nUse a response PC to review evidence and take the incident-response actions."
	_show_menu(str(station["name"]).to_upper(),body,false)

func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root)
	menu_shade = ColorRect.new()
	menu_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_shade.color = Color(0.008,0.014,0.022,0.57)
	menu_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(menu_shade)
	pause_menu = PauseMenu.new()
	pause_menu.launcher_available = launcher_managed
	pause_menu.name = "CampusPauseMenu"
	root.add_child(pause_menu)
	pause_menu.configure(training)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.destinations_requested.connect(_show_destinations)
	pause_menu.destination_requested.connect(func(destination: String):_spawn(destination);_resume())
	pause_menu.quit_requested.connect(func():
		if launcher_managed: launcher_return_requested.emit()
		else: get_tree().quit())
	pause_menu.settings_requested.connect(func(): launcher_settings_requested.emit())
	prompt = Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -370
	prompt.offset_right = 370
	prompt.offset_top = -65
	prompt.offset_bottom = -30
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 19)
	prompt.add_theme_color_override("font_color", Color("81f0d2"))
	root.add_child(prompt)
	menu = PanelContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -335
	menu.offset_right = 335
	menu.offset_top = -280
	menu.offset_bottom = 280
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.028,0.045,0.057,0.97)
	style.border_color = Color(0.46,0.65,0.70,0.27)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	menu.add_theme_stylebox_override("panel", style)
	root.add_child(menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 17)
	menu.add_child(column)
	menu_title = Label.new()
	menu_title.add_theme_font_size_override("font_size", 26)
	menu_title.add_theme_color_override("font_color", Color("81f0d2"))
	column.add_child(menu_title)
	menu_body = Label.new()
	menu_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_body.add_theme_font_size_override("font_size", 17)
	column.add_child(menu_body)
	menu_buttons = VBoxContainer.new()
	menu_buttons.add_theme_constant_override("separation", 8)
	column.add_child(menu_buttons)
	loading = Label.new()
	loading.add_theme_color_override("font_color", Color("a4b8c5"))
	column.add_child(loading)

func _clear_menu_buttons() -> void:
	for button: Node in menu_buttons.get_children():
		menu_buttons.remove_child(button)
		button.queue_free()

func _button(title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 39
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10,0.14,0.16,0.87)
	normal.border_color = Color(0.50,0.65,0.69,0.22)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.12,0.22,0.24,0.96)
	hover.border_color = Color(0.32,0.85,0.80,0.75)
	button.add_theme_stylebox_override("normal",normal)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("focus",hover)
	button.add_theme_stylebox_override("pressed",hover)
	button.pressed.connect(action)
	menu_buttons.add_child(button)

func _menu_visible() -> bool:
	return (is_instance_valid(menu) and menu.visible) or (is_instance_valid(pause_menu) and pause_menu.visible)

func _show_menu(title: String, body: String, _unused: bool) -> void:
	if title.begins_with("ENSA /") or title.begins_with("PAUSED /"):
		menu.hide()
		pause_menu.show_pause(not ready_to_play)
		_set_capture(false)
		return
	pause_menu.hide_menu()
	menu_title.text = title
	menu_body.text = body
	_clear_menu_buttons()
	_button("Start exploration / resume", _resume)
	_button("Campus destinations", _show_destinations)
	_button("Quit game", func():get_tree().quit())
	menu.show()
	_set_capture(false)

func _show_destinations() -> void:
	if not ready_to_play: return
	menu.hide()
	var names: Array[String] = []
	names.assign(SPAWNS.keys())
	pause_menu.show_destinations(names)
	_set_capture(false)


func _capture_preview(filename: String) -> void:
	var picture := get_viewport().get_texture().get_image()
	picture.save_png("user://" + filename)
	print("PREVIEW ", OS.get_user_data_dir().path_join(filename))

func _preview_destination(destination: String, filename: String) -> void:
	print("PREVIEW_START ", destination)
	training.set_exploration_visible(true)
	_spawn(destination)
	for _frame: int in range(20):
		await get_tree().physics_frame
	for _frame: int in range(30):
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	_capture_preview(filename)
	print("PREVIEW_FPS ", destination, " ", Engine.get_frames_per_second(), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

func _smoke_test() -> void:
	testing = true
	var training_result: Dictionary = training.run_self_test()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ground: Dictionary = campus.sample_ground_hits()
	_spawn("Reception / response desk")
	for frame in range(60): await get_tree().physics_frame
	var settled: bool = player.position.y > 1.5 and player.position.y < 2.2
	var moving_start: Vector3 = player.position
	test_axis = Vector2(1,0)
	for frame in range(20): await get_tree().physics_frame
	test_axis = Vector2.ZERO
	var walked: bool = player.position.distance_to(moving_start)>0.3
	var destinations: Dictionary = {}
	for destination: String in SPAWNS:
		_spawn(destination)
		for _frame: int in range(45): await get_tree().physics_frame
		destinations[destination] = {"on_floor": player.is_on_floor(), "height": player.position.y}
	_spawn("Auditorium rear aisle")
	for _frame: int in range(20): await get_tree().physics_frame
	var aisle_start: Vector3 = player.position
	test_axis = Vector2(0,-1)
	for _frame: int in range(80): await get_tree().physics_frame
	test_axis = Vector2.ZERO
	var aisle_walked: bool = aisle_start.distance_to(player.position) > 3.5 and player.position.y > -1.0
	var clear_ground: bool = true
	for hit: Dictionary in ground.values():
		if not bool(hit.get("hit",false)): clear_ground=false
	var all_destinations_grounded: bool = true
	for destination: Dictionary in destinations.values():
		all_destinations_grounded = all_destinations_grounded and bool(destination["on_floor"])
	var result := {"training":training_result,"campus":campus.stats,"ground":ground,"destinations":destinations,"player_settled":settled,"player_walked":walked,"aisle_walked":aisle_walked,"station_count":stations.size(),"passed":bool(training_result.get("passed",false)) and settled and walked and clear_ground and all_destinations_grounded and aisle_walked}
	var file := FileAccess.open("user://smoke-test.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print("GAME_SMOKE_TEST ", JSON.stringify(result))
	get_tree().quit(0 if result["passed"] else 1)
