extends "res://scripts/antigravity/launcher/launcher_view.gd"
## Antigravity owns behavior; this integration layer calibrates the newest
## reference's typography/spacing and proportional scaling at different sizes.
var _reference_styled := false
var _reference_layout_pending := false
var _zombie_launch_button: Button

func _ready() -> void:
	super._ready()
	resized.connect(_schedule_reference_layout)
	var home: Control = _pages.get("home")
	if home != null:
		home.resized.connect(_schedule_reference_layout)
		home.visibility_changed.connect(_schedule_reference_layout)
		home._root_vbox.minimum_size_changed.connect(_schedule_reference_layout)
		home._root_vbox.resized.connect(_schedule_reference_layout)
	_schedule_reference_layout()

func present(model: Dictionary) -> void:
	super.present(model)
	if model.get("page","") == "home":
		_apply_reference_layout()
		_sync_registered_preview(model)
	if model.get("page","") == "briefing" and _pages.has("briefing"):
		_pages.briefing._mode_label.text = str(model.get("mission",{}).get("mode_title","ENSA Games"))

func _sync_registered_preview(model: Dictionary) -> void:
	var home: Control = _pages.get("home")
	if home == null: return
	var mode: Dictionary = {}
	for entry: Dictionary in model.get("modes",[]):
		if entry.get("id","") == "zombie_rpg": mode = entry
	var available: bool = mode.get("availability","") == "available" and not mode.get("mission_ids",[]).is_empty()
	if _zombie_launch_button == null:
		_zombie_launch_button = Button.new()
		_zombie_launch_button.name = "RegisteredZombieLaunch"
		_zombie_launch_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_zombie_launch_button.focus_mode = Control.FOCUS_ALL
		for state: String in ["normal","hover","pressed","disabled"]:
			_zombie_launch_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = LauncherTheme.COL_ACCENT
		focus.set_border_width_all(1)
		_zombie_launch_button.add_theme_stylebox_override("focus",focus)
		_zombie_launch_button.pressed.connect(func(): intent_requested.emit(&"show_briefing",{"mode_id":"zombie_rpg"}))
		home._zombie_card.add_child(_zombie_launch_button)
	_zombie_launch_button.visible = available
	_zombie_launch_button.disabled = not available
	_zombie_launch_button.tooltip_text = "Open After Hours mission briefing" if available else ""
	_zombie_launch_button.focus_neighbor_left = home._cta_play_btn.get_path()
	_zombie_launch_button.focus_neighbor_top = home._cta_play_btn.get_path()
	home._cta_play_btn.focus_neighbor_right = _zombie_launch_button.get_path() if available else NodePath()
	home._zombie_lock.visible = not available
	home._zombie_thumb.modulate = Color.WHITE if available else Color(.65,.65,.70,.85)
	home._zombie_badge.text = "PLAY EPISODE  ›" if available else "COMING SOON"
	var accent: Color = LauncherTheme.COL_ACCENT if available else LauncherTheme.COL_COMING_SOON
	home._zombie_badge.add_theme_color_override("font_color",accent)
	home._zombie_badge.add_theme_stylebox_override("normal",LauncherTheme.make_badge_style(accent))
	home._zombie_desc.text = "Restore power. Help the survivor. Reach extraction." if available else "Explore. Survive. Protect your resources."

func _schedule_reference_layout() -> void:
	if _reference_layout_pending: return
	_reference_layout_pending = true
	_apply_reference_layout.call_deferred()

func _apply_reference_layout() -> void:
	_reference_layout_pending = false
	var home: Control = _pages.get("home")
	if home == null or home.get("_root_vbox") == null or home.size.x<1 or home.size.y<1: return
	if not _reference_styled:
		for button: Button in [home._play_btn,home._modes_btn,home._continue_btn,home._settings_btn,home._how_to_play_btn,home._credits_btn,home._quit_btn]:
			button.custom_minimum_size.y = 46
		_reference_styled = true
	# Native responsive notifications run again on resize and page visibility.
	# Reset their physical-pixel values before applying one proportional scale,
	# otherwise the minimum size and type are scaled twice after navigation.
	home._heading_label.add_theme_font_size_override("font_size",58)
	home._subheading_label.add_theme_font_size_override("font_size",18)
	home._emblem_rect.custom_minimum_size = Vector2(64,64)
	home._cta_play_btn.custom_minimum_size = Vector2(290,56)
	home._workstation_rect.get_parent().custom_minimum_size = Vector2(196,136)
	home._zombie_thumb.get_parent().custom_minimum_size = Vector2(125,130)
	# Work in a 720-high design coordinate space. This also covers standalone
	# harnesses that set content_scale_size to the physical display resolution.
	var factor: float = minf(home.size.y/720.0,home.size.x/1280.0)
	var design_size: Vector2 = home.size/factor
	# Do not temporarily resize to the minimum width: wrapping Continue's
	# summary at that transient width can leave the root expanded vertically.
	home._root_vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	home._root_vbox.position = Vector2.ZERO
	home._root_vbox.size = design_size
	home._root_vbox.scale = Vector2(factor,factor)
	var rail: float = clampf(design_size.x*.175,215.0,330.0)
	home._left_rail.custom_minimum_size.x = rail
	home._bottom_left_box.custom_minimum_size.x = rail
	var content: VBoxContainer = home._main_content_margin.get_child(0)
	content.add_theme_constant_override("separation",14)
	home._main_content_margin.add_theme_constant_override("margin_bottom",28)
	var required: float = content.get_combined_minimum_size().y
	var top: int = int(clampf(720.0-36.0-28.0-required,32.0,110.0))
	home._main_content_margin.add_theme_constant_override("margin_top",top)
	for segment: Panel in home._progress_segments: segment.custom_minimum_size = Vector2(15,12)
