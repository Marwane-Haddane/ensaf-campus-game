extends Node
## One resource request at a time. Cancellation invalidates ownership and drains
## ResourceLoader safely; Godot 4.3 has no general threaded-load cancel API.
signal progress_changed(data: Dictionary)
signal mission_ready(game: Node3D, request_id: String)
signal failed(message: String, diagnostic: String, request_id: String)
const Registry = preload("res://scripts/launcher/mode_registry.gd")
const Services = preload("res://scripts/launcher/mode_services.gd")
var services: RefCounted
var request_id := ""
var _generation := 0
var _worker_busy := false
var _building_game: Node3D
var retained_resources: Dictionary = {}
var latest: Dictionary = {}
var metrics: Array[Dictionary] = []
var resource_paths: Array[String] = Registry.asset_paths()
var test_frame_gate := false
var _disposing := 0
var current_adapter: RefCounted

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func dispose_session(game: Node3D) -> void:
	if not is_instance_valid(game) or game.has_meta("launcher_disposing"): return
	game.set_meta("launcher_disposing",true)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.hide()
	for layer: Node in game.find_children("*","CanvasLayer",true,false):
		(layer as CanvasLayer).hide()
	_disposing += 1
	_dispose_incrementally(game)

func _dispose_incrementally(game: Node3D) -> void:
	# Free descendants in a bounded post-order walk. queue_free() on an entire
	# campus made the return-to-menu frame stall while destroying 8,000+ nodes.
	var stack: Array[Node] = [game]
	var started := Time.get_ticks_usec()
	while not stack.is_empty():
		var node: Node = stack.back()
		if node.get_child_count()>0:
			stack.append(node.get_child(node.get_child_count()-1))
		else:
			stack.pop_back()
			node.free()
		if Time.get_ticks_usec()-started>4000:
			await get_tree().process_frame
			started = Time.get_ticks_usec()
	_disposing -= 1

func start(preferences: Dictionary, mode_id: String = "incident_response") -> String:
	_generation += 1
	request_id = "REQ-%d" % _generation
	_run(_generation,request_id,preferences.duplicate(true),mode_id)
	return request_id

func cancel(id: String) -> void:
	if id != request_id: return
	_generation += 1
	# Invalidating ownership is always immediate. Construction coroutines must
	# be drained before freeing their nodes. Opt into cooperative cancellation
	# only when the adapter guarantees its completion flag means fully drained.
	if is_instance_valid(_building_game) and current_adapter != null and current_adapter.has_method("supports_cooperative_cancellation") and current_adapter.supports_cooperative_cancellation():
		current_adapter.cancel(_building_game)

func _stage(id: String, label: String, stage: String, completed: Variant = null, total: Variant = null, fraction: Variant = null) -> void:
	latest = {"request_id":id,"stage_id":stage,"stage_label":label,"completed_units":completed,"total_units":total,
	"resource_progress":fraction,"can_cancel":true,"still_preparing":false,"elapsed_seconds":0.0}
	metrics.append({"stage":stage,"usec":Time.get_ticks_usec(),"request_id":id})
	progress_changed.emit(latest.duplicate(true))

func _run(generation: int, id: String, preferences: Dictionary, mode_id: String) -> void:
	# Return the ID before any completion/intent can race the controller.
	await get_tree().process_frame
	_stage(id,"Finishing the previous asset request","waiting")
	while _worker_busy or _disposing>0:
		await get_tree().process_frame
		if generation != _generation: return
	if generation != _generation: return
	_worker_busy = true
	if services == null: services = Services.new()
	var mode: Dictionary = Registry.find_mode(mode_id,services.registration_path)
	var adapter: RefCounted = services.adapter_for(mode_id)
	if adapter == null:
		_worker_busy = false
		failed.emit("The game-mode adapter is incompatible or unavailable.",services.last_error,id)
		return
	current_adapter = adapter
	# Tests may substitute resource_paths for missing-resource/cancellation probes.
	var paths: Array[String] = resource_paths if mode_id == "incident_response" else adapter.required_resources()
	for path: String in paths:
		if generation != _generation:
			_worker_busy = false
			return
		# Reuse owned resources on replay; don't impose a polling frame for each
		# already-loaded section or duplicate background requests for cached data.
		if retained_resources.has(path) and is_instance_valid(retained_resources[path]): continue
		var title := "Loading campus resource" if path.ends_with("campus.glb") else "Loading " + path.get_file().get_basename().replace("_"," ")
		if "/runtime_campus/" in path: title = "Loading campus sections"
		elif "/runtime_surfaces/" in path: title = "Loading campus surface finishes"
		_stage(id,title,"resource")
		if not ResourceLoader.exists(path):
			_worker_busy = false
			failed.emit("A required mission resource is missing.",path,id)
			return
		var result := ResourceLoader.load_threaded_request(path,"",false)
		if result != OK:
			_worker_busy = false
			failed.emit("The mission resource could not be requested.","%s (%s)" % [path,result],id)
			return
		var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var measured: Array = []
			status = ResourceLoader.load_threaded_get_status(path,measured)
			if generation == _generation:
				latest.resource_progress = measured[0] if not measured.is_empty() else null
				progress_changed.emit(latest.duplicate(true))
			await get_tree().process_frame
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			_worker_busy = false
			if generation == _generation: failed.emit("The mission asset could not be loaded.","%s (status %s)" % [path,status],id)
			return
		# This get cannot block: status is LOADED. Keep strong references until construction.
		retained_resources[path] = ResourceLoader.load_threaded_get(path)
		if generation != _generation:
			_worker_busy = false
			return
	if test_frame_gate:
		_stage(id,"Paused by the development loader test gate","test_gate")
		while test_frame_gate and generation == _generation: await get_tree().process_frame
	if generation != _generation:
		_worker_busy = false
		return
	_stage(id,"Creating "+str(mode.get("title","the mission")),"session")
	var game: Node3D = adapter.create_session(retained_resources,preferences)
	if game == null:
		_worker_busy = false
		failed.emit("The mission scene has an invalid root.","Expected Node3D",id)
		return
	if not game.has_signal("initialization_progress"):
		_worker_busy = false
		game.free()
		failed.emit("The mission scene is incompatible.","Missing initialization_progress signal",id)
		return
	_building_game = game
	# Launcher services remain active during a mode's global pause, but the
	# selected world and its inherited AI/timers must obey that pause.
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Draw incremental sections behind the opaque loading UI. Keeping 3D entirely
	# disabled until READY made the driver compile/upload every variant at once.
	if DisplayServer.get_name() != "headless": get_tree().root.disable_3d = false
	game.initialization_progress.connect(func(label: String,stage: String,done: Variant,total: Variant):
		if generation == _generation: _stage(id,label,stage,done,total))
	add_child(game)
	while not adapter.initialization_finished(game):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await get_tree().process_frame
	_building_game = null
	if generation != _generation:
		_worker_busy = false
		dispose_session(game)
		return
	if not adapter.validate_ready(game):
		_worker_busy = false
		var reason: String = adapter.error_detail(game)
		dispose_session(game)
		failed.emit("The mission could not finish preparation.",reason,id)
		return
	_stage(id,"Checking the player and mission","readiness")
	for frame: int in range(3): await get_tree().physics_frame
	if generation != _generation:
		_worker_busy = false
		dispose_session(game)
		return
	if not adapter.validate_ready(game):
		_worker_busy = false
		var reason: String = adapter.error_detail(game)
		dispose_session(game)
		failed.emit("The mission did not pass its readiness checks.",reason,id)
		return
	if adapter.has_method("validate_spawn") and not adapter.validate_spawn(game):
		_worker_busy = false
		dispose_session(game)
		failed.emit("The player start is not safely walkable.","Ground/capsule clearance check failed",id)
		return
	adapter.freeze(game)
	# Pausing keeps CollisionObject3D bodies in the physics space. Setting the
	# world root DISABLED would remove floors/doors via their disable_mode.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if DisplayServer.get_name() != "headless":
		_stage(id,"Preparing the first campus frame","first_frame")
		await get_tree().process_frame
		get_tree().root.disable_3d = false
		for frame: int in range(2):
			RenderingServer.force_draw(false)
			await get_tree().process_frame
			if generation != _generation: break
		get_tree().root.disable_3d = true
	_worker_busy = false
	if generation != _generation:
		dispose_session(game)
		return
	mission_ready.emit(game,id)
