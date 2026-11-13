extends CharacterBody3D
## First-Person Player Controller for Zombie RPG (After Hours)

signal health_changed(current: float, max_val: float)
signal stamina_changed(current: float, max_val: float)
signal player_died
signal interact_target_changed(target_info: Dictionary)

const WALK_SPEED: float = 4.0
const SPRINT_SPEED: float = 7.0
const JUMP_VELOCITY: float = 4.5
const GRAVITY: float = 12.0
const STAMINA_DRAIN_RATE: float = 25.0
const STAMINA_RECOVERY_RATE: float = 20.0
const GROUND_ACCELERATION: float = 18.0
const GROUND_BRAKING: float = 24.0
const AIR_ACCELERATION: float = 5.0
const STEP_HEIGHT: float = 0.30
const COYOTE_TIME: float = 0.10
const JUMP_BUFFER: float = 0.12

@export var mouse_sensitivity: float = 0.002
@export var reduced_motion: bool = false

var max_health: float = 100.0
var health: float = 100.0
var max_stamina: float = 100.0
var stamina: float = 100.0

var is_dead: bool = false
var _vehicle_seated := false
var input_enabled: bool = true

var camera: Camera3D
var camera_pitch: float = 0.0
var recoil_pitch_offset: float = 0.0
var weapon_controller: Node3D
var interaction_ray: RayCast3D

var current_interactable: Node = null
var current_interactable_text: String = ""

var _head_bob_timer: float = 0.0
var _initial_camera_y: float = 1.6
var _last_emitted_stamina: int = 100
var is_sprinting := false
var sprint_exhausted := false
var _stamina_recovery_delay := 0.0
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _fallback_jump_down := false
var _damage_roll := 0.0
var _step_visual_offset := 0.0
var _travel_speed := 0.0
var _landing_dip := 0.0
var _gait_weight := 0.0
var _door_system: Node

func _ready() -> void:
	add_to_group("player")
	_setup_collision()
	_setup_camera()
	_setup_interaction_ray()
	_setup_weapon()
	var campus: Variant = get_parent().get("campus")
	if is_instance_valid(campus): _door_system = campus.get("door_system")
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)

func _setup_collision() -> void:
	# Capsule collider: radius 0.4, height 1.8
	var col := CollisionShape3D.new()
	col.name = "PlayerCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col.shape = capsule
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	collision_layer = 2 # Player layer
	collision_mask = 1 | 4 # World geometry and obstacles
	floor_snap_length = 0.30
	floor_max_angle = deg_to_rad(48.0)
	floor_stop_on_slope = true
	safe_margin = 0.015

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.current = true
	camera.fov = 75.0
	camera.near = 0.025
	camera.position = Vector3(0, _initial_camera_y, 0)
	add_child(camera)

func _setup_interaction_ray() -> void:
	interaction_ray = RayCast3D.new()
	interaction_ray.name = "InteractionRay"
	interaction_ray.target_position = Vector3(0, 0, -2.0)
	interaction_ray.collision_mask = 1 | 8 # World and interactables
	interaction_ray.collide_with_areas = true
	interaction_ray.collide_with_bodies = true
	camera.add_child(interaction_ray)

func _setup_weapon() -> void:
	var weapon_script: Script = load("res://scripts/antigravity/zombie/weapon_controller.gd")
	if weapon_script:
		weapon_controller = weapon_script.new()
		weapon_controller.name = "WeaponController"
		weapon_controller.set("camera", camera)
		weapon_controller.set("player", self)
		camera.add_child(weapon_controller)

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled and not _vehicle_seated
	if not input_enabled:
		velocity = Vector3.ZERO
		_travel_speed = 0.0
		if weapon_controller:
			weapon_controller.call("set_aim", false)
		_clear_interaction()

func set_vehicle_seated(seated: bool) -> void:
	_vehicle_seated = seated
	set_input_enabled(false)
	set_physics_process(not seated)
	collision_layer = 0 if seated else 2
	collision_mask = 0 if seated else 1 | 4
	if weapon_controller:
		if seated:
			weapon_controller.call("cancel_reload")
		weapon_controller.visible = not seated and not is_dead

func add_recoil(kick: float) -> void:
	if reduced_motion:
		recoil_pitch_offset = clampf(recoil_pitch_offset + kick * 0.25, -0.05, 0.05)
	else:
		recoil_pitch_offset = clampf(recoil_pitch_offset + kick * 0.75, -0.25, 0.25)

func switch_weapon_slot(slot_index: int) -> void:
	var game = get_tree().root.find_child("ZombieGame", true, false)
	var inv = game.get("inventory") if game else null
	if inv == null:
		return
	var slots: Array = inv.get_weapon_slots()
	if slot_index < 0 or slot_index >= slots.size():
		return
	if weapon_controller and not weapon_controller._opening_allows_weapon(str(slots[slot_index].id)):
		return
	var slot_info: Dictionary = inv.call("switch_slot", slot_index)
	if slot_info.is_empty():
		return
	var w_id: String = str(slot_info.get("id", "pistol"))
	if weapon_controller and weapon_controller.has_method("switch_to_slot"):
		weapon_controller.call("switch_to_slot", w_id)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or is_dead:
		return
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Mouse look
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity, -deg_to_rad(85), deg_to_rad(85))
		camera.rotation.x = camera_pitch + recoil_pitch_offset
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				if weapon_controller:
					weapon_controller.call("trigger_fire")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if weapon_controller:
				weapon_controller.call("set_aim", event.pressed)
	
	elif event.is_action_pressed("interact") if InputMap.has_action("interact") else (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_try_interact()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			if weapon_controller:
				weapon_controller.call("start_reload")
		elif event.keycode == KEY_1:
			switch_weapon_slot(0)
		elif event.keycode == KEY_2:
			switch_weapon_slot(1)
		elif event.keycode == KEY_3:
			switch_weapon_slot(2)
		elif event.keycode == KEY_4 or event.keycode == KEY_0:
			if weapon_controller and weapon_controller.has_method("switch_to_slot"):
				weapon_controller.call("switch_to_slot", "bat")
		elif event.keycode == KEY_V:
			if weapon_controller and weapon_controller.has_method("quick_melee"):
				weapon_controller.call("quick_melee")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var grounded := is_on_floor()
	_coyote_left = COYOTE_TIME if grounded else maxf(0.0, _coyote_left - delta)
	if not grounded:
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	if not input_enabled:
		is_sprinting = false
		move_and_slide()
		_update_camera_motion(delta, Vector2.ZERO)
		return

	var move_vec := _movement_input()
	var aiming: bool = weapon_controller != null and bool(weapon_controller.get("is_aiming"))
	var sprint_pressed: bool = Input.is_action_pressed("run") if InputMap.has_action("run") else Input.is_key_pressed(KEY_SHIFT)
	# Standing still/aiming never consumes sprint stamina. Exhaustion has a
	# recovery threshold, avoiding the old five-point sprint/recover flicker.
	if stamina <= 0.0: sprint_exhausted = true
	if stamina >= max_stamina * 0.20: sprint_exhausted = false
	is_sprinting = sprint_pressed and grounded and move_vec.y < -0.1 and not aiming and not sprint_exhausted and stamina > 0.0
	if is_sprinting:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN_RATE * delta)
		_stamina_recovery_delay = 0.75
	else:
		_stamina_recovery_delay = maxf(0.0, _stamina_recovery_delay - delta)
		if _stamina_recovery_delay <= 0.0:
			stamina = minf(max_stamina, stamina + STAMINA_RECOVERY_RATE * delta)
	if int(stamina) != _last_emitted_stamina:
		_last_emitted_stamina = int(stamina)
		stamina_changed.emit(stamina, max_stamina)

	var jump_down: bool = Input.is_action_pressed("jump") if InputMap.has_action("jump") else Input.is_key_pressed(KEY_SPACE)
	var jump_pressed: bool = Input.is_action_just_pressed("jump") if InputMap.has_action("jump") else (jump_down and not _fallback_jump_down)
	_fallback_jump_down = jump_down
	_jump_buffer_left = JUMP_BUFFER if jump_pressed else maxf(0.0, _jump_buffer_left-delta)
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		is_sprinting = false

	var target_speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	if aiming: target_speed *= 0.72
	var direction := global_transform.basis * Vector3(move_vec.x, 0, move_vec.y)
	var target_velocity := Vector2(direction.x, direction.z) * target_speed
	var horizontal := Vector2(velocity.x, velocity.z)
	var acceleration := GROUND_ACCELERATION if grounded else AIR_ACCELERATION
	if move_vec.is_zero_approx(): acceleration = GROUND_BRAKING if grounded else AIR_ACCELERATION * 0.35
	horizontal = horizontal.move_toward(target_velocity, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	var before_move := global_position
	var fall_speed := velocity.y
	_try_step_up(delta)
	move_and_slide()
	var travelled := global_position - before_move
	_travel_speed = Vector2(travelled.x, travelled.z).length() / maxf(delta, 0.001)
	if not grounded and is_on_floor() and fall_speed < -2.0:
		_landing_dip = minf(0.055, absf(fall_speed) * 0.007)
	_update_camera_motion(delta, move_vec)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if weapon_controller and weapon_controller.has_method("is_automatic") and bool(weapon_controller.call("is_automatic")):
			weapon_controller.call("trigger_fire")
	_update_interaction()

func _movement_input() -> Vector2:
	var move_vec := Vector2.ZERO
	move_vec.x = float(_held("move_right",[KEY_D,KEY_RIGHT])) - float(_held("move_left",[KEY_A,KEY_Q,KEY_LEFT]))
	move_vec.y = float(_held("move_back",[KEY_S,KEY_DOWN])) - float(_held("move_forward",[KEY_W,KEY_Z,KEY_UP]))
	return move_vec.limit_length(1.0)

func _held(action: String, keys: Array) -> bool:
	if InputMap.has_action(action): return Input.is_action_pressed(action)
	for key: Key in keys:
		if Input.is_key_pressed(key): return true
	return false

func _try_step_up(delta: float) -> void:
	if not is_on_floor() or velocity.y > 0.0: return
	var motion := Vector3(velocity.x,0,velocity.z) * delta
	if motion.length_squared() < 0.000001 or not test_move(global_transform,motion): return
	if test_move(global_transform,Vector3.UP*STEP_HEIGHT): return
	var raised := global_transform.translated(Vector3.UP*STEP_HEIGHT)
	if test_move(raised,motion): return
	var landing := KinematicCollision3D.new()
	if not test_move(raised.translated(motion),Vector3.DOWN*(STEP_HEIGHT+0.06),landing): return
	if landing.get_normal().y < cos(floor_max_angle): return
	var rise := STEP_HEIGHT+landing.get_travel().y
	if rise <= 0.025 or rise > STEP_HEIGHT: return
	global_position += Vector3.UP*rise
	_step_visual_offset = minf(0.30,_step_visual_offset+rise)

func _update_camera_motion(delta: float, movement: Vector2) -> void:
	if camera == null: return
	var blend := 1.0-exp(-12.0*delta)
	recoil_pitch_offset = lerpf(recoil_pitch_offset,0.0,1.0-exp(-10.0*delta))
	_damage_roll = lerpf(_damage_roll,0.0,1.0-exp(-15.0*delta))
	_step_visual_offset = move_toward(_step_visual_offset,0.0,delta*1.8)
	var moving := input_enabled and is_on_floor() and _travel_speed > 0.08
	var aiming := weapon_controller != null and bool(weapon_controller.get("is_aiming"))
	var reloading := weapon_controller != null and bool(weapon_controller.get("is_reloading"))
	var strength := clampf(_travel_speed / WALK_SPEED, 0.0, 1.4) if moving and not reduced_motion else 0.0
	_gait_weight = lerpf(_gait_weight, strength, blend)
	# Phase follows distance covered, so pushing a wall cannot cause walking sway.
	if moving:
		_head_bob_timer = fmod(_head_bob_timer + _travel_speed * delta * TAU / (2.7 if is_sprinting else 2.1), TAU)
	_landing_dip = move_toward(_landing_dip, 0.0, delta * 0.19)
	var steady := 0.2 if aiming else 1.0
	var side := sin(_head_bob_timer)
	var step := cos(_head_bob_timer * 2.0)
	var bob := step * 0.012 * _gait_weight * steady
	var landing := 0.0 if reduced_motion else _landing_dip
	camera.position.y = lerpf(camera.position.y, _initial_camera_y + bob - _step_visual_offset - landing, blend)
	camera.position.x = lerpf(camera.position.x, side * 0.008 * _gait_weight * steady, blend)
	camera.rotation.x = clampf(camera_pitch + recoil_pitch_offset, -deg_to_rad(86.0), deg_to_rad(86.0))
	camera.rotation.z = 0.0 if reduced_motion else _damage_roll + side * 0.003 * _gait_weight * steady
	if weapon_controller:
		var sprint := float(is_sprinting and moving and not aiming and not reloading)
		var weight := _gait_weight * steady * (0.25 if reloading else 1.0)
		var hand_offset := Vector3(side * 0.014, step * 0.011 - sprint * 0.045 - landing * 0.6, absf(side) * 0.008)
		var hand_angles := Vector3(step * 0.012 - sprint * 0.12, side * 0.014, -side * 0.022 + sprint * 0.08)
		weapon_controller.position = weapon_controller.position.lerp(hand_offset * weight, blend)
		weapon_controller.rotation = weapon_controller.rotation.lerp(hand_angles * weight, blend)
	var target_fov := 75.0
	if not reduced_motion and input_enabled:
		if weapon_controller != null and bool(weapon_controller.get("is_aiming")): target_fov = 67.0
		elif is_sprinting: target_fov = 78.0
	camera.fov = lerpf(camera.fov,target_fov,1.0-exp(-8.0*delta))

func _clear_interaction() -> void:
	if current_interactable != null or not current_interactable_text.is_empty():
		if is_instance_valid(current_interactable) and current_interactable.has_method("set_focused"): current_interactable.set_focused(false)
		current_interactable = null
		current_interactable_text = ""
		interact_target_changed.emit({"target":null,"prompt":"","visible":false})

func _update_interaction() -> void:
	if interaction_ray == null or not input_enabled:
		_clear_interaction()
		return
	var target: Node = _find_interactable(interaction_ray.get_collider()) if interaction_ray.is_colliding() else null
	var prompt := ""
	if is_instance_valid(_door_system):
		var door: Dictionary = _door_system.get_target(camera,self,2.0)
		if not door.is_empty() and (target==null or float(door.distance)<camera.global_position.distance_to(interaction_ray.get_collision_point())):
			target = door.node
			prompt = door.prompt
			if prompt in ["Press E to open", "Press E to close"]:
				var action := "Close Door" if bool(target.get("is_open")) else "Open Door"
				var interact_key := "E"
				for event in InputMap.action_get_events("interact"):
					if event is InputEventKey:
						var code: Key = event.physical_keycode if event.physical_keycode else event.keycode
						if code:
							interact_key = OS.get_keycode_string(code)
							break
				prompt = "[%s] %s" % [interact_key, action]
	if target == null:
		_clear_interaction()
		return
	if prompt.is_empty():
		if target.has_method("set_interaction_point"):
			target.set_interaction_point(interaction_ray.get_collision_point())
		prompt = str(target.call("get_interaction_prompt"))
	if target != current_interactable or prompt != current_interactable_text:
		if is_instance_valid(current_interactable) and current_interactable.has_method("set_focused"): current_interactable.set_focused(false)
		current_interactable = target
		current_interactable_text = prompt
		interact_target_changed.emit({"target":target,"prompt":prompt,"visible":true})
		if target.has_method("set_focused"): target.set_focused(true)

func _find_interactable(obj: Object) -> Node:
	var curr: Node = obj as Node
	while curr and curr != get_tree().root:
		if curr.has_method("get_interaction_prompt") and curr.has_method("interact"):
			return curr
		curr = curr.get_parent()
	return null

func _try_interact() -> void:
	if interaction_ray:
		interaction_ray.force_raycast_update()
		_update_interaction()
	if current_interactable and is_instance_valid(current_interactable):
		if current_interactable.has_method("toggle"): current_interactable.toggle(self)
		else: current_interactable.call("interact", self)

func take_damage(amount: float) -> void:
	if is_dead or (not input_enabled and not _vehicle_seated) or not is_finite(amount) or amount<=0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	
	# Camera shake on hit
	if camera and not reduced_motion:
		_damage_roll = deg_to_rad(randf_range(-1.2, 1.2))
		recoil_pitch_offset += deg_to_rad(0.7)
	
	if health <= 0.0:
		_die()

func heal(amount: float) -> void:
	if is_dead or not is_finite(amount) or amount<=0.0:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)

func apply_armor_upgrade(bonus_health: float) -> void:
	max_health += bonus_health
	heal(bonus_health)

func _die() -> void:
	is_dead = true
	input_enabled = false
	velocity = Vector3.ZERO
	if weapon_controller:
		weapon_controller.call("cancel_reload")
		weapon_controller.hide()
	player_died.emit()

func capture_state() -> Dictionary:
	return {
		"health": health,
		"max_health": max_health,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y,
		"camera_pitch": camera_pitch,
		"weapon": weapon_controller.call("capture_state") if weapon_controller else {}
	}

func restore_state(data: Dictionary) -> void:
	health = float(data.get("health", 100.0))
	max_health = float(data.get("max_health", 100.0))
	stamina = float(data.get("stamina", 100.0))
	max_stamina = float(data.get("max_stamina", 100.0))
	is_dead = false
	input_enabled = true
	velocity = Vector3.ZERO
	recoil_pitch_offset = 0.0
	_damage_roll = 0.0
	_step_visual_offset = 0.0
	sprint_exhausted = false
	_travel_speed = 0.0
	_gait_weight = 0.0
	_landing_dip = 0.0
	_head_bob_timer = 0.0
	if weapon_controller:
		weapon_controller.position = Vector3.ZERO
		weapon_controller.rotation = Vector3.ZERO
	_stamina_recovery_delay = 0.0
	
	var pos: Array = data.get("position", [-27.0, 1.25, -85.0])
	global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	rotation.y = float(data.get("rotation_y", 0.0))
	camera_pitch = float(data.get("camera_pitch", 0.0))
	if camera:
		camera.rotation.x = camera_pitch
	
	if weapon_controller:
		weapon_controller.show()
		if data.has("weapon"):
			weapon_controller.call("restore_state", data["weapon"])
	
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
