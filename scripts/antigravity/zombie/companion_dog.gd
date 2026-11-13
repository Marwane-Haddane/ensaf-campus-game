extends CharacterBody3D
## Tactical Companion Dog (Max the German Shepherd)
## Guards Shaun initially, then follows the player, alerts with barks, and engages hostile infected.

signal companion_barked(alert_type: String)

enum State {
	GUARD,
	FOLLOW,
	COMBAT
}

@export var dog_name: String = "Max"
var current_state: State = State.GUARD

var model_instance: Node3D
var anim_player: AnimationPlayer
var player_target: Node3D = null
var combat_target: Node3D = null

var follow_speed: float = 4.2
var sprint_speed: float = 6.8
var attack_damage: float = 18.0
var attack_cooldown: float = 0.0
var bark_cooldown: float = 0.0

var is_following_player: bool = false

func _ready() -> void:
	add_to_group("friendly_npc")
	add_to_group("companion")
	_setup_collision()
	_setup_model()

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "DogCol"
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.7, 1.1)
	col.shape = box
	col.position = Vector3(0, 0.35, 0)
	add_child(col)
	collision_layer = 1 | 8 # World & interactable
	collision_mask = 1 | 4 # World & obstacles

func _setup_model() -> void:
	var scene: PackedScene = load("res://assets/antigravity/zombie/models/Characters_GermanShepherd.scn")
	if scene:
		model_instance = scene.instantiate() as Node3D
		add_child(model_instance)
		anim_player = model_instance.find_child("AnimationPlayer", true, false)
		_play_anim("Idle")

func activate_follow(player: Node3D) -> void:
	player_target = player
	is_following_player = true
	current_state = State.FOLLOW
	_play_synth_bark(true)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 12.0 * delta
	
	if bark_cooldown > 0.0:
		bark_cooldown -= delta
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	
	match current_state:
		State.GUARD:
			_process_guard(delta)
		State.FOLLOW:
			_process_follow(delta)
		State.COMBAT:
			_process_combat(delta)
	
	move_and_slide()

func _process_guard(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * _delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * _delta)
	_play_anim("Idle")

func _process_follow(delta: float) -> void:
	if player_target == null or not is_instance_valid(player_target):
		var p_nodes := get_tree().get_nodes_in_group("player")
		if not p_nodes.is_empty():
			player_target = p_nodes[0] as Node3D
		else:
			return
	
	# Look for nearby threats to transition into COMBAT
	var nearby_enemy = _find_nearest_threat(8.0)
	if nearby_enemy:
		combat_target = nearby_enemy
		current_state = State.COMBAT
		if bark_cooldown <= 0.0:
			_play_synth_bark(false)
			bark_cooldown = 4.0
		return
	
	var to_player := player_target.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	
	# Maintain comfortable spacing (2.2m to 5m)
	if dist > 5.5:
		var dir := to_player.normalized()
		velocity.x = dir.x * sprint_speed
		velocity.z = dir.z * sprint_speed
		_orient_towards(global_position + dir)
		_play_anim("Run")
	elif dist > 2.5:
		var dir := to_player.normalized()
		velocity.x = dir.x * follow_speed
		velocity.z = dir.z * follow_speed
		_orient_towards(global_position + dir)
		_play_anim("Walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)
		_play_anim("Idle")

func _process_combat(delta: float) -> void:
	if combat_target == null or not is_instance_valid(combat_target) or (combat_target.has_method("is_dead") and combat_target.call("is_dead")):
		combat_target = null
		current_state = State.FOLLOW
		return
	
	var to_enemy := combat_target.global_position - global_position
	to_enemy.y = 0.0
	var dist := to_enemy.length()
	
	# Disengage if enemy moves too far from player (>12m)
	if player_target and global_position.distance_to(player_target.global_position) > 14.0:
		combat_target = null
		current_state = State.FOLLOW
		return
	
	if dist > 1.4:
		var dir := to_enemy.normalized()
		velocity.x = dir.x * sprint_speed
		velocity.z = dir.z * sprint_speed
		_orient_towards(global_position + dir)
		_play_anim("Run")
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 15.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 15.0)
		_orient_towards(combat_target.global_position)
		_play_anim("Attack")
		
		if attack_cooldown <= 0.0:
			attack_cooldown = 1.1
			if combat_target.has_method("take_damage"):
				var fwd := -global_transform.basis.z
				combat_target.call("take_damage", attack_damage, false, combat_target.global_position, fwd)
			_play_synth_bark(false)

func _find_nearest_threat(max_radius: float) -> Node3D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest: Node3D = null
	var min_d := max_radius
	for e in enemies:
		if is_instance_valid(e) and not (e.has_method("is_dead") and e.call("is_dead")):
			var d := global_position.distance_to(e.global_position)
			if d < min_d:
				min_d = d
				closest = e as Node3D
	return closest

func _orient_towards(target_point: Vector3) -> void:
	var look_target := target_point
	look_target.y = global_position.y
	if global_position.distance_squared_to(look_target) > 0.01:
		look_at(look_target, Vector3.UP)
		rotate_y(PI) # Align forward with glTF rig orientation

func _play_anim(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)

func _play_synth_bark(is_friendly: bool) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var asp := AudioStreamPlayer.new()
	asp.bus = "Master"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	asp.stream = gen
	add_child(asp)
	asp.play()
	var pb = asp.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var frames := int(22050.0 * 0.12)
		var base_freq := 440.0 if is_friendly else 320.0
		for i in range(frames):
			var t := float(i) / 22050.0
			var env := exp(-t * 28.0)
			var f := base_freq * (1.0 - t * 3.0)
			var sample := sin(t * f * TAU) * env * 0.5 + (randf() * 0.3 - 0.15) * env
			pb.push_frame(Vector2(sample, sample))
	var tween := asp.create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(asp.queue_free)
	companion_barked.emit("friendly" if is_friendly else "alert")
