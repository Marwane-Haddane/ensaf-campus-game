## launcher_theme.gd — ENSA Games launcher theme factory
## Shared launcher styling based on the After Hours HUD.
## This file is owned by Antigravity and must not depend on Codex scripts.
class_name LauncherTheme

# ── Palette ──────────────────────────────────────────────────────────────────
const COL_BG_DEEP      := Color("10091e")
const COL_BG_PANEL     := Color("190d32f5")
const COL_BG_CARD      := Color("20113aee")
const COL_BG_HOVER     := Color("352053")
const COL_BG_SELECTED  := Color("281847")
const COL_BG_INPUT     := Color("120a23")
const COL_BORDER       := Color("513876")
const COL_VIOLET       := Color("8a5eff")
const COL_BORDER_FOCUS := Color("e7ff35")
const COL_ACCENT       := Color("e7ff35")
const COL_ACCENT_DIM   := Color("bc9aff")
const COL_ACCENT_HOVER := Color("f1ff75")
const COL_TEXT_PRIMARY  := Color("fff9f3")
const COL_TEXT_SECONDARY:= Color("d4ccdf")
const COL_TEXT_DISABLED := Color("9d93af")
const COL_TEXT_ACCENT   := COL_ACCENT
const DISPLAY_FONT := preload("res://assets/antigravity/zombie/hud/BarlowCondensed-ExtraBoldItalic.ttf")
const COL_ERROR        := Color(0.90, 0.35, 0.30, 1.0)      # Error red
const COL_WARNING      := Color(0.95, 0.75, 0.25, 1.0)      # Warning amber
const COL_SUCCESS      := Color(0.30, 0.80, 0.45, 1.0)      # Success green
const COL_COMING_SOON  := Color(0.95, 0.65, 0.15, 1.0)      # Coming soon badge
const COL_OVERLAY      := Color(0.0, 0.0, 0.0, 0.55)        # Dim overlay

# ── Typography sizes (base 720p, stretch scales) ────────────────────────────
const FONT_TITLE       := 50
const FONT_HEADING     := 32
const FONT_NAV         := 18
const FONT_BODY        := 16
const FONT_SMALL       := 13
const FONT_BADGE       := 12

# ── Layout ───────────────────────────────────────────────────────────────────
const MARGIN_SAFE      := 48
const CORNER_RADIUS    := 0
const CORNER_RADIUS_LG := 0
const BORDER_WIDTH     := 1
const FOCUS_BORDER_W   := 2

# ── Factory ──────────────────────────────────────────────────────────────────

static func create_theme() -> Theme:
	var theme := Theme.new()
	_setup_colors(theme)
	_setup_buttons(theme)
	_setup_panels(theme)
	_setup_labels(theme)
	_setup_tabs(theme)
	_setup_sliders(theme)
	_setup_option_button(theme)
	_setup_checkboxes(theme)
	_setup_scroll(theme)
	_setup_line_edit(theme)
	return theme

static func _make_flat_box(bg: Color, corner: int = CORNER_RADIUS,
		border_color: Color = Color.TRANSPARENT, border_w: int = 0,
		content_margin: float = -1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	if border_w > 0:
		sb.border_color = border_color
		sb.border_width_left = border_w
		sb.border_width_right = border_w
		sb.border_width_top = border_w
		sb.border_width_bottom = border_w
	if content_margin >= 0.0:
		sb.content_margin_left = content_margin
		sb.content_margin_right = content_margin
		sb.content_margin_top = content_margin
		sb.content_margin_bottom = content_margin
	sb.anti_aliasing = true
	return sb


static func make_accent_button_style(state: String) -> StyleBoxFlat:
	var style := _make_flat_box(COL_ACCENT, 0, Color.TRANSPARENT, 0, 14.0)
	match state:
		"hover":
			style.bg_color = COL_ACCENT_HOVER
		"pressed":
			style.bg_color = COL_ACCENT.darkened(0.16)
		"focus":
			style = _make_flat_box(Color.TRANSPARENT, 0, COL_TEXT_PRIMARY, FOCUS_BORDER_W, 14.0)
		"disabled":
			style = _make_flat_box(COL_BG_CARD, 0, COL_BORDER, 1, 14.0)
	style.skew.x = 0.19
	return style

static func make_ghost_button_style(state: String) -> StyleBoxFlat:
	var style := _make_flat_box(COL_BG_PANEL, 0, Color.TRANSPARENT, 0, 10.0)
	match state:
		"hover":
			style.bg_color = COL_BG_HOVER
		"pressed":
			style.bg_color = COL_BG_SELECTED
		"focus":
			style = _make_flat_box(Color.TRANSPARENT, 0, COL_BORDER_FOCUS, FOCUS_BORDER_W, 10.0)
		"disabled":
			style.bg_color = Color.TRANSPARENT
	style.skew.x = 0.14
	return style

static func make_card_style(state: String = "normal", is_accent: bool = false) -> StyleBoxFlat:
	var border := COL_VIOLET if is_accent else COL_BORDER
	var border_w := BORDER_WIDTH
	var bg := COL_BG_CARD
	match state:
		"hover":
			bg = COL_BG_HOVER
			border = COL_ACCENT if is_accent else COL_BORDER_FOCUS
			border_w = FOCUS_BORDER_W
		"focus":
			border = COL_BORDER_FOCUS
			border_w = FOCUS_BORDER_W
			bg = Color.TRANSPARENT
		"selected":
			bg = COL_BG_SELECTED
			border = COL_ACCENT
			border_w = FOCUS_BORDER_W
		"disabled":
			bg = COL_BG_DEEP
			border = COL_BORDER.darkened(0.3)
	var style := _make_flat_box(bg, 0, border, border_w, 18.0)
	style.skew.x = 0.04
	if is_accent and state == "normal":
		style.border_width_left = 5
	return style

static func display(label: Label, font_size: int) -> void:
	label.add_theme_font_override("font", DISPLAY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.uppercase = true

static func style_primary(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, make_accent_button_style(state))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, COL_BG_DEEP)

static func make_badge_style(color: Color) -> StyleBoxFlat:
	var sb := _make_flat_box(COL_BG_INPUT, 0, color, 1, 4.0)
	sb.skew.x = 0.17
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	return sb


# ── Theme sections ───────────────────────────────────────────────────────────

static func _setup_colors(theme: Theme) -> void:
	theme.set_color("font_color", "Label", COL_TEXT_PRIMARY)
	theme.set_color("font_color", "RichTextLabel", COL_TEXT_PRIMARY)

static func _setup_buttons(theme: Theme) -> void:
	# Default Button — ghost style
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "Button", make_ghost_button_style(state))
	theme.set_color("font_color", "Button", COL_TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", COL_ACCENT_HOVER)
	theme.set_color("font_pressed_color", "Button", COL_ACCENT)
	theme.set_color("font_focus_color", "Button", COL_TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "Button", COL_TEXT_DISABLED)
	theme.set_font("font", "Button", DISPLAY_FONT)
	theme.set_font_size("font_size", "Button", FONT_NAV)

static func _setup_panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer",
		_make_flat_box(COL_BG_PANEL, CORNER_RADIUS_LG, COL_BORDER, BORDER_WIDTH))
	theme.set_stylebox("panel", "Panel",
		_make_flat_box(COL_BG_DEEP, 0))

static func _setup_labels(theme: Theme) -> void:
	theme.set_font_size("font_size", "Label", FONT_BODY)
	theme.set_color("font_color", "Label", COL_TEXT_PRIMARY)

static func _setup_tabs(theme: Theme) -> void:
	theme.set_stylebox("tab_selected", "TabBar", make_accent_button_style("normal"))
	theme.set_stylebox("tab_unselected", "TabBar", make_ghost_button_style("normal"))
	theme.set_stylebox("tab_hovered", "TabBar", make_ghost_button_style("hover"))
	theme.set_stylebox("tab_focus", "TabBar", make_ghost_button_style("focus"))
	theme.set_color("font_selected_color", "TabBar", COL_BG_DEEP)
	theme.set_color("font_unselected_color", "TabBar", COL_TEXT_SECONDARY)
	theme.set_color("font_hovered_color", "TabBar", COL_TEXT_PRIMARY)
	theme.set_font("font", "TabBar", DISPLAY_FONT)
	theme.set_font_size("font_size", "TabBar", FONT_NAV)

static func _setup_sliders(theme: Theme) -> void:
	theme.set_stylebox("slider", "HSlider",
		_make_flat_box(COL_BG_INPUT, 3))
	theme.set_stylebox("grabber_area", "HSlider",
		_make_flat_box(COL_ACCENT_DIM, 3))
	theme.set_stylebox("grabber_area_highlight", "HSlider",
		_make_flat_box(COL_ACCENT, 3))

static func _setup_option_button(theme: Theme) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "OptionButton", make_ghost_button_style(state))
	theme.set_color("font_color", "OptionButton", COL_TEXT_PRIMARY)
	theme.set_color("font_hover_color", "OptionButton", COL_ACCENT_HOVER)
	theme.set_color("font_focus_color", "OptionButton", COL_TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "OptionButton", COL_TEXT_DISABLED)
	# PopupMenu
	theme.set_stylebox("panel", "PopupMenu",
		_make_flat_box(COL_BG_PANEL, CORNER_RADIUS, COL_BORDER, BORDER_WIDTH, 4.0))
	theme.set_stylebox("hover", "PopupMenu",
		_make_flat_box(COL_BG_HOVER, CORNER_RADIUS))
	theme.set_color("font_color", "PopupMenu", COL_TEXT_PRIMARY)
	theme.set_color("font_hover_color", "PopupMenu", COL_TEXT_PRIMARY)

static func _setup_scroll(theme: Theme) -> void:
	theme.set_stylebox("scroll", "VScrollBar",
		_make_flat_box(Color.TRANSPARENT, 3))
	theme.set_stylebox("grabber", "VScrollBar",
		_make_flat_box(COL_BORDER, 3))
	theme.set_stylebox("grabber_highlight", "VScrollBar",
		_make_flat_box(COL_ACCENT_DIM, 3))
	theme.set_stylebox("grabber_pressed", "VScrollBar",
		_make_flat_box(COL_ACCENT, 3))

static func _setup_checkboxes(theme: Theme) -> void:
	for checked in [false, true]:
		var fill := COL_ACCENT.to_html(false) if checked else COL_BG_INPUT.to_html(false)
		var stroke := COL_ACCENT.to_html(false) if checked else COL_TEXT_SECONDARY.to_html(false)
		var mark := '<path d="M5 9l3 3 5-6" fill="none" stroke="#10091e" stroke-width="2"/>' if checked else ""
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"><rect x="1" y="1" width="16" height="16" rx="1" fill="#%s" stroke="#%s" stroke-width="2"/>%s</svg>' % [fill, stroke, mark]
		var image := Image.new()
		if image.load_svg_from_string(svg) == OK:
			theme.set_icon("checked" if checked else "unchecked", "CheckBox", ImageTexture.create_from_image(image))

static func _setup_line_edit(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit",
		_make_flat_box(COL_BG_INPUT, CORNER_RADIUS, COL_BORDER, BORDER_WIDTH, 8.0))
	theme.set_stylebox("focus", "LineEdit",
		_make_flat_box(COL_BG_INPUT, CORNER_RADIUS, COL_BORDER_FOCUS, FOCUS_BORDER_W, 8.0))
	theme.set_color("font_color", "LineEdit", COL_TEXT_PRIMARY)
	theme.set_color("caret_color", "LineEdit", COL_ACCENT)

# ── Safe Texture Loader ───────────────────────────────────────────────────────
static func load_texture_safe(res_path: String) -> Texture2D:
	if res_path.is_empty():
		return null
	if ResourceLoader.exists(res_path):
		var res = load(res_path)
		if res is Texture2D:
			return res
	var global_path := ProjectSettings.globalize_path(res_path)
	var check_path := global_path if FileAccess.file_exists(global_path) else (res_path if FileAccess.file_exists(res_path) else "")
	if check_path != "":
		var img := Image.new()
		var err := img.load(check_path)
		if err == OK:
			var tex := ImageTexture.create_from_image(img)
			tex.resource_path = res_path
			return tex
	return null

