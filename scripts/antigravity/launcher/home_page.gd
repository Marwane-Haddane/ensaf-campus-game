## home_page.gd — ENSA Games main hub
## Matches the final user-selected design (docs/references/launcher-final-target.png)
## Owned by Antigravity; emits presentation intents for Codex controller.
class_name LauncherHomePage
extends Control

const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")

signal intent_requested(action: StringName, payload: Dictionary)

# ── Calm ring indicator for bottom status strip ──────────────────────────────
class CalmRingIndicator extends Control:
	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, 7.0, 0.0, TAU, 24, LauncherTheme.COL_ACCENT_DIM, 2.0, true)
		draw_circle(c, 2.5, LauncherTheme.COL_ACCENT)

# ── Member refs ──────────────────────────────────────────────────────────────
var _root_vbox: VBoxContainer
var _left_rail: PanelContainer
var _emblem_rect: TextureRect
var _play_btn: Button
var _modes_btn: Button
var _continue_box: VBoxContainer
var _continue_btn: Button
var _continue_label: Label
var _settings_btn: Button
var _how_to_play_btn: Button
var _credits_btn: Button
var _quit_btn: Button

var _main_content_margin: MarginContainer
var _heading_label: Label
var _subheading_label: Label
var _cta_play_btn: Button
var _enter_keycap_btn: Button

var _workstation_rect: TextureRect
var _case_id_label: Label
var _case_title_label: Label
var _case_status_label: Label
var _case_status_dot: Label
var _progress_segments_container: HBoxContainer
var _progress_segments: Array[Panel] = []
var _case_progress_label: Label
var _case_objective_label: Label

var _zombie_card: PanelContainer
var _zombie_thumb: TextureRect
var _zombie_lock: TextureRect
var _zombie_badge: Label
var _zombie_title: Label
var _zombie_desc: Label

var _bottom_strip: PanelContainer
var _bottom_left_box: HBoxContainer
var _status_sub_label: Label
var _status_ready_label: Label

var _cached_continue_data: Dictionary = {}

func get_page_id() -> String:
	return "home"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	clip_contents = true
	_build_ui()
	_update_responsive_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_instance_valid(_root_vbox):
			_root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_update_responsive_layout()

func _update_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var w := size.x
	var h := size.y
	# Fixed rail roughly 17% of viewport (about 215-240px at 1280w, clamped)
	var rail_w := clampf(w * 0.175, 215.0, 330.0)
	if is_instance_valid(_left_rail):
		_left_rail.custom_minimum_size.x = rail_w
	if is_instance_valid(_bottom_left_box):
		_bottom_left_box.custom_minimum_size.x = rail_w

	# Proportional scaling factor relative to 720p baseline
	var sf := clampf(h / 720.0, 0.8, 1.5)

	if is_instance_valid(_heading_label):
		_heading_label.add_theme_font_size_override("font_size", roundi(36 * sf))
	if is_instance_valid(_subheading_label):
		_subheading_label.add_theme_font_size_override("font_size", roundi(15 * sf))
	if is_instance_valid(_cta_play_btn):
		_cta_play_btn.custom_minimum_size = Vector2(roundf(290 * sf), roundf(50 * sf))
	if is_instance_valid(_workstation_rect) and is_instance_valid(_workstation_rect.get_parent()):
		var thumb_panel := _workstation_rect.get_parent() as PanelContainer
		if thumb_panel:
			thumb_panel.custom_minimum_size = Vector2(roundf(230 * sf), roundf(144 * sf))
	if is_instance_valid(_zombie_thumb) and is_instance_valid(_zombie_thumb.get_parent()):
		var z_box := _zombie_thumb.get_parent() as PanelContainer
		if z_box:
			z_box.custom_minimum_size = Vector2(roundf(200 * sf), roundf(110 * sf))
	if is_instance_valid(_emblem_rect):
		_emblem_rect.custom_minimum_size = Vector2(roundf(56 * sf), roundf(56 * sf))

func _build_ui() -> void:
	# Single root VBox ensures bottom strip never overlaps upper body
	_root_vbox = VBoxContainer.new()
	_root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root_vbox.add_theme_constant_override("separation", 0)
	add_child(_root_vbox)

	# ── 1. Upper Body (Left Rail + Main Content) ─────────────────────────────
	var upper_body := HBoxContainer.new()
	upper_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upper_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper_body.add_theme_constant_override("separation", 0)
	_root_vbox.add_child(upper_body)

	# ── 1A. Left Rail (Navigation) ───────────────────────────────────────────
	_left_rail = PanelContainer.new()
	_left_rail.custom_minimum_size = Vector2(220, 0)
	_left_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var rail_sb := StyleBoxFlat.new()
	rail_sb.bg_color = Color(0.06, 0.08, 0.12, 0.94)
	rail_sb.border_width_right = 1
	rail_sb.border_color = Color(0.20, 0.25, 0.32, 0.5)
	_left_rail.add_theme_stylebox_override("panel", rail_sb)
	upper_body.add_child(_left_rail)

	var rail_margin := MarginContainer.new()
	rail_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rail_margin.add_theme_constant_override("margin_top", 24)
	rail_margin.add_theme_constant_override("margin_bottom", 16)
	rail_margin.add_theme_constant_override("margin_left", 18)
	rail_margin.add_theme_constant_override("margin_right", 18)
	_left_rail.add_child(rail_margin)

	var rail_vbox := VBoxContainer.new()
	rail_vbox.add_theme_constant_override("separation", 10)
	rail_margin.add_child(rail_vbox)

	# Emblem (White Vector SVG)
	_emblem_rect = TextureRect.new()
	_emblem_rect.custom_minimum_size = Vector2(56, 56)
	_emblem_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_emblem_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_emblem_rect.texture = LauncherTheme.load_texture_safe("res://assets/launcher/ensa-emblem-white.svg")
	rail_vbox.add_child(_emblem_rect)

	# Brand title & subtitle
	var brand_title := Label.new()
	brand_title.text = "ENSA GAMES"
	brand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand_title.add_theme_font_size_override("font_size", 18)
	brand_title.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	rail_vbox.add_child(brand_title)

	var brand_sub := Label.new()
	brand_sub.text = "Campus Operations &\nSimulation Hub"
	brand_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand_sub.add_theme_font_size_override("font_size", 11)
	brand_sub.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	rail_vbox.add_child(brand_sub)

	# Fine divider below branding
	var brand_divider := ColorRect.new()
	brand_divider.custom_minimum_size = Vector2(0, 1)
	brand_divider.color = Color(0.20, 0.25, 0.32, 0.5)
	rail_vbox.add_child(brand_divider)

	# Navigation items VBox
	var nav_vbox := VBoxContainer.new()
	nav_vbox.add_theme_constant_override("separation", 4)
	rail_vbox.add_child(nav_vbox)

	# Play nav button (Selected state with quiet teal horizontal highlight and thin vertical accent)
	_play_btn = Button.new()
	_play_btn.text = "Play"
	_play_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_play_btn.custom_minimum_size = Vector2(0, 38)
	_play_btn.focus_mode = Control.FOCUS_ALL
	_play_btn.icon = LauncherTheme.load_texture_safe("res://assets/launcher/icons/player-play.svg")
	_play_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_play_btn.expand_icon = true
	_play_btn.add_theme_constant_override("icon_max_width", 18)
	_play_btn.add_theme_constant_override("h_separation", 12)
	_play_btn.add_theme_font_size_override("font_size", 15)
	_style_selected_play_btn(_play_btn)
	_play_btn.pressed.connect(func(): intent_requested.emit(&"play", {}))
	nav_vbox.add_child(_play_btn)

	# Game Modes
	_modes_btn = _make_nav_btn(nav_vbox, "Game Modes", "res://assets/launcher/icons/layout-grid.svg", func():
		intent_requested.emit(&"show_modes", {})
	)

	# Continue (only when a validated save exists)
	_continue_box = VBoxContainer.new()
	_continue_box.name = "ContinueBox"
	_continue_box.add_theme_constant_override("separation", 2)
	_continue_box.visible = false
	nav_vbox.add_child(_continue_box)

	_continue_btn = _make_nav_btn(_continue_box, "Continue", "res://assets/launcher/icons/player-play.svg", _on_continue_pressed)

	var cont_margin := MarginContainer.new()
	cont_margin.add_theme_constant_override("margin_left", 42)
	cont_margin.add_theme_constant_override("margin_right", 8)
	cont_margin.add_theme_constant_override("margin_bottom", 4)
	_continue_box.add_child(cont_margin)

	_continue_label = Label.new()
	_continue_label.text = ""
	_continue_label.add_theme_font_size_override("font_size", 11)
	_continue_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	_continue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cont_margin.add_child(_continue_label)

	# Settings
	_settings_btn = _make_nav_btn(nav_vbox, "Settings", "res://assets/launcher/icons/settings.svg", func():
		intent_requested.emit(&"show_settings", {})
	)

	# How to Play
	_how_to_play_btn = _make_nav_btn(nav_vbox, "How to Play", "res://assets/launcher/icons/book.svg", func():
		intent_requested.emit(&"show_how_to_play", {})
	)

	# Credits
	_credits_btn = _make_nav_btn(nav_vbox, "Credits", "res://assets/launcher/icons/file-description.svg", func():
		intent_requested.emit(&"show_credits", {})
	)

	# Nav spacer pushing Quit to bottom
	var nav_spacer := Control.new()
	nav_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail_vbox.add_child(nav_spacer)

	# Quit button
	_quit_btn = _make_nav_btn(rail_vbox, "Quit", "res://assets/launcher/icons/power.svg", func():
		intent_requested.emit(&"quit", {})
	)
	_quit_btn.add_theme_color_override("font_hover_color", LauncherTheme.COL_ERROR)
	_quit_btn.add_theme_color_override("icon_hover_color", LauncherTheme.COL_ERROR)

	# ── 1B. Main Content Area (~21% width start) ─────────────────────────────
	_main_content_margin = MarginContainer.new()
	_main_content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_content_margin.add_theme_constant_override("margin_top", 42)
	_main_content_margin.add_theme_constant_override("margin_bottom", 20)
	_main_content_margin.add_theme_constant_override("margin_left", 44)
	_main_content_margin.add_theme_constant_override("margin_right", 48)
	upper_body.add_child(_main_content_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	_main_content_margin.add_child(main_vbox)

	# ── Top Hero / CTA Block (NO AVAILABLE BADGE) ────────────────────────────
	var hero_vbox := VBoxContainer.new()
	hero_vbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(hero_vbox)

	_heading_label = Label.new()
	_heading_label.text = "ENSA Incident\nResponse"
	_heading_label.add_theme_font_size_override("font_size", 36)
	_heading_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	hero_vbox.add_child(_heading_label)

	_subheading_label = Label.new()
	_subheading_label.text = "Investigate incidents. Find evidence.\nDefend the campus."
	_subheading_label.add_theme_font_size_override("font_size", 15)
	_subheading_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	hero_vbox.add_child(_subheading_label)

	var cta_spacer := Control.new()
	cta_spacer.custom_minimum_size = Vector2(0, 4)
	hero_vbox.add_child(cta_spacer)

	# Prominent teal Play CTA button (~275-305px wide, dark bold label, right chevron)
	_cta_play_btn = _build_cta_play_button()
	hero_vbox.add_child(_cta_play_btn)

	# Outlined Enter keycap and Play label
	var enter_row := _build_enter_keycap_row()
	hero_vbox.add_child(enter_row)

	# Spacer pushing lower section to dark courtyard pavement area
	var hero_spacer := Control.new()
	hero_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(hero_spacer)

	# ── Fine Divider Line ────────────────────────────────────────────────────
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(0.25, 0.32, 0.42, 0.4)
	main_vbox.add_child(divider)

	var split_spacer := Control.new()
	split_spacer.custom_minimum_size = Vector2(0, 6)
	main_vbox.add_child(split_spacer)

	# ── Lower Split Section (Active Case + Zombie RPG Preview) ───────────────
	var lower_hbox := HBoxContainer.new()
	lower_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower_hbox.size_flags_vertical = Control.SIZE_SHRINK_END
	lower_hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(lower_hbox)

	# Left: Active Case Section
	var active_case_section := _build_active_case_section()
	active_case_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_case_section.size_flags_stretch_ratio = 1.35
	lower_hbox.add_child(active_case_section)

	# Vertical divider rule
	var v_rule := ColorRect.new()
	v_rule.custom_minimum_size = Vector2(1, 146)
	v_rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v_rule.color = Color(0.20, 0.25, 0.32, 0.5)
	lower_hbox.add_child(v_rule)

	# Right: Zombie RPG Survival Preview
	_zombie_card = _build_zombie_card()
	_zombie_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zombie_card.size_flags_stretch_ratio = 1.0
	lower_hbox.add_child(_zombie_card)

	# ── 2. Full-Width Bottom Status Strip ────────────────────────────────────
	_bottom_strip = _build_bottom_strip()
	_root_vbox.add_child(_bottom_strip)

	# Focus routing
	_setup_focus_chain()

func _setup_focus_chain() -> void:
	if is_instance_valid(_play_btn) and is_instance_valid(_modes_btn):
		_play_btn.focus_neighbor_bottom = _modes_btn.get_path()
		_modes_btn.focus_neighbor_top = _play_btn.get_path()

	_update_nav_focus_chain()

	if is_instance_valid(_cta_play_btn) and is_instance_valid(_play_btn):
		_cta_play_btn.focus_neighbor_left = _play_btn.get_path()
		_play_btn.focus_neighbor_right = _cta_play_btn.get_path()
	if is_instance_valid(_cta_play_btn) and is_instance_valid(_enter_keycap_btn):
		_cta_play_btn.focus_neighbor_bottom = _enter_keycap_btn.get_path()
		_enter_keycap_btn.focus_neighbor_top = _cta_play_btn.get_path()
		_enter_keycap_btn.focus_neighbor_left = _play_btn.get_path()

func _update_nav_focus_chain() -> void:
	if not is_instance_valid(_modes_btn) or not is_instance_valid(_settings_btn):
		return
	if is_instance_valid(_continue_box) and _continue_box.visible and is_instance_valid(_continue_btn):
		_modes_btn.focus_neighbor_bottom = _continue_btn.get_path()
		_continue_btn.focus_neighbor_top = _modes_btn.get_path()
		_continue_btn.focus_neighbor_bottom = _settings_btn.get_path()
		_continue_btn.focus_neighbor_right = _cta_play_btn.get_path() if is_instance_valid(_cta_play_btn) else NodePath()
		_settings_btn.focus_neighbor_top = _continue_btn.get_path()
	else:
		_modes_btn.focus_neighbor_bottom = _settings_btn.get_path()
		_settings_btn.focus_neighbor_top = _modes_btn.get_path()

	if is_instance_valid(_settings_btn) and is_instance_valid(_how_to_play_btn):
		_settings_btn.focus_neighbor_bottom = _how_to_play_btn.get_path()
		_how_to_play_btn.focus_neighbor_top = _settings_btn.get_path()
	if is_instance_valid(_how_to_play_btn) and is_instance_valid(_credits_btn):
		_how_to_play_btn.focus_neighbor_bottom = _credits_btn.get_path()
		_credits_btn.focus_neighbor_top = _how_to_play_btn.get_path()
	if is_instance_valid(_credits_btn) and is_instance_valid(_quit_btn):
		_credits_btn.focus_neighbor_bottom = _quit_btn.get_path()
		_quit_btn.focus_neighbor_top = _credits_btn.get_path()

	# All rail buttons can jump right to Play CTA
	if is_instance_valid(_cta_play_btn):
		for btn: Button in [_modes_btn, _settings_btn, _how_to_play_btn, _credits_btn, _quit_btn]:
			if is_instance_valid(btn):
				btn.focus_neighbor_right = _cta_play_btn.get_path()

func _style_selected_play_btn(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.22, 0.25, 0.70)
	sb.border_width_left = 3
	sb.border_color = LauncherTheme.COL_ACCENT
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	sb.anti_aliasing = true

	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(0.12, 0.28, 0.32, 0.85)

	var sb_focus := sb.duplicate()
	sb_focus.border_width_top = 1
	sb_focus.border_width_bottom = 1
	sb_focus.border_width_right = 1
	sb_focus.border_color = LauncherTheme.COL_ACCENT

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_stylebox_override("focus", sb_focus)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)
	btn.add_theme_color_override("icon_normal_color", LauncherTheme.COL_ACCENT)
	btn.add_theme_color_override("icon_hover_color", LauncherTheme.COL_ACCENT)
	btn.add_theme_color_override("icon_focus_color", LauncherTheme.COL_ACCENT)
	btn.add_theme_color_override("icon_pressed_color", LauncherTheme.COL_ACCENT)

func _make_nav_btn(parent: Control, label: String, icon_path: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 38)
	btn.focus_mode = Control.FOCUS_ALL
	var tex := LauncherTheme.load_texture_safe(icon_path)
	if tex:
		btn.icon = tex
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 18)
		btn.add_theme_constant_override("h_separation", 12)
		btn.add_theme_color_override("icon_normal_color", LauncherTheme.COL_TEXT_SECONDARY)
		btn.add_theme_color_override("icon_hover_color", LauncherTheme.COL_TEXT_PRIMARY)
		btn.add_theme_color_override("icon_focus_color", LauncherTheme.COL_TEXT_PRIMARY)
		btn.add_theme_color_override("icon_pressed_color", LauncherTheme.COL_TEXT_PRIMARY)

	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := LauncherTheme.make_ghost_button_style(state)
		sb.content_margin_left = 12.0
		sb.content_margin_right = 12.0
		sb.content_margin_top = 8.0
		sb.content_margin_bottom = 8.0
		btn.add_theme_stylebox_override(state, sb)

	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	btn.add_theme_color_override("font_hover_color", LauncherTheme.COL_TEXT_PRIMARY)
	btn.add_theme_color_override("font_focus_color", LauncherTheme.COL_TEXT_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", LauncherTheme.COL_TEXT_PRIMARY)

	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func _build_cta_play_button() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(290, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.focus_mode = Control.FOCUS_ALL

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.24, 0.82, 0.73, 1.0)
	sb_normal.corner_radius_top_left = 6
	sb_normal.corner_radius_top_right = 6
	sb_normal.corner_radius_bottom_left = 6
	sb_normal.corner_radius_bottom_right = 6
	sb_normal.content_margin_left = 24.0
	sb_normal.content_margin_right = 20.0
	sb_normal.content_margin_top = 12.0
	sb_normal.content_margin_bottom = 12.0
	sb_normal.anti_aliasing = true

	var sb_hover := sb_normal.duplicate()
	sb_hover.bg_color = Color(0.30, 0.88, 0.79, 1.0)

	var sb_pressed := sb_normal.duplicate()
	sb_pressed.bg_color = Color(0.18, 0.70, 0.62, 1.0)

	var sb_focus := sb_normal.duplicate()
	sb_focus.border_width_left = 2
	sb_focus.border_width_top = 2
	sb_focus.border_width_right = 2
	sb_focus.border_width_bottom = 2
	sb_focus.border_color = Color.WHITE

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("focus", sb_focus)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	var label := Label.new()
	label.text = "Play"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.04, 0.08, 0.10, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer)

	var chevron := Label.new()
	chevron.text = "›"
	chevron.add_theme_font_size_override("font_size", 22)
	chevron.add_theme_color_override("font_color", Color(0.04, 0.08, 0.10, 1.0))
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(chevron)

	btn.pressed.connect(func(): intent_requested.emit(&"play", {}))
	return btn

func _build_enter_keycap_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	_enter_keycap_btn = Button.new()
	_enter_keycap_btn.text = "Enter"
	_enter_keycap_btn.focus_mode = Control.FOCUS_ALL
	_enter_keycap_btn.custom_minimum_size = Vector2(48, 22)
	_enter_keycap_btn.add_theme_font_size_override("font_size", 11)
	_enter_keycap_btn.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	_enter_keycap_btn.add_theme_color_override("font_hover_color", LauncherTheme.COL_ACCENT)

	var sb_key := StyleBoxFlat.new()
	sb_key.bg_color = Color(0.08, 0.12, 0.16, 0.8)
	sb_key.border_width_left = 1
	sb_key.border_width_top = 1
	sb_key.border_width_right = 1
	sb_key.border_width_bottom = 1
	sb_key.border_color = Color(0.35, 0.42, 0.50, 0.8)
	sb_key.corner_radius_top_left = 4
	sb_key.corner_radius_top_right = 4
	sb_key.corner_radius_bottom_left = 4
	sb_key.corner_radius_bottom_right = 4
	sb_key.content_margin_left = 6.0
	sb_key.content_margin_right = 6.0
	sb_key.content_margin_top = 2.0
	sb_key.content_margin_bottom = 2.0

	var sb_key_focus := sb_key.duplicate()
	sb_key_focus.border_color = LauncherTheme.COL_ACCENT

	_enter_keycap_btn.add_theme_stylebox_override("normal", sb_key)
	_enter_keycap_btn.add_theme_stylebox_override("hover", sb_key_focus)
	_enter_keycap_btn.add_theme_stylebox_override("focus", sb_key_focus)
	_enter_keycap_btn.add_theme_stylebox_override("pressed", sb_key)

	_enter_keycap_btn.pressed.connect(func(): intent_requested.emit(&"play", {}))
	row.add_child(_enter_keycap_btn)

	var lbl := Label.new()
	lbl.text = "Play"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	row.add_child(lbl)

	return row

func _build_active_case_section() -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Workstation thumbnail
	var thumb_panel := PanelContainer.new()
	thumb_panel.custom_minimum_size = Vector2(230, 144)
	thumb_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var thumb_sb := StyleBoxFlat.new()
	thumb_sb.bg_color = Color(0.05, 0.07, 0.10, 0.8)
	thumb_sb.corner_radius_top_left = 6
	thumb_sb.corner_radius_top_right = 6
	thumb_sb.corner_radius_bottom_left = 6
	thumb_sb.corner_radius_bottom_right = 6
	thumb_sb.border_width_left = 1
	thumb_sb.border_width_top = 1
	thumb_sb.border_width_right = 1
	thumb_sb.border_width_bottom = 1
	thumb_sb.border_color = Color(0.20, 0.25, 0.32, 0.6)
	thumb_sb.anti_aliasing = true
	thumb_panel.add_theme_stylebox_override("panel", thumb_sb)
	thumb_panel.clip_contents = true

	_workstation_rect = TextureRect.new()
	_workstation_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_workstation_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_workstation_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_workstation_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_workstation_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_workstation_rect.texture = LauncherTheme.load_texture_safe("res://assets/launcher/case-workstation.png")
	thumb_panel.add_child(_workstation_rect)
	hbox.add_child(thumb_panel)

	# Case details VBox
	var details_vbox := VBoxContainer.new()
	details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(details_vbox)

	var case_tracker := Label.new()
	case_tracker.text = "ACTIVE CASE"
	case_tracker.add_theme_font_size_override("font_size", 11)
	case_tracker.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	details_vbox.add_child(case_tracker)

	_case_id_label = Label.new()
	_case_id_label.text = "IR-2026-001"
	_case_id_label.add_theme_font_size_override("font_size", 14)
	_case_id_label.add_theme_color_override("font_color", Color(0.70, 0.80, 0.90, 1.0))
	details_vbox.add_child(_case_id_label)

	_case_title_label = Label.new()
	_case_title_label.text = "The borrowed session"
	_case_title_label.add_theme_font_size_override("font_size", 18)
	_case_title_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	details_vbox.add_child(_case_title_label)

	# Status row
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	details_vbox.add_child(status_row)

	_case_status_dot = Label.new()
	_case_status_dot.text = "•"
	_case_status_dot.add_theme_font_size_override("font_size", 16)
	_case_status_dot.add_theme_color_override("font_color", LauncherTheme.COL_WARNING)
	status_row.add_child(_case_status_dot)

	_case_status_label = Label.new()
	_case_status_label.text = "Investigation pending"
	_case_status_label.add_theme_font_size_override("font_size", 13)
	_case_status_label.add_theme_color_override("font_color", LauncherTheme.COL_WARNING)
	status_row.add_child(_case_status_label)

	# Seven-segment progress row
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 10)
	details_vbox.add_child(progress_row)

	_progress_segments_container = HBoxContainer.new()
	_progress_segments_container.add_theme_constant_override("separation", 3)
	progress_row.add_child(_progress_segments_container)

	_case_progress_label = Label.new()
	_case_progress_label.text = "0 / 7 complete"
	_case_progress_label.add_theme_font_size_override("font_size", 12)
	_case_progress_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	progress_row.add_child(_case_progress_label)

	_update_segments(0, 7)

	# Objective
	var obj_spacer := Control.new()
	obj_spacer.custom_minimum_size = Vector2(0, 6)
	details_vbox.add_child(obj_spacer)

	var obj_hdr := Label.new()
	obj_hdr.text = "OBJECTIVE"
	obj_hdr.add_theme_font_size_override("font_size", 10)
	obj_hdr.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	details_vbox.add_child(obj_hdr)

	var obj_row := HBoxContainer.new()
	obj_row.add_theme_constant_override("separation", 8)
	details_vbox.add_child(obj_row)

	var monitor_icon := TextureRect.new()
	monitor_icon.custom_minimum_size = Vector2(16, 16)
	monitor_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	monitor_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	monitor_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	monitor_icon.modulate = LauncherTheme.COL_TEXT_SECONDARY
	monitor_icon.texture = LauncherTheme.load_texture_safe("res://assets/launcher/icons/device-desktop.svg")
	obj_row.add_child(monitor_icon)

	_case_objective_label = Label.new()
	_case_objective_label.text = "Find the marked workstation."
	_case_objective_label.add_theme_font_size_override("font_size", 13)
	_case_objective_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	obj_row.add_child(_case_objective_label)

	return hbox

func _build_zombie_card() -> PanelContainer:
	_zombie_card = PanelContainer.new()
	_zombie_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zombie_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_zombie_card.size_flags_stretch_ratio = 1.0
	_zombie_card.mouse_filter = Control.MOUSE_FILTER_PASS

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.11, 0.35)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.18, 0.24, 0.30, 0.35)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	_zombie_card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_zombie_card.add_child(vbox)

	# Thumbnail with lock overlay
	var thumb_box := PanelContainer.new()
	thumb_box.custom_minimum_size = Vector2(0, 110)
	var tsb := StyleBoxFlat.new()
	tsb.corner_radius_top_left = 4
	tsb.corner_radius_top_right = 4
	tsb.corner_radius_bottom_left = 4
	tsb.corner_radius_bottom_right = 4
	thumb_box.add_theme_stylebox_override("panel", tsb)
	thumb_box.clip_contents = true
	vbox.add_child(thumb_box)

	_zombie_thumb = TextureRect.new()
	_zombie_thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zombie_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_zombie_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_zombie_thumb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_zombie_thumb.modulate = Color(0.65, 0.65, 0.70, 0.85)
	var z_bg := "res://assets/launcher/campus-dusk-reference.png"
	var z_tex := LauncherTheme.load_texture_safe(z_bg)
	if z_tex == null:
		z_tex = LauncherTheme.load_texture_safe("res://assets/antigravity/launcher/mode_zombie.png")
	if z_tex:
		_zombie_thumb.texture = z_tex
	thumb_box.add_child(_zombie_thumb)

	var lock_center := CenterContainer.new()
	lock_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumb_box.add_child(lock_center)

	_zombie_lock = TextureRect.new()
	_zombie_lock.custom_minimum_size = Vector2(28, 28)
	_zombie_lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_zombie_lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_zombie_lock.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_zombie_lock.modulate = Color(1.0, 1.0, 1.0, 0.90)
	_zombie_lock.texture = LauncherTheme.load_texture_safe("res://assets/launcher/icons/lock.svg")
	lock_center.add_child(_zombie_lock)

	# Badge row
	var badge_row := HBoxContainer.new()
	vbox.add_child(badge_row)

	_zombie_badge = Label.new()
	_zombie_badge.text = "COMING SOON"
	_zombie_badge.add_theme_font_size_override("font_size", 11)
	_zombie_badge.add_theme_color_override("font_color", LauncherTheme.COL_COMING_SOON)
	_zombie_badge.add_theme_stylebox_override("normal", LauncherTheme.make_badge_style(LauncherTheme.COL_COMING_SOON))
	badge_row.add_child(_zombie_badge)

	# Title
	_zombie_title = Label.new()
	_zombie_title.text = "Zombie RPG Survival"
	_zombie_title.add_theme_font_size_override("font_size", 15)
	_zombie_title.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	vbox.add_child(_zombie_title)

	# Desc
	_zombie_desc = Label.new()
	_zombie_desc.text = "Explore. Survive. Protect your resources."
	_zombie_desc.add_theme_font_size_override("font_size", 12)
	_zombie_desc.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	_zombie_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_zombie_desc)

	return _zombie_card

func _build_bottom_strip() -> PanelContainer:
	_bottom_strip = PanelContainer.new()
	_bottom_strip.custom_minimum_size = Vector2(0, 36)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.09, 0.96)
	sb.border_width_top = 1
	sb.border_color = Color(0.20, 0.25, 0.32, 0.5)
	_bottom_strip.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	_bottom_strip.add_child(hbox)

	# Left segment matching rail width
	_bottom_left_box = HBoxContainer.new()
	_bottom_left_box.custom_minimum_size = Vector2(220, 0)
	hbox.add_child(_bottom_left_box)

	var left_margin := MarginContainer.new()
	left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_margin.add_theme_constant_override("margin_left", 20)
	left_margin.add_theme_constant_override("margin_right", 16)
	_bottom_left_box.add_child(left_margin)

	var left_sub_hbox := HBoxContainer.new()
	left_sub_hbox.add_theme_constant_override("separation", 8)
	left_sub_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	left_margin.add_child(left_sub_hbox)

	var ring_ind := CalmRingIndicator.new()
	ring_ind.custom_minimum_size = Vector2(20, 20)
	left_sub_hbox.add_child(ring_ind)

	var sys_label := Label.new()
	sys_label.text = "ENSA Simulation Hub"
	sys_label.add_theme_font_size_override("font_size", 12)
	sys_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	left_sub_hbox.add_child(sys_label)

	var vdiv := ColorRect.new()
	vdiv.custom_minimum_size = Vector2(1, 0)
	vdiv.color = Color(0.20, 0.25, 0.32, 0.5)
	hbox.add_child(vdiv)

	# Right segment with Menu ready
	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 24)
	right_margin.add_theme_constant_override("margin_right", 24)
	hbox.add_child(right_margin)

	var right_hbox := HBoxContainer.new()
	right_margin.add_child(right_hbox)

	_status_sub_label = Label.new()
	_status_sub_label.text = "Incident response module initialized"
	_status_sub_label.add_theme_font_size_override("font_size", 12)
	_status_sub_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	right_hbox.add_child(_status_sub_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_hbox.add_child(spacer)

	var ready_box := HBoxContainer.new()
	ready_box.add_theme_constant_override("separation", 6)
	right_hbox.add_child(ready_box)

	var dot := Label.new()
	dot.text = "•"
	dot.add_theme_font_size_override("font_size", 16)
	dot.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
	ready_box.add_child(dot)

	_status_ready_label = Label.new()
	_status_ready_label.text = "Menu ready"
	_status_ready_label.add_theme_font_size_override("font_size", 12)
	_status_ready_label.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
	ready_box.add_child(_status_ready_label)

	return _bottom_strip

func _update_segments(completed: int, total: int) -> void:
	if not is_instance_valid(_progress_segments_container):
		return
	var count := clampi(total, 1, 20)
	var comp := clampi(completed, 0, count)
	while _progress_segments.size() < count:
		var seg := Panel.new()
		seg.custom_minimum_size = Vector2(18, 8)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_progress_segments_container.add_child(seg)
		_progress_segments.append(seg)
	while _progress_segments.size() > count:
		var seg = _progress_segments.pop_back()
		seg.queue_free()

	for i in range(count):
		var seg: Panel = _progress_segments[i]
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = 2
		sb.corner_radius_top_right = 2
		sb.corner_radius_bottom_left = 2
		sb.corner_radius_bottom_right = 2
		sb.anti_aliasing = true
		if i < comp:
			sb.bg_color = LauncherTheme.COL_ACCENT
			sb.border_width_left = 0
			sb.border_width_top = 0
			sb.border_width_right = 0
			sb.border_width_bottom = 0
		else:
			sb.bg_color = Color(0.10, 0.14, 0.18, 0.75)
			sb.border_color = Color(0.28, 0.35, 0.44, 0.8)
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
		seg.add_theme_stylebox_override("panel", sb)

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not is_visible_in_tree():
		return
	if event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			var focused := get_viewport().gui_get_focus_owner()
			if focused == null or focused == _cta_play_btn or focused == _enter_keycap_btn or focused == _play_btn:
				intent_requested.emit(&"play", {})
				get_viewport().set_input_as_handled()

func _on_continue_pressed() -> void:
	if _cached_continue_data.get("available", false):
		intent_requested.emit(&"continue_game", {})

func update_from_model(model: Dictionary) -> void:
	# 1. Continue availability
	var cont_data: Dictionary = model.get("continue", {})
	_cached_continue_data = cont_data
	var is_avail: bool = cont_data.get("available", false)
	if is_instance_valid(_continue_box):
		_continue_box.visible = is_avail
		if is_avail:
			var summary: String = cont_data.get("summary", "")
			_continue_label.text = summary if summary != "" else "Checkpoint: Reception Terminal Alpha"
		_update_nav_focus_chain()

	# 2. Brand Assets
	var brand: Dictionary = model.get("brand_assets", {})
	if brand.has("logo_path") and is_instance_valid(_emblem_rect):
		var l_tex := LauncherTheme.load_texture_safe(brand["logo_path"])
		if l_tex:
			_emblem_rect.texture = l_tex
	if brand.has("case_image_path") and is_instance_valid(_workstation_rect):
		var c_tex := LauncherTheme.load_texture_safe(brand["case_image_path"])
		if c_tex:
			_workstation_rect.texture = c_tex

	# 3. Case Summary
	var cs: Dictionary = model.get("case_summary", {})
	var c_id := "IR-2026-001"
	var c_title := "The borrowed session"
	var c_status := "Investigation pending"
	var c_completed := 0
	var c_total := 7
	var c_obj := "Find the marked workstation."

	if not cs.is_empty():
		c_id = cs.get("id", c_id)
		c_title = cs.get("title", c_title)
		c_status = cs.get("status", c_status)
		c_completed = int(cs.get("completed", c_completed))
		c_total = int(cs.get("total", c_total))
		c_obj = cs.get("objective", c_obj)
	elif model.has("mission") and model["mission"] is Dictionary:
		var m: Dictionary = model["mission"]
		c_id = m.get("id", c_id)
		c_title = m.get("title", c_title)
		c_obj = m.get("objective", c_obj)

	if is_instance_valid(_case_id_label):
		_case_id_label.text = c_id
	if is_instance_valid(_case_title_label):
		_case_title_label.text = c_title
	if is_instance_valid(_case_status_label):
		_case_status_label.text = c_status
	if is_instance_valid(_case_objective_label):
		_case_objective_label.text = c_obj

	if is_instance_valid(_case_status_dot) and is_instance_valid(_case_status_label):
		if c_status.to_lower().contains("resolved") or c_status.to_lower().contains("complete"):
			_case_status_dot.add_theme_color_override("font_color", LauncherTheme.COL_SUCCESS)
			_case_status_label.add_theme_color_override("font_color", LauncherTheme.COL_SUCCESS)
		elif c_status.to_lower().contains("progress"):
			_case_status_dot.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
			_case_status_label.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
		else:
			_case_status_dot.add_theme_color_override("font_color", LauncherTheme.COL_WARNING)
			_case_status_label.add_theme_color_override("font_color", LauncherTheme.COL_WARNING)

	if is_instance_valid(_case_progress_label):
		_case_progress_label.text = "%d / %d complete" % [c_completed, c_total]
	_update_segments(c_completed, c_total)

func focus_primary() -> void:
	if is_instance_valid(_cta_play_btn):
		_cta_play_btn.grab_focus()
	elif is_instance_valid(_play_btn):
		_play_btn.grab_focus()
