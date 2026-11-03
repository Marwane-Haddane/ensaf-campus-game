## launcher_theme.gd — ENSA Games launcher theme factory
## Builds a Theme resource with the dark navy/graphite palette, cyan-teal accent,
## and consistent typography hierarchy for the launcher presentation.
## This file is owned by Antigravity and must not depend on Codex scripts.
class_name LauncherTheme

# ── Palette ──────────────────────────────────────────────────────────────────
const COL_BG_DEEP      := Color(0.08, 0.10, 0.14, 1.0)      # Deep navy
const COL_BG_PANEL     := Color(0.10, 0.13, 0.18, 0.92)     # Panel overlay
const COL_BG_CARD      := Color(0.12, 0.15, 0.21, 0.88)     # Card surface
const COL_BG_HOVER     := Color(0.14, 0.18, 0.25, 0.95)     # Hover surface
const COL_BG_SELECTED  := Color(0.10, 0.20, 0.28, 0.95)     # Selected surface
const COL_BG_INPUT     := Color(0.07, 0.09, 0.13, 0.95)     # Input fields
const COL_BORDER       := Color(0.20, 0.25, 0.32, 0.6)      # Subtle border
const COL_BORDER_FOCUS := Color(0.30, 0.85, 0.78, 0.8)      # Focus border (teal)
const COL_ACCENT       := Color(0.30, 0.85, 0.78, 1.0)      # Cyan-teal accent
const COL_ACCENT_DIM   := Color(0.20, 0.55, 0.52, 1.0)      # Dimmed accent
const COL_ACCENT_HOVER := Color(0.35, 0.92, 0.85, 1.0)      # Accent hover
const COL_TEXT_PRIMARY  := Color(0.92, 0.94, 0.96, 1.0)     # Off-white
const COL_TEXT_SECONDARY:= Color(0.55, 0.60, 0.68, 1.0)     # Steel gray
const COL_TEXT_DISABLED := Color(0.38, 0.42, 0.48, 1.0)     # Disabled
const COL_TEXT_ACCENT   := Color(0.30, 0.85, 0.78, 1.0)     # Accent text
const COL_ERROR        := Color(0.90, 0.35, 0.30, 1.0)      # Error red
const COL_WARNING      := Color(0.95, 0.75, 0.25, 1.0)      # Warning amber
const COL_SUCCESS      := Color(0.30, 0.80, 0.45, 1.0)      # Success green
const COL_COMING_SOON  := Color(0.95, 0.65, 0.15, 1.0)      # Coming soon badge
const COL_OVERLAY      := Color(0.0, 0.0, 0.0, 0.55)        # Dim overlay

# ── Typography sizes (base 720p, stretch scales) ────────────────────────────
const FONT_TITLE       := 36
const FONT_HEADING     := 24
const FONT_NAV         := 18
const FONT_BODY        := 16
const FONT_SMALL       := 13
const FONT_BADGE       := 12

# ── Layout ───────────────────────────────────────────────────────────────────
const MARGIN_SAFE      := 56   # ~48-64 px safe area
const CORNER_RADIUS    := 6
const CORNER_RADIUS_LG := 10
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
	match state:
		"normal":
			return _make_flat_box(COL_ACCENT.darkened(0.15), CORNER_RADIUS, Color.TRANSPARENT, 0, 14.0)
		"hover":
			return _make_flat_box(COL_ACCENT, CORNER_RADIUS, Color.TRANSPARENT, 0, 14.0)
		"pressed":
			return _make_flat_box(COL_ACCENT.darkened(0.3), CORNER_RADIUS, Color.TRANSPARENT, 0, 14.0)
		"focus":
			return _make_flat_box(COL_ACCENT.darkened(0.15), CORNER_RADIUS, COL_TEXT_PRIMARY, FOCUS_BORDER_W, 14.0)
		"disabled":
			return _make_flat_box(COL_BG_CARD, CORNER_RADIUS, COL_BORDER, BORDER_WIDTH, 14.0)
	return _make_flat_box(COL_ACCENT.darkened(0.15), CORNER_RADIUS)

static func make_ghost_button_style(state: String) -> StyleBoxFlat:
	match state:
		"normal":
			return _make_flat_box(Color.TRANSPARENT, CORNER_RADIUS, Color.TRANSPARENT, 0, 10.0)
		"hover":
			return _make_flat_box(COL_BG_HOVER, CORNER_RADIUS, Color.TRANSPARENT, 0, 10.0)
		"pressed":
			return _make_flat_box(COL_BG_SELECTED, CORNER_RADIUS, Color.TRANSPARENT, 0, 10.0)
		"focus":
			return _make_flat_box(Color.TRANSPARENT, CORNER_RADIUS, COL_BORDER_FOCUS, FOCUS_BORDER_W, 10.0)
		"disabled":
			return _make_flat_box(Color.TRANSPARENT, CORNER_RADIUS, Color.TRANSPARENT, 0, 10.0)
	return _make_flat_box(Color.TRANSPARENT, CORNER_RADIUS)

static func make_card_style(state: String = "normal", is_accent: bool = false) -> StyleBoxFlat:
	var border := COL_BORDER
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
		"selected":
			bg = COL_BG_SELECTED
			border = COL_ACCENT
			border_w = FOCUS_BORDER_W
		"disabled":
			bg = COL_BG_DEEP
			border = COL_BORDER.darkened(0.3)
	return _make_flat_box(bg, CORNER_RADIUS_LG, border, border_w, 16.0)

static func make_badge_style(color: Color) -> StyleBoxFlat:
	var sb := _make_flat_box(color.darkened(0.6), 4, color, 1, 4.0)
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
	theme.set_stylebox("tab_selected", "TabBar",
		_make_flat_box(COL_BG_SELECTED, CORNER_RADIUS, COL_ACCENT, BORDER_WIDTH, 10.0))
	theme.set_stylebox("tab_unselected", "TabBar",
		_make_flat_box(Color.TRANSPARENT, CORNER_RADIUS, Color.TRANSPARENT, 0, 10.0))
	theme.set_stylebox("tab_hovered", "TabBar",
		_make_flat_box(COL_BG_HOVER, CORNER_RADIUS, Color.TRANSPARENT, 0, 10.0))
	theme.set_stylebox("tab_focus", "TabBar",
		_make_flat_box(Color.TRANSPARENT, CORNER_RADIUS, COL_BORDER_FOCUS, FOCUS_BORDER_W, 10.0))
	theme.set_color("font_selected_color", "TabBar", COL_ACCENT)
	theme.set_color("font_unselected_color", "TabBar", COL_TEXT_SECONDARY)
	theme.set_color("font_hovered_color", "TabBar", COL_TEXT_PRIMARY)
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

