extends Control
## Shared composition for the After Hours loading and deployment screens.

const DISPLAY_FONT := preload("res://assets/antigravity/zombie/hud/BarlowCondensed-ExtraBoldItalic.ttf")
const INK := Color("190d39")
const VIOLET := Color("785bff")
const CITRON := Color("e7ff35")
const WHITE := Color("fff9f3")

var left: VBoxContainer
var right: VBoxContainer
var mission_code: Label
var _title: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shade := TextureRect.new()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.52, 0.74, 1.0])
	gradient.colors = PackedColorArray([
		Color("0f082b8c"), Color("0f082b20"), Color("0f082b05"),
		Color("0f082b77"), Color("0f082bf5")
	])
	var texture := GradientTexture2D.new()
	texture.width = 1
	texture.height = 256
	texture.fill_to = Vector2(0, 1)
	texture.gradient = gradient
	shade.texture = texture
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var brand := display_label("ENSA GAMES", 26)
	add_child(brand)
	brand.position = Vector2(63, 24)
	_add_slash(brand, Rect2(-20, 6, 13, 24))

	mission_code = display_label("ZB-2026-001", 21, CITRON)
	mission_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(mission_code)
	mission_code.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mission_code.offset_left = -260
	mission_code.offset_right = -42
	mission_code.offset_top = 25

	left = _footer_column(0.0, 0.56, 65, -22)
	right = _footer_column(0.61, 1.0, 0, -48)
	_title = display_label("AFTER HOURS", 102)
	left.add_child(_title)
	_add_slash(_title, Rect2(-24, 24, 17, 69))
	resized.connect(_fit_title)
	_fit_title()

func _footer_column(start: float, end: float, inset_left: float, inset_right: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	column.anchor_left = start
	column.anchor_right = end
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = inset_left
	column.offset_right = inset_right
	column.offset_bottom = -47
	column.offset_top = -47
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return column

func _fit_title() -> void:
	_title.add_theme_font_size_override("font_size", clampi(roundi(size.x * 0.08), 55, 108))

func _add_slash(label: Label, rect: Rect2) -> void:
	var slash := Polygon2D.new()
	slash.color = VIOLET
	slash.polygon = PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.65, 0),
		Vector2(rect.end.x, rect.position.y),
		rect.end - Vector2(rect.size.x * 0.65, 0),
		Vector2(rect.position.x, rect.end.y)
	])
	label.add_child(slash)

static func display_label(text: String, pixels: int, tint: Color = WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", DISPLAY_FONT)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", tint)
	return label

static func style_action(button: Button, primary: bool, pixels: int) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", pixels)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		if primary:
			style.bg_color = CITRON if state == "normal" else Color("f4ff95")
		else:
			style.bg_color = Color("190d398f") if state == "normal" else Color("4e32bb")
		style.skew.x = 0.24
		style.content_margin_left = 16
		style.content_margin_right = 16
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = VIOLET if primary else CITRON
	focus.skew.x = 0.24
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	for key in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, INK if primary else WHITE)
