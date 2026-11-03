## loading_page.gd — AAA Cinematic Loading Screen System
## Displays full-screen cinematic slideshow with Ken Burns camera effect,
## data-driven enemy/survival tips, smooth crossfades, and bottom-left UI.
## Respects real loading telemetry without fake percentages or stalls.
class_name LauncherLoadingPage
extends Control

const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")
const DeploymentLayout = preload("res://scripts/antigravity/launcher/deployment_layout.gd")
const SlideRegistry = preload("res://scripts/antigravity/launcher/slide_registry.gd")

signal intent_requested(action: StringName, payload: Dictionary)

# ── Colors & Styling ─────────────────────────────────────────────────────────
const COL_CYAN_ACCENT := Color(0.0, 0.94, 0.88, 1.0)
const COL_TEXT_MUTED := Color(0.72, 0.78, 0.88, 1.0)
const SLIDE_DURATION := 7.0
const CROSSFADE_DURATION := 1.2

# ── Slideshow Nodes ──────────────────────────────────────────────────────────
var _bg_layer: Control
var _bg_current: TextureRect
var _bg_next: TextureRect
var _vignette_rect: TextureRect

# ── Bottom-Left UI Nodes ─────────────────────────────────────────────────────
var _bottom_margin: MarginContainer
var _panel: PanelContainer
var _accent_bar: ColorRect
var _title_label: Label
var _mode_label: Label
var _progress_bar: ProgressBar
var _status_row: HBoxContainer
var _spinner: Control
var _stage_label: Label
var _units_label: Label
var _tip_row: HBoxContainer
var _tip_icon: Control
var _tip_prefix: Label
var _tip_label: Label
var _counter_label: Label
var _still_preparing_label: Label
var _cancel_btn: Button
var _classic_cancel_style: StyleBoxFlat
var _ambient_player: AudioStreamPlayer

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
var _classic_content: VBoxContainer
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
	if what == NOTIFICATION_RESIZED:
		_layout_elements()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
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

	# 2. Soft Bottom-Left Radial Dark Gradient for UI Legibility (No heavy box)
	_vignette_rect = TextureRect.new()
	_vignette_rect.name = "BottomLeftVignette"
	_vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_vignette_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	_vignette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.texture = _create_soft_vignette_gradient()
	add_child(_vignette_rect)

	# 3. Bottom-Left Margin & Container
	_bottom_margin = MarginContainer.new()
	_bottom_margin.name = "BottomLeftMargin"
	_bottom_margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bottom_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bottom_margin)

	_panel = PanelContainer.new()
	_panel.name = "LoadingPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var empty_sb := StyleBoxEmpty.new()
	_panel.add_theme_stylebox_override("panel", empty_sb)
	_bottom_margin.add_child(_panel)

	var vbox := VBoxContainer.new()
	_classic_content = vbox
	vbox.name = "LoadingVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# Header: Vertical Accent Bar + ENSA GAMES + Mode Subtitle
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(header_hbox)

	_accent_bar = ColorRect.new()
	_accent_bar.name = "CyanAccentBar"
	_accent_bar.custom_minimum_size = Vector2(3.5, 38)
	_accent_bar.color = COL_CYAN_ACCENT
	header_hbox.add_child(_accent_bar)

	var titles_vbox := VBoxContainer.new()
	titles_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(titles_vbox)

	_title_label = Label.new()
	_title_label.name = "BrandLabel"
	_title_label.text = "ENSA GAMES"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	titles_vbox.add_child(_title_label)

	_mode_label = Label.new()
	_mode_label.name = "ModeLabel"
	_mode_label.text = "Zombie RPG Survival"
	_mode_label.add_theme_font_size_override("font_size", 14)
	_mode_label.add_theme_color_override("font_color", COL_TEXT_MUTED)
	titles_vbox.add_child(_mode_label)

	# Thin Elegant Cyan Progress Bar
	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.custom_minimum_size = Vector2(390, 5)
	_progress_bar.show_percentage = false
	_progress_bar.visible = false

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.08, 0.12, 0.18, 0.75)
	sb_bg.corner_radius_top_left = 2
	sb_bg.corner_radius_top_right = 2
	sb_bg.corner_radius_bottom_left = 2
	sb_bg.corner_radius_bottom_right = 2
	_progress_bar.add_theme_stylebox_override("background", sb_bg)

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = COL_CYAN_ACCENT
	sb_fill.corner_radius_top_left = 2
	sb_fill.corner_radius_top_right = 2
	sb_fill.corner_radius_bottom_left = 2
	sb_fill.corner_radius_bottom_right = 2
	_progress_bar.add_theme_stylebox_override("fill", sb_fill)
	vbox.add_child(_progress_bar)

	# Status Line: Spinner + Stage Text + Optional Percentage
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 10)
	vbox.add_child(_status_row)

	_spinner = Control.new()
	_spinner.name = "StatusSpinner"
	_spinner.custom_minimum_size = Vector2(16, 16)
	_spinner.draw.connect(_on_draw_spinner)
	_status_row.add_child(_spinner)

	_stage_label = Label.new()
	_stage_label.name = "StageLabel"
	_stage_label.text = "Loading world assets..."
	_stage_label.add_theme_font_size_override("font_size", 14)
	_stage_label.add_theme_color_override("font_color", COL_TEXT_MUTED)
	_status_row.add_child(_stage_label)

	# Units label (e.g. "Preparing render batches: 730 / 2200 units")
	_units_label = Label.new()
	_units_label.name = "UnitsLabel"
	_units_label.text = ""
	_units_label.add_theme_font_size_override("font_size", 12)
	_units_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	_units_label.visible = false
	vbox.add_child(_units_label)

	# Tip Line: Tip Icon + "Tip:" (cyan) + Tip Text (white) + Subtle Slide Counter
	_tip_row = HBoxContainer.new()
	_tip_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_tip_row)

	_tip_icon = Control.new()
	_tip_icon.name = "TipIcon"
	_tip_icon.custom_minimum_size = Vector2(16, 16)
	_tip_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tip_icon.draw.connect(_on_draw_tip_icon)
	_tip_row.add_child(_tip_icon)

	_tip_prefix = Label.new()
	_tip_prefix.name = "TipPrefix"
	_tip_prefix.text = "Tip:"
	_tip_prefix.add_theme_font_size_override("font_size", 13)
	_tip_prefix.add_theme_color_override("font_color", COL_CYAN_ACCENT)
	_tip_prefix.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tip_row.add_child(_tip_prefix)

	_tip_label = Label.new()
	_tip_label.name = "TipLabel"
	_tip_label.text = "Go for headshots to take down zombies faster and conserve ammo."
	_tip_label.add_theme_font_size_override("font_size", 13)
	_tip_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tip_row.add_child(_tip_label)

	_counter_label = Label.new()
	_counter_label.name = "SlideCounter"
	_counter_label.text = "|  01 / 24"
	_counter_label.add_theme_font_size_override("font_size", 13)
	_counter_label.add_theme_color_override("font_color", Color(0.48, 0.55, 0.68))
	_counter_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_counter_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tip_row.add_child(_counter_label)

	# Still preparing state
	_still_preparing_label = Label.new()
	_still_preparing_label.name = "StillPreparingLabel"
	_still_preparing_label.text = ""
	_still_preparing_label.add_theme_font_size_override("font_size", 12)
	_still_preparing_label.add_theme_color_override("font_color", LauncherTheme.COL_WARNING)
	_still_preparing_label.visible = false
	vbox.add_child(_still_preparing_label)

	# Cancel Button (discreet AAA styling, preserves keyboard focus)
	_cancel_btn = Button.new()
	_cancel_btn.name = "CancelButton"
	_cancel_btn.text = "Cancel Loading"
	_cancel_btn.custom_minimum_size = Vector2(130, 28)
	_cancel_btn.add_theme_font_size_override("font_size", 12)
	_cancel_btn.focus_mode = Control.FOCUS_ALL
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_cancel_btn.visible = false

	var cancel_sb := StyleBoxFlat.new()
	cancel_sb.bg_color = Color(0.12, 0.16, 0.22, 0.8)
	cancel_sb.border_width_left = 1
	cancel_sb.border_width_top = 1
	cancel_sb.border_width_right = 1
	cancel_sb.border_width_bottom = 1
	cancel_sb.border_color = Color(0.3, 0.4, 0.5, 0.6)
	cancel_sb.corner_radius_top_left = 3
	cancel_sb.corner_radius_top_right = 3
	cancel_sb.corner_radius_bottom_left = 3
	cancel_sb.corner_radius_bottom_right = 3
	_classic_cancel_style = cancel_sb
	_cancel_btn.add_theme_stylebox_override("normal", cancel_sb)
	vbox.add_child(_cancel_btn)

	_deployment = DeploymentLayout.new()
	add_child(_deployment)
	_percent_label = DeploymentLayout.display_label("", 30, DeploymentLayout.CITRON)
	_status_row.add_child(_percent_label)
	_apply_deployment_layout()
	_layout_elements()

func _is_after_hours() -> bool:
	return _active_mode_id == "zombie_rpg"

func _apply_deployment_layout() -> void:
	var after_hours := _is_after_hours()
	_deployment.visible = after_hours
	_bottom_margin.visible = not after_hours
	_vignette_rect.visible = not after_hours
	var status_parent: VBoxContainer = _deployment.right if after_hours else _classic_content
	var tip_parent: VBoxContainer = _deployment.left if after_hours else _classic_content
	for control: Control in [_status_row, _progress_bar, _units_label, _still_preparing_label, _cancel_btn]:
		if control.get_parent() != status_parent:
			control.reparent(status_parent, false)
	if _tip_row.get_parent() != tip_parent:
		_tip_row.reparent(tip_parent, false)
	if not after_hours:
		_classic_content.move_child(_progress_bar, 1)
		_classic_content.move_child(_tip_row, 4)
	_percent_label.visible = after_hours and not _percent_label.text.is_empty()
	_tip_prefix.visible = not after_hours
	_counter_label.visible = not after_hours
	_tip_label.add_theme_font_size_override("font_size", 17 if after_hours else 13)
	_stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if after_hours else Control.SIZE_FILL
	_stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if after_hours else TextServer.AUTOWRAP_OFF
	_stage_label.add_theme_font_size_override("font_size", 17 if after_hours else 14)
	_stage_label.add_theme_color_override("font_color", DeploymentLayout.WHITE if after_hours else COL_TEXT_MUTED)
	_progress_bar.custom_minimum_size = Vector2(0, 13) if after_hours else Vector2(390, 5)
	var fill := _progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = DeploymentLayout.CITRON if after_hours else COL_CYAN_ACCENT
	var track := _progress_bar.get_theme_stylebox("background") as StyleBoxFlat
	track.bg_color = Color("402979") if after_hours else Color(0.08, 0.12, 0.18, 0.75)
	_cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if after_hours else Control.SIZE_FILL
	_cancel_btn.text = "ESC   CANCEL LOADING" if after_hours else "Cancel Loading"
	if after_hours:
		DeploymentLayout.style_action(_cancel_btn, false, 19)
	else:
		for state in ["normal", "hover", "pressed", "focus"]:
			_cancel_btn.remove_theme_stylebox_override(state)
		for key in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			_cancel_btn.remove_theme_color_override(key)
		_cancel_btn.remove_theme_font_override("font")
		_cancel_btn.add_theme_font_size_override("font_size", 12)
		_cancel_btn.add_theme_stylebox_override("normal", _classic_cancel_style)

func _layout_elements() -> void:
	if not is_instance_valid(_bottom_margin):
		return
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(1280, 720)

	var pad_x := 48.0
	var pad_y := 44.0
	_bottom_margin.offset_left = pad_x
	_bottom_margin.offset_bottom = -pad_y
	_bottom_margin.offset_right = minf(vp_size.x - pad_x, pad_x + 680.0)
	_bottom_margin.offset_top = -pad_y - 210.0

func _create_soft_vignette_gradient() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.01, 0.02, 0.05, 0.92),
		Color(0.01, 0.02, 0.05, 0.60),
		Color(0.01, 0.02, 0.05, 0.25),
		Color(0.01, 0.02, 0.05, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.28, 0.62, 1.0])

	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.0, 1.0)
	gtex.fill_to = Vector2(0.85, 0.15)
	gtex.width = 512
	gtex.height = 512
	return gtex

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

	# Update tip & counter text
	var tip_text: String = slide.get("tip", "")
	var is_impl: bool = slide.get("is_implemented", true)
	if not is_impl and slide.get("category", "") == "enemy":
		_tip_label.text = "[Concept Preview] %s" % tip_text
	else:
		_tip_label.text = "%s" % tip_text

	var total := _slides.size()
	_counter_label.text = "|  %02d / %02d" % [_current_slide_idx + 1, total]

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
	var tint := DeploymentLayout.VIOLET if _is_after_hours() else COL_CYAN_ACCENT
	_spinner.draw_arc(center, r, 0, TAU, 24, Color(tint, 0.28), 1.5, true)
	if _reduced_motion:
		_spinner.draw_arc(center, r, 0, TAU * 0.75, 24, tint, 2.0, true)
	else:
		_spinner.draw_arc(center, r, _spin_angle, _spin_angle + 4.8, 24, tint, 2.0, true)

func _on_draw_tip_icon() -> void:
	if not is_instance_valid(_tip_icon):
		return
	var c := _tip_icon.size * 0.5
	var tint := DeploymentLayout.VIOLET if _is_after_hours() else COL_CYAN_ACCENT
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
		if _active_mode_id == "incident_response" or _active_mode_id == "cyber":
			_mode_label.text = "Cybersecurity Incident Response"
		else:
			_mode_label.text = "Zombie RPG Survival"
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
	_deployment.mission_code.text = str(mission.get("id", "ZB-2026-001"))
	_percent_label.hide()

	# Status text with genuine percentage when measurable
	if res_prog != null and (res_prog is float or res_prog is int):
		var pct := int(clampf(float(res_prog) * 100.0, 0.0, 100.0))
		if _is_after_hours():
			_stage_label.text = stage_lbl if not stage_lbl.is_empty() else "Loading assets"
			_percent_label.text = "%d%%" % pct
			_percent_label.show()
		elif stage_lbl != "":
			_stage_label.text = "%s... %d%%" % [stage_lbl, pct]
		else:
			_stage_label.text = "Loading assets... %d%%" % pct
	elif stage_lbl != "":
		_stage_label.text = stage_lbl
	else:
		_stage_label.text = "Loading simulation..."

	# Work units counter
	var comp = loading.get("completed_units", null)
	var tot = loading.get("total_units", null)
	if comp != null and tot != null:
		_units_label.text = "%s: %s / %s units" % [stage_lbl, str(comp), str(tot)]
		_units_label.visible = true
	else:
		_units_label.visible = false

	# Resource stage progress bar (visible only when resource_progress is a valid float/int)
	if res_prog != null and (res_prog is float or res_prog is int):
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
