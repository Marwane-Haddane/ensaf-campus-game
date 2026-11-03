## modes_page.gd — Mode selection page
## Dynamic list/grid of game modes sourced from model.modes.
class_name LauncherModesPage
extends Control

const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")

signal intent_requested(action: StringName, payload: Dictionary)

var _back_btn: Button
var _cards_container: HBoxContainer
var _primary_focus_target: Control = null
var _cached_modes: Array = []

var _margin: MarginContainer

func get_page_id() -> String:
	return "modes"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_build_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_instance_valid(_margin):
			_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_ui() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_margin.grow_vertical = Control.GROW_DIRECTION_BOTH
	_margin.add_theme_constant_override("margin_left", LauncherTheme.MARGIN_SAFE)
	_margin.add_theme_constant_override("margin_right", LauncherTheme.MARGIN_SAFE)
	_margin.add_theme_constant_override("margin_top", LauncherTheme.MARGIN_SAFE)
	_margin.add_theme_constant_override("margin_bottom", LauncherTheme.MARGIN_SAFE)
	add_child(_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	_margin.add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	_back_btn = Button.new()
	_back_btn.text = "← Back"
	_back_btn.focus_mode = Control.FOCUS_ALL
	_back_btn.pressed.connect(func(): intent_requested.emit(&"back", {}))
	header.add_child(_back_btn)

	var title := Label.new()
	title.text = "SELECT SIMULATION MODE"
	title.add_theme_font_size_override("font_size", LauncherTheme.FONT_HEADING)
	title.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	header.add_child(title)

	var desc := Label.new()
	desc.text = "Choose an operational scenario deployed on the ENSA Fès campus grounds."
	desc.add_theme_font_size_override("font_size", LauncherTheme.FONT_BODY)
	desc.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	vbox.add_child(desc)

	# Cards container
	_cards_container = HBoxContainer.new()
	_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_container.add_theme_constant_override("separation", 24)
	vbox.add_child(_cards_container)

func update_from_model(model: Dictionary) -> void:
	var modes: Array = model.get("modes", [])
	if modes.is_empty():
		# Fallback defaults if model.modes is empty
		modes = [
			{
				"id": "incident_response",
				"title": "ENSA Incident Response",
				"subtitle": "Cybersecurity Investigation",
				"availability": "available",
				"artwork_path": "res://assets/antigravity/launcher/mode_cyber.png",
				"description": "Examine workstations, analyze security breaches, gather forensic evidence, and file incident response reports."
			},
			{
				"id": "zombie_rpg",
				"title": "Zombie RPG Survival",
				"subtitle": "Tactical Defense & Outbreak Containment",
				"availability": "coming_soon",
				"artwork_path": "res://assets/antigravity/launcher/mode_zombie.png",
				"description": "Tactical defense against infected incursions across the courtyard, auditorium, and laboratories."
			}
		]

	if _cached_modes == modes and _cards_container.get_child_count() == modes.size():
		return
	_cached_modes = modes.duplicate(true)

	# Clear old cards
	for child in _cards_container.get_children():
		child.queue_free()

	_primary_focus_target = null

	for mode in modes:
		var card = _build_mode_card(mode)
		_cards_container.add_child(card)

func _build_mode_card(mode: Dictionary) -> Control:
	var mode_id: String = mode.get("id", "")
	var is_available: bool = mode.get("availability", "") == "available"
	var title_str: String = mode.get("title", mode_id)
	var sub_str: String = mode.get("subtitle", "")
	var desc_str: String = mode.get("description", "")
	var art_path: String = mode.get("artwork_path", "")

	if is_available:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(280, 360)
		btn.focus_mode = Control.FOCUS_ALL

		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(state, LauncherTheme.make_card_style(state, true))

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vbox)

		# Thumbnail
		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(0, 160)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.clip_contents = true
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(art_path):
			img.texture = load(art_path)
		vbox.add_child(img)

		# Badge row
		var badge_row := HBoxContainer.new()
		badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(badge_row)

		var badge := Label.new()
		badge.text = "AVAILABLE"
		badge.add_theme_font_size_override("font_size", LauncherTheme.FONT_BADGE)
		badge.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
		badge.add_theme_stylebox_override("normal", LauncherTheme.make_badge_style(LauncherTheme.COL_ACCENT))
		badge_row.add_child(badge)

		# Titles
		var t_lbl := Label.new()
		t_lbl.text = title_str
		t_lbl.add_theme_font_size_override("font_size", LauncherTheme.FONT_HEADING)
		t_lbl.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
		vbox.add_child(t_lbl)

		var s_lbl := Label.new()
		s_lbl.text = sub_str
		s_lbl.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
		s_lbl.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT_DIM)
		vbox.add_child(s_lbl)

		var d_lbl := Label.new()
		d_lbl.text = desc_str
		d_lbl.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
		d_lbl.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.custom_minimum_size = Vector2(220, 36)
		d_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(d_lbl)

		var act := Label.new()
		act.text = "Open Mission Briefing →"
		act.add_theme_font_size_override("font_size", LauncherTheme.FONT_NAV)
		act.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
		vbox.add_child(act)

		btn.pressed.connect(func():
			# The controller resolves this mode's registered default mission.
			intent_requested.emit(&"show_briefing", {"mode_id": mode_id})
		)

		if _primary_focus_target == null:
			_primary_focus_target = btn

		return btn
	else:
		# Unavailable mode card (panel container, preview only)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(280, 360)
		panel.add_theme_stylebox_override("panel", LauncherTheme.make_card_style("disabled"))

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		panel.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		margin.add_child(vbox)

		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(0, 160)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.clip_contents = true
		img.modulate = Color(0.6, 0.6, 0.65, 0.8)
		if ResourceLoader.exists(art_path):
			img.texture = load(art_path)
		vbox.add_child(img)

		var badge_row := HBoxContainer.new()
		badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(badge_row)

		var badge := Label.new()
		badge.text = "COMING SOON"
		badge.add_theme_font_size_override("font_size", LauncherTheme.FONT_BADGE)
		badge.add_theme_color_override("font_color", LauncherTheme.COL_COMING_SOON)
		badge.add_theme_stylebox_override("normal", LauncherTheme.make_badge_style(LauncherTheme.COL_COMING_SOON))
		badge_row.add_child(badge)

		var t_lbl := Label.new()
		t_lbl.text = title_str
		t_lbl.add_theme_font_size_override("font_size", LauncherTheme.FONT_HEADING)
		t_lbl.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
		vbox.add_child(t_lbl)

		var s_lbl := Label.new()
		s_lbl.text = sub_str
		s_lbl.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
		s_lbl.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_DISABLED)
		vbox.add_child(s_lbl)

		var d_lbl := Label.new()
		d_lbl.text = desc_str
		d_lbl.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
		d_lbl.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_DISABLED)
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.custom_minimum_size = Vector2(220, 36)
		d_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(d_lbl)

		var note := Label.new()
		note.text = "Preview only — Not launchable"
		note.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
		note.add_theme_color_override("font_color", LauncherTheme.COL_COMING_SOON)
		vbox.add_child(note)

		return panel


func focus_primary() -> void:
	if is_instance_valid(_primary_focus_target):
		_primary_focus_target.grab_focus()
	elif is_instance_valid(_back_btn):
		_back_btn.grab_focus()
