extends Node3D
## First-Person Weapon Controller with Animated Viewmodel, Weapon Switching, and Obstructed Ballistics

signal ammo_changed(mag: int, reserve: int)
signal weapon_fired
signal reload_started
signal reload_completed
signal weapon_switched(weapon_id: String, weapon_name: String)
signal hit_enemy(damage: float, is_headshot: bool, enemy_node: Node)

@export var camera: Camera3D
@export var player: CharacterBody3D

var config_weapons: Dictionary = {}
var current_weapon_id: String = "pistol"
var weapon_data: Dictionary = {}

# Per-weapon ammo pools so switching weapons retains ammo
var weapon_pools: Dictionary = {
	"pistol": {
		"mag": 12,
		"capacity": 12,
		"reserve": 36,
		"max_reserve": 72
	},
	"scorpion": {
		"mag": 20,
		"capacity": 20,
		"reserve": 60,
		"max_reserve": 100
	}
}

var mag_ammo: int = 12
var mag_capacity: int = 12
var reserve_ammo: int = 36
var max_reserve: int = 72

var is_aiming: bool = false
var is_reloading: bool = false
var fire_cooldown_timer: float = 0.0
var reload_timer: float = 0.0
var _reload_duration := 0.0
var _reload_clips: Array[String] = []

var viewmodel_root: Node3D
var anim_player: AnimationPlayer
var muzzle_flash: OmniLight3D

var hip_pos: Vector3 = Vector3(0.08, -0.16, -0.22)
var aim_pos: Vector3 = Vector3(0.0, -0.125, -0.18)
var target_pos: Vector3 = Vector3(0.08, -0.16, -0.22)
var hip_rotation := Vector3.ZERO
var aim_rotation := Vector3.ZERO
var _visual_recoil := 0.0
var _noise_cooldown := 0.0
var _audio_players: Dictionary = {}
var _muzzle_skeleton: Skeleton3D
var _muzzle_bone := -1

func _init() -> void:
	_load_all_configs()

func _ready() -> void:
	_apply_weapon_config("pistol")
	_setup_viewmodel()

func _load_all_configs() -> void:
	var path := "res://design/antigravity/zombie/weapons.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.has("weapons"):
			config_weapons = parsed["weapons"]

func _apply_weapon_config(w_id: String) -> void:
	current_weapon_id = w_id
	weapon_data = config_weapons.get(w_id, {})
	
	if not weapon_pools.has(w_id):
		weapon_pools[w_id] = {
			"mag": int(weapon_data.get("initial_mag", 12)),
			"capacity": int(weapon_data.get("magazine_capacity", 12)),
			"reserve": int(weapon_data.get("initial_reserve", 36)),
			"max_reserve": int(weapon_data.get("max_reserve", 72))
		}
	
	var pool: Dictionary = weapon_pools[w_id]
	mag_ammo = int(pool.get("mag", 12))
	mag_capacity = int(pool.get("capacity", 12))
	reserve_ammo = int(pool.get("reserve", 36))
	max_reserve = int(pool.get("max_reserve", 72))
	
	var hp = weapon_data.get("hip_position", [0.08, -0.16, -0.22])
	hip_pos = Vector3(hp[0], hp[1], hp[2])
	var ap = weapon_data.get("aim_position", [0.0, -0.125, -0.18])
	aim_pos = Vector3(ap[0], ap[1], ap[2])
	target_pos = hip_pos
	var hr: Array = weapon_data.get("hip_rotation",[0,0,0])
	var ar: Array = weapon_data.get("aim_rotation",[0,0,0])
	hip_rotation = Vector3(deg_to_rad(hr[0]),deg_to_rad(hr[1]),deg_to_rad(hr[2]))
	aim_rotation = Vector3(deg_to_rad(ar[0]),deg_to_rad(ar[1]),deg_to_rad(ar[2]))
	is_aiming = false
	_visual_recoil = 0.0
	fire_cooldown_timer = 0.0
	
	ammo_changed.emit(mag_ammo, reserve_ammo)
	weapon_switched.emit(current_weapon_id, weapon_data.get("name", "Weapon"))

func _setup_viewmodel() -> void:
	if viewmodel_root != null:
		viewmodel_root.hide()
		viewmodel_root.queue_free()
		viewmodel_root = null
		anim_player = null
	
	var scene_path: String = weapon_data.get("scene", "res://assets/antigravity/zombie/models/pistol_hands.tscn")
	var scene: PackedScene = load(scene_path)
	if scene:
		viewmodel_root = scene.instantiate() as Node3D
		add_child(viewmodel_root)
		var scale_val: float = float(weapon_data.get("viewmodel_scale", 0.011))
		viewmodel_root.scale = Vector3(scale_val, scale_val, scale_val)
		viewmodel_root.position = hip_pos
		viewmodel_root.rotation = hip_rotation
		for mesh: Node in viewmodel_root.find_children("*","GeometryInstance3D",true,false):
			(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_muzzle_skeleton = viewmodel_root.find_child("Skeleton3D",true,false) as Skeleton3D
		_muzzle_bone = _muzzle_skeleton.find_bone("weapon_end_066") if _muzzle_skeleton else -1
		
		anim_player = viewmodel_root.find_child("AnimationPlayer", true, false)
		if anim_player:
			var idle_anim := _get_anim_name("idle")
			if not idle_anim.is_empty() and anim_player.has_animation(idle_anim):
				anim_player.play(idle_anim,0.08)
				var a = anim_player.get_animation(idle_anim)
				if a:
					a.loop_mode = Animation.LOOP_LINEAR
		
		if muzzle_flash == null:
			muzzle_flash = OmniLight3D.new()
			muzzle_flash.light_color = Color(1.0, 0.8, 0.4)
			muzzle_flash.light_energy = 0.0
			muzzle_flash.omni_range = 3.5
			muzzle_flash.position = Vector3(0, 0.05, -0.4)
			add_child(muzzle_flash)

func _get_anim_name(key: String) -> String:
	var anim_map: Dictionary = weapon_data.get("animations", {})
	return str(anim_map.get(key, ""))

func _play_synth_sound(kind: String) -> void:
	if not is_inside_tree(): return
	var key := kind+"_shotgun" if kind=="shoot" and current_weapon_id=="shotgun" else kind
	if not _audio_players.has(key):
		# Bake each short original sound once. Automatic fire reuses a bounded
		# voice instead of generating thousands of samples/nodes on every shot.
		var samples := PackedByteArray()
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(key.hash())
		for index: int in range(2646):
			var t := float(index)/22050.0
			var sample := 0.0
			if kind=="shoot":
				sample = (rng.randf_range(-0.6,0.6)+sin(t*85.0*TAU)*0.18)*exp(-t*(20.0 if "shotgun" in key else 35.0))
			elif kind=="click": sample = sin(t*1800.0*TAU)*exp(-t*80.0)*0.15
			elif kind=="hit": sample = sin(t*880.0*TAU)*exp(-t*25.0)*0.16
			elif kind=="swing": sample = rng.randf_range(-0.35,0.35)*sin(t*120.0*TAU)*exp(-t*14.0)
			else: sample = rng.randf_range(-0.25,0.25)*exp(-fmod(t,0.05)*60.0)
			var value := clampi(int(sample*14000),-32768,32767)
			samples.append(value & 255)
			samples.append((value>>8)&255)
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = samples
		var voice := AudioStreamPlayer.new()
		voice.stream = stream
		voice.bus = "SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master"
		voice.volume_db = -12.0
		add_child(voice)
		_audio_players[key] = voice
	(_audio_players[key] as AudioStreamPlayer).play()

func _process(delta: float) -> void:
	if fire_cooldown_timer > 0.0:
		fire_cooldown_timer = maxf(0.0,fire_cooldown_timer-delta)
	_noise_cooldown = maxf(0.0,_noise_cooldown-delta)
	
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()
		else:
			_update_reload_pose()
	
	# Smooth aim blending
	if viewmodel_root:
		var steady_aim := is_aiming and not is_reloading
		target_pos = aim_pos if steady_aim else hip_pos
		_visual_recoil = lerpf(_visual_recoil,0.0,1.0-exp(-17.0*delta))
		var blend := 1.0-exp(-14.0*delta)
		var reload_dip := 0.0
		if is_reloading:
			var progress := get_reload_progress()
			reload_dip = 0.035 * sin(PI * progress)
			if current_weapon_id == "pistol":
				# Keep the imported magazine change below the aim line.
				reload_dip = 0.70 * smoothstep(0.0, 0.20, progress) * (1.0 - smoothstep(0.80, 1.0, progress))
		viewmodel_root.position = viewmodel_root.position.lerp(target_pos+Vector3(0,-reload_dip,_visual_recoil),blend)
		var target_rotation := aim_rotation if steady_aim else hip_rotation
		viewmodel_root.quaternion = viewmodel_root.quaternion.slerp(Quaternion.from_euler(target_rotation+Vector3(_visual_recoil*0.8,0,0)),blend)
	
	# Muzzle flash timer decay
	if muzzle_flash and muzzle_flash.light_energy > 0.0:
		muzzle_flash.light_energy = move_toward(muzzle_flash.light_energy, 0.0, delta * 25.0)

func set_aim(aiming: bool) -> void:
	if is_aiming == aiming:
		return
	is_aiming = aiming
	if anim_player and not is_reloading:
		if is_aiming:
			var aim_anim := _get_anim_name("aim")
			if not aim_anim.is_empty() and anim_player.has_animation(aim_anim):
				anim_player.play(aim_anim,0.10)
		else:
			var aim_back := _get_anim_name("aim_back")
			if not aim_back.is_empty() and anim_player.has_animation(aim_back):
				anim_player.play(aim_back,0.10)
			var idle_anim := _get_anim_name("idle")
			if not idle_anim.is_empty() and anim_player.has_animation(idle_anim):
				anim_player.queue(idle_anim)

func switch_to_slot(weapon_id: String) -> bool:
	if player and not bool(player.get("input_enabled")):
		return false
	if weapon_id == current_weapon_id or not config_weapons.has(weapon_id):
		return false
	
	# Save current ammo
	_sync_pool()
	cancel_reload()
	
	_apply_weapon_config(weapon_id)
	_setup_viewmodel()
	var draw := _get_anim_name("draw")
	if anim_player and not draw.is_empty() and anim_player.has_animation(draw):
		anim_player.play(draw,0.10)
		anim_player.queue(_get_anim_name("idle"))
	return true

func quick_melee() -> bool:
	if player and not bool(player.get("input_enabled")):
		return false
	if is_reloading or fire_cooldown_timer > 0.0:
		return false
	fire_cooldown_timer = 0.48
	_play_synth_sound("swing")
	_do_melee_swing()
	_perform_melee_strike()
	return true

func _do_melee_swing() -> void:
	if viewmodel_root == null or not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(viewmodel_root, "rotation:x", hip_rotation.x + deg_to_rad(45.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(viewmodel_root, "position:z", hip_pos.z - 0.12, 0.12)
	tw.tween_property(viewmodel_root, "rotation:x", hip_rotation.x, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(viewmodel_root, "position:z", hip_pos.z, 0.22)

func _perform_melee_strike() -> void:
	if camera == null or not is_inside_tree():
		return
	var space_state := get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	var range_val: float = minf(2.8,float(weapon_data.get("range", 2.8)))
	var to: Vector3 = from - camera.global_transform.basis.z * range_val
	var exclude: Array[RID] = []
	if player:
		exclude.append(player.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4, exclude)
	var res := space_state.intersect_ray(query)
	if not res.is_empty():
		var col: Object = res.collider
		var enemy = _find_enemy_root(col)
		if enemy and enemy.has_method("take_damage"):
			var dmg: float = float(weapon_data.get("damage", 45.0)) if is_melee() else 18.0
			enemy.call("take_damage", dmg, false, res.position, -camera.global_transform.basis.z)
			hit_enemy.emit(dmg, false, enemy)
			_play_synth_sound("hit")
		else:
			_spawn_impact_fx(res.position, res.normal)

func trigger_fire() -> bool:
	if player and not bool(player.get("input_enabled")):
		return false
	if is_reloading or fire_cooldown_timer > 0.0:
		return false
	
	if bool(weapon_data.get("melee", false)):
		var fire_rate: float = float(weapon_data.get("fire_rate", 0.52))
		fire_cooldown_timer = fire_rate
		weapon_fired.emit()
		_play_synth_sound("swing")
		_do_melee_swing()
		_perform_melee_strike()
		return true
	
	if mag_ammo <= 0:
		fire_cooldown_timer = 0.22
		_play_synth_sound("click")
		start_reload()
		return false
	
	mag_ammo -= 1
	_sync_pool()
	
	var fire_rate: float = float(weapon_data.get("fire_rate", 0.28))
	fire_cooldown_timer = fire_rate
	ammo_changed.emit(mag_ammo, reserve_ammo)
	weapon_fired.emit()
	_play_synth_sound("shoot")
	_visual_recoil = minf(0.045,_visual_recoil+0.020)
	_emit_gunshot_noise()
	
	# Viewmodel animation
	if anim_player:
		var fire_key: String = "fire_last" if mag_ammo == 0 else "fire"
		var anim_name: String = _get_anim_name(fire_key)
		if anim_name.is_empty():
			anim_name = _get_anim_name("fire")
		if not anim_name.is_empty() and anim_player.has_animation(anim_name):
			anim_player.stop()
			anim_player.play(anim_name,0.045)
			var idle_name := _get_anim_name("aim") if is_aiming else _get_anim_name("idle")
			if not idle_name.is_empty() and anim_player.has_animation(idle_name):
				anim_player.queue(idle_name)
	
	# Muzzle flash
	if muzzle_flash:
		muzzle_flash.global_position = _get_muzzle_global_position()
		muzzle_flash.light_energy = 2.5
	
	# Recoil kick via player controller
	var kick: float = deg_to_rad(float(weapon_data.get("recoil_pitch", 1.5)))
	if player and player.has_method("add_recoil"):
		player.call("add_recoil", kick)
	
	# Perform hitscan with wall and muzzle obstruction validation
	_perform_raycast()
	return true

func _emit_gunshot_noise() -> void:
	if not is_inside_tree() or _noise_cooldown>0.0: return
	_noise_cooldown = 0.4
	var point := player.global_position if player else global_position
	for actor: Node in get_tree().get_nodes_in_group("enemies"):
		if actor.has_method("hear_noise"): actor.call("hear_noise",point,18.0 if current_weapon_id=="shotgun" else 14.0)

func _perform_raycast() -> void:
	if camera == null:
		return
	var pellet_count: int = int(weapon_data.get("pellet_count", 1))
	for p in range(pellet_count):
		_perform_single_pellet_raycast()

func _perform_single_pellet_raycast() -> void:
	if camera == null:
		return
	
	var space_state := camera.get_world_3d().direct_space_state
	var cam_origin := camera.global_position
	var range_val: float = float(weapon_data.get("range", 60.0))
	var forward := -camera.global_transform.basis.z.normalized()
	
	# Slight spread
	var spread: float = float(weapon_data.get("spread", 0.008))
	if is_aiming:
		spread *= 0.3
	forward += camera.global_transform.basis.x * randf_range(-spread, spread)
	forward += camera.global_transform.basis.y * randf_range(-spread, spread)
	forward = forward.normalized()
	
	var cam_target := cam_origin + forward * range_val
	var exclude: Array[RID] = []
	if player:
		exclude.append(player.get_rid())
	
	# 1. Camera aim raycast
	var cam_query := PhysicsRayQueryParameters3D.create(cam_origin, cam_target, 1 | 2 | 4, exclude)
	var cam_result := space_state.intersect_ray(cam_query)
	var target_point: Vector3 = cam_target
	if not cam_result.is_empty():
		target_point = cam_result.position
	
	# 2. Check muzzle clearance (ensure gun barrel is not embedded inside/behind wall)
	var muzzle_pos: Vector3 = _get_muzzle_global_position()
	var clearance_query := PhysicsRayQueryParameters3D.create(cam_origin, muzzle_pos, 1, exclude)
	var clearance_hit := space_state.intersect_ray(clearance_query)
	if not clearance_hit.is_empty():
		# Muzzle obstructed by wall directly in front of camera
		_spawn_impact_fx(clearance_hit.position, clearance_hit.normal)
		return
	
	# 3. Raycast from muzzle to target point to respect walls and barriers
	var muzzle_to_target := (target_point - muzzle_pos).normalized()
	var muzzle_dist := muzzle_pos.distance_to(target_point) + 0.1
	var muzzle_query := PhysicsRayQueryParameters3D.create(muzzle_pos, muzzle_pos + muzzle_to_target * muzzle_dist, 1 | 2 | 4, exclude)
	var result := space_state.intersect_ray(muzzle_query)
	
	if not result.is_empty():
		var collider: Object = result.collider
		var hit_pos: Vector3 = result.position
		var hit_normal: Vector3 = result.normal
		
		var enemy = _find_enemy_root(collider)
		if enemy and enemy.has_method("take_damage"):
			var base_damage: float = float(weapon_data.get("damage", 26.0))
			var rel_y: float = hit_pos.y - enemy.global_position.y
			var is_headshot := (rel_y > 1.35)
			var total_damage: float = base_damage * (float(weapon_data.get("headshot_multiplier", 2.2)) if is_headshot else 1.0)
			
			enemy.call("take_damage", total_damage, is_headshot, hit_pos, forward)
			hit_enemy.emit(total_damage, is_headshot, enemy)
			_play_synth_sound("hit")
		else:
			_spawn_impact_fx(hit_pos, hit_normal)
	elif not cam_result.is_empty():
		var collider: Object = cam_result.collider
		var hit_pos: Vector3 = cam_result.position
		var enemy = _find_enemy_root(collider)
		if enemy and enemy.has_method("take_damage"):
			var base_damage: float = float(weapon_data.get("damage", 26.0))
			var rel_y: float = hit_pos.y - enemy.global_position.y
			var is_headshot := (rel_y > 1.35)
			var total_damage: float = base_damage * (float(weapon_data.get("headshot_multiplier", 2.2)) if is_headshot else 1.0)
			enemy.call("take_damage", total_damage, is_headshot, hit_pos, forward)
			hit_enemy.emit(total_damage, is_headshot, enemy)
			_play_synth_sound("hit")
		else:
			_spawn_impact_fx(hit_pos, cam_result.normal)

func _get_muzzle_global_position() -> Vector3:
	if camera == null:
		return global_position
	if is_instance_valid(_muzzle_skeleton) and _muzzle_bone>=0:
		var point := _muzzle_skeleton.global_transform * _muzzle_skeleton.get_bone_global_pose(_muzzle_bone).origin
		if camera.to_local(point).z < -0.03: return point
	var basis := camera.global_transform.basis
	var fwd := -basis.z
	var rgt := basis.x
	var up := basis.y
	var off_fwd := 0.45
	var off_rgt := 0.0 if is_aiming else 0.08
	var off_down := -0.12 if is_aiming else -0.16
	return camera.global_position + (fwd * off_fwd) + (rgt * off_rgt) + (up * off_down)

func _find_enemy_root(collider: Object) -> Node:
	var curr: Node = collider as Node
	while curr and curr != get_tree().root:
		# Exclude friendly survivor NPC
		if curr.is_in_group("friendly_npc"):
			return null
		if curr.is_in_group("enemies"):
			# Exclude dead enemies
			if curr.has_method("is_dead") and curr.call("is_dead"):
				return null
			return curr
		curr = curr.get_parent()
	return null

func _spawn_impact_fx(pos: Vector3, normal: Vector3) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var host: Node = get_tree().current_scene
	if host == null or host == get_tree().root:
		var curr: Node = self
		while curr.get_parent() != null and curr.get_parent() != get_tree().root:
			curr = curr.get_parent()
		host = curr
	
	var p := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.03
	sphere.height = 0.06
	p.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	p.material_override = mat
	host.add_child(p)
	p.global_position = pos + normal * 0.02
	var tween := p.create_tween()
	tween.tween_property(p, "scale", Vector3(0.001, 0.001, 0.001), 0.25)
	tween.tween_callback(p.queue_free)


func start_reload() -> void:
	if bool(weapon_data.get("melee", false)):
		return
	if player and not bool(player.get("input_enabled")):
		return
	if is_reloading or mag_ammo >= mag_capacity or reserve_ammo <= 0:
		return
	
	is_reloading = true
	_reload_duration = maxf(0.1, float(weapon_data.get("reload_time", 2.0)))
	reload_timer = _reload_duration
	_reload_clips.clear()
	if anim_player:
		anim_player.clear_queue()
		for key in ["reload_start", "reloading", "reload_end"]:
			var clip := _get_anim_name(key)
			if anim_player.has_animation(clip) and clip not in _reload_clips:
				_reload_clips.append(clip)
	_update_reload_pose()
	reload_started.emit()
	_play_synth_sound("reload")

func get_reload_progress() -> float:
	return clampf(1.0 - reload_timer / _reload_duration, 0.0, 1.0) if is_reloading else 0.0

func _update_reload_pose() -> void:
	var progress := get_reload_progress()
	if current_weapon_id == "pistol":
		# This imported rig loses the hand contact during the magazine change.
		# Lower the held pistol as one piece, change the magazine out of view,
		# then raise the same two-handed pose.
		var changing_magazine := progress >= 0.20 and progress < 0.80
		if viewmodel_root:
			viewmodel_root.visible = not changing_magazine
		if not changing_magazine:
			var idle := _get_anim_name("idle")
			if anim_player and anim_player.has_animation(idle) and anim_player.current_animation != idle:
				anim_player.play(idle, 0.08)
			return
		progress = inverse_lerp(0.20, 0.80, progress)
	if _reload_clips.is_empty():
		return
	# The pistol has three authored phases, including a held magazine pose.
	# Other rigs can use a single clip on the same reload clock.
	var timeline := progress * _reload_clips.size()
	var phase := mini(int(timeline), _reload_clips.size() - 1)
	var clip := _reload_clips[phase]
	if anim_player.current_animation != clip or timeline == 0.0:
		anim_player.play(clip, 0.0, 0.0)
	var length := anim_player.get_animation(clip).length
	anim_player.seek(length * (timeline - phase), true)

func _restore_ready_pose() -> void:
	_reload_clips.clear()
	if viewmodel_root:
		viewmodel_root.show()
	if not anim_player:
		return
	var clip := _get_anim_name("aim" if is_aiming else "idle")
	if anim_player.has_animation(clip):
		anim_player.play(clip, 0.12)

func cancel_reload() -> void:
	if is_reloading:
		is_reloading = false
		reload_timer = 0.0
		_restore_ready_pose()

func _finish_reload() -> void:
	if not is_reloading:
		return
	
	var needed: int = maxi(0,mag_capacity - mag_ammo)
	var reload_amount: int = mini(needed, reserve_ammo)
	mag_ammo += reload_amount
	reserve_ammo -= reload_amount
	is_reloading = false
	reload_timer = 0.0
	_restore_ready_pose()
	
	_sync_pool()
	ammo_changed.emit(mag_ammo, reserve_ammo)
	reload_completed.emit()
	_play_synth_sound("click")

func add_ammo(amount: int, target_weapon_id: String = "") -> int:
	var w_id := target_weapon_id if not target_weapon_id.is_empty() else current_weapon_id
	if not weapon_pools.has(w_id):
		return 0
	var pool: Dictionary = weapon_pools[w_id]
	var cur_res: int = int(pool.get("reserve", 0))
	var max_res: int = int(pool.get("max_reserve", 72))
	var can_take: int = maxi(0, max_res - cur_res)
	var taken: int = mini(can_take, maxi(0,amount))
	pool["reserve"] = cur_res + taken
	
	if w_id == current_weapon_id:
		reserve_ammo = pool["reserve"]
		ammo_changed.emit(mag_ammo, reserve_ammo)
	return taken

func apply_extended_mag(new_capacity: int, target_weapon_id: String = "") -> void:
	var w_id := target_weapon_id if not target_weapon_id.is_empty() else current_weapon_id
	if weapon_pools.has(w_id):
		weapon_pools[w_id]["capacity"] = new_capacity
	if w_id == current_weapon_id:
		mag_capacity = new_capacity
		ammo_changed.emit(mag_ammo, reserve_ammo)

func _sync_pool() -> void:
	if weapon_pools.has(current_weapon_id):
		weapon_pools[current_weapon_id]["mag"] = mag_ammo
		weapon_pools[current_weapon_id]["capacity"] = mag_capacity
		weapon_pools[current_weapon_id]["reserve"] = reserve_ammo
		weapon_pools[current_weapon_id]["max_reserve"] = max_reserve

func is_automatic() -> bool:
	return bool(weapon_data.get("automatic", false))

func is_melee() -> bool:
	return bool(weapon_data.get("melee", false))

func get_current_weapon_name() -> String:
	return str(weapon_data.get("name", "Weapon"))

func capture_state() -> Dictionary:
	_sync_pool()
	return {
		"current_weapon_id": current_weapon_id,
		"weapon_pools": weapon_pools.duplicate(true),
		"mag_ammo": mag_ammo,
		"mag_capacity": mag_capacity,
		"reserve_ammo": reserve_ammo,
		"max_reserve": max_reserve
	}

func restore_state(data: Dictionary) -> void:
	cancel_reload()
	if data.has("weapon_pools") and data["weapon_pools"] is Dictionary:
		weapon_pools = data["weapon_pools"].duplicate(true)
	
	var w_id: String = str(data.get("current_weapon_id", "pistol"))
	_apply_weapon_config(w_id)
	
	if data.has("mag_ammo"):
		mag_ammo = int(data["mag_ammo"])
	if data.has("mag_capacity"):
		mag_capacity = int(data["mag_capacity"])
	if data.has("reserve_ammo"):
		reserve_ammo = int(data["reserve_ammo"])
	if data.has("max_reserve"):
		max_reserve = int(data["max_reserve"])
	
	_sync_pool()
	if is_inside_tree(): _setup_viewmodel()
	ammo_changed.emit(mag_ammo, reserve_ammo)

func reset_state() -> void:
	cancel_reload()
	fire_cooldown_timer = 0.0
	weapon_pools = {
		"pistol": {
			"mag": 12,
			"capacity": 12,
			"reserve": 36,
			"max_reserve": 72
		},
		"scorpion": {
			"mag": 20,
			"capacity": 20,
			"reserve": 60,
			"max_reserve": 100
		}
	}
	_apply_weapon_config("pistol")
	if is_inside_tree(): _setup_viewmodel()
