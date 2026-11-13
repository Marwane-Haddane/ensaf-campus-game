extends Node3D
## Root Scene and Game Loop Controller for Zombie RPG: After Hours (ZB-2026-001)

signal initialization_progress(label: String, stage: String, completed: Variant, total: Variant)
signal launcher_return_requested
signal launcher_settings_requested
signal launcher_restart_requested
signal mission_progress_updated(step_id: String, text: String)

const ModelPlacement = preload("res://scripts/antigravity/zombie/model_placement.gd")
const CampusRuntime = preload("res://scripts/campus_runtime.gd")
const CampusOcclusion = preload("res://scripts/campus_occlusion.gd")
const SaveStore = preload("res://scripts/antigravity/zombie/save_store.gd")
const Inventory = preload("res://scripts/antigravity/zombie/inventory.gd")
const MissionState = preload("res://scripts/antigravity/zombie/mission_state.gd")
const PlayerController = preload("res://scripts/antigravity/zombie/player_controller.gd")
const EnemyController = preload("res://scripts/antigravity/zombie/enemy_controller.gd")
const PickupItem = preload("res://scripts/antigravity/zombie/pickup_item.gd")
const SurvivorNPC = preload("res://scripts/antigravity/zombie/survivor_npc.gd")
const PowerStation = preload("res://scripts/antigravity/zombie/power_station.gd")
const UpgradeStation = preload("res://scripts/antigravity/zombie/upgrade_station.gd")
const ExtractionPoint = preload("res://scripts/antigravity/zombie/extraction_point.gd")
const ZombieHUD = preload("res://scripts/antigravity/zombie/zombie_hud.gd")
const CompanionDog = preload("res://scripts/antigravity/zombie/companion_dog.gd")
const LootChest = preload("res://scripts/antigravity/zombie/loot_chest.gd")
const DrivablePickup = preload("res://scripts/antigravity/zombie/drivable_pickup.gd")
const RoadLoop = preload("res://scripts/antigravity/zombie/road_loop.gd")
const RoadEncounters = preload("res://scripts/antigravity/zombie/road_encounters.gd")

const PICKUP_START := Vector3(-28.0, 0.16, -61.0)
const DRIVE_BOUNDS := Rect2(-114.0, -166.0, 204.0, 203.0)
const ROADKILL_MIN_SPEED := 5.5

var launcher_managed: bool = false
var runtime_preferences: Dictionary = {}
var prepared_campus: PackedScene
var prepared_sections: Array[PackedScene] = []
var ready_to_play: bool = false
var initialization_finished: bool = false
var initialization_error: String = ""
var initialization_cancelled: bool = false

var has_entered_gameplay: bool = false
var has_restored_checkpoint: bool = false
var is_session_frozen: bool = false

var campus: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var nav_region: NavigationRegion3D

var inventory: RefCounted
var mission_state: RefCounted
var save_store: RefCounted

var current_checkpoint_id: String = "start"
var current_checkpoint_name: String = "Campus Plaza Arrival"
var defeated_enemies: Array = []
var collected_pickups: Array = []

var active_enemies: Array[Node3D] = []
var spawned_pickups: Dictionary = {}
var brute_boss: Node3D = null
var extraction_point: Area3D
var _power_station: StaticBody3D
var _extraction_truck: Node3D
var _extraction_barriers: Array[Node3D] = []
var _pickup: DrivablePickup
var _road_loop: RoadLoop
var _road_encounters: RoadEncounters
var _pickup_exit_requested := false

var config_episode: Dictionary = {}

func _ready() -> void:
	name = "ZombieGame"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	initialization_progress.emit("Initializing survival episode services", "services", null, null)
	
	if save_store == null:
		save_store = SaveStore.new()
	inventory = Inventory.new()
	mission_state = MissionState.new()
	
	_load_episode_config()
	_setup_environment()
	
	call_deferred("_initialize_game_world")

func _load_episode_config() -> void:
	var path := "res://design/antigravity/zombie/episode_01.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			config_episode = parsed

func _setup_environment() -> void:
	# Dusk sky & environment
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.16, 0.28) # Deep twilight blue
	sky_mat.sky_horizon_color = Color(0.40, 0.43, 0.51)
	sky_mat.ground_bottom_color = Color(0.06, 0.08, 0.12)
	sky_mat.ground_horizon_color = Color(0.38, 0.26, 0.20)
	sky_mat.sun_angle_max = 24.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.42, 0.46, 0.58) # Balanced cool sky ambient for readable interiors
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	
	# Low angle warm directional dusk sun with anti-acne shadow parameters
	var sun := DirectionalLight3D.new()
	sun.name = "DuskSun"
	sun.light_color = Color(1.0, 0.82, 0.65)
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-24.0, 48.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 55.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 2.0
	sun.shadow_normal_bias = 0.12
	sun.shadow_blur = 1.4
	sun.shadow_opacity = 0.88
	add_child(sun)

func _initialize_game_world() -> void:
	if initialization_cancelled:
		_finish_init(false, "Initialization cancelled")
		return
	
	# 1. Setup HUD
	initialization_progress.emit("Creating HUD and interface", "hud", null, null)
	hud = ZombieHUD.new()
	hud.name = "ZombieHUD"
	add_child(hud)
	if launcher_managed: hud.hide()
	_wire_hud_events()
	await get_tree().process_frame
	
	# 2. Build Campus
	initialization_progress.emit("Preparing campus layout and geometry", "campus", null, null)
	campus = CampusRuntime.new()
	campus.name = "CampusRuntime"
	campus.prepared_asset = prepared_campus
	campus.prepared_sections = prepared_sections
	
	# If prepared_sections is empty, load runtime_campus chunks automatically
	if campus.prepared_sections.is_empty():
		var manifest_path := "res://assets/runtime_campus/manifest.json"
		if FileAccess.file_exists(manifest_path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			if parsed is Dictionary and parsed.has("chunks"):
				for chunk_path: String in parsed["chunks"]:
					var scn = load(chunk_path) as PackedScene
					if scn:
						campus.prepared_sections.append(scn)
	
	campus.build_progress.connect(func(label: String, stage: String, done: Variant, total: Variant):
		initialization_progress.emit(label, stage, done, total)
	)
	add_child(campus)
	await campus.build()
	
	if not bool(campus.stats.get("ready", false)):
		_finish_init(false, "Campus build failed: " + campus.build_error)
		return
	initialization_progress.emit("Culling hidden campus surfaces","occlusion",null,null)
	campus.stats["occlusion"] = CampusOcclusion.new().install(campus)
	
	await get_tree().process_frame
	if initialization_cancelled:
		_finish_init(false, "Initialization cancelled")
		return
	
	# 3. Setup Precomputed Navigation Region
	initialization_progress.emit("Loading route navigation grid", "navmesh", null, null)
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	var nav_mesh: NavigationMesh = load("res://assets/antigravity/zombie/route_navmesh.res")
	if nav_mesh:
		nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)
	await get_tree().process_frame
	if initialization_cancelled:
		_finish_init(false, "Initialization cancelled")
		return
	
	# 4. Dress Route Props
	initialization_progress.emit("Placing barricades and supplies", "props", null, null)
	await get_tree().physics_frame
	_spawn_route_props()
	
	# 5. Spawn Player
	initialization_progress.emit("Deploying player controller", "player", null, null)
	_spawn_player()
	
	# 6. Spawn Pickups & Interactables
	initialization_progress.emit("Spawning mission objectives and encounters", "actors", null, null)
	_spawn_pickups()
	_spawn_interactive_stations()
	_spawn_enemies()
	_setup_free_roam()
	_update_opening()
	apply_runtime_preferences(runtime_preferences)
	
	# Start mission sequence
	mission_state.start()
	hud.call("update_objective", mission_state.get_current_objective_text())
	_refresh_hud()
	
	# In standalone mode, create start checkpoint and resume directly
	# In managed mode, persistent writes are deferred until intentional gameplay entry
	if not launcher_managed:
		_create_checkpoint("cp_start", "Campus Plaza Arrival")
		has_entered_gameplay = true
		_resume()
	else:
		set_frozen(true)
	
	_finish_init(true, "")

func _finish_init(success: bool, err: String) -> void:
	if initialization_cancelled:
		initialization_finished = true
		ready_to_play = false
		initialization_error = "Initialization cancelled"
		return
	initialization_finished = true
	ready_to_play = success
	initialization_error = err

func _spawn_route_props() -> void:
	var props: Array = config_episode.get("props", [])
	for p_data in props:
		var scene_path: String = p_data.get("scene", "")
		if scene_path.is_empty():
			continue
		var scn: PackedScene = load(scene_path)
		if scn:
			var inst: Node3D = scn.instantiate() as Node3D
			var pos: Array = p_data.get("position", [0, 0, 0])
			inst.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
			inst.rotation_degrees.y = float(p_data.get("rotation_y", 0.0))
			var scl: Array = p_data.get("scale", [1, 1, 1])
			inst.scale = Vector3(float(scl[0]), float(scl[1]), float(scl[2]))
			add_child(inst)
			var support := _ground_point(inst.position)
			ModelPlacement.ground(inst, support.y)
			inst.add_to_group("route_props")
			# Match the asset stem so compressed and text scenes behave identically.
			match scene_path.get_file().get_basename():
				"Vehicle_Pickup_Armored":
					_extraction_truck = inst
				"TrafficBarrier_1":
					_extraction_barriers.append(inst)
				_:
					ModelPlacement.add_static_collision(inst)

func _spawn_player() -> void:
	player = PlayerController.new()
	player.name = "Player"
	var p_spawn: Dictionary = config_episode.get("player_spawn", {})
	var pos: Array = p_spawn.get("position", [-27.0, 1.25, -85.0])
	player.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	player.rotation_degrees.y = float(p_spawn.get("yaw_degrees", 0.0))
	add_child(player)
	_wire_player_events()

func _setup_free_roam() -> void:
	_road_loop = RoadLoop.new()
	_road_loop.name = "CampusRoadLoop"
	add_child(_road_loop)
	_pickup = DrivablePickup.new()
	_pickup.name = "CampusPickup"
	_pickup.position = _ground_point(PICKUP_START, 0.02)
	_pickup.rotation.y = PI / 2.0
	_pickup.driving_bounds = DRIVE_BOUNDS
	add_child(_pickup)
	_pickup.setup_pickup()
	_pickup.entry_requested.connect(_enter_pickup)
	_road_encounters = RoadEncounters.new()
	_road_encounters.name = "RoadEncounters"
	add_child(_road_encounters)
	_road_encounters.configure(_road_loop.encounter_points())
	_road_encounters.enemy_died.connect(func(enemy_id: String):
		mission_state.record_kill(0.0, enemy_id)
	)

func _enter_pickup(driver: CharacterBody3D) -> void:
	if driver != player or not ready_to_play or not has_entered_gameplay or is_session_frozen:
		return
	if hud.is_any_menu_open() or player.is_dead or extraction_point.boarding or extraction_point.driving or mission_state.extracted:
		return
	# The same interact event must not reach the exit handler after seating.
	get_viewport().set_input_as_handled()
	player.set_vehicle_seated(true)
	player.global_position = _pickup.global_position
	_pickup.start_driving(player)
	hud.set_free_roam_driving(true)

func _try_exit_pickup() -> void:
	if _pickup.speed_kph() > 5.0:
		hud.show_banner_message("Brake to exit the pickup.", 1.6)
		return
	var exit_at: Variant = _pickup.find_exit_position(player)
	if exit_at == null:
		hud.show_banner_message("Move the pickup to clear space before exiting.", 2.2)
		return
	_leave_pickup(exit_at)
	_resume()

func _leave_pickup(exit_at: Vector3) -> void:
	_pickup_exit_requested = false
	_pickup.stop_driving()
	player.global_position = exit_at
	player.rotation.y = _pickup.rotation.y + PI
	player.camera_pitch = 0.0
	player.camera.rotation.x = 0.0
	player.camera.make_current()
	player.set_vehicle_seated(false)
	hud.set_free_roam_driving(false)
	_refresh_hud()
	_update_opening()

func _reset_free_roam() -> void:
	_pickup_exit_requested = false
	if not is_instance_valid(_pickup):
		return
	if _pickup.driving:
		_leave_pickup(player.global_position)
	_pickup.reset()
	_road_encounters.clear()

func _physics_process(delta: float) -> void:
	if not ready_to_play or not has_entered_gameplay or is_session_frozen or player.is_dead:
		return
	if extraction_point.boarding or extraction_point.driving or mission_state.extracted:
		return
	if _pickup_exit_requested:
		_pickup_exit_requested = false
		_try_exit_pickup()
	if _pickup.driving:
		player.global_position = _pickup.global_position
		_apply_roadkill(delta)
	var focus := player.global_position
	_road_encounters.update(delta, focus, _road_loop.is_near_road(focus))

func _apply_roadkill(delta: float) -> void:
	if absf(_pickup.forward_speed()) < ROADKILL_MIN_SPEED:
		return
	var bumper := _pickup.bumper_position()
	var motion := _pickup.get_real_velocity() * delta
	if motion.length_squared() < 0.00001:
		return
	var hit_radius := _pickup.bumper_half_width() + 0.33
	for enemy: Node3D in _road_encounters.get_active_enemies():
		if enemy.is_dead():
			continue
		var torso := enemy.global_position + Vector3.UP * 0.64
		var closest := Geometry3D.get_closest_point_to_segment(torso, bumper - motion, bumper)
		if closest.distance_squared_to(torso) > hit_radius * hit_radius:
			continue
		var clear_path := PhysicsRayQueryParameters3D.create(closest, torso, 1)
		if not get_world_3d().direct_space_state.intersect_ray(clear_path).is_empty():
			continue
		var damage: float = enemy.health
		enemy.take_damage(damage, false, torso, motion.normalized())
		mission_state.record_damage(damage - enemy.health)

func _ground_point(point: Vector3, offset: float = 0.02) -> Vector3:
	# Authored placements describe the location, not a guessed elevation.
	# Resolve actual campus supports before actors are frozen behind Ready.
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.6,point-Vector3.UP*4.0,1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.normal.y>.65:
		point.y=hit.position.y+offset
	return point

func _spawn_pickups() -> void:
	for pickup_data: Dictionary in config_episode.get("pickups", []):
		_spawn_pickup(pickup_data)

func _spawn_pickup(data: Dictionary) -> void:
	var id: String = data.get("id", "")
	var claimed := id in collected_pickups
	var is_cache := id == PickupItem.SUPPLY_CACHE_ID
	if claimed and not is_cache:
		return
	var pickup := PickupItem.new()
	pickup.item_id = id
	pickup.item_type = data.get("type", "ammo")
	pickup.item_name = data.get("name", "Supplies")
	pickup.weapon_id = data.get("weapon_id", "")
	pickup.amount = int(data.get("amount", 12))
	var pos: Array = data.get("position", [0, 0, 0])
	pickup.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	if pickup.item_type == "ammo":
		pickup.position = _ground_point(pickup.position, 0.13)
	pickup.is_collected = claimed
	add_child(pickup)
	spawned_pickups[id] = pickup
	pickup.collected.connect(_on_pickup_collected)

func _on_pickup_collected(id: String, type: String, amount: int) -> void:
	if id in collected_pickups:
		return
	collected_pickups.append(id)
	if id != PickupItem.SUPPLY_CACHE_ID:
		spawned_pickups.erase(id)
	mission_state.on_event("pickup_item", {"item_id": id, "type": type, "amount": amount})
	hud.update_scrap(inventory.get_item_count("scrap"))
	match id:
		"item_intro_pistol":
			player.weapon_controller.show()
			hud.update_weapon_display("9mm Tactical Pistol", player.weapon_controller.mag_ammo, player.weapon_controller.reserve_ammo)
			hud.show_banner_message("Pistol recovered. Search Reception for the breaker fuse.", 5.0)
			_create_checkpoint("cp_pistol", "Pistol Recovered")
		"item_power_fuse":
			hud.show_banner_message("Main Breaker Fuse recovered", 2.0)
			_create_checkpoint("cp_fuse", "Main Breaker Fuse Recovered")
		"item_power_relay":
			hud.show_banner_message("Control Bus Relay recovered", 2.0)
			_create_checkpoint("cp_relay", "Control Bus Relay Recovered")
		_:
			var label := type.capitalize()
			for data: Dictionary in config_episode.get("pickups", []):
				if data.get("id") == id:
					label = str(data.get("name", label))
					break
			hud.show_banner_message("+%d %s" % [amount, label], 2.0)

func _spawn_interactive_stations() -> void:
	# 1. Shaun Survivor NPC
	var s_data: Dictionary = config_episode.get("survivor", {})
	var shaun := SurvivorNPC.new()
	shaun.character_name = s_data.get("name", "Shaun")
	var s_pos: Array = s_data.get("position", [-37.0, 1.92, -107.95])
	shaun.position = _ground_point(Vector3(float(s_pos[0]), float(s_pos[1]), float(s_pos[2])))
	shaun.rotation_degrees.y = float(s_data.get("yaw_degrees", 180.0))
	add_child(shaun)
	
	# 1b. Companion Dog (Max the German Shepherd)
	var dog := CompanionDog.new()
	dog.name = "CompanionMax"
	dog.dog_name = "Max"
	dog.position = _ground_point(Vector3(float(s_pos[0]) + 1.2, float(s_pos[1]), float(s_pos[2]) + 0.3))
	dog.rotation_degrees.y = float(s_data.get("yaw_degrees", 180.0))
	add_child(dog)
	
	# 1c. Matt (Security & Electrical Technician)
	var matt := SurvivorNPC.new()
	matt.name = "SurvivorMatt"
	matt.character_name = "Matt (Security Tech)"
	matt.model_path = "res://assets/antigravity/zombie/models/Characters_Matt.scn"
	matt.position = _ground_point(Vector3(2.5, 2.80, -108.5))
	matt.rotation_degrees.y = 210.0
	matt.reward_scrap = 25
	matt.custom_dialogue = [
		"Watch your step around the high-voltage conduits. I'm Matt, campus security technician.",
		"The substation breaker grid tripped hard when the infected breached the outer gates.",
		"If you can slot the missing fuse and relay into that breaker box, power will return.",
		"Here, take these 25 scrap parts. Use them at the field workbench to reinforce your gear!"
	]
	add_child(matt)
	matt.dialogue_requested.connect(func(lines: Array, speaker: String):
		_pause()
		hud.call("show_dialogue", lines, speaker)
	)
	
	# 1d. Lis (Campus Field Medic)
	var lis := SurvivorNPC.new()
	lis.name = "SurvivorLis"
	lis.character_name = "Lis (Field Medic)"
	lis.model_path = "res://assets/antigravity/zombie/models/Characters_Lis.scn"
	lis.position = _ground_point(Vector3(-31.4, 1.25, -89.1))
	lis.rotation_degrees.y = 90.0
	lis.reward_medkit = 1
	lis.custom_dialogue = [
		"Another survivor! Stay low. I'm Lis from the medical sciences wing.",
		"The infected carry violent pathogens. One severe bite can compromise your immune system.",
		"Here is an extra emergency trauma medkit. Press 'I' to use it whenever your health drops!"
	]
	add_child(lis)
	lis.dialogue_requested.connect(func(lines: Array, speaker: String):
		_pause()
		hud.call("show_dialogue", lines, speaker)
	)
	
	shaun.dialogue_requested.connect(func(lines: Array, speaker: String):
		_pause()
		hud.call("show_dialogue", lines, speaker)
	)
	shaun.survivor_contacted.connect(func():
		mission_state.call("on_event", "talk_survivor")
		_create_checkpoint("cp_survivor", "Survivor Shaun Contacted")
		if dog and is_instance_valid(dog) and player:
			dog.activate_follow(player)
			hud.show_squad_joined("Max")
	)
	
	# 2. Power Breaker Station
	_power_station = PowerStation.new()
	var pw_data: Dictionary = config_episode.get("power_station", {})
	var pw_pos: Array = pw_data.get("position", [0.90, 2.80, -110.5])
	_power_station.position = Vector3(float(pw_pos[0]), float(pw_pos[1]), float(pw_pos[2]))
	_power_station.mission = mission_state
	_power_station.inventory = inventory
	add_child(_power_station)
	_power_station.component_installed.connect(func(_id: String):
		hud.show_banner_message("Component installed. One more required.", 2.5)
		_create_checkpoint("cp_power_partial", "Substation Component Installed")
	)
	_power_station.power_restored.connect(func():
		mission_state.call("on_event", "power_restored")
		extraction_point.set_powered(true, true)
		hud.call("show_banner_message", "Power restored. Check in with Shaun while the exit opens.", 4.0)
		_create_checkpoint("cp_power", "Campus Power Restored")
	)

	# 3. Upgrade Station
	var upg_station := UpgradeStation.new()
	var upg_data: Dictionary = config_episode.get("upgrade_station", {})
	var upg_pos: Array = upg_data.get("position", [-35.0, 1.91, -105.0])
	upg_station.position = _ground_point(Vector3(float(upg_pos[0]), float(upg_pos[1]), float(upg_pos[2])))
	add_child(upg_station)
	
	upg_station.upgrade_menu_opened.connect(func():
		_pause()
		hud.call("toggle_upgrade_menu", true)
	)
	
	# 4. Extraction Point
	extraction_point = ExtractionPoint.new()
	var ext_data: Dictionary = config_episode.get("extraction_point", {})
	var ext_pos: Array = ext_data.get("position", [-20.0, 1.25, -68.0])
	extraction_point.position = Vector3(float(ext_pos[0]), float(ext_pos[1]), float(ext_pos[2]))
	extraction_point.mission = mission_state
	add_child(extraction_point)
	extraction_point.setup_route(_extraction_truck, _extraction_barriers)
	
	# 5. Tactical Supply Crates
	var chest_shotgun := LootChest.new()
	chest_shotgun.chest_id = "chest_shotgun_substation"
	chest_shotgun.loot_type = "shotgun"
	var cache_pos: Array = config_episode.get("shotgun_cache", {}).get("position", [-27.9, 1.25, -89.1])
	chest_shotgun.position = _ground_point(Vector3(cache_pos[0], cache_pos[1], cache_pos[2]))
	add_child(chest_shotgun)
	chest_shotgun.chest_opened.connect(func(id: String, _reward: String):
		mission_state.on_event("pickup_item", {"item_id": id})
	)
	
	var chest_scrap := LootChest.new()
	chest_scrap.chest_id = "chest_scrap_reception"
	chest_scrap.loot_type = "scrap"
	chest_scrap.loot_amount = 30
	chest_scrap.position = _ground_point(Vector3(-24.5, 1.25, -88.0))
	add_child(chest_scrap)

func _spawn_enemies() -> void:
	var spawns: Array = config_episode.get("enemy_spawns", [])
	for e_data in spawns:
		var e_id: String = e_data.get("id", "")
		if e_id in defeated_enemies:
			continue
		
		var enemy := EnemyController.new()
		enemy.enemy_id = e_id
		enemy.enemy_type = e_data.get("type", "walker")
		enemy.is_boss = bool(e_data.get("is_boss", false))
		enemy.patrol_points = e_data.get("patrol_points", [])
		var pos: Array = e_data.get("position", [0, 0, 0])
		enemy.position = _ground_point(Vector3(float(pos[0]), float(pos[1]), float(pos[2])))
		add_child(enemy)
		_prepare_encounter(enemy)
		active_enemies.append(enemy)
		
		if enemy.is_boss:
			brute_boss = enemy
		
		enemy.enemy_died.connect(func(dead_id: String, boss: bool):
			if not dead_id in defeated_enemies:
				defeated_enemies.append(dead_id)
			mission_state.call("record_kill", 0.0, dead_id)
			inventory.award_enemy_reward(dead_id,boss)
			if boss:
				mission_state.call("on_event", "boss_killed")
				hud.call("show_banner_message", "Chubby Brute Defeated! Escape route cleared!", 4.0)
				_create_checkpoint("cp_boss", "Brute Eliminated")
		)

func _wire_player_events() -> void:
	if player == null or hud == null:
		return
	
	player.health_changed.connect(func(cur: float, max_v: float):
		hud.call("update_health", cur, max_v)
	)
	player.stamina_changed.connect(func(cur: float, max_v: float):
		hud.call("update_stamina", cur, max_v)
	)
	player.player_died.connect(func():
		if is_instance_valid(_pickup) and _pickup.driving:
			_leave_pickup(player.global_position)
		hud.call("show_death_screen")
	)
	player.interact_target_changed.connect(func(info: Dictionary):
		hud.call("update_interaction_prompt", str(info.get("prompt", "")), bool(info.get("visible", false)))
	)
	
	var wc = player.get("weapon_controller")
	if wc:
		wc.ammo_changed.connect(func(mag: int, reserve: int):
			hud.call("update_ammo", mag, reserve)
		)
		wc.weapon_switched.connect(func(_id: String, w_name: String):
			hud.call("update_weapon_display", w_name, wc.mag_ammo, wc.reserve_ammo)
		)
		wc.hit_enemy.connect(func(dmg: float, _headshot: bool, _target: Node):
			hud.call("show_hit_marker")
			mission_state.call("record_damage", dmg)
		)

func _wire_hud_events() -> void:
	inventory.progression_changed.connect(func(summary: Dictionary):
		hud.update_progression(summary))
	mission_state.objective_completed.connect(func(id: String,xp: int,scrap: int):
		if inventory.claim_reward("objective:"+id,xp,scrap):
			hud.show_banner_message("Objective secured  +%d XP%s" % [xp,"  +%d scrap" % scrap if scrap>0 else ""],3.0))
	hud.update_progression(inventory.get_progression_summary())
	hud.menu_state_changed.connect(func(open: bool):
		if is_session_frozen or not has_entered_gameplay: return
		if open: _pause()
		else: _resume()
	)
	hud.retry_checkpoint_requested.connect(_retry_checkpoint)
	hud.restart_mission_requested.connect(_restart_mission)
	hud.return_to_launcher_requested.connect(func(): launcher_return_requested.emit())
	hud.settings_requested.connect(func(): launcher_settings_requested.emit())
	hud.pause_toggled.connect(func(paused: bool):
		if not paused:
			_resume()
		else:
			_pause()
	)
	
	hud.dialogue_closed.connect(func():
		_resume()
	)
	hud.upgrade_menu_closed.connect(func():
		_resume()
	)
	
	hud.medkit_use_requested.connect(func():
		inventory.call("use_medkit", player)
		hud.call("toggle_inventory", false)
		_resume()
	)
	
	hud.upgrade_chosen.connect(func(upgrade_id: String):
		if inventory.can_afford_upgrade(25):
			if inventory.buy_upgrade(upgrade_id, 25):
				hud.call("update_scrap", inventory.get_item_count("scrap"))
				if upgrade_id == "upgrade_armor":
					player.call("apply_armor_upgrade", 50.0)
					hud.call("show_banner_message", "Armor Upgraded! +50 Max Health", 3.0)
				elif upgrade_id == "upgrade_extended_mag":
					var wc = player.get("weapon_controller")
					if wc:
						wc.call("apply_extended_mag", 18, "pistol")
						wc.call("apply_extended_mag", 30, "scorpion")
					hud.call("show_banner_message", "Magazine Upgraded!", 3.0)
				_create_checkpoint(current_checkpoint_id,current_checkpoint_name)
		else:
			hud.call("show_banner_message", "Not enough scrap! Requires 25 scrap.", 2.5)
	)
	
	mission_state.objective_updated.connect(func(step_id: String, text: String, _is_final: bool):
		hud.call("update_objective", text)
		if has_entered_gameplay and not is_session_frozen:
			mission_progress_updated.emit(step_id, text)
	)
	
	mission_state.mission_completed.connect(func(stats: Dictionary):
		if player:
			player.set_input_enabled(false)
		extraction_point.show_debrief_camera()
		hud.call("show_victory_screen", stats)
	)

func _unhandled_input(event: InputEvent) -> void:
	if not ready_to_play or is_session_frozen or player == null or bool(player.get("is_dead")):
		return
	if extraction_point.boarding or mission_state.extracted:
		return
	
	if event is InputEventKey and event.pressed:
		var is_pause_press: bool = (event.is_action_pressed("pause") if InputMap.has_action("pause") else (event.keycode == KEY_ESCAPE))
		if is_pause_press:
			if hud.is_any_menu_open():
				hud.toggle_pause(false)
				hud.toggle_inventory(false)
				hud.toggle_journal(false)
				hud.toggle_upgrade_menu(false)
				hud.call("close_dialogue")
			else:
				hud.toggle_pause(true)
		
		elif _pickup.driving:
			var interact_pressed: bool = event.is_action_pressed("interact") if InputMap.has_action("interact") else event.keycode == KEY_E
			if interact_pressed and not event.echo:
				_pickup_exit_requested = true
				get_viewport().set_input_as_handled()
		elif extraction_point.driving:
			return
		elif event.keycode == KEY_I:
			if not hud.pause_menu.visible:
				var open: bool = not hud.inventory_menu.visible
				hud.toggle_inventory(open, inventory)
				if open:
					_pause()
				else:
					_resume()
		
		elif event.keycode == KEY_TAB:
			if not hud.pause_menu.visible:
				var open: bool = not hud.journal_menu.visible
				hud.toggle_journal(open, mission_state)
				if open:
					_pause()
				else:
					_resume()

func _create_checkpoint(cp_id: String, cp_name: String) -> void:
	current_checkpoint_id = cp_id
	current_checkpoint_name = cp_name
	var state_dict: Dictionary = save_store.capture(self)
	save_store.write_save(state_dict)

func _process(delta: float) -> void:
	if not ready_to_play or is_session_frozen or not has_entered_gameplay: return
	if not get_tree().paused: mission_state.tick_playtime(delta)
	_update_opening()
	var weapon = player.weapon_controller
	if _pickup.driving:
		hud.update_driving_speed(_pickup.speed_kph())
	else:
		hud.update_reload(weapon.get_reload_progress() if weapon.is_reloading else -1.0, weapon.get_current_weapon_name())
	if is_instance_valid(brute_boss):
		var nearby: bool = is_instance_valid(player) and player.global_position.distance_to(brute_boss.global_position)<18.0
		var encounter_active: bool = mission_state.get_current_step().get("id") == "obj_boss" \
			or brute_boss.health < brute_boss.max_health or not brute_boss.attack_phase.is_empty()
		hud.update_boss(brute_boss.health,brute_boss.max_health,nearby and encounter_active and not brute_boss.is_dead(),brute_boss.attack_phase)

func restore_safe_pose(data: Dictionary) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var pos: Array = data.get("position", [])
	if pos.size() != 3:
		return false
	var wanted := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	var world_3d := get_world_3d()
	if world_3d != null and world_3d.direct_space_state != null:
		var ray := PhysicsRayQueryParameters3D.create(wanted + Vector3.UP * 0.5, wanted - Vector3.UP * 3.0, 1, [player.get_rid()])
		var hit: Dictionary = world_3d.direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y < 0.6: return false
		if not hit.is_empty() and hit.normal.y >= 0.6:
			wanted = Vector3(wanted.x, hit.position.y + 0.05, wanted.z)
			var query := PhysicsShapeQueryParameters3D.new()
			var col_shape = player.find_child("PlayerCollision", true, false)
			if col_shape and col_shape is CollisionShape3D:
				query.shape = (col_shape as CollisionShape3D).shape
				query.transform = Transform3D(Basis.IDENTITY, wanted+col_shape.position)
				query.collision_mask = 1
				query.exclude = [player.get_rid()]
				if not world_3d.direct_space_state.intersect_shape(query).is_empty():
					return false
	player.global_position = wanted
	player.rotation.y = float(data.get("rotation_y", 0.0))
	var pitch_val: float = clampf(float(data.get("camera_pitch", 0.0)), -deg_to_rad(85), deg_to_rad(85))
	player.camera_pitch = pitch_val
	if player.camera:
		player.camera.rotation.x = pitch_val
	return true

func _retry_checkpoint() -> void:
	var saved: Dictionary = save_store.read_save()
	if not saved.is_empty():
		_reset_free_roam()
		save_store.restore(self, saved)
		restore_safe_pose(saved.get("player_state", {}))
		_resync_world_state()
		_refresh_hud()
		hud.dismiss_end_screens()
		hud.call("show_banner_message", "Checkpoint Restored: " + current_checkpoint_name, 3.0)
	else:
		_restart_mission()

func _resync_world_state() -> void:
	extraction_point.mission = mission_state
	extraction_point.reset_presentation()
	for data: Dictionary in config_episode.get("pickups", []):
		var id: String = data.get("id", "")
		var pickup = spawned_pickups.get(id)
		if not is_instance_valid(pickup):
			_spawn_pickup(data)
		elif id == PickupItem.SUPPLY_CACHE_ID:
			pickup.set_cache_open(id in collected_pickups)
		elif id in collected_pickups:
			pickup.queue_free()
			spawned_pickups.erase(id)

	# Restore the physical cabinet from the same state as the objective and exit gate.
	_power_station.mission = mission_state
	_power_station.inventory = inventory
	_power_station.sync_state()

	# 3. Resync enemies:
	var spawns: Array = config_episode.get("enemy_spawns", [])
	for e_data in spawns:
		var e_id: String = str(e_data.get("id", ""))
		var should_be_dead := (e_id in defeated_enemies)
		var existing_enemy = null
		for e in active_enemies:
			if is_instance_valid(e) and str(e.get("enemy_id")) == e_id:
				existing_enemy = e
				break
		
		if should_be_dead:
			if existing_enemy and is_instance_valid(existing_enemy):
				active_enemies.erase(existing_enemy)
				existing_enemy.queue_free()
		else:
			if existing_enemy == null or not is_instance_valid(existing_enemy) or bool(existing_enemy.call("is_dead")):
				if existing_enemy and is_instance_valid(existing_enemy):
					active_enemies.erase(existing_enemy)
					existing_enemy.queue_free()
				
				var enemy := EnemyController.new()
				enemy.enemy_id = e_id
				enemy.enemy_type = e_data.get("type", "walker")
				enemy.is_boss = bool(e_data.get("is_boss", false))
				enemy.patrol_points = e_data.get("patrol_points", [])
				var pos: Array = e_data.get("position", [0, 0, 0])
				enemy.position = _ground_point(Vector3(float(pos[0]), float(pos[1]), float(pos[2])))
				add_child(enemy)
				_prepare_encounter(enemy)
				active_enemies.append(enemy)
				if enemy.is_boss:
					brute_boss = enemy
				
				enemy.enemy_died.connect(func(dead_id: String, boss: bool):
					if not dead_id in defeated_enemies:
						defeated_enemies.append(dead_id)
					mission_state.call("record_kill", 0.0, dead_id)
					inventory.award_enemy_reward(dead_id,boss)
					if boss:
						mission_state.call("on_event", "boss_killed")
						hud.call("show_banner_message", "Chubby Brute Defeated! Escape route cleared!", 4.0)
						_create_checkpoint("cp_boss", "Brute Eliminated")
				)
	
	# 4. Resync survivor NPC:
	for c in get_children():
		if c is SurvivorNPC or c.has_signal("survivor_contacted"):
			var has_talked: bool = bool(mission_state.get("survivor_talked"))
			c.set("has_spoken", has_talked)

func _restart_mission() -> void:
	if launcher_managed:
		launcher_restart_requested.emit()
		_reset_mode_state()
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()

func _reset_mode_state() -> void:
	get_tree().paused = false
	_reset_free_roam()
	current_checkpoint_id = "cp_start"
	current_checkpoint_name = "Campus Plaza Arrival"
	has_restored_checkpoint = false
	defeated_enemies.clear()
	collected_pickups.clear()
	
	# Reset inventory
	if inventory and inventory.has_method("reset"):
		inventory.call("reset")
	else:
		inventory = Inventory.new()
	
	# Reset mission state
	if mission_state and mission_state.has_method("reset"):
		mission_state.call("reset")
	else:
		mission_state = MissionState.new()
		mission_state.objective_updated.connect(func(step_id: String, text: String, _is_final: bool):
			if hud:
				hud.call("update_objective", text)
			if has_entered_gameplay and not is_session_frozen:
				mission_progress_updated.emit(step_id, text)
		)
		mission_state.mission_completed.connect(func(stats: Dictionary):
			if player:
				player.set_input_enabled(false)
			extraction_point.show_debrief_camera()
			if hud:
				hud.call("show_victory_screen", stats)
		)
		mission_state.start()
	
	# Reset player
	if player:
		player.is_dead = false
		player.health = 100.0
		player.max_health = 100.0
		player.stamina = 100.0
		player.max_stamina = 100.0
		var p_spawn: Dictionary = config_episode.get("player_spawn", {})
		var pos: Array = p_spawn.get("position", [-27.0, 1.25, -85.0])
		player.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		player.rotation_degrees.y = float(p_spawn.get("yaw_degrees", 0.0))
		player.camera_pitch = 0.0
		if player.camera:
			player.camera.rotation.x = 0.0
		var wc = player.get("weapon_controller")
		if wc:
			if wc.has_method("reset_state"):
				wc.call("reset_state")
			else:
				wc.call("_apply_weapon_config", "pistol")
			wc.show()
	
	# Resynchronize world entities
	_resync_world_state()
	
	# Reset HUD menus
	if hud:
		hud.toggle_pause(false)
		hud.toggle_inventory(false)
		hud.toggle_journal(false)
		hud.toggle_upgrade_menu(false)
		hud.call("close_dialogue")
		hud.dismiss_end_screens()
	
	_refresh_hud()
	start_gameplay()
	_resume()

func cancel_initialization() -> void:
	initialization_cancelled = true
	if campus:
		campus.set("cancelled", true)
	initialization_finished = true
	ready_to_play = false
	initialization_error = "Initialization cancelled" 

func start_gameplay() -> void:
	has_entered_gameplay = true
	is_session_frozen = false
	if not has_restored_checkpoint:
		_create_checkpoint("cp_start", "Campus Plaza Arrival")

func set_frozen(frozen: bool) -> void:
	is_session_frozen = frozen
	if is_instance_valid(_pickup):
		_pickup.set_physics_process(not frozen and _pickup.driving)
		_road_encounters.set_frozen(frozen)
	if frozen:
		_set_capture(false)
		if player:
			player.set_input_enabled(false)
		for enemy in active_enemies:
			if is_instance_valid(enemy):
				enemy.set_physics_process(false)
				enemy.set_process(false)
	else:
		if player and not bool(player.get("is_dead")):
			player.set_input_enabled(true)
		for enemy in active_enemies:
			if is_instance_valid(enemy):
				enemy.set_physics_process(true)
				enemy.set_process(true)

func _refresh_hud() -> void:
	if hud == null:
		return
	if player:
		hud.call("update_health", player.health, player.max_health)
		hud.call("update_stamina", player.stamina, player.max_stamina)
		var wc = player.get("weapon_controller")
		if wc:
			hud.call("update_ammo", wc.mag_ammo, wc.reserve_ammo)
			hud.call("update_weapon_display", wc.call("get_current_weapon_name"), wc.mag_ammo, wc.reserve_ammo)
	if inventory:
		hud.call("update_scrap", inventory.get_item_count("scrap"))
		hud.update_progression(inventory.get_progression_summary())
	if mission_state:
		hud.call("update_objective", mission_state.get_current_objective_text())

func apply_runtime_preferences(preferences: Dictionary) -> void:
	runtime_preferences = preferences
	var sens: float = clampf(float(preferences.get("mouse_sensitivity", 1.0)), 0.5, 3.0)
	if player:
		player.mouse_sensitivity = 0.002 * sens
	var red_motion: bool = bool(preferences.get("reduced_motion", false))
	if extraction_point:
		extraction_point.reduced_motion = red_motion
	if player:
		player.reduced_motion = red_motion
		if player.camera: player.camera.far = {"low":100.0,"medium":170.0,"high":220.0}.get(preferences.get("graphics_preset","medium"),170.0)
	if hud:
		hud.reduced_motion = red_motion
	var preset: String = str(preferences.get("graphics_preset", "medium"))
	for child in get_children():
		if child is DirectionalLight3D:
			child.directional_shadow_max_distance = {"low": 24.0, "medium": 45.0, "high": 60.0}.get(preset, 45.0)
			child.shadow_enabled = (preset != "low")

func _set_capture(captured: bool) -> void:
	if not ready_to_play or is_session_frozen or not has_entered_gameplay:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	if captured and hud and not hud.is_any_menu_open() and not get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _pause() -> void:
	get_tree().paused = true
	if player:
		player.set_input_enabled(false)
	_set_capture(false)

func _resume() -> void:
	if mission_state.extracted:
		_pause()
		extraction_point.show_debrief_camera()
		if not hud.victory_screen.visible:
			hud.show_victory_screen(mission_state.get_completion_summary())
		return
	get_tree().paused = false
	if player and not bool(player.get("is_dead")) and not is_session_frozen and not extraction_point.driving:
		player.set_input_enabled(true)
	_set_capture(true)


# Opening progression also derives from mission steps for existing checkpoints.
func has_intro_weapon() -> bool:
	return "item_intro_pistol" in collected_pickups or mission_state.current_step_index > 0

func _prepare_encounter(enemy: Node3D) -> void:
	enemy.hide()
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.collision_layer = 0
	enemy.set_meta("encounter_waiting", true)

func _update_opening() -> void:
	var armed := has_intro_weapon()
	var in_pickup := is_instance_valid(_pickup) and _pickup.driving
	var in_extraction: bool = is_instance_valid(extraction_point) and (extraction_point.boarding or extraction_point.driving)
	var show_weapon: bool = armed and not player.is_dead and not in_pickup and not in_extraction
	player.weapon_controller.visible = show_weapon
	hud.set_armed(show_weapon)
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or enemy.is_dead():
			continue
		if mission_state.current_step_index < 2:
			_prepare_encounter(enemy)
			continue
		if not enemy.get_meta("encounter_waiting", false):
			continue
		var required_step := 4 if enemy.is_boss else 2
		if mission_state.current_step_index < required_step:
			continue
		var distance: float = player.global_position.distance_to(enemy.global_position)
		if distance < 7.0 or distance > 35.0:
			continue
		# Encounters enter outside the camera view, so turning a corner reveals them naturally.
		if player.camera.is_position_in_frustum(enemy.global_position + Vector3.UP):
			continue
		enemy.set_meta("encounter_waiting", false)
		enemy.collision_layer = 4
		enemy.process_mode = Node.PROCESS_MODE_INHERIT
		enemy.show()
