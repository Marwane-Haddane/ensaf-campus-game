extends Control

signal finished

const PANEL_SECONDS := 5.0
const TITLE_FONT = preload("res://assets/antigravity/zombie/hud/BarlowCondensed-ExtraBoldItalic.ttf")
const PANELS := [
	["01-radio.webp", "Auditorium steps · Before the blackout", "LAST CALL", "RADIO CHECK", "Shaun: Meet me at the Auditorium.\nYou: On my way.", Color("ffbe45")],
	["02-blackout.webp", "Campus plaza · Moments later", "LIGHTS OUT", "CAMPUS ALERT", "Infected flood the plaza. The power fails, trapping everyone behind the main gate.", Color("ff6380")],
	["03-shelter.webp", "Auditorium · Emergency shelter", "HOLD THE DOOR", "SHAUN / RADIO", "I’ve got survivors inside the Auditorium. We need power to open the gate.", Color("ffaf54")],
	["04-reception.webp", "Reception · Emergency supplies", "FIRST STOP: RECEPTION", "SHAUN / RADIO", "Search Reception for the emergency pistol. Then find the main breaker fuse.", Color("5af5d1")],
	["05-power.webp", "Glazed entrance → Security Substation", "BRING THE POWER BACK", "SHAUN / RADIO", "Grab the relay by the glazed entrance. Take it and the fuse to the Security Substation.", Color("78d8ff")],
	["06-extraction.webp", "Main gate · Extraction route", "CLEAR THE WAY", "SHAUN / RADIO", "Once power’s back, come find me. We’ll clear the way to the extraction truck.", Color("defb55")],
]
const ART_DIR := "res://assets/launcher/after-hours-story/"

var panels: Array = PANELS
var art_directory := ART_DIR
var heading := "AFTER HOURS    /    OPENING STORY"
var story_note := "STORY ADVANCES EVERY 5 SECONDS"

var _panel := 0
var _remaining := PANEL_SECONDS
var _done := false
var _textures: Array[Texture2D] = []
var _art: TextureRect
var _location: Label
var _title: Label
var _speaker: Label
var _dialogue: Label
var _progress: ProgressBar
var _index: Label
var _next: Button
var _fill := StyleBoxFlat.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for panel: Array in panels:
		var path := art_directory + str(panel[0])
		_textures.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
	_build()
	_show_panel()
	_next.grab_focus()

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("111025")
	add_child(background)
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var margins := MarginContainer.new()
	add_child(margins)
	margins.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 24 if edge in ["left", "right"] else 12)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margins.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var brand := _label(heading, 25, TITLE_FONT)
	brand.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(brand)
	_index = _label("", 23, TITLE_FONT)
	header.add_child(_index)

	var spread := HBoxContainer.new()
	spread.size_flags_vertical = SIZE_EXPAND_FILL
	spread.add_theme_constant_override("separation", 12)
	column.add_child(spread)
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 2.5
	frame.add_theme_stylebox_override("panel", _box(Color("282142"), 4))
	spread.add_child(frame)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = MOUSE_FILTER_IGNORE
	frame.add_child(_art)

	var caption := PanelContainer.new()
	caption.size_flags_horizontal = SIZE_EXPAND_FILL
	caption.custom_minimum_size.x = 280
	caption.add_theme_stylebox_override("panel", _box(Color("231c40"), 10, 16))
	spread.add_child(caption)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 12)
	caption.add_child(words)
	_location = _label("", 15)
	_location.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_location)
	_title = _label("", 46, TITLE_FONT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_title)
	_speaker = _label("", 15, TITLE_FONT)
	words.add_child(_speaker)
	_dialogue = _label("", 21)
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_dialogue)

	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 4
	_progress.max_value = PANEL_SECONDS
	_progress.step = 0.0
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("background", _box(Color("383054"), 0))
	_progress.add_theme_stylebox_override("fill", _fill)
	column.add_child(_progress)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	column.add_child(controls)
	var hint := _label(story_note, 16, TITLE_FONT)
	hint.size_flags_horizontal = SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", Color("c1b5da"))
	controls.add_child(hint)
	var skip_all := _button("Skip All", Color("31264e"), Color.WHITE)
	controls.add_child(skip_all)
	skip_all.pressed.connect(_finish)
	_next = _button("Skip  →", Color("defb55"), Color("141126"))
	controls.add_child(_next)
	_next.pressed.connect(_advance)

func _label(value: String, font_size: int, font: Font = null) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	if font:
		label.add_theme_font_override("font", font)
	return label

func _button(value: String, color: Color, ink: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(112, 40)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _box(color, 7))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.16), 7))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.12), 7))
	for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(key, ink)
	return button

func _box(color: Color, radius: int, padding: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, padding)
	return box

func _show_panel() -> void:
	var panel: Array = panels[_panel]
	_art.texture = _textures[_panel]
	_location.text = panel[1]
	_title.text = panel[2]
	_speaker.text = panel[3]
	_dialogue.text = panel[4]
	_title.add_theme_color_override("font_color", panel[5])
	_speaker.add_theme_color_override("font_color", panel[5])
	_fill.bg_color = panel[5]
	_fill.emit_changed()
	_index.text = "%02d / %02d" % [_panel + 1, panels.size()]
	_next.text = "Start Mission" if _panel == panels.size() - 1 else "Skip  →"
	_remaining = PANEL_SECONDS
	_progress.value = PANEL_SECONDS

func _process(delta: float) -> void:
	if _done: return
	_remaining -= delta
	_progress.value = maxf(_remaining, 0.0)
	if _remaining <= 0.0:
		_advance()

func _advance() -> void:
	if _done: return
	if _panel + 1 == panels.size():
		_finish()
		return
	_panel += 1
	_show_panel()

func _finish() -> void:
	if _done: return
	_done = true
	finished.emit()
