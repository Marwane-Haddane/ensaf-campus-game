extends CharacterBody3D
## Friendly Animated Survivor NPC (Shaun)

signal dialogue_requested(dialogue_lines: Array, speaker_name: String)
signal survivor_contacted

@export var character_name: String = "Shaun"
@export var model_path: String = "res://assets/antigravity/zombie/models/Characters_Shaun.tscn"
@export var custom_dialogue: Array = []
@export var reward_scrap: int = 0
@export var reward_medkit: int = 0

var model_instance: Node3D
var anim_player: AnimationPlayer
var dialogue_lines: Array = []
var has_spoken: bool = false
var reward_given: bool = false
var _wave_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("friendly_npc")
	_setup_collision()
	_setup_model()
	_load_dialogue()

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "SurvivorCol"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	col.shape = capsule
	col.position = Vector3(0, 0.88, 0)
	add_child(col)
	collision_layer = 1 | 8 # World & interactable
	collision_mask = 1

func _setup_model() -> void:
	var scene: PackedScene = load(model_path)
	if scene:
		model_instance = scene.instantiate() as Node3D
		add_child(model_instance)
		anim_player = model_instance.find_child("AnimationPlayer", true, false)
		_play_anim("Idle")

func _load_dialogue() -> void:
	if not custom_dialogue.is_empty():
		dialogue_lines = custom_dialogue.duplicate()
		return
	var path := "res://design/antigravity/zombie/episode_01.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.has("survivor"):
			dialogue_lines = parsed["survivor"].get("dialogue", [])

func _process(delta: float) -> void:
	if _wave_cooldown > 0.0:
		_wave_cooldown -= delta
	
	# Check distance to player
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p: CharacterBody3D = players[0] as CharacterBody3D
		var dist := global_position.distance_to(p.global_position)
		if dist < 6.0 and _wave_cooldown <= 0.0 and not has_spoken:
			_play_anim("Wave")
			_wave_cooldown = 8.0
			# Face player gently
			var target_pos := p.global_position
			target_pos.y = global_position.y
			look_at(target_pos, Vector3.UP)
			rotate_y(PI) # glTF face orientation

func _get_interact_key_hint() -> String:
	if InputMap.has_action("interact"):
		var events := InputMap.action_get_events("interact")
		if not events.is_empty() and events[0] is InputEventKey:
			var code = events[0].physical_keycode if events[0].physical_keycode != 0 else events[0].keycode
			if code != 0:
				return OS.get_keycode_string(code)
	return "E"

func get_interaction_prompt() -> String:
	return "[%s] Speak with %s" % [_get_interact_key_hint(), character_name]

func interact(player: Node) -> void:
	has_spoken = true
	_play_anim("Yes")
	
	if not reward_given and player:
		reward_given = true
		var game = get_tree().root.find_child("ZombieGame", true, false)
		var inv = game.get("inventory") if game else null
		var hud = game.get("hud") if game else null
		if inv:
			if inv.has_method("claim_reward"):
				var bonus: Dictionary = {"medkit":reward_medkit} if reward_medkit>0 else {}
				var granted: bool = inv.claim_reward("npc:"+character_name,0,reward_scrap,bonus)
				if granted and hud and (reward_scrap>0 or reward_medkit>0):
					hud.show_banner_message("Supplies received from "+character_name,3.0)
				survivor_contacted.emit()
				dialogue_requested.emit(dialogue_lines,character_name)
				return
			if reward_scrap > 0:
				inv.call("add_item", "scrap", reward_scrap)
				if hud:
					hud.call("show_banner_message", "+%d Scrap Parts received from %s!" % [reward_scrap, character_name], 3.5)
			if reward_medkit > 0:
				inv.call("add_item", "medkit", reward_medkit)
				if hud:
					hud.call("show_banner_message", "+%d Trauma Medkit received from %s!" % [reward_medkit, character_name], 3.5)
	
	survivor_contacted.emit()
	dialogue_requested.emit(dialogue_lines, character_name)

func _play_anim(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		if anim_name != "Idle":
			anim_player.queue("Idle")

func take_damage(_amount: float, _is_headshot: bool = false, _pos: Vector3 = Vector3.ZERO, _dir: Vector3 = Vector3.ZERO) -> void:
	# Shaun is invulnerable friendly NPC
	pass
