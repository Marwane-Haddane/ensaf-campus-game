extends Control
## Shared composition for cinematic mission loading and deployment.

const DISPLAY_FONT := preload("res://assets/antigravity/zombie/hud/BarlowCondensed-ExtraBoldItalic.ttf")
const INK := Color("190d39")
const VIOLET := Color("785bff")
const CITRON := Color("e7ff35")
const WHITE := Color("fff9f3")
const TEAL := Color("37e3d4")
const BLUE := Color("42bfff")

var left: VBoxContainer
var right: VBoxContainer
var mission_code: Label
var _title: Label
var _brand: Label
var _brand_slash: Polygon2D
var _title_slash: Polygon2D
var _shade: Gradient
var _cyber := false
var _cyber_ready := false
var _cyber_loading := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shade := TextureRect.new()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade = Gradient.new()
	_shade.offsets = PackedFloat32Array([0.0, 0.22, 0.52, 0.74, 1.0])
	var texture := GradientTexture2D.new()
	texture.width = 1
	texture.height = 256
	texture.fill_to = Vector2(0, 1)
	texture.gradient = _shade
	shade.texture = texture
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_brand = display_label("ENSA GAMES", 26)
	add_child(_brand)
	_brand.position = Vector2(63, 24)
	_brand_slash = _add_slash(_brand)

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
	_title_slash = _add_slash(_title)
	resized.connect(_fit_title)
	set_cyber(false)

func set_cyber(enabled: bool, mission_ready: bool = false, loading_design: bool = false) -> void:
	_cyber = enabled
	_cyber_ready = enabled and mission_ready
	_cyber_loading = enabled and loading_design
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _cyber_loading else TextServer.AUTOWRAP_OFF
	_title.text = "INCIDENT RESPONSE" if _cyber else "AFTER HOURS"
	var accent := BLUE if _cyber_loading else (TEAL if _cyber else VIOLET)
	_brand_slash.color = accent
	_title_slash.color = accent
	_brand_slash.polygon = _slash_points(Rect2(-20, 6, 13, 24))
	left.anchor_right = 0.60 if _cyber_loading else (0.67 if _cyber else 0.56)
	left.offset_right = -22
	right.anchor_left = 0.64 if _cyber_loading else (0.70 if _cyber else 0.61)
	right.offset_left = 0
	for label in [_title, _brand, mission_code]:
		if _cyber and not _cyber_loading:
			label.remove_theme_font_override("font")
		else:
			label.add_theme_font_override("font", DISPLAY_FONT)
	if _cyber_ready:
		_title.add_theme_font_override("font", cyber_display_font())
	mission_code.add_theme_font_size_override("font_size", 17 if _cyber else 21)
	mission_code.add_theme_color_override("font_color", Color("e2e9ee") if _cyber else CITRON)
	_shade.colors = PackedColorArray([
		Color("06131dda"), Color("06131d18"), Color("06131d08"),
		Color("06131d88"), Color("06131dfc")
	] if _cyber else [
		Color("0f082b8c"), Color("0f082b20"), Color("0f082b05"),
		Color("0f082b77"), Color("0f082bf5")
	])
	_fit_title()

func set_loading_title(title: String) -> void:
	if not _cyber_loading:
		return
	_title.text = title
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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
	var pixels := clampi(roundi(size.x * 0.037), 28, 56) if _cyber else clampi(roundi(size.x * 0.08), 55, 108)
	if _cyber_ready:
		pixels = clampi(roundi(size.x * 0.046), 30, 74)
	if _cyber_loading:
		pixels = clampi(roundi(size.x * 0.055), 46, 88)
	_title.add_theme_font_size_override("font_size", pixels)
	_title_slash.polygon = PackedVector2Array() if _cyber_loading else _slash_points(
		Rect2(-25, 9, 16, pixels * 0.77) if _cyber else Rect2(-24, 24, 17, 69))

func _add_slash(label: Label) -> Polygon2D:
	var slash := Polygon2D.new()
	label.add_child(slash)
	return slash

func _slash_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.65, 0),
		Vector2(rect.end.x, rect.position.y),
		rect.end - Vector2(rect.size.x * 0.65, 0),
		Vector2(rect.position.x, rect.end.y)
	])

static func display_label(text: String, pixels: int, tint: Color = WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", DISPLAY_FONT)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", tint)
	return label

static func cyber_display_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial", "sans-serif"])
	font.font_weight = 800
	font.font_italic = true
	return font

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
