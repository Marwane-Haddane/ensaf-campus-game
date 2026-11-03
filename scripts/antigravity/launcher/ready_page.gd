## ready_page.gd — Mission ready page
## Displayed when world, collision, props, and player are fully initialized.
## Presents Enter Mission button emitting enter_game with active request_id.
class_name LauncherReadyPage
extends Control

const DeploymentLayout = preload("res://scripts/antigravity/launcher/deployment_layout.gd")
const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")

signal intent_requested(action: StringName, payload: Dictionary)

var _title_label: Label
var _mission_label: Label
var _enter_btn: Button
var _return_btn: Button
var _request_id: String = ""
var _center: CenterContainer
var _panel: PanelContainer
var _deployment: Control
var _campus_art: TextureRect
var _deployment_enter: Button
var _deployment_details: Label

func get_page_id() -> String:
	return "ready"

func get_panel() -> PanelContainer:
	return _panel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_build_ui()
	_build_deployment()

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

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 320)
	_panel.add_theme_stylebox_override("panel", LauncherTheme.make_card_style("selected", true))
	_center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(vbox)

	var badge := Label.new()
	badge.text = "CAMPUS ENVIRONMENT PREPARED"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", LauncherTheme.FONT_BADGE)
	badge.add_theme_color_override("font_color", LauncherTheme.COL_SUCCESS)
	badge.add_theme_stylebox_override("normal", LauncherTheme.make_badge_style(LauncherTheme.COL_SUCCESS))
	vbox.add_child(badge)

	_title_label = Label.new()
	_title_label.text = "READY FOR DEPLOYMENT"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", LauncherTheme.FONT_TITLE)
	_title_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	vbox.add_child(_title_label)

	_mission_label = Label.new()
	_mission_label.text = "ENSA Incident Response • IR-2026-001"
	_mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission_label.add_theme_font_size_override("font_size", LauncherTheme.FONT_BODY)
	_mission_label.add_theme_color_override("font_color", LauncherTheme.COL_ACCENT)
	vbox.add_child(_mission_label)

	var hint := Label.new()
	hint.text = "All world collision, stations, and simulation systems are verified."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
	hint.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	vbox.add_child(hint)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	_enter_btn = Button.new()
	_enter_btn.text = "Enter Mission"
	_enter_btn.custom_minimum_size = Vector2(200, 48)
	_enter_btn.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_enter_btn.add_theme_stylebox_override(state, LauncherTheme.make_accent_button_style(state))
	_enter_btn.add_theme_color_override("font_color", Color(0.05, 0.08, 0.12, 1.0))
	_enter_btn.add_theme_color_override("font_hover_color", Color(0.02, 0.05, 0.08, 1.0))
	_enter_btn.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.0, 1.0))
	_enter_btn.add_theme_color_override("font_focus_color", Color(0.05, 0.08, 0.12, 1.0))
	_enter_btn.pressed.connect(_on_enter_pressed)
	btn_row.add_child(_enter_btn)

	_return_btn = Button.new()
	_return_btn.text = "Return to Menu"
	_return_btn.custom_minimum_size = Vector2(160, 48)
	_return_btn.focus_mode = Control.FOCUS_ALL
	_return_btn.pressed.connect(func(): intent_requested.emit(&"return_to_menu", {}))
	btn_row.add_child(_return_btn)

func _build_deployment() -> void:
	_campus_art = TextureRect.new()
	_campus_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_campus_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_campus_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_campus_art)
	_campus_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_deployment = DeploymentLayout.new()
	add_child(_deployment)
	var kicker := DeploymentLayout.display_label("READY FOR DEPLOYMENT", 24, DeploymentLayout.CITRON)
	_deployment.left.add_child(kicker)
	_deployment.left.move_child(kicker, 0)
	_deployment_details = Label.new()
	_deployment_details.add_theme_font_size_override("font_size", 17)
	_deployment.left.add_child(_deployment_details)

	_deployment_enter = Button.new()
	_deployment_enter.text = "ENTER MISSION"
	_deployment_enter.custom_minimum_size.y = 64
	DeploymentLayout.style_action(_deployment_enter, true, 36)
	_deployment_enter.pressed.connect(_on_enter_pressed)
	_deployment.right.add_child(_deployment_enter)

	var back := Button.new()
	back.text = "RETURN TO MENU"
	back.custom_minimum_size.y = 39
	DeploymentLayout.style_action(back, false, 21)
	back.pressed.connect(func(): intent_requested.emit(&"return_to_menu", {}))
	_deployment.right.add_child(back)

	_deployment.hide()
	_campus_art.hide()

func _on_enter_pressed() -> void:
	intent_requested.emit(&"enter_game", {"request_id": _request_id})

func update_from_model(model: Dictionary) -> void:
	var loading_data = model.get("loading", {})
	_request_id = loading_data.get("request_id", "")
	var mission_data = model.get("mission", {})
	var title = mission_data.get("title", "")
	var code = mission_data.get("id", "")
	if title != "":
		_mission_label.text = "%s • %s" % [title, code]
	var mode: String = model.get("selected_mode_id", "")
	if mode.is_empty():
		mode = mission_data.get("mode_id", "")
	var after_hours: bool = mode == "zombie_rpg" or code == "ZB-2026-001"
	if after_hours and _campus_art.texture == null:
		_campus_art.texture = LauncherTheme.load_texture_safe("res://assets/loading/zombie/campus_courtyard.webp")
	_center.visible = not after_hours
	_campus_art.visible = after_hours
	_deployment.visible = after_hours
	_deployment.mission_code.text = code if code != "" else "ZB-2026-001"
	_deployment_details.text = "After Hours  ·  %s" % _deployment.mission_code.text

func focus_primary() -> void:
	if _deployment.visible:
		_deployment_enter.grab_focus()
	elif is_instance_valid(_enter_btn):
		_enter_btn.grab_focus()
