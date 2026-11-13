extends RefCounted
## Shared Launcher Integration Adapter for Zombie RPG (After Hours)
## Follows the ENSA Games mode contract cleanly without dependencies on cybersecurity code.

const SaveStore = preload("res://scripts/antigravity/zombie/save_store.gd")
const ENTRY_SCENE_PATH: String = "res://scenes/antigravity/zombie/zombie_game.tscn"

var saves = SaveStore.new()
var last_error: String = ""

func save_service() -> RefCounted:
	return saves

func required_resources() -> Array[String]:
	var paths: Array[String] = [
		ENTRY_SCENE_PATH,
		"res://assets/campus.glb",
		"res://assets/antigravity/zombie/route_navmesh.res",
		"res://assets/antigravity/zombie/models/pistol_hands.scn",
		"res://assets/antigravity/zombie/models/Zombie_Basic.scn",
		"res://assets/antigravity/zombie/models/Zombie_Chubby.scn",
		"res://assets/antigravity/zombie/models/Characters_Shaun.scn"
	]
	
	# Include runtime campus chunks if manifest is present
	var campus_manifest := "res://assets/runtime_campus/manifest.json"
	if FileAccess.file_exists(campus_manifest):
		var sections: Variant = JSON.parse_string(FileAccess.get_file_as_string(campus_manifest))
		if sections is Dictionary and sections.get("version", 0) == 1 and not sections.get("chunks", []).is_empty():
			paths.erase("res://assets/campus.glb")
			for chunk_path: String in sections["chunks"]:
				paths.append(chunk_path)
	
	# Prepare combat models before spawning actors or switching weapons.
	for manifest in ["weapons", "enemies"]:
		var path := "res://design/antigravity/zombie/%s.json" % manifest
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			for config: Dictionary in data.get(manifest, {}).values():
				var model: String = str(config.get("scene", ""))
				if ResourceLoader.exists(model) and model not in paths:
					paths.append(model)
	var surface_manifest := "res://assets/runtime_surfaces/manifest.json"
	if FileAccess.file_exists(surface_manifest):
		var surfaces: Variant = JSON.parse_string(FileAccess.get_file_as_string(surface_manifest))
		if surfaces is Dictionary:
			for tex_path: String in surfaces.get("textures", []):
				paths.append(tex_path)
	
	return paths

func entry_scene() -> String:
	return ENTRY_SCENE_PATH

func create_session(resources: Dictionary, preferences: Dictionary) -> Node3D:
	var scene := resources.get(entry_scene()) as PackedScene
	if scene == null:
		scene = load(entry_scene()) as PackedScene
	if scene == null:
		return null
	
	var game := scene.instantiate() as Node3D
	if game == null:
		return null
	
	game.launcher_managed = true
	game.runtime_preferences = preferences
	game.save_store = saves
	game.prepared_campus = resources.get("res://assets/campus.glb")
	
	for path: String in resources:
		if "/runtime_campus/" in path:
			var res = resources[path]
			if res is PackedScene:
				game.prepared_sections.append(res)
	
	return game

func initialization_finished(game: Node3D) -> bool:
	return bool(game.get("initialization_finished"))

func validate_ready(game: Node3D) -> bool:
	if game == null or not is_instance_valid(game):
		return false
	var ready_flag: bool = bool(game.get("ready_to_play"))
	var has_player: bool = (game.get("player") != null)
	var has_campus: bool = (game.get("campus") != null and bool(game.campus.stats.get("ready", false)))
	var has_nav: bool = (game.get("nav_region") != null and game.nav_region.navigation_mesh != null)
	var has_mission: bool = (game.get("mission_state") != null)
	return ready_flag and has_player and has_campus and has_nav and has_mission

func error_detail(game: Node3D) -> String:
	return str(game.get("initialization_error"))

func validate_spawn(game: Node3D) -> bool:
	return _verify_safe_player_pose(game)

func _verify_safe_player_pose(game: Node3D) -> bool:
	var player: CharacterBody3D = game.get("player")
	if player == null or not is_instance_valid(player):
		return false
	
	var start: Vector3 = player.global_position
	if not (is_finite(start.x) and is_finite(start.y) and is_finite(start.z)):
		return false
	
	var world_3d := game.get_world_3d()
	if world_3d == null or world_3d.direct_space_state == null:
		return true
	
	var ray := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 1.5, start - Vector3.UP * 3.5, 1, [player.get_rid()])
	var hit: Dictionary = world_3d.direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.6:
		return false
	
	var foot_y: float = hit.position.y
	var standing_feet := Vector3(start.x, foot_y + 0.05, start.z)
	var capsule_center := Vector3(start.x, foot_y + 0.95, start.z)
	
	var col_shape = player.find_child("PlayerCollision", true, false)
	if col_shape and col_shape is CollisionShape3D:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = (col_shape as CollisionShape3D).shape
		query.transform = Transform3D(Basis.IDENTITY, capsule_center)
		query.collision_mask = 1
		query.exclude = [player.get_rid()]
		query.margin = 0.01
		if not world_3d.direct_space_state.intersect_shape(query).is_empty():
			return false
	
	player.global_position = standing_feet
	return true

func cancel(game: Node3D) -> void:
	if game and game.has_method("cancel_initialization"):
		game.cancel_initialization()

func set_input(game: Node3D, enabled: bool) -> void:
	game.set_process(enabled)
	game.set_physics_process(enabled)
	game.set_process_unhandled_input(enabled)
	var paused := game.get_tree().paused
	if game.get("player"):
		game.player.set_input_enabled(enabled and not paused)
	# Shared Settings owns the screen while mode input is suspended.
	if game.get("hud"):
		game.hud.visible = enabled
		if enabled and paused:
			game.hud._focus_open_menu.call_deferred()
	var enemies = game.get("active_enemies")
	if enemies is Array:
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.set_physics_process(enabled)
				enemy.set_process(enabled)
	if not enabled:
		game._set_capture(false)

func freeze(game: Node3D) -> void:
	set_input(game, false)
	if game.has_method("set_frozen"):
		game.set_frozen(true)

func start(game: Node3D) -> void:
	if game.has_method("set_frozen"):
		game.set_frozen(false)
	set_input(game, true)
	if game.has_method("start_gameplay"):
		game.start_gameplay()
	game._resume()

func connect_events(game: Node3D, on_return: Callable, on_settings: Callable, on_progress: Callable) -> void:
	game.launcher_return_requested.connect(on_return)
	game.launcher_settings_requested.connect(on_settings)
	if game.has_signal("mission_progress_updated"):
		game.mission_progress_updated.connect(func(_id: String, _txt: String):
			if not bool(game.get("is_session_frozen")):
				on_progress.call()
		)
	elif game.get("mission_state"):
		game.mission_state.objective_updated.connect(func(_id: String, _txt: String, _final: bool):
			if not bool(game.get("is_session_frozen")):
				on_progress.call()
		)

func apply_preferences(game: Node3D, preferences: Dictionary) -> void:
	if game.has_method("apply_runtime_preferences"):
		game.apply_runtime_preferences(preferences)

func capture(game: Node3D) -> Dictionary:
	return saves.capture(game)

func restore(game: Node3D, checkpoint: Dictionary) -> bool:
	last_error = ""
	if game == null or not is_instance_valid(game):
		last_error = "Game session is null or invalid"
		saves.last_error = last_error
		return false
	
	if not saves.validate(checkpoint):
		last_error = saves.last_error
		return false
	
	var ok: bool = saves.restore(game, checkpoint)
	if not ok:
		last_error = saves.last_error if not saves.last_error.is_empty() else "Failed to restore checkpoint state"
		return false
	
	# Resynchronize world entities
	if game.has_method("_resync_world_state"):
		game.call("_resync_world_state")
	
	# Restore safe player pose if game supports it
	if game.has_method("restore_safe_pose"):
		game.call("restore_safe_pose", checkpoint.get("player_state", {}))
	
	# Refresh HUD
	if game.has_method("_refresh_hud"):
		game.call("_refresh_hud")
	
	# Verify player pose safety
	if not _verify_safe_player_pose(game):
		last_error = "Player restored to unsafe or obstructed position"
		saves.last_error = last_error
		return false
	
	game.set("has_restored_checkpoint", true)
	freeze(game)
	return true

func is_ready(game: Node3D) -> bool:
	return bool(game.get("ready_to_play"))
