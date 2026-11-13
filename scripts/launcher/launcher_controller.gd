extends Node
## Lightweight app root. No world scripts or GLBs are dependencies of this scene.
const State = preload("res://scripts/launcher/boot_state.gd")
const Registry = preload("res://scripts/launcher/mode_registry.gd")
const Settings = preload("res://scripts/launcher/settings_store.gd")
const Saves = preload("res://scripts/launcher/save_store.gd")
const Services = preload("res://scripts/launcher/mode_services.gd")
const Loader = preload("res://scripts/launcher/mission_loader.gd")
const Fallback = preload("res://scripts/launcher/fallback_view.gd")
var state = State.new()
var settings = Settings.new()
var saves = Saves.new()
var saves_mode := "incident_response"
var loader: Node
var view: Control
var game: Node3D
var session_adapter: RefCounted
var mode_services = Services.new()
var registration_path := Registry.REGISTRATION_PATH
var page := "boot"
var current_request := ""
var selected_mode := "incident_response"
var selected_mission := "IR-2026-001"
var pending_checkpoint: Dictionary = {}
var continue_data: Dictionary = {}
var case_summary: Dictionary = {}
var error_data: Dictionary = {}
var loading_data: Dictionary = {}
var capturing_action := ""
var initialized := false
var _canvas: CanvasLayer
var _storyboard: Control
var _boot: Control
var _boot_status: Label
var _boot_logo: TextureRect
var _boot_pulse: Control
var _refresh_due := 0.0
var _load_started := 0
var _stage_started := 0
var _last_stage := ""
var _autosave_due := 0.0
var _autosave_dirty := false
var _tone: AudioStreamPlayer
var _feedback: Label
var _feedback_seconds := 0.0
var _boot_started := 0
var metrics := {"boot_first_frame_ms":0.0,"menu_interactive_ms":0.0,"max_frame_gap_ms":0.0,"stages":{}}
var _last_frame_usec := 0
var test_preferences_path := ""
var test_save_path := ""

class BootPulse extends Control:
	var angle := 0.0
	var reduced_motion := false
	func _process(delta: float) -> void:
		if not reduced_motion: angle += delta*2.5
		queue_redraw()
	func _draw() -> void:
		draw_arc(size*.5,18,0.0 if reduced_motion else angle,TAU if reduced_motion else angle+4.7,32,Color("6fe8d1"),2.0,true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_boot_started = Time.get_ticks_usec()
	get_tree().auto_accept_quit = false
	get_tree().root.disable_3d = true
	DisplayServer.window_set_title("ENSA Games")
	_build_boot()
	_initialize.call_deferred()

func _build_boot() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	add_child(_canvas)
	_boot = Control.new()
	_boot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(_boot)
	var background := ColorRect.new()
	background.color = Color("0b1724")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boot.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boot.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	center.add_child(column)
	_boot_logo = TextureRect.new()
	_boot_logo.custom_minimum_size = Vector2(96,96)
	_boot_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boot_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_boot_logo)
	var title := Label.new()
	title.text = "ENSA GAMES"
	title.add_theme_font_size_override("font_size",36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var pulse := BootPulse.new()
	_boot_pulse = pulse
	pulse.custom_minimum_size = Vector2(48,48)
	column.add_child(pulse)
	_boot_status = Label.new()
	_boot_status.text = "Starting the launcher…"
	_boot_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_boot_status)
	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(_quit)
	column.add_child(quit_button)
	_feedback = Label.new()
	_feedback.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_feedback.offset_left = -580
	_feedback.offset_right = -24
	_feedback.offset_top = 16
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feedback.add_theme_color_override("font_color",Color("ffd08a"))
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback.z_index = 100
	_canvas.add_child(_feedback)

func _initialize() -> void:
	# Give the minimal UI an actual rendered frame before any optional art loads.
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": RenderingServer.force_draw(false)
	metrics.boot_first_frame_ms = (Time.get_ticks_usec()-_boot_started)/1000.0
	state.change("INITIALIZING")
	_boot_status.text = "Reading preferences and available modes…"
	if not test_preferences_path.is_empty(): settings.path = test_preferences_path
	if not test_save_path.is_empty(): saves.path = test_save_path
	mode_services.registration_path = registration_path
	mode_services.test_save_path = test_save_path
	var initial_saves: RefCounted = mode_services.save_for("incident_response")
	if initial_saves != null: saves = initial_saves
	settings.initialize()
	_boot_pulse.reduced_motion = settings.saved.reduced_motion
	if ResourceLoader.exists("res://assets/launcher/ensa-emblem-white.svg"):
		_boot_logo.texture = load("res://assets/launcher/ensa-emblem-white.svg") as Texture2D
	_load_recent_mode()
	_refresh_continue()
	loader = Loader.new()
	loader.services = mode_services
	loader.name = "MissionLoader"
	add_child(loader)
	loader.progress_changed.connect(_on_loading_progress)
	loader.mission_ready.connect(_on_mission_ready)
	loader.failed.connect(_on_loading_failed)
	_build_feedback_tone()
	# A complete fallback menu is ready even if the optional view fails to load.
	view = Fallback.new()
	_canvas.add_child(view)
	view.intent_requested.connect(_on_view_intent)
	view.hide()
	_boot_status.text = "Preparing the launcher interface…"
	var scene_path := "res://scenes/antigravity/launcher/launcher_view.tscn"
	if ResourceLoader.exists(scene_path):
		var result := ResourceLoader.load_threaded_request(scene_path,"PackedScene")
		if result == OK:
			var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS
			while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				status = ResourceLoader.load_threaded_get_status(scene_path)
				await get_tree().process_frame
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
				var candidate: Control = scene.instantiate() as Control if scene != null else null
				if candidate != null:
					var adapter := load("res://scripts/launcher/launcher_view_adapter.gd") as GDScript
					if adapter != null and adapter.can_instantiate(): candidate.set_script(adapter)
					_canvas.add_child(candidate)
					if candidate.has_signal("intent_requested") and candidate.has_method("get_contract_version") and candidate.get_contract_version()==1:
						view.queue_free()
						view = candidate
						view.intent_requested.connect(_on_view_intent)
					else: candidate.queue_free()
	_boot.queue_free()
	_boot = null
	initialized = true
	state.change("MAIN_MENU")
	page = "home"
	view.show()
	_refresh()
	view.focus_primary.call_deferred()
	metrics.menu_interactive_ms = (Time.get_ticks_usec()-_boot_started)/1000.0
	print("ENSA_LAUNCHER_READY ",JSON.stringify(metrics)," campus_requested=",not loader.retained_resources.is_empty())
	if not settings.message.is_empty(): _notify(settings.message)
	if not saves.last_error.is_empty(): _notify(saves.last_error)
	# Preserve explicit developer smoke/preview paths; normal startup never loads this.
	if "--smoke-test" in OS.get_cmdline_user_args() or "--preview" in OS.get_cmdline_user_args():
		view.hide()
		get_tree().root.disable_3d = false
		var direct: Node = load("res://main.tscn").instantiate()
		add_child(direct)

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_frame_usec>0:
		var gap: float = (now-_last_frame_usec)/1000.0
		metrics.max_frame_gap_ms = maxf(metrics.max_frame_gap_ms,gap)
		var stage: String = state.value+"/"+str(loading_data.get("stage_id",""))
		metrics.stages[stage] = maxf(float(metrics.stages.get(stage,0.0)),gap)
	_last_frame_usec = now
	if not initialized: return
	_refresh_due -= delta
	if settings.tick():
		_notify("Display changes reverted.")
		_refresh()
	if _feedback_seconds>0:
		_feedback_seconds -= delta
		if _feedback_seconds<=0: _feedback.text = ""
	if state.value == "LOADING_GAME":
		loading_data.elapsed_seconds = (Time.get_ticks_msec()-_load_started)/1000.0
		loading_data.still_preparing = Time.get_ticks_msec()-_stage_started>10000
	if _refresh_due<=0 and (state.value == "LOADING_GAME" or settings.confirmation_pending):
		_refresh_due = .10
		_refresh()
	if state.value == "PLAYING" and is_instance_valid(game):
		_autosave_due -= delta
		if _autosave_dirty and _autosave_due<=0: _save_checkpoint()

func _model() -> Dictionary:
	var mission := Registry.mission_for(selected_mode,selected_mission,registration_path)
	mission.controls = mission.get("controls",settings.hints())
	if mission.controls.is_empty(): mission.controls = settings.hints()
	mission.mode_title = Registry.find_mode(selected_mode,registration_path).get("title",selected_mode)
	return {"contract_version":1,"state":state.value,"page":page,"brand":"ENSA Games","modes":Registry.entries(registration_path),
	"selected_mode_id":selected_mode,"mission":mission,"continue":continue_data,"loading":loading_data,"error":error_data,
	"settings":settings.model(),"preferences":settings.draft if page == "settings" else settings.saved,
	"control_hints":settings.hints(),"development_build":OS.is_debug_build() and "--launcher-debug" in OS.get_cmdline_user_args(),"capturing_action":capturing_action,
	"case_summary":case_summary,"brand_assets":{"logo_path":"res://assets/launcher/ensa-emblem-white.svg","background_path":"res://assets/launcher/campus-dusk-reference.png","case_image_path":"res://assets/launcher/case-workstation.png"}}

func _refresh() -> void:
	if is_instance_valid(view): view.present(_model())

func _on_view_intent(action: StringName, payload: Dictionary) -> void:
	if action == &"quit":
		_quit()
		return
	if not initialized: return
	if is_instance_valid(_storyboard): return
	if settings.confirmation_pending and action not in [&"confirm_display",&"revert_display"]: return
	if state.value == "LOADING_GAME" and action not in [&"cancel_loading"]: return
	match action:
		&"play", &"show_modes":
			if state.value != "MAIN_MENU" and state.value != "SELECT_MODE": return
			state.change("SELECT_MODE")
			page = "briefing" if action == &"play" else "modes"
			if action == &"play":
				selected_mode = "incident_response"
				selected_mission = "IR-2026-001"
		&"select_mode", &"show_briefing":
			var mode_id: String = str(payload.get("mode_id",""))
			var mission_id: String = str(payload.get("mission_id",Registry.default_mission(mode_id,registration_path)))
			if state.value not in ["MAIN_MENU","SELECT_MODE"] or not Registry.can_launch(mode_id,mission_id,registration_path): return
			selected_mode = mode_id
			selected_mission = mission_id
			state.change("SELECT_MODE")
			page = "briefing"
		&"start_mission":
			if state.value not in ["MAIN_MENU","SELECT_MODE"] or not Registry.can_launch(str(payload.get("mode_id","")),str(payload.get("mission_id","")),registration_path): return
			pending_checkpoint = {}
			selected_mode = str(payload.get("mode_id",""))
			selected_mission = str(payload.get("mission_id",""))
			if (selected_mode == "zombie_rpg" and selected_mission == "ZB-2026-001") or (selected_mode == "incident_response" and selected_mission == "IR-2026-001"):
				_show_mission_storyboard()
			else:
				_start_mission()
		&"continue_game":
			if state.value != "MAIN_MENU" or not continue_data.get("available",false): return
			var continue_saves: RefCounted = mode_services.save_for(str(continue_data.get("mode_id","")))
			if continue_saves == null:
				_notify(mode_services.last_error)
				return
			pending_checkpoint = mode_services.checkpoint_for(str(continue_data.get("mode_id","")))
			if pending_checkpoint.is_empty():
				_refresh_continue()
				_notify(continue_saves.last_error)
			else:
				selected_mode = str(pending_checkpoint.get("mode_id","incident_response"))
				selected_mission = str(pending_checkpoint.get("mission_id","IR-2026-001"))
				if Registry.can_launch(selected_mode,selected_mission,registration_path): _start_mission()
		&"cancel_loading":
			if state.value != "LOADING_GAME" or str(payload.get("request_id","")) != current_request: return
			loader.cancel(current_request)
			state.change("CANCELLED")
			_return_home()
		&"retry_loading":
			if state.value != "ERROR" or str(payload.get("request_id","")) != current_request: return
			state.change("SELECT_MODE")
			_start_mission()
		&"enter_game":
			if state.value != "READY" or str(payload.get("request_id","")) != current_request or not is_instance_valid(game): return
			_enter_game()
		&"return_to_menu":
			if state.value == "READY": state.change("CANCELLED")
			_return_home()
		&"show_settings":
			if state.value not in ["MAIN_MENU","SELECT_MODE","PLAYING"]: return
			page = "settings"
			if is_instance_valid(game): _set_game_input(false)
			view.show()
			view.set_process_unhandled_input(true)
		&"show_how_to_play", &"show_credits":
			if state.value not in ["MAIN_MENU","SELECT_MODE"]: return
			page = "how_to_play" if action == &"show_how_to_play" else "credits"
		&"edit_setting":
			if page != "settings": return
			settings.edit(str(payload.get("key","")),payload.get("value"))
		&"set_preferences_preview":
			if page == "settings": view.set_preferences_preview(settings.draft)
		&"capture_binding":
			if page != "settings": return
			capturing_action = str(Settings.ALIASES.get(payload.get("action",""),payload.get("action","")))
			if capturing_action == "pause":
				capturing_action = ""
				settings.errors = ["Escape remains reserved for recovery."]
		&"apply_settings":
			if page != "settings": return
			capturing_action = ""
			if settings.apply() and not settings.confirmation_pending:
				_apply_to_game()
				_notify("Preferences saved.")
		&"confirm_display":
			if settings.confirm_display():
				_apply_to_game()
				_notify("Display and preferences saved.")
		&"revert_display": settings.revert_display()
		&"cancel_settings":
			capturing_action = ""
			settings.cancel()
		&"restore_defaults": settings.restore_defaults()
		&"back":
			if page == "settings" and (settings.draft != settings.saved or not settings.errors.is_empty()): return
			if state.value == "PLAYING":
				view.hide()
				view.set_process_unhandled_input(false)
				_set_game_input(true)
				page = "home"
			else:
				state.change("MAIN_MENU")
				page = "home"
		_:
			return
	_play_tone()
	_refresh()

func _input(event: InputEvent) -> void:
	if capturing_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode != KEY_ESCAPE:
		settings.bind(capturing_action,event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	capturing_action = ""
	get_viewport().set_input_as_handled()
	_refresh()

func _show_mission_storyboard() -> void:
	var script_path := "res://scripts/launcher/cyber_storyboard.gd" if selected_mode == "incident_response" else "res://scripts/launcher/zombie_storyboard.gd"
	var story_script := load(script_path) as Script
	_storyboard = story_script.new()
	view.hide()
	view.set_process_unhandled_input(false)
	_storyboard.finished.connect(_finish_mission_storyboard)
	_canvas.add_child(_storyboard)

func _finish_mission_storyboard() -> void:
	_storyboard.hide()
	_storyboard.queue_free()
	_storyboard = null
	view.show()
	view.set_process_unhandled_input(true)
	_start_mission()

func _start_mission() -> void:
	if state.value == "MAIN_MENU": state.change("SELECT_MODE")
	if not state.change("LOADING_GAME"): return
	get_tree().paused = false
	error_data.clear()
	page = "loading"
	_load_started = Time.get_ticks_msec()
	_stage_started = _load_started
	current_request = loader.start(settings.saved,selected_mode)
	loading_data = {"request_id":current_request,"stage_id":"request","stage_label":"Requesting the mission resources","completed_units":null,"total_units":null,"resource_progress":null,"can_cancel":true,"still_preparing":false,"elapsed_seconds":0.0}
	_refresh()

func _on_loading_progress(data: Dictionary) -> void:
	if state.value != "LOADING_GAME" or data.request_id != current_request: return
	if data.stage_id != _last_stage:
		_stage_started = Time.get_ticks_msec()
		_last_stage = data.stage_id
	loading_data = data

func _on_mission_ready(loaded_game: Node3D, id: String) -> void:
	if state.value != "LOADING_GAME" or id != current_request:
		loader.dispose_session(loaded_game)
		return
	game = loaded_game
	session_adapter = loader.current_adapter
	var mode_save_service: RefCounted = session_adapter.save_service()
	saves = mode_save_service
	saves_mode = selected_mode
	if not pending_checkpoint.is_empty() and not session_adapter.restore(game,pending_checkpoint):
		_on_loading_failed("The checkpoint could not be restored.",saves.last_error,id)
		loader.dispose_session(game)
		game = null
		return
	# Restoring a mode may refresh UI or input internally. Ready always restores
	# the launcher-owned frozen boundary until intentional Enter.
	session_adapter.freeze(game)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	session_adapter.connect_events(game,_return_home,func():_on_view_intent(&"show_settings",{}),func():
		_autosave_dirty = true
		_autosave_due = .5)
	state.change("READY")
	page = "ready"
	loading_data.stage_label = "Campus ready"
	loading_data.can_cancel = false
	_refresh()
	print("ENSA_MISSION_READY ",id," elapsed_ms=",Time.get_ticks_msec()-_load_started)

func _on_loading_failed(message: String, diagnostic: String, id: String) -> void:
	if id != current_request or state.value != "LOADING_GAME": return
	state.change("ERROR")
	get_tree().paused = false
	get_tree().root.disable_3d = true
	page = "error"
	error_data = {"code":"MISSION_LOAD_FAILED","message":message,"diagnostic":diagnostic,"retry_allowed":true,"return_allowed":true}
	push_warning("ENSA_LOAD_FAILED request=%s stage=%s detail=%s" % [id,loading_data.get("stage_id",""),diagnostic])
	_refresh()

func _enter_game() -> void:
	if not state.change("PLAYING"): return
	get_tree().paused = false
	get_tree().root.disable_3d = false
	view.hide()
	view.set_process_unhandled_input(false)
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	session_adapter.start(game)
	_save_checkpoint()

func _set_game_input(enabled: bool) -> void:
	if not is_instance_valid(game): return
	session_adapter.set_input(game,enabled)

func _return_home() -> void:
	if state.value == "LOADING_GAME": return
	if is_instance_valid(game):
		if state.value == "PLAYING": _save_checkpoint()
		session_adapter.set_input(game,false)
		game.set_process_mode(Node.PROCESS_MODE_DISABLED)
		loader.dispose_session(game)
		game = null
	# A mode may use SceneTree.paused for inventory/death/pause. It cannot leave
	# that global state behind after its session has relinquished ownership.
	get_tree().paused = false
	if settings.confirmation_pending: settings.revert_display()
	settings.cancel()
	capturing_action = ""
	if state.value == "SELECT_MODE" or state.value == "PLAYING" or state.value == "ERROR" or state.value == "CANCELLED": state.change("MAIN_MENU")
	page = "home"
	get_tree().root.disable_3d = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_title("ENSA Games")
	_refresh_continue()
	view.show()
	view.set_process_unhandled_input(true)
	_refresh()
	view.focus_primary.call_deferred()

func _refresh_continue() -> void:
	var checkpoint: Dictionary = mode_services.checkpoint_for(saves_mode)
	continue_data = {"available":not checkpoint.is_empty() and Registry.can_launch(str(checkpoint.get("mode_id","")),str(checkpoint.get("mission_id","")),registration_path),"mode_id":checkpoint.get("mode_id","incident_response"),"mission_id":checkpoint.get("mission_id","IR-2026-001"),"summary":Services.summary_text(saves,checkpoint)}
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://design/incident.json"))
	var cyber_saves: RefCounted = mode_services.save_for("incident_response")
	var cyber_checkpoint: Dictionary = mode_services.checkpoint_for("incident_response") if cyber_saves != null else {}
	var flags: Dictionary = cyber_checkpoint.get("training",{}).get("state",{})
	var completed := 0
	for step: Dictionary in authored.get("steps",[]):
		if bool(flags.get(step.get("completion_flag",""),false)): completed += 1
	case_summary = {"id":"IR-2026-001","title":"The borrowed session","status":"Investigation pending" if completed==0 else ("Case resolved" if completed==7 else "Response in progress"),"completed":completed,"total":7,"objective":"Find the marked workstation"}
	if completed>0:
		case_summary.objective = "Case completed"
		for step: Dictionary in authored.get("steps",[]):
			if not bool(flags.get(step.get("completion_flag",""),false)):
				case_summary.objective = str(step.get("title","Continue the response"))
				break

func _save_checkpoint() -> void:
	if not is_instance_valid(game) or session_adapter == null or not session_adapter.is_ready(game): return
	_autosave_dirty = false
	var checkpoint: Dictionary = session_adapter.capture(game)
	if checkpoint.get("mode_id","") != selected_mode or checkpoint.get("mission_id","") != selected_mission:
		_notify("The mode returned an incompatible checkpoint; the previous save was preserved.")
		return
	if not saves.write_save(checkpoint): _notify(saves.last_error)
	else:
		var recent := ConfigFile.new()
		recent.set_value("session","mode_id",selected_mode)
		recent.set_value("session","mission_id",selected_mission)
		recent.save(_recent_path())

func _recent_path() -> String:
	return test_save_path.get_basename()+"-last-session.cfg" if not test_save_path.is_empty() else "user://ensagames/last-session.cfg"

func _load_recent_mode() -> void:
	var recent := ConfigFile.new()
	if recent.load(_recent_path()) != OK: return
	var id: String = str(recent.get_value("session","mode_id",""))
	var mission_id: String = str(recent.get_value("session","mission_id",""))
	if id == "incident_response" or not Registry.can_launch(id,mission_id,registration_path): return
	var recent_saves: RefCounted = mode_services.save_for(id)
	if recent_saves != null:
		saves = recent_saves
		saves_mode = id

func _apply_to_game() -> void:
	if is_instance_valid(game): session_adapter.apply_preferences(game,settings.saved)
	view.set_preferences_preview(settings.saved)

func _notify(message: String) -> void:
	_feedback.text = message
	_feedback_seconds = 8.0
	if not message.is_empty(): print("ENSA_NOTICE ",message)

func _build_feedback_tone() -> void:
	# Original, quiet UI sound. Music and SFX remain independent buses.
	var samples := PackedByteArray()
	for idx: int in range(2205):
		var envelope: float = pow(1.0-idx/2205.0,3.0)
		var value: int = int(sin(TAU*580.0*idx/44100.0)*envelope*900.0)
		samples.append(value & 255)
		samples.append((value>>8)&255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.data = samples
	_tone = AudioStreamPlayer.new()
	_tone.stream = stream
	_tone.bus = "SFX"
	add_child(_tone)

func _play_tone() -> void:
	if is_instance_valid(_tone): _tone.play()

func _quit() -> void:
	if is_instance_valid(game) and state.value == "PLAYING": _save_checkpoint()
	if is_instance_valid(loader): loader.cancel(current_request)
	if settings.confirmation_pending: settings.revert_display()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _quit()
