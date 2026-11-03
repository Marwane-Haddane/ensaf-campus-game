extends RefCounted
## Saved/draft/live are separate. Risky display changes commit only after Keep.
const KEYS := {"move_forward":[KEY_W,KEY_Z,KEY_UP],"move_back":[KEY_S,KEY_DOWN],
	"move_left":[KEY_A,KEY_Q,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"run":[KEY_SHIFT],
	"jump":[KEY_SPACE],"interact":[KEY_E],"destinations":[KEY_TAB],"response_plan":[KEY_J],"pause":[KEY_ESCAPE]}
const ALIASES := {"move_backward":"move_back","sprint":"run","campus_guide":"destinations"}
const RESOLUTIONS := ["1280x720","1920x1080","1600x900"]
var path := "user://ensagames/preferences.cfg"
var saved: Dictionary = {}
var draft: Dictionary = {}
var errors: Array[String] = []
var confirmation_pending := false
var confirmation_deadline := 0
var window_backup: Dictionary = {}
var message := ""

static func defaults() -> Dictionary:
	return {"resolution":"1280x720","fullscreen":false,"graphics_preset":"medium","frame_cap":60,"vsync":true,
	"master_volume":80.0,"music_volume":50.0,"sfx_volume":85.0,"mouse_sensitivity":1.0,
	"language":"en","subtitles":false,"reduced_motion":false,"ui_scale":1.0,"bindings":KEYS.duplicate(true)}

func initialize(apply_live: bool = true) -> void:
	saved = defaults()
	var config := ConfigFile.new()
	var result := config.load(path)
	if result == OK and int(config.get_value("meta","version",0)) == 1:
		var proposed := defaults()
		for key: String in proposed:
			proposed[key] = config.get_value("preferences",key,proposed[key])
		if validate(proposed).is_empty(): saved = proposed
		else: message = "Invalid preferences were reset to safe defaults."
	elif result != ERR_FILE_NOT_FOUND:
		message = "Preferences could not be read; safe defaults are active."
	draft = saved.duplicate(true)
	if apply_live: apply_runtime(saved)

func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if not str(data.get("resolution","")) in RESOLUTIONS: problems.append("Choose a supported resolution.")
	if not str(data.get("graphics_preset","")) in ["low","medium","high"]: problems.append("Choose a supported graphics preset.")
	if not data.get("frame_cap",-1) in [0,30,60]: problems.append("Choose 30, 60 or unlimited FPS.")
	for key: String in ["fullscreen","vsync","subtitles","reduced_motion"]:
		if not data.get(key) is bool: problems.append("Invalid preference: "+key)
	for key: String in ["master_volume","music_volume","sfx_volume","mouse_sensitivity","ui_scale"]:
		var val: Variant = data.get(key)
		if not (val is int or val is float) or not is_finite(float(val)):
			problems.append("Invalid numeric preference: "+key)
			continue
		var bounds := Vector2(.5,3.0) if key == "mouse_sensitivity" else Vector2(0,100)
		if key == "ui_scale": bounds = Vector2(1,1)
		if float(val)<bounds.x or float(val)>bounds.y: problems.append("Preference out of range: "+key)
	if data.get("language","") != "en": problems.append("Only the supplied English translation is available.")
	var bindings: Variant = data.get("bindings")
	if not bindings is Dictionary: problems.append("Invalid key bindings.")
	else:
		var occupied: Dictionary = {}
		for action: String in KEYS:
			var codes: Variant = bindings.get(action,[])
			if not codes is Array or codes.is_empty():
				problems.append("A key is required for "+action)
				continue
			for code: Variant in codes:
				if not code is int or int(code)<=0: problems.append("Invalid key for "+action)
				elif occupied.has(code) and occupied[code] != action: problems.append("Key conflict: "+OS.get_keycode_string(code))
				occupied[code] = action
		if bindings.get("pause",[]) != [KEY_ESCAPE]: problems.append("Escape remains available for pause and recovery.")
	return problems

func edit(key: String, value: Variant) -> void:
	if confirmation_pending or not draft.has(key) or key == "bindings": return
	draft[key] = value
	errors = validate(draft)
	# Audio can be previewed and is reverted on Cancel. Display waits for Apply.
	if key.ends_with("_volume") and errors.is_empty(): _apply_audio(draft)

func bind(action: String, code: int) -> void:
	action = str(ALIASES.get(action,action))
	if action not in KEYS or action == "pause":
		errors = ["Escape is reserved for pause and recovery."]
		return
	var candidate: Dictionary = draft.duplicate(true)
	candidate.bindings[action] = [code]
	errors = validate(candidate)
	if errors.is_empty(): draft = candidate

func restore_defaults() -> void:
	if confirmation_pending: return
	draft = defaults()
	errors.clear()

func cancel() -> void:
	if confirmation_pending: revert_display()
	draft = saved.duplicate(true)
	errors.clear()
	_apply_audio(saved)

func apply(allow_display: bool = true) -> bool:
	if confirmation_pending: return false
	errors = validate(draft)
	if not errors.is_empty(): return false
	var display_changed: bool = draft.fullscreen != saved.fullscreen or draft.resolution != saved.resolution
	if display_changed and allow_display and DisplayServer.get_name() != "headless":
		window_backup = {"mode":DisplayServer.window_get_mode(),"size":DisplayServer.window_get_size(),"position":DisplayServer.window_get_position()}
		confirmation_pending = true
		confirmation_deadline = Time.get_ticks_msec()+15000
		apply_runtime(draft)
		return true
	return _commit()

func confirm_display() -> bool:
	if not confirmation_pending: return false
	return _commit()

func _commit() -> bool:
	var config := ConfigFile.new()
	config.set_value("meta","version",1)
	for key: String in draft: config.set_value("preferences",key,draft[key])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var result := config.save(path+".tmp")
	if result == OK: result = DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
	if result != OK:
		errors = ["Preferences could not be saved ("+str(result)+"). Previous settings remain active."]
		if confirmation_pending: revert_display()
		else: apply_runtime(saved)
		return false
	saved = draft.duplicate(true)
	confirmation_pending = false
	apply_runtime(saved)
	return true

func revert_display() -> void:
	confirmation_pending = false
	apply_runtime(saved)
	if not window_backup.is_empty() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(window_backup.mode)
		DisplayServer.window_set_size(window_backup.size)
		DisplayServer.window_set_position(window_backup.position)
	window_backup.clear()
	draft = saved.duplicate(true)

func tick() -> bool:
	if confirmation_pending and Time.get_ticks_msec()>=confirmation_deadline:
		revert_display()
		return true
	return false

func apply_runtime(data: Dictionary) -> void:
	Engine.max_fps = int(data.frame_cap)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not data.fullscreen:
			var parts: PackedStringArray = str(data.resolution).split("x")
			DisplayServer.window_set_size(Vector2i(int(parts[0]),int(parts[1])))
	var viewport := Engine.get_main_loop().root as Window
	viewport.msaa_3d = {"low":Viewport.MSAA_DISABLED,"medium":Viewport.MSAA_2X,"high":Viewport.MSAA_4X}[data.graphics_preset]
	_apply_audio(data)
	for action: String in KEYS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for code: int in data.bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action,event)
	TranslationServer.set_locale("en")

func _apply_audio(data: Dictionary) -> void:
	for bus: String in ["Master","Music","SFX"]:
		var index := AudioServer.get_bus_index(bus)
		if index<0:
			AudioServer.add_bus()
			index = AudioServer.bus_count-1
			AudioServer.set_bus_name(index,bus)
			AudioServer.set_bus_send(index,"Master")
		var volume: float = float(data[bus.to_lower()+"_volume"])
		AudioServer.set_bus_mute(index,volume<=0)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(volume/100.0,.0001)))

func model() -> Dictionary:
	return {"saved":saved.duplicate(true),"draft":draft.duplicate(true),"dirty":draft != saved,"validation_errors":errors.duplicate(),
	"display_confirmation_required":confirmation_pending,"display_confirmation_seconds_remaining":maxi(0,ceili((confirmation_deadline-Time.get_ticks_msec())/1000.0)),
	"capabilities":{"languages":["en"],"spoken_content":false,"music_content":false,"ui_scale":false},"message":message}

func hints() -> Array:
	var result: Array = []
	for action: String in KEYS:
		var names: PackedStringArray = []
		for code: int in saved.bindings[action]: names.append(OS.get_keycode_string(code))
		result.append({"action":action.replace("_"," ").capitalize(),"binding":" / ".join(names),"label":action})
	return result
