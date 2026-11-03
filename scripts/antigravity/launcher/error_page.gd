## error_page.gd — Error recovery page
## Displays human-readable error messages, expandable diagnostic logs for dev builds,
## and controller-authorized recovery buttons (Retry, Return to Menu, Quit).
class_name LauncherErrorPage
extends Control

const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")

signal intent_requested(action: StringName, payload: Dictionary)

var _code_label: Label
var _message_label: Label
var _diagnostic_box: TextEdit
var _diagnostic_container: VBoxContainer
var _toggle_diag_btn: Button

var _retry_btn: Button
var _return_btn: Button
var _quit_btn: Button

var _request_id: String = ""
var _center: CenterContainer

func get_page_id() -> String:
	return "error"

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

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 380)
	panel.add_theme_stylebox_override("panel", LauncherTheme.make_card_style("normal"))
	_center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	# Error badge
	var badge := Label.new()
	badge.text = "OPERATION FAILED"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", LauncherTheme.FONT_BADGE)
	badge.add_theme_color_override("font_color", LauncherTheme.COL_ERROR)
	badge.add_theme_stylebox_override("normal", LauncherTheme.make_badge_style(LauncherTheme.COL_ERROR))
	vbox.add_child(badge)

	# Code label
	_code_label = Label.new()
	_code_label.text = "ERR_LOAD_FAILED"
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.add_theme_font_size_override("font_size", LauncherTheme.FONT_HEADING)
	_code_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_PRIMARY)
	vbox.add_child(_code_label)

	# Human-readable message
	_message_label = Label.new()
	_message_label.text = "The system encountered an error while preparing the campus environment."
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", LauncherTheme.FONT_BODY)
	_message_label.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	vbox.add_child(_message_label)

	# Expandable Diagnostic (Development build only)
	_diagnostic_container = VBoxContainer.new()
	_diagnostic_container.add_theme_constant_override("separation", 6)
	_diagnostic_container.visible = false
	vbox.add_child(_diagnostic_container)

	_toggle_diag_btn = Button.new()
	_toggle_diag_btn.text = "Show Technical Diagnostic ▼"
	_toggle_diag_btn.focus_mode = Control.FOCUS_ALL
	_toggle_diag_btn.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
	_toggle_diag_btn.pressed.connect(_on_toggle_diagnostic)
	_diagnostic_container.add_child(_toggle_diag_btn)

	_diagnostic_box = TextEdit.new()
	_diagnostic_box.custom_minimum_size = Vector2(0, 100)
	_diagnostic_box.editable = false
	_diagnostic_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_diagnostic_box.add_theme_font_size_override("font_size", LauncherTheme.FONT_SMALL)
	_diagnostic_box.visible = false
	_diagnostic_container.add_child(_diagnostic_box)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	_retry_btn = Button.new()
	_retry_btn.text = "Retry"
	_retry_btn.custom_minimum_size = Vector2(130, 42)
	_retry_btn.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_retry_btn.add_theme_stylebox_override(state, LauncherTheme.make_accent_button_style(state))
	_retry_btn.add_theme_color_override("font_color", Color(0.05, 0.08, 0.12, 1.0))
	_retry_btn.add_theme_color_override("font_hover_color", Color(0.02, 0.05, 0.08, 1.0))
	_retry_btn.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.0, 1.0))
	_retry_btn.add_theme_color_override("font_focus_color", Color(0.05, 0.08, 0.12, 1.0))
	_retry_btn.pressed.connect(_on_retry_pressed)
	btn_row.add_child(_retry_btn)

	_return_btn = Button.new()
	_return_btn.text = "Return to Menu"
	_return_btn.custom_minimum_size = Vector2(150, 42)
	_return_btn.focus_mode = Control.FOCUS_ALL
	_return_btn.pressed.connect(func(): intent_requested.emit(&"return_to_menu", {}))
	btn_row.add_child(_return_btn)

	_quit_btn = Button.new()
	_quit_btn.text = "Quit"
	_quit_btn.custom_minimum_size = Vector2(100, 42)
	_quit_btn.focus_mode = Control.FOCUS_ALL
	_quit_btn.pressed.connect(func(): intent_requested.emit(&"quit", {}))
	btn_row.add_child(_quit_btn)

func _on_toggle_diagnostic() -> void:
	_diagnostic_box.visible = not _diagnostic_box.visible
	_toggle_diag_btn.text = "Hide Technical Diagnostic ▲" if _diagnostic_box.visible else "Show Technical Diagnostic ▼"

func _on_retry_pressed() -> void:
	intent_requested.emit(&"retry_loading", {"request_id": _request_id})

func update_from_model(model: Dictionary) -> void:
	var err: Dictionary = model.get("error", {})
	var loading: Dictionary = model.get("loading", {})
	_request_id = loading.get("request_id", "")

	_code_label.text = err.get("code", "ERROR")
	_message_label.text = err.get("message", "An unexpected error occurred.")

	# Diagnostics (dev builds only)
	var is_dev: bool = model.get("development_build", false)
	var diag_text: String = err.get("diagnostic", "")
	if is_dev and diag_text != "":
		_diagnostic_container.visible = true
		_diagnostic_box.text = diag_text
	else:
		_diagnostic_container.visible = false

	# Allowed actions
	_retry_btn.visible = err.get("retry_allowed", true)
	_return_btn.visible = err.get("return_allowed", true)

func focus_primary() -> void:
	if _retry_btn.visible and is_instance_valid(_retry_btn):
		_retry_btn.grab_focus()
	elif _return_btn.visible and is_instance_valid(_return_btn):
		_return_btn.grab_focus()
	elif is_instance_valid(_quit_btn):
		_quit_btn.grab_focus()
