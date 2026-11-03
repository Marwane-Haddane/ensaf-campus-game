extends RefCounted
## Version-1 mode adapter. Cybersecurity-specific knowledge stays out of the
## shared loading pipeline, so future modes can own independent scenes and saves.
const Registry = preload("res://scripts/launcher/mode_registry.gd")
const SaveStore = preload("res://scripts/launcher/save_store.gd")
var saves = SaveStore.new()
func save_service() -> RefCounted: return saves
func required_resources() -> Array[String]: return Registry.asset_paths()
func entry_scene() -> String: return "res://main.tscn"
func create_session(resources: Dictionary,preferences: Dictionary) -> Node3D:
	var scene := resources.get(entry_scene()) as PackedScene
	if scene == null: return null
	var game := scene.instantiate() as Node3D
	if game == null: return null
	game.launcher_managed = true
	game.runtime_preferences = preferences
	game.prepared_campus = resources.get("res://assets/campus.glb")
	for path: String in Registry.asset_paths():
		if "/runtime_campus/" in path: game.prepared_sections.append(resources[path])
	return game
func initialization_finished(game: Node3D) -> bool: return bool(game.get("initialization_finished"))
func validate_ready(game: Node3D) -> bool:
	return game.ready_to_play and game.stations.size()==5 and game.campus.door_system.doors.size()==4 and game.training.mission.get("mission_id","")=="campus_ir_01"
func error_detail(game: Node3D) -> String: return str(game.get("initialization_error"))
func validate_spawn(game: Node3D) -> bool:
	var player: CharacterBody3D = game.get("player")
	var start: Vector3 = player.global_position
	var ray := PhysicsRayQueryParameters3D.create(start+Vector3.UP*.5,start-Vector3.UP*3.0,1,[player.get_rid()])
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y<.6: return false
	var standing: Vector3 = Vector3(start.x,hit.position.y+.92,start.z)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = (player.get_child(0) as CollisionShape3D).shape
	query.transform = Transform3D(Basis.IDENTITY,standing)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	if not game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(): return false
	player.global_position = standing
	return true
func cancel(game: Node3D) -> void: game.cancel_initialization()
func supports_cooperative_cancellation() -> bool: return true
func set_input(game: Node3D,enabled: bool) -> void:
	game.set_process(enabled)
	game.set_physics_process(enabled)
	game.set_process_unhandled_input(enabled)
	game.training.set_process_input(enabled)
	if not enabled: game._set_capture(false)
func freeze(game: Node3D) -> void:
	set_input(game,false)
	game.campus.door_system.process_mode = Node.PROCESS_MODE_DISABLED
	game.overlay.hide()
	game.training.hide()
	game.focus_overlay.hide()
func start(game: Node3D) -> void:
	game.overlay.show()
	game.training.show()
	game.focus_overlay.show()
	set_input(game,true)
	game._resume()
func connect_events(game: Node3D,on_return: Callable,on_settings: Callable,on_progress: Callable) -> void:
	game.launcher_return_requested.connect(on_return)
	game.launcher_settings_requested.connect(on_settings)
	game.training.mission_progress_changed.connect(func(_complete: int,_total: int):on_progress.call())
func apply_preferences(game: Node3D,preferences: Dictionary) -> void: game.apply_runtime_preferences(preferences)
func capture(game: Node3D) -> Dictionary: return saves.capture(game)
func restore(game: Node3D,checkpoint: Dictionary) -> bool: return saves.restore(game,checkpoint)
func is_ready(game: Node3D) -> bool: return game.ready_to_play
