## how_to_play_page.gd — Operational guide & gameplay instructions
## Explains movement, interaction ranges (doors 2m, PCs 2.8m), terminal commands, and response workflow.
class_name LauncherHowToPlayPage
extends Control

const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")

signal intent_requested(action: StringName, payload: Dictionary)

var _back_btn: Button
var _scroll: ScrollContainer
var _section_labels: Array[Label] = []

var _margin: MarginContainer

func get_page_id() -> String:
	return "how_to_play"

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
	title.text = "HOW TO PLAY & OPERATIONAL GUIDE"
	title.add_theme_font_size_override("font_size", LauncherTheme.FONT_HEADING)
	title.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	header.add_child(title)

	# Scrollable guide content
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 24)
	_scroll.add_child(content_vbox)

	_section_labels.clear()

	_add_guide_section(content_vbox, "1. Campus Exploration & Locomotion",
		"Navigate the digital twin of the ENSA Fès campus. Movement: W / S / A / D. Mouse: look. Run: Shift. Jump: Space. Campus guide: Tab. Response plan: J. Escape: pause.")

	_add_guide_section(content_vbox, "2. Targeted Interaction (Doors & Workstations)",
		"To interact with doors or computers, look directly at a nearby door or computer. Press E when its prompt appears. Doors respond within 2 metres; PCs within 2.8 metres. Closed doors block movement; open doors allow passage.")

	_add_guide_section(content_vbox, "3. Simulated Linux Terminal Environment",
		"Accessing a workstation opens the local Linux-style training desktop. Use ls, cd, pwd, cat and help to explore the virtual files. Read ~/Help/START_HERE.md, then use ir inspect and follow the guide. Commands are simulated and never run on your Windows computer.")

	_add_guide_section(content_vbox, "4. Incident Response Methodology",
		"Follow the standard incident handling workflow for the borrowed session: inspect the timeline; preserve evidence; isolate the workstation; revoke the reused session; restore the approved baseline; verify recovery; write and submit the incident report.")

func _add_guide_section(parent: Control, section_title: String, body: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", LauncherTheme.make_card_style("normal"))
	parent.add_child(panel)

	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 8)
	panel.add_child(svbox)

	var stitle := Label.new()
	stitle.text = section_title
	stitle.add_theme_font_size_override("font_size", LauncherTheme.FONT_NAV)
	stitle.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
	svbox.add_child(stitle)

	var sbody := Label.new()
	sbody.text = body
	sbody.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sbody.add_theme_font_size_override("font_size", LauncherTheme.FONT_BODY)
	sbody.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	svbox.add_child(sbody)
	_section_labels.append(sbody)

func update_from_model(model: Dictionary) -> void:
	var keys: Dictionary = {}
	for hint in model.get("control_hints", []):
		var label_key = str(hint.get("label", ""))
		var bind_key = str(hint.get("binding", ""))
		if not label_key.is_empty():
			keys[label_key] = bind_key

	var mf = keys.get("move_forward", "W")
	var mb = keys.get("move_back", keys.get("move_backward", "S"))
	var ml = keys.get("move_left", "A")
	var mr = keys.get("move_right", "D")
	var run = keys.get("run", keys.get("sprint", "Shift"))
	var jump = keys.get("jump", "Space")
	var guide = keys.get("destinations", keys.get("campus_guide", "Tab"))
	var resp = keys.get("response_plan", "J")
	var interact = keys.get("interact", "E")

	if _section_labels.size() >= 4:
		_section_labels[0].text = "Navigate the digital twin of the ENSA Fès campus. Movement: %s / %s / %s / %s. Mouse: look. Run: %s. Jump: %s. Campus guide: %s. Response plan: %s. Escape: pause." % [mf, mb, ml, mr, run, jump, guide, resp]
		_section_labels[1].text = "To interact with doors or computers, look directly at a nearby door or computer. Press %s when its prompt appears. Doors respond within 2 metres; PCs within 2.8 metres. Closed doors block movement; open doors allow passage." % interact
		_section_labels[2].text = "Accessing a workstation opens the local Linux-style training desktop. Use ls, cd, pwd, cat and help to explore the virtual files. Read ~/Help/START_HERE.md, then use ir inspect and follow the guide. Commands are simulated and never run on your Windows computer."
		_section_labels[3].text = "Follow the standard incident handling workflow for the borrowed session: inspect the timeline; preserve evidence; isolate the workstation; revoke the reused session; restore the approved baseline; verify recovery; write and submit the incident report."

func focus_primary() -> void:
	if is_instance_valid(_back_btn):
		_back_btn.grab_focus()
