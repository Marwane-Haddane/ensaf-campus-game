extends Control
## An interactive Linux-style workstation, rendered entirely inside the game.
signal exit_requested
signal report_requested
signal journal_requested
const DesktopWindow = preload("res://scripts/desktop_window.gd")
const HOME := "/home/analyst"
const WHITE := Color("e4e9ef")
const MUTED := Color("9caab8")
const BLUE := Color("55aaf0")
var training: Node
var shell: RefCounted
var canvas: Control
var windows: Control
var terminal_window: Panel
var file_window: Panel
var output: RichTextLabel
var command_input: LineEdit
var prompt: Label
var file_list: Tree
var preview: RichTextLabel
var path_input: LineEdit
var file_count: Label
var terminal_column: VBoxContainer
var file_path: String = HOME
var selected_file: String = ""
var terminal_text: String = ""
var history: Array[String] = []
var history_index: int = 0
var history_draft: String = ""
var folder_history: Array[String] = []
var folder_index: int = -1
var _apps: Dictionary = {}
var _workspace: int = 1
var _workspace_buttons: Array[Button] = []
var _workspace_windows: Dictionary = {}
var _task_terminal: Button
var _task_files: Button
var _clock: Label
var _bottom_bar: Panel
var _simulation_label: Label
var _files_opened: bool = false
var _app_tasks: Dictionary = {}
var _last_clock: String = ""
var _files_guard: bool = false
var _mono: SystemFont
var _terminal_scroll: ScrollContainer
var _app_menu: PopupMenu

func configure(owner_ui: Node, backend: RefCounted) -> void:
	training = owner_ui
	shell = backend
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI","Arial"])
	var desktop_theme := Theme.new()
	desktop_theme.default_font = font
	desktop_theme.default_font_size = 15
	desktop_theme.set_color("font_color","Label",WHITE)
	desktop_theme.set_color("default_color","RichTextLabel",WHITE)
	theme = desktop_theme
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Consolas","DejaVu Sans Mono","Liberation Mono"])
	canvas = Control.new()
	canvas.size = Vector2(1280,720)
	add_child(canvas)
	var wallpaper := ColorRect.new()
	wallpaper.size = Vector2(1280,720)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/workstation_wallpaper.gdshader")
	wallpaper.material = material
	canvas.add_child(wallpaper)
	_build_icons()
	windows = Control.new()
	windows.size = canvas.size
	windows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(windows)
	_build_terminal()
	_build_file_manager()
	_build_bars()
	reset_session()
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if is_instance_valid(canvas): canvas.scale = size/Vector2(1280,720)

func _panel(parent: Node, rect: Rect2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel",_style(color))
	parent.add_child(panel)
	return panel

func _style(color: Color, padding: int = 0, border: Color = Color(0,0,0,0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _label(parent: Node, text: String, at: Vector2, font_size: int = 15, color: Color = WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(text: String, callback: Callable, icon_name: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_stylebox_override("normal",_style(Color(0,0,0,0),6))
	button.add_theme_stylebox_override("hover",_style(Color("2c4053"),6))
	button.add_theme_stylebox_override("pressed",_style(Color("245a89"),6))
	button.add_theme_stylebox_override("focus",_style(Color(0.1,0.35,0.58,0.38),6,Color("527a9d")))
	button.add_theme_color_override("font_color",WHITE)
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	button.add_theme_font_size_override("font_size",15)
	if not icon_name.is_empty():
		button.icon = load("res://assets/ui/icons/"+icon_name+".svg")
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",20)
	button.pressed.connect(callback)
	return button

func _build_icons() -> void:
	var names := ["Home","File System","Help","Evidence","Reports"]
	var paths := [HOME,"/",HOME+"/Help",HOME+"/Evidence",HOME+"/Reports"]
	for i: int in range(names.size()):
		var button := _button("",open_folder.bind(paths[i]))
		button.position = Vector2(22,50+i*85)
		button.size = Vector2(88,79)
		button.tooltip_text = "Open the step-by-step field guide" if names[i] == "Help" else "Open "+names[i]
		canvas.add_child(button)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/ui/icons/"+("home" if i == 0 else ("drive" if i == 1 else "folder"))+".svg")
		icon.position = Vector2(25,4)
		icon.size = Vector2(39,39)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var label := _label(button,names[i],Vector2(0,49),13)
		label.size.x = 88
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if names[i] == "Help": _label(button,"●",Vector2(64,47),12,BLUE)

func _build_bars() -> void:
	var top := _panel(canvas,Rect2(0,0,1280,36),Color("1b2530"))
	var apps := _button("Applications",func(): _app_menu.position = Vector2i(get_global_rect().position+Vector2(8,36)*canvas.scale);_app_menu.popup(),"applications")
	apps.position = Vector2(7,0)
	apps.size = Vector2(145,35)
	top.add_child(apps)
	_app_menu = PopupMenu.new()
	for text: String in ["Terminal","Home folder","Help","Evidence","Reports","Return to campus","Operation Blackout"]: _app_menu.add_item(text)
	_app_menu.id_pressed.connect(func(id: int):
		match id:
			0: focus_terminal()
			1: open_folder(HOME)
			2: open_folder(HOME+"/Help")
			3: open_folder(HOME+"/Evidence")
			4: open_folder(HOME+"/Reports")
			5: exit_requested.emit()
			6:
				focus_terminal()
				submit_command("lab status" if shell.cyber.active else "mission start blackout")
	)
	apps.add_child(_app_menu)
	var terminal := _button("",focus_terminal,"terminal")
	terminal.position = Vector2(158,0)
	terminal.size = Vector2(40,35)
	terminal.tooltip_text = "Open terminal"
	top.add_child(terminal)
	var folder := _button("",open_folder.bind(HOME),"folder")
	folder.position = Vector2(203,0)
	folder.size = Vector2(40,35)
	folder.tooltip_text = "File manager"
	top.add_child(folder)
	for index: int in range(4):
		var button := _button(str(index+1),_switch_workspace.bind(index+1))
		button.position = Vector2(996+index*31,2)
		button.size = Vector2(29,31)
		top.add_child(button)
		_workspace_buttons.append(button)
	for pair: Array in [["network",1131],["volume",1167]]:
		var indicator := TextureRect.new()
		indicator.texture = load("res://assets/ui/icons/"+str(pair[0])+".svg")
		indicator.position = Vector2(pair[1],9)
		indicator.size = Vector2(19,19)
		indicator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		indicator.tooltip_text = "Campus lab connection" if pair[0] == "network" else "Desktop audio"
		top.add_child(indicator)
	_clock = _label(top,"10:42",Vector2(1210,7),14)
	var bottom := _panel(canvas,Rect2(0,682,1280,38),Color("1a232e"))
	_bottom_bar = bottom
	_label(bottom,"CAMPUS LAB  /  IR-2026-001",Vector2(20,11),11,MUTED)
	_simulation_label = _label(bottom,"Training simulation",Vector2(581,11),11,MUTED)
	var leave := _button("Esc   Return to campus",func():exit_requested.emit())
	leave.position = Vector2(1090,1)
	leave.size = Vector2(180,36)
	bottom.add_child(leave)
	_task_terminal = _button("Terminal",focus_terminal,"terminal")
	_task_terminal.position = Vector2(257,0)
	_task_terminal.size = Vector2(115,36)
	bottom.add_child(_task_terminal)
	_task_files = _button("Files",func():file_window.show();file_window.raise_window(),"folder")
	_task_files.position = Vector2(376,0)
	_task_files.size = Vector2(100,36)
	bottom.add_child(_task_files)
	_update_workspace_buttons()

func _build_terminal() -> void:
	terminal_window = DesktopWindow.new()
	windows.add_child(terminal_window)
	terminal_window.configure("analyst@campus-lab: ~",Rect2(370,119,850,420))
	terminal_column = VBoxContainer.new()
	terminal_column.add_theme_constant_override("separation",0)
	terminal_window.content.add_child(terminal_column)
	var menus := HBoxContainer.new()
	menus.custom_minimum_size.y = 30
	terminal_column.add_child(menus)
	for menu_text: String in ["File","Edit","View","Terminal","Help"]:
		var menu := MenuButton.new()
		menu.text = menu_text
		menu.add_theme_font_size_override("font_size",14)
		menu.add_theme_stylebox_override("normal",_style(Color("202a34"),7))
		menu.add_theme_stylebox_override("hover",_style(Color("344653"),7))
		menus.add_child(menu)
		var popup := menu.get_popup()
		match menu_text:
			"File":
				popup.add_item("Open file manager",0)
				popup.add_item("Close terminal",1)
				popup.id_pressed.connect(func(id:int):
					if id==0: open_folder(shell.cwd)
					else: terminal_window.hide())
			"Edit":
				popup.add_item("Copy selection",0)
				popup.add_item("Paste",1)
				popup.id_pressed.connect(func(id:int):
					if id==0: DisplayServer.clipboard_set(output.get_selected_text())
					else: command_input.insert_text_at_caret(DisplayServer.clipboard_get().left(1000)))
			"View":
				popup.add_item("Maximize / restore",0)
				popup.add_item("Clear display",1)
				popup.id_pressed.connect(func(id:int):
					if id==0: terminal_window.toggle_maximize()
					else: clear_terminal())
			"Terminal":
				popup.add_item("Clear display",0)
				popup.add_item("Case status",1)
				popup.id_pressed.connect(func(id:int):
					if id==0: clear_terminal()
					else: submit_command("ir status"))
			"Help":
				popup.add_item("Incident response field guide",0)
				popup.add_item("Shell commands",1)
				popup.id_pressed.connect(func(id:int):
					if id==0: open_folder(HOME+"/Help")
					else: submit_command("help"))
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left","right"]: pad.add_theme_constant_override("margin_"+side,18)
	pad.add_theme_constant_override("margin_top",12)
	pad.add_theme_constant_override("margin_bottom",12)
	terminal_column.add_child(pad)
	_terminal_scroll = ScrollContainer.new()
	_terminal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_terminal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_child(_terminal_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	_terminal_scroll.add_child(body)
	output = RichTextLabel.new()
	output.bbcode_enabled = true
	output.selection_enabled = true
	output.scroll_following = true
	output.fit_content = true
	output.scroll_active = false
	output.size_flags_vertical = Control.SIZE_FILL
	output.add_theme_font_override("normal_font",_mono)
	output.add_theme_font_override("bold_font",_mono)
	output.add_theme_font_override("mono_font",_mono)
	output.add_theme_font_size_override("normal_font_size",16)
	output.add_theme_constant_override("line_separation",4)
	body.add_child(output)
	prompt = Label.new()
	prompt.add_theme_font_override("font",_mono)
	prompt.add_theme_font_size_override("font_size",16)
	prompt.add_theme_color_override("font_color",Color("26e3c3"))
	body.add_child(prompt)
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation",7)
	body.add_child(input_row)
	var dollar := Label.new()
	dollar.text = "└─$"
	dollar.add_theme_font_override("font",_mono)
	dollar.add_theme_font_size_override("font_size",16)
	dollar.add_theme_color_override("font_color",Color("26e3c3"))
	input_row.add_child(dollar)
	command_input = LineEdit.new()
	command_input.name = "ShellInput"
	command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_input.size_flags_vertical = Control.SIZE_SHRINK_END
	command_input.add_theme_font_override("font",_mono)
	command_input.add_theme_font_size_override("font_size",16)
	command_input.add_theme_stylebox_override("normal",_style(Color(0,0,0,0)))
	command_input.add_theme_stylebox_override("focus",_style(Color(0,0,0,0)))
	command_input.add_theme_color_override("font_color",WHITE)
	command_input.add_theme_color_override("caret_color",Color.WHITE)
	command_input.add_theme_constant_override("caret_width",7)
	command_input.caret_blink = true
	command_input.max_length = 1000
	command_input.text_submitted.connect(submit_command)
	command_input.gui_input.connect(_command_key)
	input_row.add_child(command_input)
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel",_style(Color("18212b"),7))
	terminal_column.add_child(footer)
	var hint := Label.new()
	hint.text = "Tab: complete command    ↑ ↓: history    Ctrl+L: clear"
	hint.add_theme_font_override("font",_mono)
	hint.add_theme_font_size_override("font_size",11)
	hint.modulate = MUTED
	footer.add_child(hint)

func _build_file_manager() -> void:
	file_window = DesktopWindow.new()
	windows.add_child(file_window)
	file_window.configure("Help — File Manager",Rect2(32,62,708,595))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",0)
	file_window.content.add_child(column)
	var menus := HBoxContainer.new()
	menus.custom_minimum_size.y = 29
	column.add_child(menus)
	for text: String in ["File","Edit","View","Go","Help"]:
		var menu := MenuButton.new()
		menu.text = text
		menu.add_theme_font_size_override("font_size",14)
		menus.add_child(menu)
		var popup := menu.get_popup()
		if text == "Go":
			for name: String in ["Home","Evidence","Help","Reports"]: popup.add_item(name)
			popup.id_pressed.connect(func(id:int):open_folder(HOME if id==0 else HOME+"/"+["Home","Evidence","Help","Reports"][id]))
		elif text == "File":
			popup.add_item("Open selected file",0)
			popup.add_item("Close window",1)
			popup.id_pressed.connect(func(id:int):
				if id==0: _activate_file()
				else: file_window.hide())
		elif text == "Edit":
			popup.add_item("Copy selected file path",0)
			popup.id_pressed.connect(func(_id:int): DisplayServer.clipboard_set(selected_file))
		elif text == "View":
			popup.add_item("Maximize / restore",0)
			popup.add_item("Refresh",1)
			popup.id_pressed.connect(func(id:int):
				if id==0: file_window.toggle_maximize()
				else: _fill_files())
		else:
			popup.add_item("Open field guide",0)
			popup.id_pressed.connect(func(_id:int): open_folder(HOME+"/Help"))
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation",3)
	toolbar.custom_minimum_size.y = 37
	column.add_child(toolbar)
	for pair: Array in [["back",_folder_back],["forward",_folder_forward],["up",func():open_folder(file_path.get_base_dir())],["home",open_folder.bind(HOME)]]:
		var button := _button("",pair[1],pair[0])
		button.custom_minimum_size = Vector2(33,32)
		button.tooltip_text = str(pair[0]).capitalize()
		toolbar.add_child(button)
	path_input = LineEdit.new()
	path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_input.add_theme_stylebox_override("normal",_style(Color("121b25"),6,Color("374957")))
	path_input.add_theme_stylebox_override("focus",_style(Color("121b25"),6,Color("527a9d")))
	path_input.add_theme_color_override("font_color",WHITE)
	path_input.text_submitted.connect(open_folder)
	toolbar.add_child(path_input)
	toolbar.add_child(_button("",_fill_files,"refresh"))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",0)
	column.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 131
	sidebar.add_theme_constant_override("separation",2)
	body.add_child(sidebar)
	for folder: String in ["Home","Desktop","Evidence","Help","Reports"]:
		var button := _button(folder,open_folder.bind(HOME if folder=="Home" else HOME+"/"+folder),"home" if folder=="Home" else "folder")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 34
		sidebar.add_child(button)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",0)
	body.add_child(right)
	file_list = Tree.new()
	file_list.hide_root = true
	file_list.columns = 4
	file_list.column_titles_visible = true
	file_list.custom_minimum_size.y = 108
	for i: int in range(4):
		file_list.set_column_title(i,["Name","Size","Type","Modified"][i])
		file_list.set_column_expand(i,i==0)
		if i>0: file_list.set_column_custom_minimum_width(i,[0,65,110,90][i])
	file_list.add_theme_stylebox_override("panel",_style(Color("161f29"),0,Color("344451")))
	file_list.add_theme_stylebox_override("selected",_style(Color("205d9b")))
	file_list.add_theme_stylebox_override("selected_focus",_style(Color("205d9b")))
	file_list.add_theme_font_size_override("font_size",12)
	file_list.item_selected.connect(_select_file)
	file_list.item_activated.connect(_activate_file)
	right.add_child(file_list)
	file_count = Label.new()
	file_count.add_theme_font_size_override("font_size",11)
	file_count.modulate = MUTED
	right.add_child(file_count)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left",20)
	pad.add_theme_constant_override("margin_right",15)
	pad.add_theme_constant_override("margin_top",12)
	pad.add_theme_constant_override("margin_bottom",12)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(pad)
	preview = RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.selection_enabled = true
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_theme_font_size_override("normal_font_size",14)
	preview.add_theme_font_override("mono_font",_mono)
	preview.add_theme_font_size_override("mono_font_size",13)
	preview.add_theme_constant_override("line_separation",5)
	preview.meta_clicked.connect(func(meta:Variant): submit_command(str(meta)))
	pad.add_child(preview)
	file_window.hide()

func reset_session() -> void:
	terminal_text = "Campus incident response lab\nCase IR-2026-001 — The borrowed session\nAdvanced mission: [color=#55aaf0]mission start blackout[/color]\n\nStart here: [color=#55aaf0]cat ~/Help/START_HERE.md[/color]\nYour case files are in [color=#55aaf0]~/Evidence[/color]\n"
	history.clear()
	history_index = 0
	command_input.clear()
	output.text = terminal_text
	_refresh_prompt()

func focus_terminal() -> void:
	terminal_window.show()
	terminal_window.raise_window()
	command_input.grab_focus()

func _refresh_prompt() -> void:
	var path: String = shell.display_path()
	# A compact two-line prompt also fits the side-by-side reference layout.
	prompt.text = "┌─ analyst@campus-lab ["+path+"]"
	if prompt.get_minimum_size().x > terminal_window.size.x*0.62:
		prompt.text = "┌─ analyst ["+path+"]"
	terminal_window.set_title("analyst@campus-lab: "+path)

func submit_command(line: String) -> void:
	var command := line.strip_edges()
	if command in ["lab restart", "mission start blackout"]:
		for key: String in _apps.keys():
			if key.begins_with("Python: "):
				_apps[key].queue_free()
				_apps.erase(key)
	command_input.clear()
	if command.is_empty(): return
	history.append(command)
	history_index = history.size()
	history_draft = ""
	var prompt_path: String = shell.display_path()
	var result: Dictionary = shell.execute(command)
	if result.clear:
		clear_terminal()
	else:
		terminal_text += "\n[color=#26e3c3]analyst@campus-lab[/color]:[color=#55aaf0]"+_escape(prompt_path)+"[/color]$ "+_escape(command)+"\n"+str(result.text)+"\n"
		if terminal_text.length()>65000: terminal_text = terminal_text.right(55000)
		output.text = terminal_text
	_refresh_prompt()
	refresh_state()
	call_deferred("_scroll_end")
	match str(result.action):
		"editor": _open_python_editor(str(result.path))
		"report": report_requested.emit()
		"journal": journal_requested.emit()
	if str(result.action).is_empty(): command_input.grab_focus()

func clear_terminal() -> void:
	terminal_text = ""
	output.text = ""
	command_input.grab_focus()
	call_deferred("_scroll_end")

func _scroll_end() -> void:
	await get_tree().process_frame
	if is_instance_valid(_terminal_scroll): _terminal_scroll.ensure_control_visible(command_input)

func _command_key(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	match event.keycode:
		KEY_UP:
			if history_index == history.size(): history_draft = command_input.text
			history_index = maxi(0,history_index-1)
			if not history.is_empty(): command_input.text = history[history_index]
		KEY_DOWN:
			history_index = mini(history.size(),history_index+1)
			command_input.text = history_draft if history_index==history.size() else history[history_index]
		KEY_TAB:
			var candidates: Array[String] = shell.complete(command_input.text)
			if candidates.size()==1: command_input.text = candidates[0]
			elif candidates.size()>1:
				terminal_text += "\n"+"   ".join(candidates)+"\n"
				output.text = terminal_text
		KEY_L:
			if event.ctrl_pressed: clear_terminal()
			else: return
		_: return
	command_input.caret_column = command_input.text.length()
	command_input.accept_event()

func open_folder(path: String) -> void:
	var resolved: String = shell.resolve(path)
	if not shell.is_directory(resolved):
		preview.text = "[color=#e6b85c]Folder not found: "+_escape(path)+"[/color]"
		return
	file_path = resolved
	_files_opened = true
	if folder_index<0 or folder_history[folder_index]!=resolved:
		folder_history.resize(folder_index+1)
		folder_history.append(resolved)
		folder_index = folder_history.size()-1
	_fill_files()
	file_window.show()
	file_window.maximized = false
	file_window.configure(file_path.get_file()+" — File Manager",Rect2(32,60,708,596))
	terminal_window.maximized = false
	terminal_window.configure("analyst@campus-lab: "+shell.display_path(),Rect2(756,60,492,596))
	terminal_window.show()
	file_window.raise_window()

func _folder_back() -> void:
	if folder_index>0:
		folder_index-=1
		file_path=folder_history[folder_index]
		_fill_files()

func _folder_forward() -> void:
	if folder_index<folder_history.size()-1:
		folder_index+=1
		file_path=folder_history[folder_index]
		_fill_files()

func _fill_files() -> void:
	_files_guard = true
	path_input.text = file_path
	file_window.set_title(("Home" if file_path==HOME else file_path.get_file())+" — File Manager")
	file_list.clear()
	var root_item := file_list.create_item()
	var entries: Array[Dictionary] = shell.list_directory(file_path)
	entries.sort_custom(func(a:Dictionary,b:Dictionary):
		if a.name == "START_HERE.md": return true
		if b.name == "START_HERE.md": return false
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	var first: TreeItem
	for entry: Dictionary in entries:
		var item := file_list.create_item(root_item)
		item.set_text(0,entry.name)
		item.set_icon(0,load("res://assets/ui/icons/"+("folder" if entry.directory else "file")+".svg"))
		item.set_icon_max_width(0,16)
		for i: int in range(1,4): item.set_text(i,str(entry[["name","size","type","modified"][i]]))
		item.set_metadata(0,entry)
		if first==null or entry.name=="START_HERE.md": first=item
	file_count.text = "  %d %s" % [entries.size(),"guides" if file_path.ends_with("/Help") else "items"]
	_files_guard = false
	if first!=null:
		first.select(0)
		_select_file()
	else:
		selected_file = ""
		preview.text = "[color=#9caab8]This folder is empty.[/color]"

func _select_file() -> void:
	if _files_guard: return
	var item := file_list.get_selected()
	if item==null: return
	var entry: Dictionary = item.get_metadata(0)
	selected_file = str(entry.path)
	if entry.directory:
		preview.text = "[font_size=21]"+_escape(entry.name)+"[/font_size]\n\nFolder\n\nDouble-click to open."
	else:
		var document: Dictionary = shell.read_file(selected_file)
		preview.text = _markdown(str(document.text))
	preview.scroll_to_line(0)

func _activate_file() -> void:
	var item := file_list.get_selected()
	if item==null: return
	var entry: Dictionary = item.get_metadata(0)
	if entry.directory: open_folder(entry.path)
	elif str(entry.path).ends_with(".py"): _open_python_editor(str(entry.path))
	elif str(entry.path).ends_with("/Reports/incident-report.md"): report_requested.emit()
	else: _select_file()

func refresh_state() -> void:
	if is_instance_valid(file_window) and file_window.visible and not selected_file.is_empty(): _select_file()
	if is_instance_valid(_task_files): _task_files.visible = _files_opened
	if is_instance_valid(_task_terminal): _task_terminal.visible = true

func _markdown(text: String) -> String:
	var lines: Array[String] = []
	for line: String in text.split("\n"):
		var safe := _escape(line)
		if line.begins_with("# "): safe = "[font_size=22][b]"+_escape(line.substr(2))+"[/b][/font_size]"
		elif line.begins_with("## "): safe = "[font_size=17][b]"+_escape(line.substr(3))+"[/b][/font_size]"
		elif line.begins_with("Run: `"):
			var command := line.trim_prefix("Run: `").trim_suffix("`")
			safe = "Run: [color=#55aaf0][url="+command+"]"+_escape(command)+"[/url][/color]"
		elif line.contains("`"): safe = safe.replace("`","")
		if line.ends_with("✓"): safe = "[color=#76d9bc]"+safe+"[/color]"
		lines.append(safe)
	return "\n".join(lines)

func _escape(text: String) -> String:
	return text.replace("[","[lb]")

func show_document_app(title: String, content: Control) -> void:
	var window: Panel
	if _apps.has(title): window = _apps[title]
	else:
		window = DesktopWindow.new()
		windows.add_child(window)
		window.configure(title,Rect2(195,68,920,574))
		for side: String in ["left","right"]: window.content.add_theme_constant_override("margin_"+side,16)
		for side: String in ["top","bottom"]: window.content.add_theme_constant_override("margin_"+side,10)
		_apps[title] = window
		var task := _button(title,func():window.show();window.raise_window(),"file")
		task.position = Vector2(488+_app_tasks.size()*154,0)
		task.size = Vector2(150,36)
		task.add_theme_font_size_override("font_size",11)
		_bottom_bar.add_child(task)
		_app_tasks[title] = task
		_simulation_label.hide()
	if content.get_parent()!=window.content: content.reparent(window.content)
	content.show()
	window.show()
	window.raise_window()

func _switch_workspace(index: int) -> void:
	var current: Array[Control] = []
	for window: Control in windows.get_children():
		if window.visible: current.append(window)
		window.hide()
	_workspace_windows[_workspace] = current
	_workspace = index
	for window: Control in _workspace_windows.get(index,[]): window.show()
	_update_workspace_buttons()
	refresh_state()

func _update_workspace_buttons() -> void:
	for i: int in range(_workspace_buttons.size()):
		_workspace_buttons[i].add_theme_stylebox_override("normal",_style(Color("215e9d") if i+1==_workspace else Color(0,0,0,0),5))

func _process(_delta: float) -> void:
	if not visible: return
	if is_instance_valid(_clock):
		var now: Dictionary = Time.get_time_dict_from_system()
		var value := "%02d:%02d" % [int(now.hour),int(now.minute)]
		if value!=_last_clock:
			_clock.text = value
			_last_clock = value
	if is_instance_valid(_task_files): _task_files.visible = _files_opened
	if is_instance_valid(_task_terminal): _task_terminal.visible = true

func _open_python_editor(path: String) -> void:
	var key := "Python: " + path.get_file()
	if _apps.has(key):
		_apps[key].show()
		_apps[key].raise_window()
		return
	var window := DesktopWindow.new()
	windows.add_child(window)
	window.configure(key, Rect2(180,65,930,585))
	_apps[key] = window
	var layout := VBoxContainer.new()
	window.content.add_child(layout)
	var label := Label.new()
	label.text = "Python lab · print candidates · Save / Run writes ~/Documents/candidates.txt"
	layout.add_child(label)
	var editor := CodeEdit.new()
	editor.name = "PythonEditor"
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.add_theme_font_override("font",_mono)
	editor.add_theme_font_size_override("font_size",16)
	editor.text = str(shell.read_file(path).text)
	editor.indent_size = 4
	editor.indent_use_spaces = true
	layout.add_child(editor)
	var row := HBoxContainer.new()
	layout.add_child(row)
	var feedback := Label.new()
	row.add_child(_button("Save",func():
		feedback.text = "Saved" if shell.save_script(path,editor.text) else "Save failed: 12 KB maximum."
	))
	row.add_child(_button("Save / Run",func():
		if shell.save_script(path,editor.text):
			submit_command("python3 " + path + " > ~/Documents/candidates.txt")
			feedback.text = "Result is in Terminal"
		else: feedback.text = "Save failed: 12 KB maximum."
	))
	row.add_child(feedback)
	editor.grab_focus()
