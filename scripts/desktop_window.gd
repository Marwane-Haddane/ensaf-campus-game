extends Panel
## Native in-game window with constrained dragging, resize, minimize and maximize.
signal closed
signal minimized
var content: MarginContainer
var title_label: Label
var title_bar: Panel
var maximized: bool = false
var restore_rect: Rect2
var _dragging: bool = false
var _resizing: bool = false

func _ready() -> void:
	clip_contents = true
	add_theme_stylebox_override("panel",_style(Color("111820"),Color("53616e")))
	title_bar = Panel.new()
	title_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_bar.offset_bottom = 34
	title_bar.add_theme_stylebox_override("panel",_style(Color("202a34"),Color("354451")))
	add_child(title_bar)
	title_bar.gui_input.connect(_title_input)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/icons/terminal.svg")
	icon.position = Vector2(10,8)
	icon.size = Vector2(19,19)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(icon)
	title_label = Label.new()
	title_label.position = Vector2(43,5)
	title_label.add_theme_font_size_override("font_size",15)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(title_label)
	var controls := HBoxContainer.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	controls.position = Vector2(-105,0)
	controls.offset_right = 0
	controls.offset_bottom = 34
	title_bar.add_child(controls)
	controls.add_child(_icon_button("minimize",func():hide();minimized.emit()))
	controls.add_child(_icon_button("maximize",toggle_maximize))
	controls.add_child(_icon_button("close",func():hide();closed.emit()))
	content = MarginContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 35
	content.offset_left = 1
	content.offset_right = -1
	content.offset_bottom = -1
	add_child(content)
	var grip := Control.new()
	grip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grip.offset_left = -15
	grip.offset_top = -15
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_resizing = event.pressed and not maximized
			accept_event())
	add_child(grip)
	gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed: raise_window())

func _style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0,0,0,0.25)
	style.shadow_size = 8
	return style

func _icon_button(icon: String, action: Callable) -> Button:
	var button := Button.new()
	button.icon = load("res://assets/ui/icons/"+icon+".svg")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width",14)
	button.custom_minimum_size = Vector2(32,32)
	button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover",_style(Color("344653"),Color("344653")))
	button.add_theme_stylebox_override("pressed",_style(Color("215884"),Color("215884")))
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = icon.capitalize()
	button.pressed.connect(action)
	return button

func configure(caption: String, rectangle: Rect2) -> void:
	title_label.text = caption
	position = rectangle.position
	size = rectangle.size
	restore_rect = rectangle

func set_title(caption: String) -> void:
	title_label.text = caption

func raise_window() -> void:
	get_parent().move_child(self,get_parent().get_child_count()-1)

func toggle_maximize() -> void:
	if maximized:
		position = restore_rect.position
		size = restore_rect.size
	else:
		restore_rect = Rect2(position,size)
		position = Vector2(9,45)
		size = Vector2(1262,628)
	maximized = not maximized
	raise_window()

func _title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click: toggle_maximize()
		_dragging = event.pressed and not maximized
		if event.pressed: raise_window()
		accept_event()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_dragging = false
		_resizing = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		_resizing = false
	if event is InputEventMouseMotion:
		var delta: Vector2 = event.relative / get_global_transform().get_scale()
		if _dragging:
			position += delta
			position.x = clampf(position.x,12-size.x+100,1180)
			position.y = clampf(position.y,39,635)
			get_viewport().set_input_as_handled()
		elif _resizing:
			size = (size+delta).clamp(Vector2(340,220),Vector2(1260,640))
			get_viewport().set_input_as_handled()
