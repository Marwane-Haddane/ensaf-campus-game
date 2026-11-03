extends CanvasLayer
class_name InteractionFocus
## A single, context-sensitive exploration prompt. The caller owns LOS/range gates.
## Only an added perimeter mesh is changed; imported screen materials are untouched.

const CYAN := Color("58e4df")
const INK := Color("edf5f7")
const MUTED := Color("b3c5ce")
const OUTLINE_SHADER := preload("res://shaders/focus_screen.gdshader")

class FocusCanvas:
	extends Control
	var dot := Vector2.ZERO
	var connector_end := Vector2.ZERO
	var show_connector := false
	func _draw() -> void:
		if not show_connector:
			return
		draw_line(dot, connector_end, Color(0.34, 0.89, 0.87, 0.90), 1.0, true)
		draw_circle(dot, 4.0, Color(0.24, 0.91, 0.88, 0.18))
		draw_circle(dot, 2.4, Color("a7fcf3"))

var _canvas: FocusCanvas
var _card: PanelContainer
var _keycap: PanelContainer
var _title: Label
var _subtitle: Label
var _tag: VBoxContainer
var _tag_title: Label
var _distance: Label
var _active_screen: MeshInstance3D
var _outline: MeshInstance3D
var _anchor_local := Vector3.ZERO
var _camera: Camera3D
var _target: Dictionary = {}
var _distance_m := 0.0
var _target_world := Vector3.ZERO
var _is_active := false

func _ready() -> void:
	layer = 12
	_build_ui()
	get_viewport().size_changed.connect(_fit_layout)
	clear_target()

func update_target(camera: Camera3D, station: Dictionary, distance: float, visible: bool) -> void:
	if not visible or station.is_empty() or not is_instance_valid(camera):
		clear_target()
		return
	if not is_instance_valid(_canvas):
		_build_ui()
	_camera = camera
	_target = station
	_distance_m = maxf(distance, 0.0)
	_target_world = station.get("screen", Vector3.ZERO)
	var server := str(station.get("kind", "pc")) == "server"
	var door := str(station.get("kind", "pc")) == "door"
	_title.text = str(station.get("prompt","Press E to open")) if door else ("Inspect server" if server else "Inspect workstation")
	_subtitle.text = str(station.get("name","Glass entrance")) if door else ("Review role & status" if server else "Access console & timeline")
	_tag_title.text = "CAMPUS SERVER" if server else "TRAINING CONSOLE"
	_distance.text = "%.1f m" % _distance_m
	var asset: Dictionary = station.get("asset", {})
	var screen: MeshInstance3D = asset.get("screen_mesh") as MeshInstance3D
	if screen != _active_screen:
		_replace_outline(screen)
	_is_active = true
	_canvas.show()
	if is_instance_valid(_outline):
		_outline.show()
	_fit_layout()

func clear_target() -> void:
	_is_active = false
	_target = {}
	if is_instance_valid(_canvas):
		_canvas.hide()
		_canvas.show_connector = false
		_canvas.queue_redraw()
	if is_instance_valid(_outline):
		_outline.hide()

func _exit_tree() -> void:
	if is_instance_valid(_outline):
		_outline.queue_free()

func _build_ui() -> void:
	if is_instance_valid(_canvas):
		return
	_canvas = FocusCanvas.new()
	_canvas.name = "FocusedInteraction"
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_card = PanelContainer.new()
	_card.name = "InteractionCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", _panel(Color(0.035, 0.071, 0.095, 0.88), Color(0.62, 0.80, 0.86, 0.21), 6, 13, 12))
	_canvas.add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	_keycap = PanelContainer.new()
	_keycap.name = "InteractKey"
	_keycap.custom_minimum_size = Vector2(34, 38)
	_keycap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keycap.add_theme_stylebox_override("panel", _panel(Color(0.10, 0.15, 0.19, 0.70), Color(0.75, 0.85, 0.89, 0.78), 3, 0, 0))
	row.add_child(_keycap)
	var key := _label("E", 19, INK)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_keycap.add_child(key)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", 3)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	_title = _label("Inspect workstation", 14, INK)
	var semibold := FontVariation.new()
	semibold.base_font = ThemeDB.fallback_font
	semibold.variation_embolden = 0.45
	_title.add_theme_font_override("font", semibold)
	copy.add_child(_title)
	_subtitle = _label("Access console & timeline", 11, MUTED)
	copy.add_child(_subtitle)
	_tag = VBoxContainer.new()
	_tag.name = "ProjectedTargetTag"
	_tag.add_theme_constant_override("separation", 2)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_tag)
	var name_panel := PanelContainer.new()
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_theme_stylebox_override("panel", _panel(Color(0.025, 0.070, 0.095, 0.84), Color(0.55, 0.79, 0.84, 0.17), 3, 7, 5))
	_tag.add_child(name_panel)
	_tag_title = _label("TRAINING CONSOLE", 10, INK)
	_tag_title.add_theme_font_override("font", semibold)
	name_panel.add_child(_tag_title)
	var distance_panel := PanelContainer.new()
	distance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	distance_panel.add_theme_stylebox_override("panel", _panel(Color(0.025, 0.070, 0.095, 0.62), Color.TRANSPARENT, 2, 7, 3))
	_tag.add_child(distance_panel)
	_distance = _label("0.0 m", 11, MUTED)
	distance_panel.add_child(_distance)

func _fit_layout() -> void:
	if not is_instance_valid(_canvas) or not _is_active or not is_instance_valid(_camera):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var card_width := minf(272.0, maxf(220.0, viewport_size.x - 32.0))
	var bottom_space := 54.0 if viewport_size.y >= 430.0 else 18.0
	_card.size = Vector2(card_width, 64)
	_card.position = Vector2((viewport_size.x - _card.size.x) * 0.5, maxf(16.0, viewport_size.y - bottom_space - 64.0))
	if _target.get("kind","") == "door":
		_tag.hide()
		_canvas.show_connector = false
		_canvas.queue_redraw()
		return
	var world_point := _target_world
	if is_instance_valid(_active_screen):
		world_point = _active_screen.to_global(_anchor_local)
	if _camera.is_position_behind(world_point):
		_tag.hide()
		_canvas.show_connector = false
		_canvas.queue_redraw()
		return
	var point := _camera.unproject_position(world_point)
	var bounds := Rect2(Vector2(12, 70), viewport_size - Vector2(24, 86))
	# The projected label is useful only while its actual anchor is on screen.
	if not bounds.has_point(point) or viewport_size.x < 440.0:
		_tag.hide()
		_canvas.show_connector = false
		_canvas.queue_redraw()
		return
	_tag.show()
	_tag.size = _tag.get_combined_minimum_size()
	var minimum_x := minf(322.0, viewport_size.x - _tag.size.x - 16.0)
	var maximum_x := maxf(16.0, viewport_size.x - _tag.size.x - 16.0)
	var maximum_y := maxf(78.0, _card.position.y - _tag.size.y - 22.0)
	_tag.position = Vector2(clampf(point.x + 24.0, minimum_x, maximum_x), clampf(point.y - 49.0, 78.0, maximum_y))
	_canvas.dot = point
	_canvas.connector_end = _tag.position + Vector2(0, _tag.get_child(0).size.y - 2.0)
	_canvas.show_connector = true
	_canvas.queue_redraw()

func _replace_outline(screen: MeshInstance3D) -> void:
	if is_instance_valid(_outline):
		_outline.hide()
		_outline.queue_free()
	_outline = null
	_active_screen = screen
	if not is_instance_valid(screen) or screen.mesh == null:
		return
	var border := _perimeter_mesh(screen.mesh)
	if border == null:
		return
	_outline = MeshInstance3D.new()
	_outline.name = "FocusScreenPerimeter"
	_outline.mesh = border
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.render_priority = 10
	_outline.material_override = material
	screen.add_child(_outline)
	_outline.transform = Transform3D.IDENTITY
	_anchor_local = _screen_anchor(screen.mesh)

func _perimeter_mesh(mesh: Mesh) -> ImmediateMesh:
	var welded: Dictionary = {}
	var edge_counts: Dictionary = {}
	var next_id := 0
	for surface: int in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index: int in range(vertices.size()):
				indices.append(index)
		var ids := PackedInt32Array()
		for vertex: Vector3 in vertices:
			# Weld the duplicated strip vertices before counting open mesh edges.
			var key := Vector3i(roundi(vertex.x * 100000.0), roundi(vertex.y * 100000.0), roundi(vertex.z * 100000.0))
			if not welded.has(key):
				welded[key] = next_id
				next_id += 1
			ids.append(int(welded[key]))
		for triangle: int in range(0, indices.size() - 2, 3):
			for side: int in range(3):
				var a := indices[triangle + side]
				var b := indices[triangle + (side + 1) % 3]
				var edge_key := Vector2i(mini(ids[a], ids[b]), maxi(ids[a], ids[b]))
				if edge_counts.has(edge_key):
					edge_counts[edge_key].count += 1
				else:
					var na := normals[a] if normals.size() > a else Vector3.FORWARD
					var nb := normals[b] if normals.size() > b else Vector3.FORWARD
					edge_counts[edge_key] = {"count": 1, "a": vertices[a] + na * 0.006, "b": vertices[b] + nb * 0.006}
	var outline := ImmediateMesh.new()
	outline.surface_begin(Mesh.PRIMITIVE_LINES)
	var count := 0
	for edge: Dictionary in edge_counts.values():
		if edge.count == 1:
			outline.surface_add_vertex(edge.a)
			outline.surface_add_vertex(edge.b)
			count += 1
	outline.surface_end()
	outline.set_meta("boundary_segments", count)
	return outline if count > 0 else null

func _screen_anchor(mesh: Mesh) -> Vector3:
	var box := mesh.get_aabb()
	var wanted_x := box.position.x + box.size.x * 0.74
	var top := box.end.z
	var best := INF
	var anchor := box.get_center()
	for surface: int in range(mesh.get_surface_count()):
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var score := absf(vertex.x - wanted_x) + absf(vertex.z - top) * 3.0
			if score < best:
				best = score
				anchor = vertex
	return anchor

func _label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _panel(background: Color, border: Color, radius: int, horizontal: int, vertical: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


