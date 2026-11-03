## launcher_view.gd — ENSA Games launcher presentation root
## Implements the shared presentation contract v1.
## Owned by Antigravity; emits intents for Codex's controller to handle.
extends Control

const LauncherTheme = preload("res://scripts/antigravity/launcher/launcher_theme.gd")
const LauncherBootPage = preload("res://scripts/antigravity/launcher/boot_page.gd")
const LauncherHomePage = preload("res://scripts/antigravity/launcher/home_page.gd")
const LauncherModesPage = preload("res://scripts/antigravity/launcher/modes_page.gd")
const LauncherBriefingPage = preload("res://scripts/antigravity/launcher/briefing_page.gd")
const LauncherLoadingPage = preload("res://scripts/antigravity/launcher/loading_page.gd")
const LauncherReadyPage = preload("res://scripts/antigravity/launcher/ready_page.gd")
const LauncherSettingsPage = preload("res://scripts/antigravity/launcher/settings_page.gd")
const LauncherHowToPlayPage = preload("res://scripts/antigravity/launcher/how_to_play_page.gd")
const LauncherCreditsPage = preload("res://scripts/antigravity/launcher/credits_page.gd")
const LauncherErrorPage = preload("res://scripts/antigravity/launcher/error_page.gd")

signal intent_requested(action: StringName, payload: Dictionary)


# ── Cached state ─────────────────────────────────────────────────────────────
var _current_model: Dictionary = {}
var _current_page: String = ""
var _reduced_motion: bool = false
var _theme_resource: Theme
var _pages: Dictionary = {}   # page_name -> Control node
var _active_tween: Tween = null
var _transition_duration: float = 0.3

# ── Node refs ────────────────────────────────────────────────────────────────
@onready var _bg_layer: Control = %BackgroundLayer
@onready var _page_container: Control = %PageContainer
@onready var _overlay_container: Control = %OverlayContainer
@onready var _version_label: Label = %VersionLabel

func _ensure_nodes() -> void:
	if _bg_layer == null:
		_bg_layer = get_node_or_null("%BackgroundLayer")
	if _page_container == null:
		_page_container = get_node_or_null("%PageContainer")
	if _overlay_container == null:
		_overlay_container = get_node_or_null("%OverlayContainer")
	if _version_label == null:
		_version_label = get_node_or_null("%VersionLabel")

func _ensure_initialized() -> void:
	_ensure_nodes()
	if _theme_resource == null:
		_theme_resource = LauncherTheme.create_theme()
		theme = _theme_resource
	if _bg_layer and _bg_layer.get_child_count() == 0:
		_setup_background()
	if _pages.is_empty():
		_register_pages()

func _ready() -> void:
	_ensure_initialized()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hide_all_pages()
	# Start with boot page visible as minimal first frame
	if _pages.has("boot"):
		_pages["boot"].visible = true
		_pages["boot"].modulate.a = 1.0
		_pages["boot"].mouse_filter = Control.MOUSE_FILTER_STOP
		_pages["boot"].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_current_page = "boot"

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if is_instance_valid(_page_container):
			_page_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for child in _page_container.get_children():
				if child is Control:
					child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
					for sub in child.get_children():
						if sub is Control and (sub is CenterContainer or sub is MarginContainer or (sub.anchor_right == 1.0 and sub.anchor_bottom == 1.0)):
							sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if _display_confirm_overlay != null and _display_confirm_overlay.visible:
			_display_confirm_overlay.position = Vector2(
				maxf(0.0, (size.x - _display_confirm_overlay.size.x) * 0.5),
				maxf(0.0, (size.y - _display_confirm_overlay.size.y) * 0.5)
			)
		if _confirm_scrim != null and _confirm_scrim.visible:
			_confirm_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# ── Contract methods ─────────────────────────────────────────────────────────

func get_contract_version() -> int:
	return 1

func present(model: Dictionary) -> void:
	_ensure_initialized()
	_current_model = model

	_reduced_motion = model.get("preferences", {}).get("reduced_motion", false)
	_transition_duration = 0.0 if _reduced_motion else 0.3

	var target_page: String = model.get("page", "boot")
	var dev_build: bool = model.get("development_build", false)
	if is_instance_valid(_version_label):
		_version_label.visible = dev_build
		if dev_build:
			_version_label.text = "DEV BUILD — Contract v%d" % model.get("contract_version", 1)
			_version_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			_version_label.offset_left = -220.0
			_version_label.offset_top = 12.0
			_version_label.offset_right = -16.0
			_version_label.offset_bottom = 32.0

	# Update background texture if supplied in brand_assets
	var brand_bg: String = model.get("brand_assets", {}).get("background_path", "")
	if brand_bg != "" and is_instance_valid(_bg_layer):
		var bg_tex: TextureRect = _bg_layer.find_child("BackgroundTexture", true, false)
		if bg_tex and (bg_tex.texture == null or bg_tex.texture.resource_path != brand_bg):
			var tex := LauncherTheme.load_texture_safe(brand_bg)
			if tex:
				bg_tex.texture = tex

	# Navigate to target page if changed
	if target_page != _current_page:
		_transition_to_page(target_page)

	# Update the active page with model data
	_update_active_page(model)

	# Handle overlay states (display confirmation, dirty settings, etc.)
	_update_overlays(model)

func set_preferences_preview(preferences: Dictionary) -> void:
	_reduced_motion = preferences.get("reduced_motion", _reduced_motion)
	_transition_duration = 0.0 if _reduced_motion else 0.3
	if _pages.has("loading") and is_instance_valid(_pages.loading):
		var spinner = _pages.loading.get("_spinner")
		if spinner != null and is_instance_valid(spinner):
			spinner.queue_redraw()
	var ui_scale: float = preferences.get("ui_scale", 1.0)
	if is_instance_valid(_page_container):
		_page_container.scale = Vector2(ui_scale, ui_scale)

func focus_primary() -> void:
	if _current_page != "" and _pages.has(_current_page):
		var page = _pages[_current_page]
		if page.has_method("focus_primary"):
			page.focus_primary()

# ── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _current_model.get("state") == "PLAYING" and _current_page != "settings":
		return

	# If capturing key binding, do not handle Esc as Back
	if _current_model.get("capturing_action", "") != "":
		return

	# If display confirmation overlay is visible, Esc triggers revert
	if _display_confirm_overlay != null and _display_confirm_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			intent_requested.emit(&"revert_display", {})
			get_viewport().set_input_as_handled()
		return

	# If settings discard modal is visible, Esc dismisses modal (stay on page)
	if _pages.has("settings") and is_instance_valid(_pages.settings):
		var disc_modal = _pages.settings.get("_discard_modal")
		if disc_modal != null and is_instance_valid(disc_modal) and disc_modal.visible:
			if event.is_action_pressed("ui_cancel"):
				_pages.settings.hide_discard_prompt()
				get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel"):
		_handle_back()
		get_viewport().set_input_as_handled()

func _handle_back() -> void:
	match _current_page:
		"boot":
			intent_requested.emit(&"skip_branding", {})
		"home":
			pass # Explicit quit button
		"modes", "briefing", "how_to_play", "credits":
			intent_requested.emit(&"back", {})
		"settings":
			var settings_data = _current_model.get("settings", {})
			if settings_data.get("display_confirmation_required", false):
				return
			var errors: Array = settings_data.get("validation_errors", [])
			if settings_data.get("dirty", false) or not errors.is_empty():
				if _pages.has("settings") and _pages["settings"].has_method("show_discard_prompt"):
					_pages["settings"].show_discard_prompt()
			else:
				intent_requested.emit(&"back", {})
		"loading":
			var loading_data = _current_model.get("loading", {})
			if loading_data.get("can_cancel", false):
				intent_requested.emit(&"cancel_loading", {
					"request_id": loading_data.get("request_id", "")
				})
		"error":
			var error_data = _current_model.get("error", {})
			if error_data.get("return_allowed", true):
				intent_requested.emit(&"return_to_menu", {})
		_:
			intent_requested.emit(&"back", {})

# ── Page management ──────────────────────────────────────────────────────────

func _register_pages() -> void:
	if _page_container.get_child_count() == 0:
		_instantiate_default_pages()

	for child in _page_container.get_children():
		if child.has_method("get_page_id"):
			var page_id: String = child.get_page_id()
			_pages[page_id] = child
			if child.has_signal("intent_requested") and not child.intent_requested.is_connected(_on_page_intent):
				child.intent_requested.connect(_on_page_intent)

func _instantiate_default_pages() -> void:
	var page_classes = [
		LauncherBootPage,
		LauncherHomePage,
		LauncherModesPage,
		LauncherBriefingPage,
		LauncherLoadingPage,
		LauncherReadyPage,
		LauncherSettingsPage,
		LauncherHowToPlayPage,
		LauncherCreditsPage,
		LauncherErrorPage
	]
	for cls in page_classes:
		var p = cls.new()
		_page_container.add_child(p)
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.grow_horizontal = Control.GROW_DIRECTION_BOTH
		p.grow_vertical = Control.GROW_DIRECTION_BOTH

func _on_page_intent(action: StringName, payload: Dictionary) -> void:
	intent_requested.emit(action, payload)

func _hide_all_pages() -> void:
	for page in _pages.values():
		page.visible = false
		page.modulate.a = 0.0
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _transition_to_page(target: String) -> void:
	if not _pages.has(target):
		push_warning("LauncherView: Unknown page '%s'" % target)
		return

	# Kill any existing transition and track if an interruption occurred
	var was_tweening: bool = (_active_tween != null and _active_tween.is_valid())
	if was_tweening:
		_active_tween.kill()
		_active_tween = null
		for id: String in _pages:
			if id != target:
				_pages[id].visible = false
				_pages[id].modulate.a = 0.0
				_pages[id].mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Hide and disable input on all non-participating pages immediately
	for id: String in _pages:
		if id != target and id != _current_page:
			_pages[id].visible = false
			_pages[id].modulate.a = 0.0
			_pages[id].mouse_filter = Control.MOUSE_FILTER_IGNORE

	var old_page: Control = _pages.get(_current_page) if _current_page != "" else null
	var new_page: Control = _pages[target]
	new_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	new_page.grow_horizontal = Control.GROW_DIRECTION_BOTH
	new_page.grow_vertical = Control.GROW_DIRECTION_BOTH
	for c in new_page.get_children():
		if c is Control and (c is CenterContainer or c is MarginContainer or (c.anchor_right == 1.0 and c.anchor_bottom == 1.0)):
			c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if _transition_duration <= 0.01 or _reduced_motion or was_tweening:
		# Immediate transition (reduced motion or interrupted rapid transition)
		if old_page:
			old_page.visible = false
			old_page.modulate.a = 0.0
			old_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for id: String in _pages:
			if id != target:
				_pages[id].visible = false
				_pages[id].modulate.a = 0.0
				_pages[id].mouse_filter = Control.MOUSE_FILTER_IGNORE
		new_page.visible = true
		new_page.modulate.a = 1.0
		new_page.mouse_filter = Control.MOUSE_FILTER_STOP
		_current_page = target
		_focus_after_transition(new_page)
		return

	# Crossfade
	new_page.visible = true
	new_page.modulate.a = 0.0
	new_page.mouse_filter = Control.MOUSE_FILTER_STOP
	if old_page:
		old_page.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.set_trans(Tween.TRANS_CUBIC)

	if old_page:
		_active_tween.tween_property(old_page, "modulate:a", 0.0, _transition_duration * 0.6)
	_active_tween.tween_property(new_page, "modulate:a", 1.0, _transition_duration)

	_active_tween.chain().tween_callback(func():
		for id: String in _pages:
			if id != target:
				_pages[id].visible = false
				_pages[id].modulate.a = 0.0
				_pages[id].mouse_filter = Control.MOUSE_FILTER_IGNORE
		_focus_after_transition(new_page)
	)
	_current_page = target

func _focus_after_transition(page: Control) -> void:
	if page.has_method("focus_primary"):
		page.focus_primary.call_deferred()

func _update_active_page(model: Dictionary) -> void:
	if _current_page == "" or not _pages.has(_current_page):
		return
	var page = _pages[_current_page]
	if page.has_method("update_from_model"):
		page.update_from_model(model)

func _update_overlays(model: Dictionary) -> void:
	if not is_instance_valid(_overlay_container):
		return
	var settings: Dictionary = model.get("settings", {})
	if settings.get("display_confirmation_required", false):
		_show_display_confirmation(settings.get("display_confirmation_seconds_remaining", 15))
	else:
		_hide_display_confirmation()

# ── Background ───────────────────────────────────────────────────────────────

func _setup_background() -> void:
	if not is_instance_valid(_bg_layer):
		return
	if _bg_layer.get_child_count() == 0:
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.color = LauncherTheme.COL_BG_DEEP
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_layer.add_child(rect)

		var tex_rect := TextureRect.new()
		tex_rect.name = "BackgroundTexture"
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var default_bg := "res://assets/launcher/campus-dusk-reference.png"
		var tex := LauncherTheme.load_texture_safe(default_bg)
		if tex == null:
			tex = LauncherTheme.load_texture_safe("res://assets/antigravity/launcher/bg_campus.png")
		if tex:
			tex_rect.texture = tex
		if ResourceLoader.exists("res://shaders/antigravity/launcher/background_grade.gdshader"):
			var shader = load("res://shaders/antigravity/launcher/background_grade.gdshader")
			var mat = ShaderMaterial.new()
			mat.shader = shader
			tex_rect.material = mat
		_bg_layer.add_child(tex_rect)

# ── Display confirmation overlay ─────────────────────────────────────────────

var _display_confirm_overlay: PanelContainer = null
var _confirm_scrim: ColorRect = null
var _overlay_previous_focus: Control = null

func _show_display_confirmation(seconds_remaining: int) -> void:
	if _confirm_scrim == null:
		_confirm_scrim = ColorRect.new()
		_confirm_scrim.color = Color(0.0, 0.0, 0.0, 0.6)
		_confirm_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_confirm_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		_overlay_container.add_child(_confirm_scrim)
	else:
		_confirm_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_scrim.visible = true

	if _display_confirm_overlay == null:
		_display_confirm_overlay = _build_display_confirm()
		_overlay_container.add_child(_display_confirm_overlay)

	_display_confirm_overlay.visible = true
	_display_confirm_overlay.position = Vector2(
		maxf(0.0, (size.x - _display_confirm_overlay.size.x) * 0.5),
		maxf(0.0, (size.y - _display_confirm_overlay.size.y) * 0.5)
	)

	var lbl: Label = _display_confirm_overlay.get_node_or_null("VBox/CountdownLabel")
	if lbl:
		lbl.text = "Reverting in %d seconds..." % seconds_remaining

	if _overlay_previous_focus == null:
		_overlay_previous_focus = get_viewport().gui_get_focus_owner()

	var keep_btn: Button = _display_confirm_overlay.get_node_or_null("VBox/ButtonRow/KeepButton")
	var revert_btn: Button = _display_confirm_overlay.get_node_or_null("VBox/ButtonRow/RevertButton")
	if keep_btn and not keep_btn.has_focus() and (revert_btn == null or not revert_btn.has_focus()):
		keep_btn.grab_focus.call_deferred()

func _hide_display_confirmation() -> void:
	if _confirm_scrim:
		_confirm_scrim.visible = false
	if _display_confirm_overlay:
		_display_confirm_overlay.visible = false
	if _overlay_previous_focus != null and is_instance_valid(_overlay_previous_focus) and _overlay_previous_focus.is_inside_tree():
		_overlay_previous_focus.grab_focus.call_deferred()
		_overlay_previous_focus = null

func _build_display_confirm() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(480, 200)
	var sb := LauncherTheme._make_flat_box(
		LauncherTheme.COL_BG_PANEL, LauncherTheme.CORNER_RADIUS_LG,
		LauncherTheme.COL_ACCENT, 2, 32.0)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Keep display settings?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", LauncherTheme.FONT_HEADING)
	vbox.add_child(title)

	var countdown := Label.new()
	countdown.name = "CountdownLabel"
	countdown.text = "Reverting in 15 seconds..."
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.add_theme_color_override("font_color", LauncherTheme.COL_TEXT_SECONDARY)
	vbox.add_child(countdown)

	var btn_row := HBoxContainer.new()
	btn_row.name = "ButtonRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var keep_btn := Button.new()
	keep_btn.name = "KeepButton"
	keep_btn.text = "Keep Changes"
	keep_btn.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus"]:
		keep_btn.add_theme_stylebox_override(state, LauncherTheme.make_accent_button_style(state))
	keep_btn.pressed.connect(func(): intent_requested.emit(&"confirm_display", {}))
	btn_row.add_child(keep_btn)

	var revert_btn := Button.new()
	revert_btn.name = "RevertButton"
	revert_btn.text = "Revert"
	revert_btn.focus_mode = Control.FOCUS_ALL
	revert_btn.pressed.connect(func(): intent_requested.emit(&"revert_display", {}))
	btn_row.add_child(revert_btn)

	# Focus containment loop (all directions)
	keep_btn.focus_next = NodePath("../RevertButton")
	keep_btn.focus_previous = NodePath("../RevertButton")
	keep_btn.focus_neighbor_right = NodePath("../RevertButton")
	keep_btn.focus_neighbor_left = NodePath("../RevertButton")
	keep_btn.focus_neighbor_top = NodePath("../RevertButton")
	keep_btn.focus_neighbor_bottom = NodePath("../RevertButton")

	revert_btn.focus_next = NodePath("../KeepButton")
	revert_btn.focus_previous = NodePath("../KeepButton")
	revert_btn.focus_neighbor_right = NodePath("../KeepButton")
	revert_btn.focus_neighbor_left = NodePath("../KeepButton")
	revert_btn.focus_neighbor_top = NodePath("../KeepButton")
	revert_btn.focus_neighbor_bottom = NodePath("../KeepButton")

	return panel
