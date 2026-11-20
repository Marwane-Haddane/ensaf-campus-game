extends Node3D
## Auditorium cinema: a remote on the stage lip, five sittable front-row seats,
## and the large projection screen turned into a cinema screen.
## Kept off the mission station list so incident-response checks stay at 5 stations.
## Cheap by design: the screen viewport renders only while cinema mode is on.

const InteractionTarget = preload("res://scripts/interaction_target.gd")

const SCREEN_CENTER := Vector3(-37.0, 3.125, -124.33)
const SCREEN_SIZE := Vector2(5.30, 3.15)
const FRONT_FLOOR_Y := -0.677
## Row 01 seats nearest the centre aisle (seats 003, 002, 001 | 010, 011).
const SEATS: Array[Vector3] = [
	Vector3(-39.463, -0.07, -118.99), Vector3(-38.762, -0.07, -119.00), Vector3(-38.061, -0.07, -119.01),
	Vector3(-35.939, -0.07, -119.01), Vector3(-35.238, -0.07, -119.00)]
const REMOTE_HOME := Vector3(-37.0, 0.1, -121.15)
const AUDITORIUM := AABB(Vector3(-47.5, -2.0, -126.0), Vector3(21.0, 12.0, 20.0))
const VIDEO_EXT := ["ogv"]
const REMOTE_MODEL := "res://assets/props/cinema/telecommande.glb"

var game: Node3D
var targets: Array[Dictionary] = []
var remote_held := false
var seated := false
var seat_index := -1
var cinema_on := false
var lights_dimmed := false

var _remote_world: Node3D
var _remote_target: Dictionary = {}
var _remote_hand: Node3D
var _screen: MeshInstance3D
var _viewport: SubViewport
var _video: VideoStreamPlayer
var _home: Control
var _now_title: Label
var _now_sub: Label
var _clock: Label
var _light_energy: Dictionary = {}
var _ui: CanvasLayer
var _panel: PanelContainer
var _hint: Label
var _hint_timer := 0.0
var _video_list: ItemList
var _video_paths: Array[String] = []
var _power_button: Button
var _lights_button: Button
var _play_button: Button
var _url: LineEdit
var _file_dialog: FileDialog
var _volume: HSlider
## Embedded Chromium (gdcef GDExtension in res://cef_artifacts). Started lazily on
## the first web request so the campus pays nothing until someone opens YouTube.
var _cef: Node
var _browser: Object
var _web_rect: TextureRect
var _web_error := ""
var _controlling := false
var _mouse_down := false
var _mute_button: Button

func install(owner_game: Node3D) -> void:
	game = owner_game
	name = "AuditoriumCinema"
	_build_remote()
	_build_seats()
	_build_screen()
	_build_ui()
	_set_cinema(false)

# ---------- world props ----------

func _build_remote() -> void:
	var home := REMOTE_HOME
	var hit := _ground(Vector3(REMOTE_HOME.x, 2.0, REMOTE_HOME.z), 3.0)
	if not hit.is_empty(): home.y = float(hit.position.y) + 0.012
	_remote_world = Node3D.new()
	_remote_world.name = "CinemaRemote"
	add_child(_remote_world)
	_remote_world.global_position = home
	_remote_world.rotation.y = 0.35
	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 0.16
	pad_mesh.bottom_radius = 0.16
	pad_mesh.height = 0.01
	pad_mesh.radial_segments = 20
	pad.mesh = pad_mesh
	pad.material_override = _unshaded(Color(0.25, 0.9, 0.85, 0.35), true)
	_remote_world.add_child(pad)
	_remote_world.add_child(_remote_mesh())
	_remote_world.set_meta("local_bounds", AABB(Vector3(-0.17, -0.02, -0.17), Vector3(0.34, 0.14, 0.34)))
	var label := Label3D.new()
	label.text = "CINEMA REMOTE"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 26
	label.pixel_size = 0.004
	label.modulate = Color("69efd0")
	label.position = Vector3(0, 0.32, 0)
	_remote_world.add_child(label)
	_remote_target = {"name":"Cinema remote", "node":_remote_world, "screen":home + Vector3(0, 0.04, 0), "kind":"remote", "prompt":"Press E to take remote"}
	targets.append(_remote_target)
	_remote_hand = _remote_mesh()
	_remote_hand.name = "RemoteInHand"
	game.camera.add_child(_remote_hand)
	_remote_hand.position = Vector3(0.30, -0.27, -0.62)
	_remote_hand.rotation = Vector3(0.55, -0.35, 0.0)
	_remote_hand.scale = Vector3.ONE * 0.8
	_remote_hand.visible = false

## The user's remote model has ~97 parts; merge them once into one mesh with one
## surface per material (8 draw calls) and share it between stage and hand copies.
static var _merged_remote: ArrayMesh

func _remote_mesh() -> Node3D:
	if _merged_remote == null and ResourceLoader.exists(REMOTE_MODEL):
		var scene := load(REMOTE_MODEL) as PackedScene
		if scene != null: _merged_remote = _merge_meshes(scene.instantiate())
	if _merged_remote != null:
		var model := MeshInstance3D.new()
		model.name = "RemoteModel"
		model.mesh = _merged_remote
		model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var holder := Node3D.new()
		holder.add_child(model)
		return holder
	return _box_remote()

static func _merge_meshes(source: Node3D) -> ArrayMesh:
	var tools: Dictionary = {}
	for node: Node in source.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null: continue
		var xf: Transform3D = _relative_transform(part, source)
		for i: int in part.mesh.get_surface_count():
			var mat: Material = part.get_active_material(i)
			if not tools.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[mat] = st
			(tools[mat] as SurfaceTool).append_from(part.mesh, i, xf)
	var merged := ArrayMesh.new()
	for mat: Variant in tools:
		var st := tools[mat] as SurfaceTool
		st.set_material(mat)
		merged = st.commit(merged)
	source.free()
	return merged if merged.get_surface_count() > 0 else null

static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D: xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

func _box_remote() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.022, 0.17)
	body.mesh = box
	body.position.y = 0.011
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.075, 0.08)
	mat.roughness = 0.5
	body.material_override = mat
	root.add_child(body)
	var buttons := [[Vector3(0, 0.023, -0.06), Color(0.95, 0.2, 0.2)], [Vector3(0, 0.023, -0.02), Color(0.3, 0.95, 0.85)], [Vector3(0, 0.023, 0.02), Color(0.85, 0.88, 0.9)]]
	for spec: Array in buttons:
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.022, 0.004, 0.014)
		cap.mesh = cap_mesh
		cap.position = spec[0]
		cap.material_override = _unshaded(spec[1], false)
		root.add_child(cap)
	for child: Node in root.get_children():
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

func _build_seats() -> void:
	for i: int in SEATS.size():
		var marker := Node3D.new()
		marker.name = "CinemaSeat%d" % (i + 1)
		add_child(marker)
		marker.global_position = SEATS[i]
		marker.set_meta("local_bounds", AABB(Vector3(-0.34, -0.6, -0.37), Vector3(0.68, 1.2, 0.74)))
		targets.append({"name":"Front-row seat %d" % (i + 1), "node":marker, "screen":SEATS[i] + Vector3(0, -0.15, 0), "kind":"seat", "seat":i, "prompt":"Press E to sit"})

func _build_screen() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "CinemaViewport"
	_viewport.size = Vector2i(1280, 720)
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var root := Control.new()
	_viewport.add_child(root)
	root.position = Vector2.ZERO
	root.size = Vector2(_viewport.size)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.012, 0.018)
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_home = VBoxContainer.new()
	_home.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_home)
	_home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := _screen_label("ENSA CINEMA", 96, Color("69efd0"))
	_home.add_child(title)
	_now_title = _screen_label("Grab a seat", 46, Color("edf5f7"))
	_home.add_child(_now_title)
	_now_sub = _screen_label("Use the remote (R) to pick a video, YouTube or a website", 28, Color("9fb3bf"))
	_home.add_child(_now_sub)
	_clock = _screen_label("", 30, Color("5d7480"))
	_home.add_child(_clock)
	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.visible = false
	_video.finished.connect(_on_video_finished)
	root.add_child(_video)
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_web_rect = TextureRect.new()
	_web_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_web_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_web_rect.visible = false
	root.add_child(_web_rect)
	_web_rect.position = Vector2.ZERO
	_web_rect.size = Vector2(_viewport.size)
	_screen = MeshInstance3D.new()
	_screen.name = "CinemaScreen"
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	_screen.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _viewport.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_screen.material_override = mat
	_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_screen)
	_screen.global_position = SCREEN_CENTER

func _screen_label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	return label

# ---------- remote panel ----------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 14
	add_child(_ui)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_left = -360
	_hint.offset_right = 360
	_hint.offset_top = 84
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color("81f0d2"))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hint)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_panel.offset_left = -360
	_panel.offset_right = -24
	_panel.offset_top = -300
	_panel.offset_bottom = 300
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.028, 0.045, 0.057, 0.95)
	style.border_color = Color(0.32, 0.85, 0.80, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	_ui.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	_panel.add_child(col)
	var head := Label.new()
	head.text = "CINEMA REMOTE"
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Color("81f0d2"))
	col.add_child(head)
	var row := HBoxContainer.new()
	col.add_child(row)
	_power_button = _btn(row, "Cinema: OFF", func(): _set_cinema(not cinema_on))
	_lights_button = _btn(row, "Lights: ON", func(): _set_lights_dimmed(not lights_dimmed))
	col.add_child(_section("VIDEO ON THE SCREEN (.ogv)"))
	_video_list = ItemList.new()
	_video_list.custom_minimum_size.y = 96
	_video_list.item_selected.connect(func(i: int): _play_file(_video_paths[i]))
	col.add_child(_video_list)
	var vrow := HBoxContainer.new()
	col.add_child(vrow)
	_btn(vrow, "Browse file…", _browse)
	_play_button = _btn(vrow, "Pause", _toggle_pause)
	_btn(vrow, "Stop", _stop_video)
	var vol_row := HBoxContainer.new()
	col.add_child(vol_row)
	var vol_label := Label.new()
	vol_label.text = "Volume"
	vol_row.add_child(vol_label)
	_volume = HSlider.new()
	_volume.min_value = 0
	_volume.max_value = 1
	_volume.step = 0.05
	_volume.value = 0.8
	_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume.value_changed.connect(func(v: float): _video.volume = v)
	vol_row.add_child(_volume)
	col.add_child(_section("YOUTUBE / BROWSER"))
	_url = LineEdit.new()
	_url.placeholder_text = "Search YouTube or paste a link"
	_url.text_submitted.connect(func(_t: String): _open_web(false))
	col.add_child(_url)
	var wrow := HBoxContainer.new()
	col.add_child(wrow)
	_btn(wrow, "YouTube", func(): _open_web(true))
	_btn(wrow, "Open link", func(): _open_web(false))
	var nrow := HBoxContainer.new()
	col.add_child(nrow)
	_btn(nrow, "Back", _web_back)
	_btn(nrow, "Reload", _web_reload)
	_mute_button = _btn(nrow, "Mute", _toggle_mute)
	_btn(col, "Use mouse on screen  [C]", _start_control)
	var tip := Label.new()
	tip.text = "Web plays on the big screen. C: click / scroll / type on it." if web_supported() else "Web opens in your system browser (Alt+Tab back)."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", Color("8aa0ad"))
	col.add_child(tip)
	var brow := HBoxContainer.new()
	col.add_child(brow)
	_btn(brow, "Put remote back", _return_remote)
	_btn(brow, "Close  [R]", _close_panel)
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.ogv ; Ogg Theora video"])
	_file_dialog.use_native_dialog = true
	_file_dialog.title = "Pick a video for the cinema screen"
	_file_dialog.file_selected.connect(_play_file)
	_ui.add_child(_file_dialog)

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color("69efd0"))
	return l

func _btn(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 34
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b

# ---------- interaction API used by main.gd ----------

func find_target(camera: Camera3D, player: CharacterBody3D) -> Dictionary:
	if seated or not AUDITORIUM.has_point(player.global_position): return {}
	return InteractionTarget.find(camera, player, targets)

func interact(target: Dictionary) -> void:
	match str(target.get("kind", "")):
		"remote": _take_remote()
		"seat": _sit(int(target["seat"]))

func is_seated() -> bool:
	return seated

func panel_open() -> bool:
	return is_instance_valid(_panel) and _panel.visible

func _input(event: InputEvent) -> void:
	if not _controlling: return
	get_viewport().set_input_as_handled()
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_stop_control()
		elif _browser != null:
			_browser.set_key_pressed(event.unicode if event.unicode != 0 else event.keycode, event.pressed, event.shift_pressed, event.alt_pressed, event.is_command_or_control_pressed())
	elif event is InputEventMouseMotion:
		var px: Variant = _screen_pixel(event.position)
		if px != null and _browser != null:
			if _mouse_down: _browser.set_mouse_left_down()
			_browser.set_mouse_moved(int(px.x), int(px.y))
	elif event is InputEventMouseButton and _browser != null:
		var px: Variant = _screen_pixel(event.position)
		if px == null:
			if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT: _stop_control()
			return
		_browser.set_mouse_moved(int(px.x), int(px.y))
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed: _browser.set_mouse_wheel_vertical(2)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: _browser.set_mouse_wheel_vertical(-2)
			MOUSE_BUTTON_LEFT:
				_mouse_down = event.pressed
				if event.pressed: _browser.set_mouse_left_down()
				else: _browser.set_mouse_left_up()
			MOUSE_BUTTON_RIGHT:
				if event.pressed: _browser.set_mouse_right_down()
				else: _browser.set_mouse_right_up()

func _unhandled_input(event: InputEvent) -> void:
	if not game.ready_to_play: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_C and _browser != null and remote_held and not game.training.terminal_open and not game._menu_visible():
		_start_control()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		if game.training.terminal_open or (game._menu_visible() and not panel_open()): return
		if panel_open(): _close_panel()
		elif remote_held: _open_panel()
		elif AUDITORIUM.has_point(game.player.global_position): _flash("Take the remote from the stage first")
		get_viewport().set_input_as_handled()
	elif panel_open() and event.is_action_pressed("ui_cancel"):
		_close_panel()
		get_viewport().set_input_as_handled()
	elif seated and game.moving and (event.is_action_pressed("interact") or event.is_action_pressed("jump")):
		_stand()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0: _refresh_hint()
	if cinema_on and _home.visible:
		_clock.text = Time.get_time_string_from_system().substr(0, 5)

# ---------- remote / seats ----------

func _take_remote() -> void:
	remote_held = true
	_remote_world.visible = false
	targets.erase(_remote_target)
	_remote_hand.visible = true
	_flash("Remote taken · R: open remote · sit in a front seat to watch")

func _return_remote() -> void:
	remote_held = false
	_remote_hand.visible = false
	_remote_world.visible = true
	if not targets.has(_remote_target): targets.insert(0, _remote_target)
	_close_panel()
	_flash("Remote returned to the stage")

func _sit(index: int) -> void:
	seated = true
	seat_index = index
	var p: CharacterBody3D = game.player
	p.velocity = Vector3.ZERO
	var seat: Vector3 = SEATS[index]
	p.global_position = Vector3(seat.x, FRONT_FLOOR_Y + 1.15 - game.camera.position.y, seat.z + 0.05)
	p.rotation = Vector3(0, atan2(-(SCREEN_CENTER.x - seat.x), -(SCREEN_CENTER.z - seat.z)), 0)
	game.pitch = 0.42
	game.camera.rotation.x = game.pitch
	_refresh_hint()

func _stand() -> void:
	if not seated: return
	var seat: Vector3 = SEATS[seat_index]
	seated = false
	seat_index = -1
	var p: CharacterBody3D = game.player
	p.global_position = Vector3(seat.x, FRONT_FLOOR_Y + 1.0, -119.95)
	p.velocity = Vector3.ZERO
	game.pitch = 0.0
	game.camera.rotation.x = 0.0
	_refresh_hint()

# ---------- cinema ----------

func _set_cinema(on: bool) -> void:
	cinema_on = on
	_screen.visible = on
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on:
		_stop_video()
		_close_browser()
	else:
		_scan_videos()
	_set_lights_dimmed(on)
	if is_instance_valid(_power_button): _power_button.text = "Cinema: ON" if on else "Cinema: OFF"

func _set_lights_dimmed(dim: bool) -> void:
	lights_dimmed = dim
	if _light_energy.is_empty():
		for child: Node in game.get_children():
			if (child is OmniLight3D or child is SpotLight3D) and AUDITORIUM.has_point((child as Node3D).global_position):
				_light_energy[child] = (child as Light3D).light_energy
	for light: Variant in _light_energy:
		if is_instance_valid(light):
			(light as Light3D).light_energy = float(_light_energy[light]) * (0.18 if dim else 1.0)
	if is_instance_valid(_lights_button): _lights_button.text = "Lights: DIM" if dim else "Lights: ON"

func _scan_videos() -> void:
	_video_paths.clear()
	_video_list.clear()
	var folders: Array[String] = [OS.get_user_data_dir().path_join("cinema"), OS.get_system_dir(OS.SYSTEM_DIR_MOVIES), OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)]
	DirAccess.make_dir_recursive_absolute(folders[0])
	for folder: String in folders:
		var dir := DirAccess.open(folder)
		if dir == null: continue
		for file: String in dir.get_files():
			if file.get_extension().to_lower() in VIDEO_EXT and _video_paths.size() < 40:
				_video_paths.append(folder.path_join(file))
				_video_list.add_item(file)
	if _video_paths.is_empty():
		_video_list.add_item("No .ogv found in Videos / Downloads")
		_video_list.set_item_disabled(0, true)

func _browse() -> void:
	_file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_MOVIES)
	_file_dialog.popup_centered_ratio(0.6)

func _play_file(path: String) -> void:
	var stream := VideoStreamTheora.new()
	stream.file = path
	if not cinema_on: _set_cinema(true)
	_close_browser()
	_video.stream = stream
	_video.volume = _volume.value
	_video.visible = true
	_home.visible = false
	_video.play()
	_play_button.text = "Pause"
	if not _video.is_playing():
		_show_home("Could not play that file", "Only Ogg Theora (.ogv) video plays on the screen")

func _toggle_pause() -> void:
	if _video.stream == null: return
	_video.paused = not _video.paused
	_play_button.text = "Play" if _video.paused else "Pause"

func _stop_video() -> void:
	if is_instance_valid(_video):
		_video.stop()
		_video.stream = null
		_video.visible = false
	if _browser != null: return
	_show_home("Grab a seat", "Use the remote (R) to pick a video, YouTube or a website")

func _on_video_finished() -> void:
	_stop_video()

func _show_home(main_text: String, sub_text: String) -> void:
	if not is_instance_valid(_home): return
	_home.visible = true
	_now_title.text = main_text
	_now_sub.text = sub_text

func _open_web(youtube: bool) -> void:
	var text := _url.text.strip_edges()
	var url := ""
	if youtube:
		url = "https://www.youtube.com/results?search_query=" + text.uri_encode() if not text.is_empty() else "https://www.youtube.com"
		if text.begins_with("http"): url = text
	else:
		if text.is_empty(): text = "https://www.google.com"
		url = text if text.contains("://") else "https://" + text
	if not cinema_on: _set_cinema(true)
	_stop_video()
	if _load_on_screen(url):
		_flash("On the big screen · press C to click on it")
		return
	_show_home("Now on " + ("YouTube" if youtube else "the web"), "Playing in your browser · Alt+Tab back to the auditorium")
	OS.shell_open(url)

# ---------- embedded browser (gdcef) ----------

func web_supported() -> bool:
	return ClassDB.class_exists("GDCef") and _web_error.is_empty()

func _ensure_cef() -> bool:
	if is_instance_valid(_cef): return true
	if not web_supported(): return false
	_cef = ClassDB.instantiate("GDCef")
	_cef.name = "CinemaCEF"
	add_child(_cef)
	# Chromium profile lives in user:// (always writable, also in exported builds),
	# never inside cef_artifacts next to the game files.
	var cache := OS.get_user_data_dir().path_join("cinema_browser")
	DirAccess.make_dir_recursive_absolute(cache)
	var ok: bool = _cef.initialize({
		"artifacts": "res://cef_artifacts/",
		"root_cache_path": cache,
		"cache_path": cache.path_join("profile"),
		"log_file": cache.path_join("debug.log"),
		"persist_session_cookies": false,
		"incognito": true,
		"locale": "en-US",
		"enable_media_stream": false,
		"user_gesture_required": false,
		"remote_debugging_port": 0,
		"log_severity": "error"})
	if not ok:
		_web_error = str(_cef.get_error())
		push_warning("Cinema browser unavailable: " + _web_error)
		_cef.queue_free()
		_cef = null
		return false
	return true

func _load_on_screen(url: String) -> bool:
	if not _ensure_cef(): return false
	if _browser == null:
		_browser = _cef.create_browser(url, _web_rect, {"javascript": true, "webgl": true, "frame_rate": 30, "user_gesture_required": false, "allow_downloads": false})
		if _browser == null:
			_web_error = str(_cef.get_error())
			return false
		_browser.resize(Vector2(_viewport.size))
		_browser.on_page_failed_loading.connect(_on_page_failed)
	else:
		_browser.load_url(url)
	_home.visible = false
	_web_rect.visible = true
	# Show the browser picture directly on the screen; the 2D viewport can sleep.
	(_screen.material_override as StandardMaterial3D).albedo_texture = _browser.get_texture()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return true

func _on_page_failed(_code: Variant, message: Variant, _view: Variant) -> void:
	_flash("Page failed to load: " + str(message))

func _web_back() -> void:
	if _browser != null and _browser.has_previous_page(): _browser.previous_page()

func _web_reload() -> void:
	if _browser != null: _browser.reload()

func _close_browser() -> void:
	_stop_control()
	if _browser != null:
		_browser.close()
		_browser = null
	if is_instance_valid(_web_rect):
		_web_rect.visible = false
		_web_rect.texture = null
	if is_instance_valid(_screen):
		(_screen.material_override as StandardMaterial3D).albedo_texture = _viewport.get_texture()
		if cinema_on: _viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _toggle_mute() -> void:
	if _browser == null: return
	_browser.set_muted(not _browser.is_muted())
	_mute_button.text = "Unmute" if _browser.is_muted() else "Mute"

func _start_control() -> void:
	if _browser == null:
		_flash("Open YouTube or a link first")
		return
	_panel.visible = false
	_controlling = true
	game._set_capture(false)
	game.focus_overlay.clear_target()
	_hint.text = "Mouse controls the big screen · click, scroll, type · Esc: back"
	_hint_timer = 0.0

func _stop_control() -> void:
	if not _controlling: return
	_controlling = false
	_mouse_down = false
	if not game._menu_visible(): game._set_capture(true)
	_refresh_hint()

## Mouse position in the game window -> browser pixel, or null when off the screen.
func _screen_pixel(mouse: Vector2) -> Variant:
	var cam: Camera3D = game.camera
	var origin := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	if absf(dir.z) < 0.0001: return null
	var t := (SCREEN_CENTER.z - origin.z) / dir.z
	if t <= 0.0: return null
	var local := origin + dir * t - SCREEN_CENTER
	var u := local.x / SCREEN_SIZE.x + 0.5
	var v := 0.5 - local.y / SCREEN_SIZE.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0: return null
	return Vector2(u * _viewport.size.x, v * _viewport.size.y)

# ---------- panel / hint ----------

func _open_panel() -> void:
	_scan_videos()
	_panel.visible = true
	game._set_capture(false)
	game.focus_overlay.clear_target()

func _close_panel() -> void:
	if not panel_open(): return
	_panel.visible = false
	if not game._menu_visible(): game._set_capture(true)

func _flash(text: String) -> void:
	_hint.text = text
	_hint_timer = 3.5

func _refresh_hint() -> void:
	if seated: _hint.text = "Seated · E / Space: stand up" + (" · R: remote" if remote_held else "")
	else: _hint.text = ""

# ---------- helpers ----------

func _ground(from: Vector3, depth: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * depth, 1)
	return game.get_world_3d().direct_space_state.intersect_ray(query)

func _unshaded(color: Color, transparent: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if transparent: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
