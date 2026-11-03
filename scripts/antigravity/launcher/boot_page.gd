## boot_page.gd — ENSA Games boot & startup identity page
## Displays lightweight branding and initial loading status.
## Skippable immediately via click or key press.
class_name LauncherBootPage
extends Control

const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")

signal intent_requested(action: StringName, payload: Dictionary)

var _status_label: Label
var _spinner: Control
var _skip_button: Button
var _reduced_motion: bool = false
var _spin_angle: float = 0.0
var _center: CenterContainer
var _emblem_rect: TextureRect

func get_page_id() -> String:
	return "boot"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_build_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_instance_valid(_center):
			_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_ui() -> void:
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center.grow_vertical = Control.GROW_DIRECTION_BOTH
	_center.use_top_left = false
	add_child(_center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	vbox.custom_minimum_size = Vector2(480, 320)
	_center.add_child(vbox)

	# University Emblem (White SVG)
	_emblem_rect = TextureRect.new()
	_emblem_rect.custom_minimum_size = Vector2(72, 72)
	_emblem_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_emblem_rect.texture = LauncherTheme.load_texture_safe("res://assets/launcher/ensa-emblem-white.svg")
	vbox.add_child(_emblem_rect)

	# Brand title
	var title := Label.new()
	title.text = "ENSA GAMES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", LauncherTheme.FONT_TITLE)
	title.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	vbox.add_child(title)

	# Subtitle / tagline
	var subtitle := Label.new()
	subtitle.text = "INCIDENT RESPONSE & DEFENSE SIMULATION"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
	subtitle.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	vbox.add_child(subtitle)

	# Spacing
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	# Activity spinner
	_spinner = Control.new()
	_spinner.custom_minimum_size = Vector2(32, 32)
	_spinner.draw.connect(_on_draw_spinner)
	vbox.add_child(_spinner)

	# Status text
	_status_label = Label.new()
	_status_label.text = "INITIALIZING..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
	_status_label.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
	vbox.add_child(_status_label)

	# Engine credit (bottom)
	var bottom_box := MarginContainer.new()
	bottom_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_box.add_theme_constant_override("margin_bottom", 24)
	add_child(bottom_box)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	bottom_box.add_child(hbox)

	var credit := Label.new()
	credit.text = "Powered by Godot Engine 4.3"
	credit.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
	credit.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_DISABLED)
	hbox.add_child(credit)

	_skip_button = Button.new()
	_skip_button.text = "Skip [Space/Esc]"
	_skip_button.focus_mode = Control.FOCUS_ALL
	_skip_button.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
	_skip_button.pressed.connect(_on_skip_pressed)
	hbox.add_child(_skip_button)

func _process(delta: float) -> void:
	if not visible or _reduced_motion:
		return
	_spin_angle += delta * 4.0
	if _spin_angle > TAU:
		_spin_angle -= TAU
	if is_instance_valid(_spinner):
		_spinner.queue_redraw()

func _on_draw_spinner() -> void:
	if not is_instance_valid(_spinner):
		return
	var center := _spinner.size * 0.5
	var r := 12.0
	if _reduced_motion:
		# Static circle
		_spinner.draw_arc(center, r, 0, TAU, 24, LauncherTheme.COL_ACCENT_DIM, 2.0, true)
	else:
		# Rotating arc
		_spinner.draw_arc(center, r, _spin_angle, _spin_angle + 4.5, 24, LauncherTheme.COL_ACCENT, 2.5, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_skip_pressed()
		accept_event()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			_on_skip_pressed()
			accept_event()

func _on_skip_pressed() -> void:
	intent_requested.emit(&"skip_branding", {})

func update_from_model(model: Dictionary) -> void:
	var prev_rm := _reduced_motion
	_reduced_motion = model.get("preferences", {}).get("reduced_motion", false)
	if is_instance_valid(_spinner) and (_reduced_motion != prev_rm or _reduced_motion):
		_spinner.queue_redraw()

	var brand_logo: String = model.get("brand_assets", {}).get("logo_path", "")
	if brand_logo != "" and is_instance_valid(_emblem_rect):
		var tex := LauncherTheme.load_texture_safe(brand_logo)
		if tex:
			_emblem_rect.texture = tex

	var state: String = model.get("state", "INITIALIZING")
	if not is_instance_valid(_status_label):
		return
	match state:
		"STARTUP":
			_status_label.text = "STARTING SUBSYSTEMS..."
		"INITIALIZING":
			_status_label.text = "INITIALIZING CORE SERVICES..."
		_:
			_status_label.text = "READY"

func focus_primary() -> void:
	if is_instance_valid(_skip_button):
		_skip_button.grab_focus()
