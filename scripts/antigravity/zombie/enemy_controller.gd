extends CharacterBody3D
## Smooth, budgeted enemy steering with readable, dodgeable melee attacks.
signal enemy_died(enemy_id: String, is_boss: bool)
signal damage_dealt_to_player(amount: float)
signal attack_started(enemy_id: String, windup_seconds: float)
# Preserve original state values; append investigate for compatibility.
enum State { IDLE, PATROL, CHASE, ATTACK, HIT_REACT, DEAD, INVESTIGATE }
@export var enemy_id := "walker"
@export var enemy_type := "walker"
@export var is_boss := false
@export var patrol_points: Array = []
var state: State = State.IDLE
var target_player: CharacterBody3D
var max_health := 55.0
var health := 55.0
var walk_speed := 1.45
var run_speed := 2.85
var attack_damage := 15.0
var attack_range := 1.65
var attack_cooldown := 1.65
var attack_contact_time := 0.6
var detection_radius := 16.0
var lose_target_radius := 25.0
var xp_reward := 25
var scrap_reward := 5
var attack_phase := ""
var _brute_attack_clip := ""
var _model_rest_rotation := Vector3.ZERO
var nav_agent: NavigationAgent3D
var model_instance: Node3D
var anim_player: AnimationPlayer
var current_patrol_idx := 0
var attack_timer := 0.0
var attack_contact_timer := -1.0
var attack_has_damaged := false
var state_timer := 0.0
var stuck_timer := 0.0
var last_pos := Vector3.ZERO
var death_timer := 0.0
var gravity := 16.0
var mesh_scale := 1.0
var last_known_position := Vector3.ZERO
var _config: Dictionary = {}
var _animations: Dictionary = {}
var _acceleration := 7.5
var _turn_speed := 4.2
var _perception_due := 0.0
var _path_due := 0.0
var _neighbor_due := 0.0
var _lookup_due := 0.0
var _lost_sight_time := 0.0
var _can_see_target := false
var _stagger_cooldown := 0.0
var _separation := Vector3.ZERO
var _recovery_direction := Vector3.ZERO
var _recovery_remaining := 0.0
var _nav_target := Vector3(INF,INF,INF)
var _cached_candidate: CharacterBody3D
var _step_due := 0.0
var _visual_step_offset := 0.0
var _model_base_y := 0.0
static var _config_cache: Dictionary = {}

func _ready() -> void:
	add_to_group("enemies")
	_load_config()
	_setup_collision()
	_setup_model()
	_setup_navigation()
	floor_snap_length = 0.35
	floor_stop_on_slope = true
	last_pos = global_position
	# Stagger expensive updates instead of spiking every enemy on one frame.
	_perception_due = float(absi(enemy_id.hash())%13)*0.013
	_neighbor_due = _perception_due
	_path_due = _perception_due

func _load_config() -> void:
	if _config_cache.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://design/antigravity/zombie/enemies.json"))
		if value is Dictionary: _config_cache = value.get("enemies",{})
	_config = _config_cache.get(enemy_type,{})
	max_health = float(_config.get("max_health",55.0))
	health = max_health
	walk_speed = float(_config.get("walk_speed",1.45))
	run_speed = float(_config.get("run_speed",2.85))
	attack_damage = float(_config.get("attack_damage",15.0))
	attack_range = float(_config.get("attack_range",1.65))
	attack_cooldown = float(_config.get("attack_cooldown",1.65))
	attack_contact_time = clampf(float(_config.get("attack_contact_time",0.6)),0.2,attack_cooldown-0.15)
	detection_radius = float(_config.get("detection_radius",16.0))
	lose_target_radius = float(_config.get("lose_target_radius",25.0))
	mesh_scale = float(_config.get("scale",1.0))
	xp_reward = int(_config.get("xp_reward",25))
	scrap_reward = int(_config.get("scrap_reward",5))
	_animations = _config.get("animations",{})
	_acceleration = float(_config.get("acceleration",7.5))
	_turn_speed = deg_to_rad(float(_config.get("turn_speed_degrees",240.0)))

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "EnemyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = float(_config.get("capsule_radius",0.35))
	capsule.height = float(_config.get("capsule_height",1.75))
	col.shape = capsule
	col.position.y = capsule.height*0.5
	add_child(col)
	collision_layer = 4
	collision_mask = 1|2|4

func _setup_model() -> void:
	var scene := load(str(_config.get("scene","res://assets/antigravity/zombie/models/Zombie_Basic.tscn"))) as PackedScene
	if scene == null: return
	model_instance = scene.instantiate() as Node3D
	_model_base_y = model_instance.position.y
	model_instance.scale = Vector3.ONE*mesh_scale
	model_instance.rotation.y = deg_to_rad(float(_config.get("model_yaw_degrees",180.0)))
	_model_rest_rotation = model_instance.rotation
	add_child(model_instance)
	anim_player = model_instance.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if anim_player:
		# glTF has no loop metadata. Locomotion needs actual cyclic playback,
		# while strikes, hit reactions and death must remain one-shot clips.
		for role: String in _animations:
			var clip: String = str(_animations[role])
			if anim_player.has_animation(clip):
				anim_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if role in ["idle","walk","run"] else Animation.LOOP_NONE
	_play_anim("Idle")

func _setup_navigation() -> void:
	nav_agent = NavigationAgent3D.new()
	nav_agent.name = "NavAgent"
	nav_agent.radius = float(_config.get("capsule_radius",0.35))+0.1
	nav_agent.avoidance_enabled = false
	nav_agent.path_desired_distance = 0.45
	nav_agent.target_desired_distance = 0.65
	add_child(nav_agent)

func _physics_process(delta: float) -> void:
	if state==State.DEAD:
		death_timer += delta
		if death_timer>15.0 and not is_boss: queue_free()
		return
	velocity.y = velocity.y-gravity*delta if not is_on_floor() else minf(velocity.y,0.0)
	attack_timer = maxf(0.0,attack_timer-delta)
	_stagger_cooldown = maxf(0.0,_stagger_cooldown-delta)
	_path_due -= delta
	_step_due -= delta
	_neighbor_due -= delta
	_lookup_due -= delta
	_perception_due -= delta
	if _perception_due<=0.0:
		_perception_due = float(_config.get("perception_interval",0.18))
		_can_see_target = _check_perception()
		if _can_see_target:
			last_known_position = target_player.global_position
			if state in [State.IDLE,State.PATROL,State.INVESTIGATE]: _enter_state(State.CHASE)
	_lost_sight_time = 0.0 if _can_see_target else _lost_sight_time+delta
	# Stagger and death cancel a swing. Delayed timers cannot deal stale damage.
	if state==State.ATTACK and attack_contact_timer>0.0:
		attack_contact_timer -= delta
		if attack_contact_timer<=0.0 and not attack_has_damaged:
			attack_phase = "recovery"
			_try_apply_attack_damage()
	match state:
		State.IDLE: _process_idle(delta)
		State.PATROL: _process_patrol(delta)
		State.CHASE: _process_chase(delta)
		State.ATTACK: _process_attack(delta)
		State.HIT_REACT: _process_hit_react(delta)
		State.INVESTIGATE: _process_investigate(delta)
	_try_step_up(delta)
	move_and_slide()
	_visual_step_offset = move_toward(_visual_step_offset,0.0,delta*2.0)
	if model_instance: model_instance.position.y = _model_base_y+_visual_step_offset

func _process_idle(delta: float) -> void:
	_slow_down(delta)
	_play_anim("Idle")
	state_timer += delta
	if state_timer>2.0 and not patrol_points.is_empty(): _enter_state(State.PATROL)

func _process_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		_enter_state(State.IDLE)
		return
	var point: Variant = patrol_points[current_patrol_idx%patrol_points.size()]
	if not point is Array or point.size()<3:
		_enter_state(State.IDLE)
		return
	var goal := Vector3(float(point[0]),float(point[1]),float(point[2]))
	if _planar_distance(goal)<0.9:
		current_patrol_idx = (current_patrol_idx+1)%patrol_points.size()
		_enter_state(State.IDLE)
	else: _steer_towards(goal,walk_speed,delta)

func _process_chase(delta: float) -> void:
	if not _valid_target() or _planar_distance(target_player.global_position)>lose_target_radius:
		target_player = null
		_enter_state(State.INVESTIGATE)
		return
	if not _can_see_target and _lost_sight_time>float(_config.get("memory_seconds",2.5)):
		_enter_state(State.INVESTIGATE)
		return
	if _can_see_target and _target_in_reach(attack_range):
		_slow_down(delta)
		_play_anim("Idle")
		_look_at_smooth(target_player.global_position,delta*_turn_speed)
		var direction := target_player.global_position-global_position
		direction.y = 0.0
		if attack_timer<=0.0 and (direction.length_squared()<0.01 or (-global_basis.z).dot(direction.normalized())>0.7):
			_enter_state(State.ATTACK)
	else: _steer_towards(last_known_position,run_speed,delta)

func _process_investigate(delta: float) -> void:
	state_timer += delta
	if _planar_distance(last_known_position)>0.9 and state_timer<5.0:
		_steer_towards(last_known_position,walk_speed,delta)
	else:
		_slow_down(delta)
		_play_anim("Idle")
		rotation.y += delta*0.55
	if state_timer>6.0:
		target_player = null
		_enter_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)

func _process_attack(delta: float) -> void:
	_slow_down(delta,1.7)
	state_timer += delta
	# Early tracking stops before contact, allowing a deliberate sidestep.
	if _valid_target() and state_timer<attack_contact_time*0.55:
		_look_at_smooth(target_player.global_position,delta*_turn_speed*0.65)
	if enemy_type == "brute":
		_update_brute_attack_pose()
	if state_timer>=attack_cooldown: _enter_state(State.CHASE if _valid_target() else State.INVESTIGATE)

func _update_brute_attack_pose() -> void:
	if model_instance == null:
		return
	var windup := clampf(state_timer / attack_contact_time, 0.0, 1.0)
	var recovery := clampf((state_timer - attack_contact_time) / (attack_cooldown - attack_contact_time), 0.0, 1.0)
	# Hold anticipation, accelerate into contact, then give the player an opening.
	var coil := sin(PI * pow(windup, 2.8)) if windup < 1.0 else 0.0
	var follow_through := pow(windup, 6.0) * (1.0 - smoothstep(0.0, 1.0, recovery))
	model_instance.rotation = _model_rest_rotation + Vector3(
		deg_to_rad(10.0 * coil - 12.0 * follow_through),
		deg_to_rad(-16.0 * coil + 10.0 * follow_through), 0.0)
	if not _brute_attack_clip.is_empty():
		var clip_length := anim_player.get_animation(_brute_attack_clip).length
		# Split the imported punch at its extension so pose and melee share a clock.
		var extension := float(_config.get("attack_extension_fraction", 0.48))
		var phase := lerpf(0.0, extension, pow(windup, 2.2))
		if recovery > 0.0:
			phase = lerpf(extension, 1.0, smoothstep(0.0, 1.0, recovery))
		anim_player.seek(minf(clip_length * phase, clip_length - 0.001), true)

func _process_hit_react(delta: float) -> void:
	_slow_down(delta)
	state_timer += delta
	if state_timer>=float(_config.get("hit_recovery",0.3)): _enter_state(State.CHASE if _valid_target() else State.IDLE)

func _enter_state(next_state: State) -> void:
	if state==next_state: return
	if state==State.ATTACK:
		attack_contact_timer = -1.0
		attack_phase = ""
		_brute_attack_clip = ""
		if model_instance:
			model_instance.rotation = _model_rest_rotation
	state = next_state
	state_timer = 0.0
	_path_due = 0.0
	match state:
		State.IDLE: _play_anim("Idle")
		State.PATROL,State.INVESTIGATE: _play_anim("Walk")
		State.CHASE: _play_anim("Run")
		State.ATTACK: _start_attack_swing()
		State.HIT_REACT: _play_anim("HitReact",true)
		State.DEAD: _play_anim("Death",true)

func _start_attack_swing() -> void:
	state_timer = 0.0
	attack_contact_timer = attack_contact_time
	attack_has_damaged = false
	attack_timer = attack_cooldown
	attack_phase = "windup"
	if enemy_type == "brute":
		_brute_attack_clip = str(_animations.get("attack", "Punch"))
		if anim_player and anim_player.has_animation(_brute_attack_clip):
			anim_player.play(_brute_attack_clip, 0.0)
			anim_player.speed_scale = 0.0
			_update_brute_attack_pose()
		else:
			_brute_attack_clip = ""
	else:
		_play_anim("Punch",true)
		if anim_player and anim_player.has_animation(anim_player.current_animation):
			anim_player.speed_scale = clampf(anim_player.get_animation(anim_player.current_animation).length/attack_cooldown,0.25,2.0)
	attack_started.emit(enemy_id,attack_contact_time)

func _try_apply_attack_damage() -> void:
	attack_has_damaged = true
	if state!=State.ATTACK or not _valid_target() or get_tree().paused: return
	if not _target_in_reach(attack_range+float(_config.get("attack_hit_tolerance",0.12))): return
	var direction := target_player.global_position-global_position
	direction.y = 0.0
	var arc_cos := cos(deg_to_rad(float(_config.get("attack_arc_degrees",100.0)))*0.5)
	if direction.length_squared()>0.001 and (-global_basis.z).dot(direction.normalized())<arc_cos: return
	if not _has_line_of_sight(_target_chest(target_player)): return
	var before: float = float(target_player.get("health"))
	target_player.call("take_damage",attack_damage)
	var actual: float = maxf(0.0,before-float(target_player.get("health")))
	if actual>0.0: damage_dealt_to_player.emit(actual)

func _steer_towards(goal: Vector3,speed: float,delta: float) -> void:
	var next := goal
	var map: RID = nav_agent.get_navigation_map()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map)>0:
		if _path_due<=0.0 and (not _nav_target.is_finite() or _nav_target.distance_squared_to(goal)>0.36 or stuck_timer>0.6):
			nav_agent.target_position = goal
			_nav_target = goal
			_path_due = float(_config.get("path_interval",0.38))
		next = nav_agent.get_next_path_position()
		if nav_agent.is_navigation_finished() and _planar_distance(goal)>1.0:
			if _has_line_of_sight(goal+Vector3.UP): next = goal
			else:
				_slow_down(delta)
				return
	var direction := next-global_position
	direction.y = 0.0
	if direction.length_squared()<0.01:
		_slow_down(delta)
		return
	direction = direction.normalized()
	if _neighbor_due<=0.0:
		_neighbor_due = 0.2
		_update_separation()
	direction = (direction+_separation*0.65).normalized()
	if _recovery_remaining>0.0:
		_recovery_remaining -= delta
		direction = (direction+_recovery_direction*0.9).normalized()
	var wanted := direction*speed
	velocity.x = move_toward(velocity.x,wanted.x,_acceleration*delta)
	velocity.z = move_toward(velocity.z,wanted.z,_acceleration*delta)
	_look_at_smooth(global_position+direction,delta*_turn_speed)
	var actual := Vector2(velocity.x,velocity.z).length()
	_play_anim("Idle" if actual<0.18 else ("Run" if speed>walk_speed+0.1 else "Walk"))
	if anim_player and actual>=0.18: anim_player.speed_scale = clampf(actual/maxf(speed,0.1),0.55,1.15)
	# Bounded deterministic sidestep replaces per-frame random velocity jitter.
	if global_position.distance_squared_to(last_pos)<0.002 and actual>0.4:
		stuck_timer += delta
		if stuck_timer>1.0 and _recovery_remaining<=0.0:
			var side: float = 1.0 if absi(enemy_id.hash())%2==0 else -1.0
			_recovery_direction = Vector3(-direction.z,0,direction.x)*side
			_recovery_remaining = 0.65
			stuck_timer = 0.0
			_nav_target = Vector3(INF,INF,INF)
	else: stuck_timer = maxf(0.0,stuck_timer-delta*2.0)
	last_pos = global_position

func _update_separation() -> void:
	_separation = Vector3.ZERO
	var count := 0
	for other: Node in get_tree().get_nodes_in_group("enemies"):
		if other==self or not other is Node3D or bool(other.call("is_dead")): continue
		var offset: Vector3 = global_position-(other as Node3D).global_position
		if absf(offset.y)>1.2: continue
		offset.y = 0.0
		var distance := offset.length()
		if distance>0.01 and distance<1.2:
			_separation += offset/distance*(1.0-distance/1.2)
			count += 1
			if count>=4: break
	if _separation.length_squared()>1.0: _separation = _separation.normalized()

func _slow_down(delta: float,multiplier: float = 1.0) -> void:
	velocity.x = move_toward(velocity.x,0.0,_acceleration*multiplier*delta)
	velocity.z = move_toward(velocity.z,0.0,_acceleration*multiplier*delta)

func _try_step_up(delta: float) -> void:
	# Small consistent campus risers can be climbed; tall walls cannot. Queries
	# are bounded and only run after an actual grounded collision.
	if _step_due>0.0 or not is_on_floor() or not is_on_wall(): return
	var motion := Vector3(velocity.x,0,velocity.z)*delta
	if motion.length_squared()<0.00001: return
	_step_due = 0.12
	if not test_move(global_transform,motion): return
	var raised := global_transform
	raised.origin.y += 0.27
	if test_move(raised,motion): return
	var ahead := global_position+motion.normalized()*(float(_config.get("capsule_radius",0.35))+0.12)
	var query := PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*0.29,ahead-Vector3.UP*0.04,1,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y<0.65: return
	var rise: float = hit.position.y-global_position.y
	if rise<0.025 or rise>0.26: return
	global_position.y += rise+0.01
	_visual_step_offset = maxf(-0.4,_visual_step_offset-rise)

func _valid_target() -> bool:
	return is_instance_valid(target_player) and not bool(target_player.get("is_dead"))

func _planar_distance(point: Vector3) -> float:
	return Vector2(point.x-global_position.x,point.z-global_position.z).length()

func _target_in_reach(reach: float) -> bool:
	return _valid_target() and _planar_distance(target_player.global_position)<=reach and absf(target_player.global_position.y-global_position.y)<2.0

func _check_perception() -> bool:
	if _lookup_due<=0.0 or not is_instance_valid(_cached_candidate):
		_lookup_due = 0.75
		var players := get_tree().get_nodes_in_group("player")
		_cached_candidate = players[0] as CharacterBody3D if not players.is_empty() else null
	var candidate := _cached_candidate
	if candidate==null or bool(candidate.get("is_dead")): return false
	var offset := candidate.global_position-global_position
	if offset.length()>detection_radius: return false
	var flat := Vector3(offset.x,0,offset.z)
	if flat.length()>float(_config.get("close_awareness",3.0)) and target_player!=candidate and flat.length_squared()>0.01:
		var fov_cos := cos(deg_to_rad(float(_config.get("field_of_view_degrees",140.0)))*0.5)
		if (-global_basis.z).dot(flat.normalized())<fov_cos: return false
	if not _has_line_of_sight(_target_chest(candidate)): return false
	target_player = candidate
	return true

func _target_chest(candidate: CharacterBody3D) -> Vector3:
	# Both center-origin and feet-origin players are supported. Derive the
	# torso from actual capsule placement, not a guessed root offset.
	var collision := candidate.find_child("PlayerCollision",true,false) as CollisionShape3D
	if collision!=null and collision.shape is CapsuleShape3D:
		return collision.global_position+Vector3.UP*(collision.shape.height*0.18)
	return candidate.global_position+Vector3.UP*0.35

func hear_noise(point: Vector3,radius: float = 14.0) -> void:
	if state not in [State.IDLE,State.PATROL,State.INVESTIGATE] or not is_physics_processing() or get_tree().paused: return
	if global_position.distance_squared_to(point)>radius*radius: return
	last_known_position = point
	state_timer = 0.0
	_enter_state(State.INVESTIGATE)

func _has_line_of_sight(point: Vector3) -> bool:
	var height := float(_config.get("capsule_height",1.75))*0.8
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*height,point,1,[get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func take_damage(amount: float,is_headshot: bool = false,_hit_pos: Vector3 = Vector3.ZERO,impulse_dir: Vector3 = Vector3.ZERO) -> void:
	if state==State.DEAD or not is_physics_processing() or get_tree().paused or not is_finite(amount) or amount<=0.0: return
	health = maxf(0.0,health-amount)
	if health<=0.0:
		_die()
		return
	if not _valid_target():
		_lookup_due = 0.0
		_check_perception()
		if not _valid_target():
			var players := get_tree().get_nodes_in_group("player")
			if not players.is_empty(): target_player = players[0] as CharacterBody3D
	if _valid_target():
		last_known_position = target_player.global_position
		_lost_sight_time = 0.0
	# Brute body-shot poise avoids permanent stunlock; headshots stagger windup.
	if (enemy_type!="brute" or is_headshot) and _stagger_cooldown<=0.0 and (state!=State.ATTACK or attack_phase=="windup"):
		_stagger_cooldown = 1.0 if enemy_type=="brute" else 0.65
		_enter_state(State.HIT_REACT)
		var knockback := Vector3(impulse_dir.x,0,impulse_dir.z)
		if knockback.length_squared()>0.01:
			knockback = knockback.normalized()*0.8
			velocity.x += knockback.x
			velocity.z += knockback.z
	elif state in [State.IDLE,State.PATROL,State.INVESTIGATE]: _enter_state(State.CHASE)

func _die() -> void:
	if state==State.DEAD: return
	_enter_state(State.DEAD)
	attack_contact_timer = -1.0
	attack_phase = ""
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	enemy_died.emit(enemy_id,is_boss)

func is_dead() -> bool:
	return state==State.DEAD

func _look_at_smooth(target: Vector3,max_turn: float) -> void:
	var direction := target-global_position
	direction.y = 0.0
	if direction.length_squared()>0.001: rotation.y = rotate_toward(rotation.y,atan2(-direction.x,-direction.z),max_turn)

func _play_anim(name: String,restart: bool = false) -> void:
	if anim_player==null: return
	var key: String = {"Idle":"idle","Walk":"walk","Run":"run","Punch":"attack","HitReact":"hit","Death":"death"}.get(name,name.to_lower())
	var clip: String = str(_animations.get(key,name))
	if not anim_player.has_animation(clip): clip = name
	if not anim_player.has_animation(clip): return
	if restart or anim_player.current_animation!=clip:
		anim_player.speed_scale = 1.0
		anim_player.play(clip,0.15)
