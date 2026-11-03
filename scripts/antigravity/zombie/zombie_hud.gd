extends CanvasLayer
## Professional ENSA Games Survival HUD, Menus, Dialogue, and Game Over Overlays

const DISPLAY_FONT := preload("res://assets/antigravity/zombie/hud/BarlowCondensed-ExtraBoldItalic.ttf")
const PISTOL_ICON := preload("res://assets/antigravity/zombie/hud/desert-eagle.svg")
const SMG_ICON := preload("res://assets/antigravity/zombie/hud/cz-skorpion.svg")
const CHEVRON_ICON := preload("res://assets/ui/icons/chevron.svg")
const INK := Color("190d39f5")
const VIOLET := Color("785bff")
const CITRON := Color("e7ff35")
const WHITE := Color("fff9f3")

signal retry_checkpoint_requested
signal restart_mission_requested
signal return_to_launcher_requested
signal settings_requested
signal medkit_use_requested
signal upgrade_chosen(upgrade_id: String)
signal pause_toggled(is_paused: bool)
signal dialogue_closed
signal upgrade_menu_closed
signal menu_state_changed(open: bool)

var health_bar: ProgressBar
var stamina_bar: ProgressBar
var health_label: Label
var stamina_label: Label

var ammo_label: Label
var weapon_name_label: Label
var scrap_label: Label
var objective_label: Label
var prompt_label: Label
var _hud_root: Control
var _prompt: HBoxContainer
var _prompt_key: Label
var _prompt_role: Label
var _prompt_beside_target := false
var _dialogue_speaker: Label
var _dialogue_role: Label
var _dialogue_next: Button
var _dialogue_key: Label
var crosshair: Control
var hit_marker: Control
var damage_rect: ColorRect

# Menus & Overlays
var pause_menu: PanelContainer
var inventory_menu: PanelContainer
var journal_menu: PanelContainer
var dialogue_menu: PanelContainer
var upgrade_menu: PanelContainer
var death_screen: PanelContainer
var victory_screen: PanelContainer

var dialogue_text_label: Label
var dialogue_lines: Array = []
var dialogue_index: int = 0

var inv_items_container: VBoxContainer
var journal_steps_container: VBoxContainer
var _victory_values: Array[Label] = []
var banner_timer: float = 0.0

var is_paused: bool = false
var reduced_motion: bool = false
var notice_label: Label
var boss_bar: ProgressBar
var boss_label: Label
var progression_label: Label
var _notice_remaining := 0.0
var _modal_scrim: ColorRect
var _pause_fade: TextureRect
var _objective_box: VBoxContainer
var _weapon_icon: TextureRect
var _ammo_warning: Label
var _medkit_button: Button
var _upgrade_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_hud_elements()
	_build_menus()
	_apply_survival_theme()
	get_viewport().size_changed.connect(_layout_menus)
	_layout_menus.call_deferred()

func _process(delta: float) -> void:
	if _notice_remaining>0:
		_notice_remaining = maxf(0.0,_notice_remaining-delta)
		if notice_label: notice_label.visible = _notice_remaining>0

func _apply_survival_theme() -> void:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI","Arial"])
	theme.default_font = font
	theme.default_font_size = 15
	var root: Control = get_child(0)
	root.theme = theme
	for panel: PanelContainer in [inventory_menu,journal_menu,upgrade_menu,death_screen]:
		panel.theme = theme
		var style := StyleBoxFlat.new()
		style.bg_color = Color("101925f5")
		style.border_color = Color("b58a4f")
		style.border_width_top = 2
		style.set_corner_radius_all(8)
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 22
		style.content_margin_bottom = 22
		panel.add_theme_stylebox_override("panel",style)
		for child: Node in panel.find_children("*","Label",true,false):
			(child as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_scrim = ColorRect.new()
	_modal_scrim.color = Color(0.015,0.025,0.045,.62)
	_modal_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_scrim.hide()
	add_child(_modal_scrim)
	move_child(_modal_scrim,1)
	_pause_fade = TextureRect.new()
	_pause_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pause_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.32, 0.75, 1.0])
	gradient.colors = PackedColorArray([
		Color("100823f7"), Color("100823d9"), Color("10082300"), Color("10082300")
	])
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = gradient
	fade_texture.width = 256
	fade_texture.height = 1
	_pause_fade.texture = fade_texture
	_modal_scrim.add_child(_pause_fade)
	notice_label = _hud_label("", 18, CITRON)
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	notice_label.offset_left = -421
	notice_label.offset_right = -32
	notice_label.offset_top = 28
	notice_label.offset_bottom = 67
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var notice_padding := StyleBoxEmpty.new()
	notice_padding.content_margin_left = 20
	notice_padding.content_margin_right = 24
	notice_padding.content_margin_top = 5
	notice_padding.content_margin_bottom = 5
	notice_label.add_theme_stylebox_override("normal", notice_padding)
	notice_label.hide()
	root.add_child(notice_label)
	_add_hud_plate(notice_label, INK, VIOLET, true)
	var boss_box := VBoxContainer.new()
	boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_box.offset_left = -180
	boss_box.offset_right = 180
	boss_box.offset_top = 108
	boss_box.offset_bottom = 146
	root.add_child(boss_box)
	boss_label = Label.new()
	boss_label.text = "COURTYARD BRUTE"
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size",12)
	boss_box.add_child(boss_label)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(360,6)
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color("c17955")
	boss_fill.set_corner_radius_all(3)
	boss_bar.add_theme_stylebox_override("fill", boss_fill)
	boss_box.add_child(boss_bar)
	boss_box.hide()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node: Node in root.find_children("*","Control",true,false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _layout_menus() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_layout_objective()
	pause_menu.size = pause_menu.get_combined_minimum_size()
	pause_menu.position = Vector2(56, maxf(24, (viewport_size.y - pause_menu.size.y) * 0.32))
	victory_screen.size = victory_screen.get_combined_minimum_size()
	victory_screen.position = Vector2(56, maxf(18, (viewport_size.y - victory_screen.size.y) * 0.46))
	for panel: PanelContainer in [inventory_menu,journal_menu,upgrade_menu,death_screen]:
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.size = panel.get_combined_minimum_size().min(viewport_size-Vector2(48,48))
		panel.position = (viewport_size-panel.size)*.5
	_layout_dialogue()

func _layout_dialogue() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(820, viewport_size.x - 64)
	dialogue_menu.size = Vector2(width, dialogue_menu.get_combined_minimum_size().y)
	dialogue_menu.position = Vector2((viewport_size.x - dialogue_menu.size.x) * 0.5,
		viewport_size.y - dialogue_menu.size.y - 42)

func update_progression(text: String) -> void:
	if progression_label: progression_label.text = text

func update_boss(health: float,max_health: float,show: bool,phase: String = "") -> void:
	if boss_bar:
		boss_bar.get_parent().visible = show
		boss_bar.max_value = max_health
		boss_bar.value = health
		match phase:
			"windup":
				boss_label.text = "BRUTE  ·  WIND-UP / MOVE"
				boss_label.modulate = Color("f2bd70")
			"recovery":
				boss_label.text = "BRUTE  ·  RECOVERING / FIRE"
				boss_label.modulate = Color("80ddc7")
			_:
				boss_label.text = "COURTYARD BRUTE"
				boss_label.modulate = Color.WHITE

func update_reload(progress: float, weapon_name: String) -> void:
	weapon_name_label.text = "RELOADING  %d%%" % int(progress * 100) if progress >= 0.0 else weapon_name.to_upper()

func _build_hud_elements() -> void:
	# Root control
	var root := Control.new()
	_hud_root = root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	
	# Damage flash / vignette
	damage_rect = ColorRect.new()
	damage_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_rect.color = Color(0.8, 0.05, 0.05, 0.0)
	damage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_rect)
	
	# Crosshair in center
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	_draw_crosshair(crosshair)
	
	# Hit marker tick (hidden initially)
	hit_marker = Control.new()
	hit_marker.set_anchors_preset(Control.PRESET_CENTER)
	hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_marker.visible = false
	root.add_child(hit_marker)
	_draw_hit_marker(hit_marker)
	
	_build_interaction_prompt(root)
	_build_objective(root)
	_build_vitals(root)
	_build_ammo(root)

func _build_interaction_prompt(root: Control) -> void:
	_prompt = HBoxContainer.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.offset_top = 54
	_prompt.add_theme_constant_override("separation", 0)
	_prompt.hide()
	root.add_child(_prompt)
	_prompt.resized.connect(_position_prompt)
	_add_hud_plate(_prompt, INK, VIOLET, true)

	_prompt_key = _hud_label("E", 34, INK)
	_prompt_key.custom_minimum_size = Vector2(66, 51)
	_prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_child(_prompt_key)
	_add_hud_plate(_prompt_key, CITRON)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 13)
	padding.add_theme_constant_override("margin_right", 28)
	padding.add_theme_constant_override("margin_top", 5)
	padding.add_theme_constant_override("margin_bottom", 5)
	_prompt.add_child(padding)
	var labels := VBoxContainer.new()
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.add_theme_constant_override("separation", 0)
	padding.add_child(labels)
	prompt_label = _hud_label("", 23)
	labels.add_child(prompt_label)
	_prompt_role = _hud_label("", 15, Color("ada0ff"))
	labels.add_child(_prompt_role)

func _position_prompt() -> void:
	var center := _hud_root.size * 0.5
	_prompt.position = Vector2(maxf(24, center.x - _prompt.size.x - 45), center.y - 22) if _prompt_beside_target \
		else center + Vector2(-_prompt.size.x * 0.5, 54)

func _speaker_name_and_role(speaker: String) -> PackedStringArray:
	var role_start := speaker.rfind(" (")
	if role_start >= 0 and speaker.ends_with(")"):
		return PackedStringArray([speaker.left(role_start), speaker.substr(role_start + 2,
			speaker.length() - role_start - 3)])
	return PackedStringArray([speaker, ""])

func _build_objective(root: Control) -> void:
	_objective_box = VBoxContainer.new()
	_objective_box.position = Vector2(32, 28)
	_objective_box.size.x = 620
	_objective_box.add_theme_constant_override("separation", 4)
	root.add_child(_objective_box)

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 0)
	_objective_box.add_child(strip)
	_add_hud_plate(strip, INK, VIOLET, true)

	var badge := _hud_label("OBJECTIVE", 23, INK)
	badge.custom_minimum_size = Vector2(146, 36)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip.add_child(badge)
	_add_hud_plate(badge, CITRON)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	strip.add_child(margin)
	objective_label = _hud_label("Explore campus and find supplies", 19)
	objective_label.custom_minimum_size.x = 140
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(objective_label)

	progression_label = Label.new()
	progression_label.add_theme_font_size_override("font_size", 15)
	progression_label.add_theme_color_override("font_color", WHITE)
	progression_label.add_theme_color_override("font_shadow_color", Color("120820"))
	progression_label.add_theme_constant_override("shadow_offset_y", 1)
	_objective_box.add_child(progression_label)

func _layout_objective() -> void:
	var text_width := DISPLAY_FONT.get_string_size(objective_label.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var viewport_width := get_viewport().get_visible_rect().size.x
	var notice_width := minf(389, viewport_width * 0.31)
	notice_label.offset_left = -32 - notice_width
	var max_width := minf(886, viewport_width - notice_width - 80)
	_objective_box.size = Vector2(minf(max_width, maxf(360, ceilf(text_width) + 186)), 0)

func _build_vitals(root: Control) -> void:
	var vitals := VBoxContainer.new()
	vitals.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vitals.offset_left = 32
	vitals.offset_right = 386
	vitals.offset_bottom = -24
	vitals.add_theme_constant_override("separation", 7)
	root.add_child(vitals)

	health_label = _hud_label("HEALTH    100 / 100", 19)
	stamina_label = _hud_label("STAMINA    100%", 19)
	health_bar = _add_vital(vitals, health_label, Color("ff4473"))
	stamina_bar = _add_vital(vitals, stamina_label, Color("36cefc"))

	scrap_label = _hud_label("SCRAP    0", 19, CITRON)
	scrap_label.custom_minimum_size = Vector2(136, 28)
	scrap_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vitals.add_child(scrap_label)
	_add_hud_plate(scrap_label, INK, VIOLET)

func _add_vital(parent: VBoxContainer, label: Label, tint: Color) -> ProgressBar:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 8)
	parent.add_child(margin)
	_add_hud_plate(margin, INK, VIOLET)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	margin.add_child(stack)
	stack.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 13
	bar.show_percentage = false
	bar.value = 100.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color("3e277c")
	track.skew.x = 0.25
	bar.add_theme_stylebox_override("background", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = tint
	bar.add_theme_stylebox_override("fill", fill)
	stack.add_child(bar)
	return bar

func _build_ammo(root: Control) -> void:
	var tile := VBoxContainer.new()
	tile.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tile.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tile.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tile.offset_left = -388
	tile.offset_right = -32
	tile.offset_bottom = -24
	tile.add_theme_constant_override("separation", 2)
	root.add_child(tile)

	var plate := MarginContainer.new()
	plate.add_theme_constant_override("margin_left", 24)
	plate.add_theme_constant_override("margin_right", 28)
	plate.add_theme_constant_override("margin_top", 8)
	plate.add_theme_constant_override("margin_bottom", 8)
	tile.add_child(plate)
	_add_hud_plate(plate, INK, VIOLET, true)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	plate.add_child(row)
	_weapon_icon = TextureRect.new()
	_weapon_icon.texture = PISTOL_ICON
	_weapon_icon.custom_minimum_size = Vector2(96, 62)
	_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_weapon_icon)
	var divider := Control.new()
	divider.custom_minimum_size.x = 14
	row.add_child(divider)
	_add_hud_plate(divider, VIOLET, Color.TRANSPARENT, false, 10.0)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", -5)
	row.add_child(text_box)
	weapon_name_label = _hud_label("9MM TACTICAL PISTOL", 19)
	text_box.add_child(weapon_name_label)
	ammo_label = _hud_label("12 / 36", 49)
	text_box.add_child(ammo_label)

	# Reserve the warning slot so the weapon plate does not jump when ammo changes.
	var warning_slot := Control.new()
	warning_slot.custom_minimum_size.y = 30
	tile.add_child(warning_slot)
	_ammo_warning = _hud_label("OUT OF AMMO", 21, INK)
	warning_slot.add_child(_ammo_warning)
	_ammo_warning.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ammo_warning.offset_left = 144
	_ammo_warning.offset_right = -16
	_ammo_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_hud_plate(_ammo_warning, CITRON, VIOLET, true)
	_ammo_warning.hide()

func _hud_label(text: String, font_size: int, tint: Color = WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", DISPLAY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	return label

func _add_hud_plate(parent: Control, tint: Color, accent: Color = Color.TRANSPARENT,
		accent_right: bool = false, cut: float = 14.0) -> void:
	var plate := parent
	if parent is Label:
		plate = Control.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.show_behind_parent = true
		parent.add_child(plate)
		plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.resized.connect(plate.queue_redraw)
	plate.draw.connect(func():
		_draw_slant(plate, Rect2(Vector2.ZERO, plate.size), tint, cut)
		if accent.a > 0.0:
			var x := plate.size.x - cut - 7.0 if accent_right else 0.0
			_draw_slant(plate, Rect2(x, 0, cut + 7.0, plate.size.y), accent, cut)
	)

func _draw_slant(canvas: Control, rect: Rect2, tint: Color, cut: float = 14.0) -> void:
	if not rect.has_area():
		return
	cut = minf(cut, rect.size.x * 0.8)
	canvas.draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(cut, 0),
		Vector2(rect.end.x, rect.position.y),
		rect.end - Vector2(cut, 0),
		Vector2(rect.position.x, rect.end.y)
	]), tint)

func _draw_crosshair(parent: Control) -> void:
	# Subtle 4-tick crosshair
	var clr := Color(1.0, 1.0, 1.0, 0.65)
	var size := 5.0
	var gap := 4.0
	
	# Top, bottom, left, right lines
	var t := ColorRect.new()
	t.color = clr
	t.custom_minimum_size = Vector2(2, size)
	t.position = Vector2(-1, -gap - size)
	parent.add_child(t)
	
	var b := ColorRect.new()
	b.color = clr
	b.custom_minimum_size = Vector2(2, size)
	b.position = Vector2(-1, gap)
	parent.add_child(b)
	
	var l := ColorRect.new()
	l.color = clr
	l.custom_minimum_size = Vector2(size, 2)
	l.position = Vector2(-gap - size, -1)
	parent.add_child(l)
	
	var r := ColorRect.new()
	r.color = clr
	r.custom_minimum_size = Vector2(size, 2)
	r.position = Vector2(gap, -1)
	parent.add_child(r)

func _draw_hit_marker(parent: Control) -> void:
	var clr := Color(1.0, 0.2, 0.2, 0.85)
	for rot in [45.0, 135.0, 225.0, 315.0]:
		var line := ColorRect.new()
		line.color = clr
		line.custom_minimum_size = Vector2(6, 2)
		line.position = Vector2(4, -1).rotated(deg_to_rad(rot))
		line.rotation_degrees = rot
		parent.add_child(line)

func show_hit_marker() -> void:
	hit_marker.visible = true
	var timer := get_tree().create_timer(0.12)
	timer.timeout.connect(func(): hit_marker.visible = false)

func flash_damage() -> void:
	if reduced_motion:
		return
	damage_rect.color = Color(0.8, 0.05, 0.05, 0.35)
	var tween := create_tween()
	tween.tween_property(damage_rect, "color:a", 0.0, 0.35)

func _build_menus() -> void:
	_build_pause_menu()
	_build_inventory_menu()
	_build_journal_menu()
	_build_dialogue_menu()
	_build_upgrade_menu()
	_build_death_screen()
	_build_victory_screen()

func _build_pause_menu() -> void:
	pause_menu = PanelContainer.new()
	pause_menu.custom_minimum_size.x = 498
	pause_menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	pause_menu.hide()
	add_child(pause_menu)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	pause_menu.add_child(content)
	var brand := _hud_label("AFTER HOURS", 33, VIOLET)
	content.add_child(brand)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 16)
	content.add_child(heading)
	heading.add_child(_hud_label("PAUSED", 96))
	var slash := Control.new()
	slash.custom_minimum_size = Vector2(38, 79)
	slash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(slash)
	_add_hud_plate(slash, VIOLET, Color.TRANSPARENT, false, 24.0)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	content.add_child(spacer)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 5)
	content.add_child(actions)
	_add_pause_action(actions, "RESUME GAME", func(): toggle_pause(false))
	_add_pause_action(actions, "RETRY FROM CHECKPOINT", func():
		toggle_pause(false)
		retry_checkpoint_requested.emit()
	)
	_add_pause_action(actions, "SETTINGS", func(): settings_requested.emit())
	_add_pause_action(actions, "RETURN TO LAUNCHER", func():
		toggle_pause(false)
		return_to_launcher_requested.emit()
	)

func _add_pause_action(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 53
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", 29)
	var style := StyleBoxEmpty.new()
	style.content_margin_left = 46
	style.content_margin_right = 25
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
	parent.add_child(button)
	button.pressed.connect(callback)

	var arrow := TextureRect.new()
	arrow.texture = CHEVRON_ICON
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.position = Vector2(13, 14)
	arrow.modulate = INK
	arrow.hide()
	button.add_child(arrow)

	var redraw := func():
		var active := button.has_focus()
		var tint := INK if active else WHITE
		for theme_color in ["font_color", "font_hover_color", "font_pressed_color",
				"font_focus_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(theme_color, tint)
		arrow.visible = active
		parent.queue_redraw()
	for state_change: Signal in [button.focus_entered, button.focus_exited,
			button.mouse_entered, button.mouse_exited, button.resized]:
		state_change.connect(redraw)
	parent.draw.connect(func():
		var rect := button.get_rect()
		if button.has_focus():
			_draw_slant(parent, rect, CITRON, 24.0)
		elif button.is_hovered():
			_draw_slant(parent, rect, Color("43298e"), 24.0)
		elif button.get_index() < parent.get_child_count() - 1:
			parent.draw_line(Vector2(24, rect.end.y), rect.end - Vector2(28, 0),
				Color("785bff7f"), 1.5)
	)
	redraw.call()

func _build_inventory_menu() -> void:
	inventory_menu = PanelContainer.new()
	inventory_menu.set_anchors_preset(Control.PRESET_CENTER)
	inventory_menu.custom_minimum_size = Vector2(420, 340)
	inventory_menu.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.17, 0.95)
	style.border_color = Color(0.3, 0.65, 0.85, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	inventory_menu.add_theme_stylebox_override("panel", style)
	add_child(inventory_menu)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	inventory_menu.add_child(vbox)
	
	var title := Label.new()
	title.text = "SURVIVAL INVENTORY (Press I to close)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	inv_items_container = VBoxContainer.new()
	inv_items_container.add_theme_constant_override("separation", 8)
	vbox.add_child(inv_items_container)
	
	var btn_medkit := _create_btn("Use Medkit (+40 HP)", func():
		medkit_use_requested.emit()
	)
	_medkit_button=btn_medkit
	vbox.add_child(btn_medkit)
	
	var btn_close := _create_btn("Close (I / Esc)", func(): toggle_inventory(false))
	vbox.add_child(btn_close)

func _build_journal_menu() -> void:
	journal_menu = PanelContainer.new()
	journal_menu.set_anchors_preset(Control.PRESET_CENTER)
	journal_menu.custom_minimum_size = Vector2(460, 360)
	journal_menu.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.17, 0.95)
	style.border_color = Color(0.85, 0.6, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	journal_menu.add_theme_stylebox_override("panel", style)
	add_child(journal_menu)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	journal_menu.add_child(vbox)
	
	var title := Label.new()
	title.text = "MISSION JOURNAL — ZB-2026-001 (Tab to close)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	journal_steps_container = VBoxContainer.new()
	journal_steps_container.add_theme_constant_override("separation", 6)
	vbox.add_child(journal_steps_container)
	
	var btn_close := _create_btn("Close (Tab / Esc)", func(): toggle_journal(false))
	vbox.add_child(btn_close)

func _build_dialogue_menu() -> void:
	dialogue_menu = PanelContainer.new()
	dialogue_menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	dialogue_menu.hide()
	add_child(dialogue_menu)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", -5)
	dialogue_menu.add_child(stack)
	var tab := MarginContainer.new()
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tab.add_theme_constant_override("margin_left", 30)
	tab.add_theme_constant_override("margin_right", 31)
	tab.z_index = 1
	stack.add_child(tab)
	_add_hud_plate(tab, Color("4e32bb"))
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 15)
	tab.add_child(heading)
	_dialogue_speaker = _hud_label("", 31)
	heading.add_child(_dialogue_speaker)
	_dialogue_role = _hud_label("", 19)
	heading.add_child(_dialogue_role)

	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 37)
	body.add_theme_constant_override("margin_right", 39)
	body.add_theme_constant_override("margin_top", 14)
	body.add_theme_constant_override("margin_bottom", 17)
	stack.add_child(body)
	_add_hud_plate(body, INK, VIOLET, true, 24.0)
	dialogue_text_label = Label.new()
	dialogue_text_label.custom_minimum_size = Vector2(260, 51)
	dialogue_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text_label.add_theme_color_override("font_color", WHITE)
	dialogue_text_label.add_theme_font_size_override("font_size", 22)
	body.add_child(dialogue_text_label)
	dialogue_text_label.minimum_size_changed.connect(_layout_dialogue.call_deferred)

	_dialogue_next = Button.new()
	_dialogue_next.text = "NEXT"
	_dialogue_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_dialogue_next.custom_minimum_size = Vector2(152, 42)
	_dialogue_next.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_dialogue_next.add_theme_font_override("font", DISPLAY_FONT)
	_dialogue_next.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = CITRON if state == "normal" else Color("f4ff95")
		style.skew.x = 0.28
		style.content_margin_left = 54
		style.content_margin_right = 16
		_dialogue_next.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.set_border_width_all(2)
	focus.border_color = VIOLET
	focus.skew.x = 0.28
	_dialogue_next.add_theme_stylebox_override("focus", focus)
	for key in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_dialogue_next.add_theme_color_override(key, INK)
	_dialogue_next.pressed.connect(_advance_dialogue)
	stack.add_child(_dialogue_next)
	_dialogue_key = _hud_label("E", 22, CITRON)
	_dialogue_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_key.position = Vector2(18, 7)
	_dialogue_key.size = Vector2(31, 28)
	_dialogue_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_next.add_child(_dialogue_key)
	_add_hud_plate(_dialogue_key, INK, Color.TRANSPARENT, false, 5)

func _interact_key_hint() -> String:
	if InputMap.has_action("interact"):
		for event in InputMap.action_get_events("interact"):
			if event is InputEventKey:
				var key: Key = event.physical_keycode if event.physical_keycode else event.keycode
				if key != KEY_NONE:
					return OS.get_keycode_string(key)
	return "E"

func _build_upgrade_menu() -> void:
	upgrade_menu = PanelContainer.new()
	upgrade_menu.set_anchors_preset(Control.PRESET_CENTER)
	upgrade_menu.custom_minimum_size = Vector2(460, 300)
	upgrade_menu.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.17, 0.95)
	style.border_color = Color(0.9, 0.7, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	upgrade_menu.add_theme_stylebox_override("panel", style)
	add_child(upgrade_menu)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	upgrade_menu.add_child(vbox)
	
	var title := Label.new()
	title.text = "FIELD WORKBENCH — UPGRADES (Cost: 25 Scrap)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	var btn_armor := _create_btn("Reinforced Armor (+50 Max HP & Heal 50)", func():
		upgrade_chosen.emit("upgrade_armor")
		toggle_upgrade_menu(false)
	)
	_upgrade_buttons["upgrade_armor"] = btn_armor
	vbox.add_child(btn_armor)
	
	var btn_mag := _create_btn("Extended Magazine (18 Rounds Mag)", func():
		upgrade_chosen.emit("upgrade_extended_mag")
		toggle_upgrade_menu(false)
	)
	_upgrade_buttons["upgrade_extended_mag"] = btn_mag
	vbox.add_child(btn_mag)
	
	var btn_cancel := _create_btn("Cancel (Esc)", func(): toggle_upgrade_menu(false))
	vbox.add_child(btn_cancel)

func _build_death_screen() -> void:
	death_screen = PanelContainer.new()
	death_screen.set_anchors_preset(Control.PRESET_CENTER)
	death_screen.custom_minimum_size = Vector2(400, 260)
	death_screen.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.04, 0.04, 0.96)
	style.border_color = Color(0.9, 0.1, 0.1, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	death_screen.add_theme_stylebox_override("panel", style)
	add_child(death_screen)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	death_screen.add_child(vbox)
	
	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "Overwhelmed by infected on campus."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.7, 0.7))
	vbox.add_child(subtitle)
	
	var btn_retry := _create_btn("Retry From Checkpoint", func():
		death_screen.visible = false
		retry_checkpoint_requested.emit()
	)
	vbox.add_child(btn_retry)
	
	var btn_restart := _create_btn("Restart Episode", func():
		death_screen.visible = false
		restart_mission_requested.emit()
	)
	vbox.add_child(btn_restart)

func _build_victory_screen() -> void:
	victory_screen = PanelContainer.new()
	victory_screen.custom_minimum_size.x = 475
	victory_screen.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	victory_screen.hide()
	add_child(victory_screen)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	victory_screen.add_child(stack)

	var badge := _hud_label("AFTER HOURS  /  EXTRACTION COMPLETE", 23, INK)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(393, 33)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stack.add_child(badge)
	_add_hud_plate(badge, CITRON)
	var title := _hud_label("MISSION\nACCOMPLISHED", 69)
	title.add_theme_constant_override("line_spacing", -13)
	stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Power restored. Shaun and survivor route secured."
	subtitle.add_theme_color_override("font_color", WHITE)
	subtitle.add_theme_font_size_override("font_size", 18)
	stack.add_child(subtitle)

	for caption in ["EXTRACTION TIME", "INFECTED NEUTRALIZED", "DAMAGE DEALT"]:
		var rule := ColorRect.new()
		rule.color = Color("785bff9f")
		rule.custom_minimum_size.y = 1
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(rule)
		var row := HBoxContainer.new()
		stack.add_child(row)
		var label := _hud_label(caption, 23)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var value := _hud_label("", 27, CITRON)
		row.add_child(value)
		_victory_values.append(value)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	stack.add_child(spacer)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	stack.add_child(actions)
	_add_pause_action(actions, "REPLAY EPISODE", func():
		victory_screen.hide()
		restart_mission_requested.emit()
	)
	_add_pause_action(actions, "RETURN TO LAUNCHER", func():
		victory_screen.hide()
		return_to_launcher_requested.emit()
	)

func _create_btn(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 36)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.18, 0.28, 0.9)
	style.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.22, 0.28, 0.42, 0.95)
	btn.add_theme_stylebox_override("hover", hover)
	btn.pressed.connect(callback)
	return btn

func show_banner_message(msg: String, duration: float = 3.0) -> void:
	if notice_label:
		notice_label.text = msg
		notice_label.show()
		_notice_remaining = duration

func update_health(cur: float, max_v: float) -> void:
	if health_bar:
		health_bar.max_value = max_v
		health_bar.value = cur
	if health_label:
		health_label.text = "HEALTH    %d / %d" % [int(cur), int(max_v)]

func update_stamina(cur: float, max_v: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_v
		stamina_bar.value = cur
	if stamina_label:
		stamina_label.text = "STAMINA    %d%%" % int(cur / max_v * 100.0 if max_v > 0.0 else 0.0)

func update_weapon_display(w_name: String, mag: int, reserve: int) -> void:
	if weapon_name_label:
		weapon_name_label.text = w_name.to_upper()
		_weapon_icon.texture = SMG_ICON if "scorpion" in w_name.to_lower() else PISTOL_ICON
	update_ammo(mag, reserve)

func update_ammo(mag: int, reserve: int) -> void:
	if ammo_label:
		ammo_label.text = "%d / %d" % [mag, reserve]
		var empty := mag <= 0 and reserve <= 0
		_ammo_warning.visible = empty
		ammo_label.add_theme_color_override("font_color", CITRON if empty else WHITE)

func update_scrap(amount: int) -> void:
	if scrap_label:
		scrap_label.text = "SCRAP    %d" % [amount]

func update_objective(text: String) -> void:
	if objective_label:
		objective_label.text = text
		_layout_objective()

func update_interaction_prompt(prompt_text: String, is_visible: bool) -> void:
	_prompt.visible = is_visible and not prompt_text.is_empty()
	if not _prompt.visible:
		return
	var action_text := prompt_text
	var key_end := prompt_text.find("]")
	_prompt_key.visible = prompt_text.begins_with("[") and key_end > 1
	if _prompt_key.visible:
		_prompt_key.text = prompt_text.substr(1, key_end - 1)
		action_text = prompt_text.substr(key_end + 1).strip_edges()
	var parts := _speaker_name_and_role(action_text) if action_text.begins_with("Speak with ") else action_text.split("\n", true, 1)
	_prompt_beside_target = action_text.contains("\n")
	if parts.size() < 2:
		parts.append("")
	prompt_label.text = parts[0].to_upper()
	_prompt_role.text = parts[1].to_upper()
	_prompt_role.visible = not parts[1].is_empty()
	_prompt.reset_size()
	_position_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var game := get_parent()
	if game.get("launcher_managed") and not game.is_processing_unhandled_input(): return
	if death_screen.visible or victory_screen.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		var is_interact: bool = event.is_action_pressed("interact") if InputMap.has_action("interact") else event.keycode == KEY_E
		if dialogue_menu.visible and is_interact:
			_advance_dialogue()
			get_viewport().set_input_as_handled()
			return
		if (inventory_menu.visible and event.keycode==KEY_I) or (journal_menu.visible and event.keycode==KEY_TAB):
			toggle_inventory(false)
			toggle_journal(false)
			get_viewport().set_input_as_handled()
			return
		var is_pause: bool = (event.is_action_pressed("pause") if InputMap.has_action("pause") else (event.keycode == KEY_ESCAPE))
		if is_pause:
			if is_paused or is_any_menu_open():
				toggle_pause(false)
				toggle_inventory(false)
				toggle_journal(false)
				toggle_upgrade_menu(false)
				close_dialogue()
				get_viewport().set_input_as_handled()
			else:
				toggle_pause(true)
				get_viewport().set_input_as_handled()

func toggle_pause(paused: bool) -> void:
	is_paused = paused
	pause_menu.visible = is_paused
	_update_input_capture()
	pause_toggled.emit(is_paused)

func toggle_inventory(open: bool, inv: RefCounted = null) -> void:
	inventory_menu.visible = open
	if open and inv:
		_populate_inventory(inv)
	_update_input_capture()

func _populate_inventory(inv: RefCounted) -> void:
	if _medkit_button:
		_medkit_button.text="Use Medkit (+%d HP)" % int(inv.get_medkit_healing())
		_medkit_button.disabled=not inv.has_item("medkit")
	for c in inv_items_container.get_children():
		c.queue_free()
	
	# Weapon slots
	var slots: Array = inv.call("get_weapon_slots") if inv.has_method("get_weapon_slots") else []
	if not slots.is_empty():
		var slots_title := Label.new()
		slots_title.text = "LOADOUT - Number keys while exploring"
		slots_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
		slots_title.add_theme_font_size_override("font_size", 13)
		inv_items_container.add_child(slots_title)
		
		var active_slot = int(inv.get("active_slot_index"))
		for i in range(slots.size()):
			var s: Dictionary = slots[i]
			var slot_lbl := Label.new()
			var is_active: bool = (i == active_slot)
			var mark: String = " [EQUIPPED]" if is_active else ""
			slot_lbl.text = "  [%d] %s%s" % [i + 1, s.get("name", "Weapon"), mark]
			slot_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5) if is_active else Color(0.75, 0.8, 0.85))
			inv_items_container.add_child(slot_lbl)
	
	var items: Dictionary = inv.get("items")
	var names := {
		"medkit": "Emergency Medkit",
		"scrap": "Salvaged Scrap",
		"item_power_fuse": "Main Breaker Fuse (Quest)",
		"item_power_relay": "Control Bus Relay (Quest)"
	}
	for id in items:
		if id == "ammo": continue # The weapon owns the live reserve.
		var count: int = items[id]
		var item_lbl := Label.new()
		item_lbl.text = "• %s: %d" % [names.get(id, id), count]
		item_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
		inv_items_container.add_child(item_lbl)
	
	var upgs: Array = inv.get("upgrades")
	if not upgs.is_empty():
		var upg_lbl := Label.new()
		upg_lbl.text = "Upgrades: " + ", ".join(upgs)
		upg_lbl.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
		inv_items_container.add_child(upg_lbl)

func toggle_journal(open: bool, mission: RefCounted = null) -> void:
	journal_menu.visible = open
	if open and mission:
		_populate_journal(mission)
	_update_input_capture()

func _populate_journal(mission: RefCounted) -> void:
	for c in journal_steps_container.get_children():
		c.queue_free()
	
	var cur_step: int = int(mission.get("current_step_index"))
	var steps: Array = mission.get("STEPS")
	for i in range(steps.size()):
		var s: Dictionary = steps[i]
		var l := Label.new()
		if i < cur_step:
			l.text = "[✔] " + str(s.get("text"))
			l.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
		elif i == cur_step:
			l.text = "[►] " + str(s.get("text")) + " (ACTIVE)"
			l.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
		else:
			l.text = "[  ] " + str(s.get("text"))
			l.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		journal_steps_container.add_child(l)

func show_dialogue(lines: Array, speaker: String) -> void:
	dialogue_lines = lines
	dialogue_index = 0
	var parts := _speaker_name_and_role(speaker)
	_dialogue_speaker.text = parts[0].to_upper()
	_dialogue_role.text = parts[1].to_upper()
	_dialogue_role.visible = not parts[1].is_empty()
	_dialogue_key.text = _interact_key_hint()
	var key_width := maxf(31, _dialogue_key.get_combined_minimum_size().x + 12)
	_dialogue_key.size.x = key_width
	for state in ["normal", "hover", "pressed"]:
		_dialogue_next.get_theme_stylebox(state).content_margin_left = 23 + key_width
	dialogue_menu.visible = true
	_update_dialogue_line()
	_update_input_capture()

func _advance_dialogue() -> void:
	dialogue_index += 1
	if dialogue_index < dialogue_lines.size():
		_update_dialogue_line()
	else:
		close_dialogue()

func close_dialogue() -> void:
	dialogue_menu.visible = false
	_update_input_capture()
	dialogue_closed.emit()

func _update_dialogue_line() -> void:
	if dialogue_index < dialogue_lines.size():
		dialogue_text_label.text = dialogue_lines[dialogue_index]

func toggle_upgrade_menu(open: bool) -> void:
	if open:
		var inv: Variant = get_parent().get("inventory")
		if inv != null:
			for option: Dictionary in inv.get_upgrade_options():
				var button: Button = _upgrade_buttons.get(option.id)
				if button != null:
					button.text="%s · %d scrap\n%s" % [option.title,option.cost,option.reason]
					button.tooltip_text=option.description
					button.disabled=not option.can_buy
	upgrade_menu.visible = open
	_update_input_capture()
	if not open:
		upgrade_menu_closed.emit()

func show_death_screen() -> void:
	death_screen.visible = true
	_update_input_capture()

func show_victory_screen(stats: Dictionary) -> void:
	_victory_values[0].text = str(stats.get("time_formatted", "00:00"))
	_victory_values[1].text = str(int(stats.get("kills", 0)))
	_victory_values[2].text = "%d HP" % int(stats.get("damage_dealt", 0))
	victory_screen.show()
	_update_input_capture()

func is_any_menu_open() -> bool:
	return pause_menu.visible or inventory_menu.visible or journal_menu.visible or dialogue_menu.visible or upgrade_menu.visible or death_screen.visible or victory_screen.visible

func _update_input_capture() -> void:
	if _modal_scrim:
		_modal_scrim.visible = is_any_menu_open()
		var debrief := victory_screen.visible
		_modal_scrim.color = Color("10082333") if debrief else Color("10082366") if is_paused else Color("10082355") if dialogue_menu.visible else Color(0.015,0.025,0.045,.62)
		_hud_root.visible = not (dialogue_menu.visible or debrief)
		_pause_fade.visible = is_paused or debrief
		_objective_box.visible = not is_paused
		crosshair.visible = not is_paused
	_layout_menus.call_deferred()
	menu_state_changed.emit(is_any_menu_open())
	if is_any_menu_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_focus_open_menu.call_deferred()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _focus_open_menu() -> void:
	for panel: Control in [death_screen,victory_screen,dialogue_menu,upgrade_menu,inventory_menu,journal_menu,pause_menu]:
		if not panel.is_visible_in_tree(): continue
		var buttons: Array[Node] = panel.find_children("*","Button",true,false)
		for index: int in range(buttons.size()):
			var button: Button = buttons[index]
			button.focus_neighbor_top = buttons[(index-1+buttons.size())%buttons.size()].get_path()
			button.focus_neighbor_bottom = buttons[(index+1)%buttons.size()].get_path()
		var focused: Control = get_viewport().gui_get_focus_owner()
		if not buttons.is_empty() and (focused==null or not panel.is_ancestor_of(focused)):
			(buttons[0] as Button).grab_focus()
		return
