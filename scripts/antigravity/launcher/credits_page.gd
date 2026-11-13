## credits_page.gd — Project credits & licensing attributions
## Documents engine, approved 3D assets, authors, and open-source licenses.
class_name LauncherCreditsPage
extends Control

const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")

signal intent_requested(action: StringName, payload: Dictionary)

var _back_btn: Button
var _scroll: ScrollContainer

var _margin: MarginContainer

func get_page_id() -> String:
	return "credits"

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
	vbox.add_theme_constant_override("separation", 20)
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
	title.text = "CREDITS & LICENSING ATTRIBUTIONS"
	LauncherTheme.display(title, LauncherTheme.FONT_HEADING)
	title.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	header.add_child(title)

	# Scrollable credits content
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 20)
	_scroll.add_child(content_vbox)

	_add_credit_card(content_vbox, "Engine & Runtime",
		"Godot Engine 4.3 Stable (GL Compatibility Renderer)\n" +
		"Free and open-source software under the MIT License.\n" +
		"Copyright (c) 2014-present Godot Engine contributors.\n" +
		"Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.")

	_add_credit_card(content_vbox, "Campus Digital Twin & Architecture",
		"ENSA Fès Architectural Model (Morocco)\n" +
		"Source campus geometry: assets/campus.glb\n" +
		"Design & Optimization: ENSA Fes Cyber Training Project Team.")

	_add_credit_card(content_vbox, "Approved 3D Prop Models",
		"• gamer_setup_pack.glb — Author: user_models (Licensed under CC-BY 4.0)\n" +
		"• office_chair.glb — Author: user_models (Licensed under CC-BY 4.0)\n" +
		"• office_desk_140x60.glb — Author: user_models (Licensed under CC-BY 4.0)\n" +
		"• server_rack.glb — Author: user_models (Licensed under CC-BY 4.0)\n" +
		"• server_rack_1.glb — Author: user_models (Licensed under CC-BY 4.0)")

	_add_credit_card(content_vbox, "Development & Engineering",
		"Antigravity — launcher presentation and environment polish. Codex — gameplay, launcher services and integration.\n" +
		"Built with GDScript for native Windows PC execution.")

func _add_credit_card(parent: Control, section_title: String, body: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", LauncherTheme.make_card_style("normal", true))
	parent.add_child(panel)

	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 8)
	panel.add_child(svbox)

	var stitle := Label.new()
	stitle.text = section_title
	LauncherTheme.display(stitle, 24)
	stitle.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
	svbox.add_child(stitle)

	var sbody := Label.new()
	sbody.text = body
	sbody.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sbody.add_theme_font_size_override("font_size", LauncherTheme.FONT_BODY)
	sbody.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	svbox.add_child(sbody)

func update_from_model(_model: Dictionary) -> void:
	pass

func focus_primary() -> void:
	if is_instance_valid(_back_btn):
		_back_btn.grab_focus()
