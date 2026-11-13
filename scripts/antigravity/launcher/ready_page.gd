## Cinematic mission-ready screen. The request ID remains the launch authority.
class_name LauncherReadyPage
extends Control

const DeploymentLayout = preload("res://scripts/antigravity/launcher/deployment_layout.gd")
const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")

signal intent_requested(action: StringName, payload: Dictionary)

var _request_id := ""
var _deployment: DeploymentLayout
var _campus_art: TextureRect
var _kicker: Label
var _details: Label
var _enter_btn: Button
var _return_btn: Button
var _panel: PanelContainer
var _mode := ""

func get_page_id() -> String:
	return "ready"

func get_panel() -> PanelContainer:
	return _panel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_campus_art = TextureRect.new()
	_campus_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_campus_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_campus_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_campus_art)
	_campus_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_deployment = DeploymentLayout.new()
	add_child(_deployment)
	_kicker = DeploymentLayout.display_label("READY FOR DEPLOYMENT", 24, DeploymentLayout.CITRON)
	_deployment.left.add_child(_kicker)
	_deployment.left.move_child(_kicker, 0)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 17)
	_deployment.left.add_child(_details)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_deployment.right.add_child(_panel)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	_panel.add_child(actions)
	_enter_btn = Button.new()
	_enter_btn.text = "ENTER MISSION"
	_enter_btn.pressed.connect(func(): intent_requested.emit(&"enter_game", {"request_id": _request_id}))
	actions.add_child(_enter_btn)
	_return_btn = Button.new()
	_return_btn.text = "RETURN TO MENU"
	_return_btn.pressed.connect(func(): intent_requested.emit(&"return_to_menu", {}))
	actions.add_child(_return_btn)

func _apply_mode(after_hours: bool) -> void:
	_deployment.set_cyber(not after_hours, true)
	var art := "res://assets/loading/zombie/campus_courtyard.webp" if after_hours \
		else "res://assets/launcher/campus-dusk-reference.png"
	_campus_art.texture = LauncherTheme.load_texture_safe(art)
	_enter_btn.custom_minimum_size.y = 64 if after_hours else 59
	_return_btn.custom_minimum_size.y = 39
	_details.add_theme_font_size_override("font_size", 17 if after_hours else 20)
	if after_hours:
		_details.remove_theme_font_override("font")
		_kicker.add_theme_font_override("font", DeploymentLayout.DISPLAY_FONT)
		_kicker.add_theme_color_override("font_color", DeploymentLayout.CITRON)
		DeploymentLayout.style_action(_enter_btn, true, 36)
		DeploymentLayout.style_action(_return_btn, false, 21)
	else:
		var font := DeploymentLayout.cyber_display_font()
		var spaced := FontVariation.new()
		spaced.base_font = _details.get_theme_default_font()
		spaced.spacing_glyph = 4
		_details.add_theme_font_override("font", spaced)
		_kicker.add_theme_font_override("font", font)
		_kicker.add_theme_color_override("font_color", DeploymentLayout.TEAL)
		_style_cyber_action(_enter_btn, font, true)
		_style_cyber_action(_return_btn, font, false)

func _style_cyber_action(button: Button, font: Font, primary: bool) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 30 if primary else 18)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.skew.x = 0.36
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
			style.border_color = Color("d3fffa") if primary else DeploymentLayout.TEAL
		elif primary:
			style.bg_color = DeploymentLayout.TEAL if state == "normal" else Color("8bf7eb")
		else:
			style.bg_color = Color.TRANSPARENT if state == "normal" else Color("143943cf")
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color("0b222b") if primary else Color("f0f5f7"))

func update_from_model(model: Dictionary) -> void:
	_request_id = str(model.get("loading", {}).get("request_id", ""))
	var mission: Dictionary = model.get("mission", {})
	var mode := str(model.get("selected_mode_id", ""))
	if mode.is_empty():
		mode = str(mission.get("mode_id", ""))
	var code := str(mission.get("id", ""))
	var after_hours := mode == "zombie_rpg" or code == "ZB-2026-001"
	var theme_mode := "after_hours" if after_hours else "cyber"
	if theme_mode != _mode:
		_mode = theme_mode
		_apply_mode(after_hours)
	if code.is_empty():
		code = "ZB-2026-001" if after_hours else "IR-2026-001"
	_deployment.mission_code.text = code
	var title := str(mission.get("title", ""))
	_details.text = "After Hours  ·  %s" % code if after_hours \
		else ("THE BORROWED SESSION" if title.is_empty() else title.to_upper())

func focus_primary() -> void:
	_enter_btn.grab_focus()
