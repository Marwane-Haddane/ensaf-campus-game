## loading_page.gd — AAA Cinematic Loading Screen System
## Displays full-screen cinematic slideshow with Ken Burns camera effect,
## data-driven tips, smooth crossfades, and a two-column footer.
## Respects real loading telemetry without fake percentages or stalls.
class_name LauncherLoadingPage
extends Control

const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")
const DeploymentLayout = preload("res://scripts/antigravity/launcher/deployment_layout.gd")
const SlideRegistry = preload("res://scripts/antigravity/launcher/slide_registry.gd")

signal intent_requested(action: StringName, payload: Dictionary)

# ── Colors & Styling ─────────────────────────────────────────────────────────
const SLIDE_DURATION := 7.0
const CROSSFADE_DURATION := 1.2

# ── Slideshow Nodes ──────────────────────────────────────────────────────────
var _bg_layer: Control
var _bg_current: TextureRect
var _bg_next: TextureRect
# ── Loading UI ──────────────────────────────────────────────────────────────
var _panel: PanelContainer
var _subtitle: Label
var _tip_rule: HSeparator
var _progress_bar: ProgressBar
var _status_row: HBoxContainer
var _spinner: Control
var _stage_label: Label
var _units_label: Label
var _tip_row: HBoxContainer
var _tip_icon: Control
var _tip_label: Label
var _still_preparing_label: Label
var _cancel_btn: Button
var _cancel_key: Label
var _ambient_player: AudioStreamPlayer
var _status_panel: PanelContainer
var _status_content: VBoxContainer
var _heading_row: HBoxContainer
var _loading_heading: Label
var _tip_badge: Label
var _track_ticks: Control

# ── Slideshow State ──────────────────────────────────────────────────────────
var _active_mode_id: String = "zombie_rpg"
var _slides: Array[Dictionary] = []
var _current_slide_idx: int = 0
var _slide_timer: float = 0.0
var _crossfade_tween: Tween = null
var _ken_burns_time: float = 0.0
var _texture_cache: Dictionary = {} # path -> Texture2D

# ── Telemetry & Accessibility ────────────────────────────────────────────────
var _deployment: Control
var _percent_label: Label
var _request_id: String = ""
var _spin_angle: float = 0.0
var _reduced_motion: bool = false
var _is_transitioning: bool = false

func get_page_id() -> String:
	return "loading"

func get_panel() -> PanelContainer:
	return _panel

func is_slideshow_active() -> bool:
	return is_instance_valid(_bg_current) and _bg_current.texture != null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_init_slideshow()
	_init_audio()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_instance_valid(_ambient_player):
			if visible and is_inside_tree():
				if not _ambient_player.playing:
					_ambient_player.play()
			else:
				_ambient_player.stop()

func _build_ui() -> void:
	# 1. Background Layers for Full-Screen Slideshow
	_bg_layer = Control.new()
	_bg_layer.name = "SlideshowLayer"
	_bg_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_layer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bg_layer.grow_vertical = Control.GROW_DIRECTION_BOTH
	_bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_layer)

	_bg_current = TextureRect.new()
	_bg_current.name = "BackgroundCurrent"
	_bg_current.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_current.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bg_current.grow_vertical = Control.GROW_DIRECTION_BOTH
	_bg_current.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_current.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_current.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_layer.add_child(_bg_current)

	_bg_next = TextureRect.new()
	_bg_next.name = "BackgroundNext"
	_bg_next.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_next.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bg_next.grow_vertical = Control.GROW_DIRECTION_BOTH
	_bg_next.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_next.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_next.modulate.a = 0.0
	_bg_layer.add_child(_bg_next)

	_deployment = DeploymentLayout.new()
	add_child(_deployment)
	_build_case_footer()
	_build_status_footer()
	_apply_deployment_layout()

func _build_case_footer() -> void:
	_panel = PanelContainer.new()
	_panel.name = "LoadingPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_deployment.left.add_child(_panel)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	_panel.add_child(info)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 21)
	_subtitle.add_theme_color_override("font_color", Color("dce8ec"))
	_deployment.left.add_child(_subtitle)
	_deployment.left.move_child(_subtitle, 0)

	_tip_rule = HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color("9cbac36b")
	_tip_rule.add_theme_stylebox_override("separator", line)
	info.add_child(_tip_rule)

	_tip_row = HBoxContainer.new()
	_tip_row.add_theme_constant_override("separation", 6)
	info.add_child(_tip_row)
	_tip_icon = Control.new()
	_tip_icon.custom_minimum_size = Vector2(16, 16)
	_tip_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tip_icon.draw.connect(_on_draw_tip_icon)
	_tip_row.add_child(_tip_icon)
	_tip_badge = DeploymentLayout.display_label("FIELD TIP", 20, DeploymentLayout.WHITE)
	_tip_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_badge.add_theme_stylebox_override("normal", _cyber_badge_style())
	_tip_row.add_child(_tip_badge)
	_tip_label = Label.new()
	_tip_label.add_theme_font_size_override("font_size", 17)
	_tip_label.add_theme_color_override("font_color", Color("dce8ec"))
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip_row.add_child(_tip_label)

func _build_status_footer() -> void:
	_status_panel = PanelContainer.new()
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deployment.right.add_child(_status_panel)
	_status_content = VBoxContainer.new()
	_status_content.add_theme_constant_override("separation", 6)
	_status_panel.add_child(_status_content)
	var status := _status_content
	_heading_row = HBoxContainer.new()
	status.add_child(_heading_row)
	_loading_heading = DeploymentLayout.display_label("PREPARING CAMPUS", 25)
	_loading_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading_row.add_child(_loading_heading)
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 8)
	status.add_child(_status_row)

	_spinner = Control.new()
	_spinner.custom_minimum_size = Vector2(16, 16)
	_spinner.draw.connect(_on_draw_spinner)
	_status_row.add_child(_spinner)
	_stage_label = Label.new()
	_stage_label.add_theme_font_size_override("font_size", 17)
	_stage_label.add_theme_color_override("font_color", DeploymentLayout.WHITE)
	_stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_row.add_child(_stage_label)
	_percent_label = DeploymentLayout.display_label("", 38, DeploymentLayout.BLUE)
	_heading_row.add_child(_percent_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.show_percentage = false
	_progress_bar.hide()
	status.add_child(_progress_bar)
	_track_ticks = Control.new()
	_track_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.add_child(_track_ticks)
	_track_ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_track_ticks.resized.connect(_track_ticks.queue_redraw)
	_track_ticks.draw.connect(func():
		for tick in range(1, 10):
			var x := _track_ticks.size.x * tick / 10.0
			_track_ticks.draw_line(Vector2(x, 4), Vector2(x, _track_ticks.size.y - 4),
				Color("15344a99"), 1.0)
	)

	_units_label = Label.new()
	_units_label.add_theme_font_size_override("font_size", 13)
	_units_label.add_theme_color_override("font_color", Color("b8cbd4"))
	_units_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_units_label.hide()
	_status_row.add_child(_units_label)

	_still_preparing_label = Label.new()
	_still_preparing_label.add_theme_font_size_override("font_size", 13)
	_still_preparing_label.add_theme_color_override("font_color", LauncherTheme.COL_WARNING)
	_still_preparing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_still_preparing_label.hide()
	status.add_child(_still_preparing_label)

	_cancel_btn = Button.new()
	_cancel_btn.name = "CancelButton"
	_cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_cancel_btn.hide()
	status.add_child(_cancel_btn)

	_cancel_key = Label.new()
	_cancel_key.text = "ESC"
	_cancel_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cancel_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cancel_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cancel_key.add_theme_font_size_override("font_size", 14)
	_cancel_btn.add_child(_cancel_key)
	_cancel_key.position = Vector2(1, 2)
	_cancel_key.size = Vector2(49, 29)

func _is_after_hours() -> bool:
	return _active_mode_id == "zombie_rpg"

func _apply_deployment_layout() -> void:
	var after_hours := _is_after_hours()
	_deployment.set_cyber(not after_hours, false, not after_hours)
	_subtitle.visible = not after_hours
	_tip_rule.hide()
	_tip_icon.visible = after_hours
	_tip_badge.visible = not after_hours
	_cancel_key.visible = not after_hours
	_percent_label.add_theme_font_size_override("font_size", 30 if after_hours else 38)
	_percent_label.add_theme_color_override("font_color", DeploymentLayout.CITRON if after_hours else DeploymentLayout.BLUE)
	_percent_label.reparent(_status_row if after_hours else _heading_row)
	_units_label.reparent(_status_content if after_hours else _status_row)
	if after_hours:
		_status_content.move_child(_units_label, _status_content.get_children().find(_still_preparing_label))
	_stage_label.add_theme_font_size_override("font_size", 17 if after_hours else 14)
	_units_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if after_hours else TextServer.AUTOWRAP_OFF
	_heading_row.visible = not after_hours
	_status_content.move_child(_heading_row, 0)
	_status_content.move_child(_progress_bar, 1)
	_status_content.move_child(_status_row, 0 if after_hours else 2)
	_track_ticks.visible = not after_hours

	var panel_style: StyleBox = StyleBoxEmpty.new()
	if not after_hours:
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color("071b30ed")
		plate.border_color = Color("42bfff8c")
		plate.set_border_width_all(1)
		plate.border_width_left = 5
		plate.skew.x = 0.10
		plate.content_margin_left = 20
		plate.content_margin_right = 20
		plate.content_margin_top = 8
		plate.content_margin_bottom = 10
		panel_style = plate
	_status_panel.add_theme_stylebox_override("panel", panel_style)
	_subtitle.add_theme_font_override("font", DeploymentLayout.DISPLAY_FONT)
	_subtitle.add_theme_font_size_override("font_size", 25)
	_subtitle.add_theme_color_override("font_color", DeploymentLayout.BLUE)
	_tip_row.add_theme_constant_override("separation", 0 if not after_hours else 6)
	if after_hours:
		_tip_label.remove_theme_stylebox_override("normal")
	else:
		_tip_label.add_theme_stylebox_override("normal", _cyber_badge_style(false))

	var track := StyleBoxFlat.new()
	track.bg_color = Color("402979") if after_hours else Color("17354f")
	track.set_corner_radius_all(2 if after_hours else 0)
	if not after_hours:
		track.set_border_width_all(1)
		track.border_color = Color("5a9fca")
	var fill := StyleBoxFlat.new()
	fill.bg_color = DeploymentLayout.CITRON if after_hours else DeploymentLayout.BLUE
	fill.set_corner_radius_all(2 if after_hours else 0)
	_progress_bar.add_theme_stylebox_override("background", track)
	_progress_bar.add_theme_stylebox_override("fill", fill)
	_progress_bar.custom_minimum_size.y = 13 if after_hours else 17

	if after_hours:
		_cancel_btn.text = "ESC   CANCEL LOADING"
		_cancel_btn.custom_minimum_size.y = 28
		DeploymentLayout.style_action(_cancel_btn, false, 19)
	else:
		_style_cyber_cancel()

func _cyber_badge_style(solid: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("12679c") if solid else Color("071b30e6")
	style.skew.x = 0.17
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _style_cyber_cancel() -> void:
	_cancel_btn.text = "Cancel loading"
	_cancel_btn.custom_minimum_size.y = 34
	_cancel_btn.add_theme_font_override("font", DeploymentLayout.DISPLAY_FONT)
	_cancel_btn.add_theme_font_size_override("font_size", 21)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.content_margin_left = 63
		style.content_margin_right = 12
		style.bg_color = Color.TRANSPARENT if state in ["normal", "focus"] else Color("123e61")
		style.skew.x = 0.15
		if state == "focus":
			style.border_color = DeploymentLayout.BLUE
			style.set_border_width_all(1)
		_cancel_btn.add_theme_stylebox_override(state, style)
	for color in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_cancel_btn.add_theme_color_override(color, DeploymentLayout.WHITE)
	var keycap := StyleBoxFlat.new()
	keycap.bg_color = Color("071b30")
	keycap.border_color = Color("97dbff")
	keycap.set_border_width_all(1)
	keycap.skew.x = 0.15
	_cancel_key.add_theme_stylebox_override("normal", keycap)

# ── Slideshow Logic ──────────────────────────────────────────────────────────

func _init_slideshow() -> void:
	_slides = SlideRegistry.get_slides_for_mode(_active_mode_id)
	if _slides.is_empty():
		_slides = [_create_emergency_fallback_slide()]
	_current_slide_idx = 0
	_slide_timer = 0.0
	_ken_burns_time = 0.0
	_display_slide(_slides[_current_slide_idx], false)

func _load_slide_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]

	var tex: Texture2D = LauncherTheme.load_texture_safe(path)
	if tex == null:
		# Fallback to campus dusk reference
		tex = LauncherTheme.load_texture_safe("res://assets/launcher/campus-dusk-reference.png")
	if tex != null:
		_texture_cache[path] = tex
		# Keep cache bounded to at most 4 textures in memory to respect low memory constraint
		if _texture_cache.size() > 4:
			var oldest_key: String = _texture_cache.keys()[0]
			if oldest_key != path:
				_texture_cache.erase(oldest_key)
	return tex

func _display_slide(slide: Dictionary, animate: bool) -> void:
	var path: String = slide.get("image_path", "")
	var tex := _load_slide_texture(path)

	# Update the slide tip
	var tip_text: String = slide.get("tip", "")
	var is_impl: bool = slide.get("is_implemented", true)
	if not is_impl and slide.get("category", "") == "enemy":
		_tip_label.text = "[Concept Preview] %s" % tip_text
	else:
		_tip_label.text = "%s" % tip_text

	# Preload upcoming slide
	_preload_next_slide()

	if not animate or _reduced_motion:
		if is_instance_valid(_bg_current):
			_bg_current.texture = tex
			_bg_current.scale = Vector2.ONE
			_bg_current.pivot_offset = _bg_current.size * 0.5
		if is_instance_valid(_bg_next):
			_bg_next.modulate.a = 0.0
		return

	# Crossfade
	if is_instance_valid(_bg_next) and is_instance_valid(_bg_current):
		_bg_next.texture = tex
		_bg_next.modulate.a = 0.0
		_bg_next.scale = Vector2.ONE
		_bg_next.pivot_offset = _bg_next.size * 0.5

		if _crossfade_tween != null and _crossfade_tween.is_valid():
			_crossfade_tween.kill()

		_crossfade_tween = create_tween().set_parallel(true)
		_crossfade_tween.tween_property(_bg_next, "modulate:a", 1.0, CROSSFADE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_crossfade_tween.tween_property(_tip_label, "modulate:a", 1.0, CROSSFADE_DURATION * 0.8).from(0.3)

		_crossfade_tween.chain().tween_callback(func():
			if is_instance_valid(_bg_current) and is_instance_valid(_bg_next):
				_bg_current.texture = _bg_next.texture
				_bg_current.scale = _bg_next.scale
				_bg_next.modulate.a = 0.0
		)

func _preload_next_slide() -> void:
	if _slides.is_empty():
		return
	var next_idx := (_current_slide_idx + 1) % _slides.size()
	var next_path: String = _slides[next_idx].get("image_path", "")
	if next_path != "" and not _texture_cache.has(next_path):
		var _t := _load_slide_texture(next_path)

func _advance_slide() -> void:
	if _slides.is_empty():
		return
	_current_slide_idx = (_current_slide_idx + 1) % _slides.size()
	_slide_timer = 0.0
	_ken_burns_time = 0.0
	_display_slide(_slides[_current_slide_idx], true)

func _process(delta: float) -> void:
	if not visible:
		return

	# Spinner rotation
	_spin_angle += delta * 3.5
	if _spin_angle > TAU:
		_spin_angle -= TAU
	if is_instance_valid(_spinner):
		_spinner.queue_redraw()

	# Slideshow progression
	_slide_timer += delta
	if _slide_timer >= SLIDE_DURATION:
		_advance_slide()

	# Gentle Ken Burns effect (Subtle slow camera pan/zoom)
	if not _reduced_motion and is_instance_valid(_bg_current) and _bg_current.texture != null:
		_ken_burns_time += delta
		var norm := clampf(_ken_burns_time / SLIDE_DURATION, 0.0, 1.0)
		var scale_val := 1.0 + (norm * 0.038)
		_bg_current.pivot_offset = _bg_current.size * 0.5
		_bg_current.scale = Vector2(scale_val, scale_val)

func _on_draw_spinner() -> void:
	if not is_instance_valid(_spinner):
		return
	var center := _spinner.size * 0.5
	var r := 6.5
	# Subtle dim background ring track for AAA feel
	var tint := DeploymentLayout.VIOLET if _is_after_hours() else DeploymentLayout.BLUE
	_spinner.draw_arc(center, r, 0, TAU, 24, Color(tint, 0.28), 1.5, true)
	if _reduced_motion:
		_spinner.draw_arc(center, r, 0, TAU * 0.75, 24, tint, 2.0, true)
	else:
		_spinner.draw_arc(center, r, _spin_angle, _spin_angle + 4.8, 24, tint, 2.0, true)

func _on_draw_tip_icon() -> void:
	if not is_instance_valid(_tip_icon):
		return
	var c := _tip_icon.size * 0.5
	var tint := DeploymentLayout.VIOLET if _is_after_hours() else DeploymentLayout.BLUE
	# Sleek lightbulb icon matching reference image
	var bulb_center := Vector2(c.x, c.y - 2.5)
	_tip_icon.draw_arc(bulb_center, 4.5, deg_to_rad(-45), deg_to_rad(225), 18, tint, 1.5, true)
	_tip_icon.draw_line(Vector2(c.x - 2.5, c.y + 2.5), Vector2(c.x + 2.5, c.y + 2.5), tint, 1.5)
	_tip_icon.draw_line(Vector2(c.x - 1.8, c.y + 4.8), Vector2(c.x + 1.8, c.y + 4.8), tint, 1.5)

func _init_audio() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientLoadingAudio"
	_ambient_player.stream = _create_subtle_ambient_stream()
	_ambient_player.bus = &"Master"
	_ambient_player.volume_db = -24.0
	add_child(_ambient_player)

func _create_subtle_ambient_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0

	var duration := 3.0
	var sample_count := int(22050.0 * duration)
	stream.loop_end = sample_count

	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / 22050.0
		var wind_env := 0.7 + 0.3 * sin(TAU * t * 0.33)
		var s := (sin(TAU * 55.0 * t) * 0.4 + sin(TAU * 110.0 * t) * 0.2) * wind_env * 0.16
		var sample_val := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample_val)

	stream.data = data
	return stream

func _on_cancel_pressed() -> void:
	intent_requested.emit(&"cancel_loading", {"request_id": _request_id})

func update_from_model(model: Dictionary) -> void:
	var prev_rm := _reduced_motion
	_reduced_motion = model.get("preferences", {}).get("reduced_motion", false)
	if is_instance_valid(_spinner) and (_reduced_motion != prev_rm or _reduced_motion):
		_spinner.queue_redraw()

	# Ambient audio volume adjustment according to preferences
	var prefs: Dictionary = model.get("preferences", {})
	var master_vol: float = float(prefs.get("master_volume", 80.0)) / 100.0
	var music_vol: float = float(prefs.get("music_volume", 80.0)) / 100.0
	var combined_vol: float = master_vol * music_vol
	if is_instance_valid(_ambient_player):
		if combined_vol <= 0.01:
			_ambient_player.volume_db = -80.0
		else:
			_ambient_player.volume_db = -24.0 + linear_to_db(combined_vol)
		if visible and not _ambient_player.playing and combined_vol > 0.01:
			_ambient_player.play()

	# Switch mode if specified
	var mode_id: String = model.get("selected_mode_id", "")
	if mode_id == "":
		mode_id = model.get("mission", {}).get("mode_id", "")
	if mode_id == "":
		mode_id = "zombie_rpg"

	if mode_id != _active_mode_id:
		_active_mode_id = mode_id
		_apply_deployment_layout()
		_slides = SlideRegistry.get_slides_for_mode(_active_mode_id)
		_current_slide_idx = 0
		_slide_timer = 0.0
		_ken_burns_time = 0.0
		_display_slide(_slides[_current_slide_idx], false)

	var loading: Dictionary = model.get("loading", {})
	_request_id = loading.get("request_id", "")

	var stage_lbl: String = loading.get("stage_label", "")
	var res_prog = loading.get("resource_progress", null)
	var mission: Dictionary = model.get("mission", {})
	var default_code := "ZB-2026-001" if _is_after_hours() else "IR-2026-001"
	var mission_code := str(mission.get("id", ""))
	_deployment.mission_code.text = default_code if mission_code.is_empty() else mission_code
	var mission_title := str(mission.get("title", ""))
	_subtitle.text = "ENSA INCIDENT RESPONSE"
	var title := "THE BORROWED SESSION" if mission_title.is_empty() else mission_title.to_upper()
	_deployment.set_loading_title("THE BORROWED\nSESSION" if title == "THE BORROWED SESSION" else title)
	var comp = loading.get("completed_units", null)
	var tot = loading.get("total_units", null)
	var valid_units := (comp is int or comp is float) and (tot is int or tot is float) \
		and is_finite(float(comp)) and is_finite(float(tot)) and float(comp) >= 0.0 and float(tot) > 0.0
	var measured: bool = (res_prog is float or res_prog is int) and is_finite(float(res_prog))
	if not _is_after_hours() and not measured and valid_units:
		res_prog = float(comp) / float(tot)
		measured = true
	_stage_label.text = stage_lbl if not stage_lbl.is_empty() else "Loading simulation..."
	_percent_label.visible = measured
	_spinner.visible = _is_after_hours() or not measured
	if measured:
		var percentage := clampf(float(res_prog) * 100.0, 0.0, 100.0)
		_percent_label.text = "%d%%" % (int(percentage) if _is_after_hours() else roundi(percentage))

	# Work units counter
	if valid_units:
		var count := "%s / %s units" % [_format_units(int(comp)), _format_units(int(tot))]
		_units_label.text = "%s: %s" % [stage_lbl, count] if _is_after_hours() else count
		_units_label.visible = true
	else:
		_units_label.visible = false

	# Resource stage progress bar (visible only when resource_progress is a valid float/int)
	if measured:
		_progress_bar.visible = true
		_progress_bar.value = clamp(float(res_prog) * 100.0, 0.0, 100.0)
	else:
		_progress_bar.visible = false

	# Still preparing state
	var still_prep: bool = loading.get("still_preparing", false)
	var elapsed: float = loading.get("elapsed_seconds", 0.0)
	if still_prep:
		_still_preparing_label.text = "Still preparing... (%s — %.1fs elapsed)" % [stage_lbl, elapsed]
		_still_preparing_label.visible = true
	else:
		_still_preparing_label.visible = false

	# Cancel button — preserve focus if already focused
	var can_cancel: bool = loading.get("can_cancel", false)
	var was_focused: bool = _cancel_btn.has_focus()
	_cancel_btn.visible = can_cancel
	if can_cancel and was_focused:
		_cancel_btn.grab_focus()

func _format_units(count: int) -> String:
	var digits := str(count)
	var groups: Array[String] = []
	while digits.length() > 3:
		groups.push_front(digits.right(3))
		digits = digits.left(digits.length() - 3)
	groups.push_front(digits)
	return ",".join(groups)

func focus_primary() -> void:
	if _cancel_btn.visible and is_instance_valid(_cancel_btn):
		_cancel_btn.grab_focus()

func _create_emergency_fallback_slide() -> Dictionary:
	return {
		"id": "emergency_fallback",
		"mode_id": _active_mode_id,
		"image_path": "res://assets/launcher/campus-dusk-reference.png",
		"title": "ENSA FÈS CAMPUS",
		"subtitle": "Central Incursion Zone",
		"tip": "Observe enemy silhouettes and manage ammunition carefully.",
		"category": "environment",
		"enemy_type": "",
		"is_implemented": true
	}
