extends StaticBody3D
## Interactive Military Loot Chest
## Contains survival rewards such as scrap caches, field medkits, or unlockable weapons.

const SupplyMarker = preload("res://scripts/antigravity/zombie/supply_marker.gd")

signal chest_opened(chest_id: String, reward_type: String)

@export var chest_id: String = "chest_default"
@export var loot_type: String = "shotgun" # "shotgun" or "scrap"
@export var loot_amount: int = 25

var is_opened: bool = false
var lid_mesh: MeshInstance3D = null
var _lid_hinge: Node3D
var _inventory: RefCounted
var _open_tween: Tween
var _marker: Label3D

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("loot_chests")
	_setup_collision_and_mesh()
	if loot_type == "shotgun":
		_marker = SupplyMarker.attach(self, "◆  BENELLI M4  /  WEAPONS CASE", Color("ffbf66"), 1.18, 35)
	var game := get_tree().root.find_child("ZombieGame",true,false)
	_inventory = game.get("inventory") if game else null
	if _inventory != null:
		_inventory.inventory_changed.connect(_sync_open_state)
		_sync_open_state()

func _setup_collision_and_mesh() -> void:
	collision_layer = 1 | 8 # World & interactable
	collision_mask = 0
	
	# Collider
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.85, 0.55, 0.6)
	col.shape = box
	col.position = Vector3(0, 0.28, 0)
	add_child(col)
	
	# Visual Base Crate
	var base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(0.8, 0.4, 0.55)
	base.mesh = base_box
	base.position = Vector3(0, 0.2, 0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.28, 0.22) if loot_type == "shotgun" else Color(0.25, 0.25, 0.28) # Military Olive or Slate
	mat.metallic = 0.65
	mat.roughness = 0.45
	base.material_override = mat
	add_child(base)
	
	# Lid
	_lid_hinge = Node3D.new()
	_lid_hinge.position = Vector3(0,.40,-.275)
	add_child(_lid_hinge)
	lid_mesh = MeshInstance3D.new()
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(0.82, 0.12, 0.57)
	lid_mesh.mesh = lid_box
	lid_mesh.position = Vector3(0,.04,.275)
	
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.24, 0.36, 0.28) if loot_type == "shotgun" else Color(0.32, 0.32, 0.35)
	lid_mat.metallic = 0.7
	lid_mat.roughness = 0.4
	lid_mesh.material_override = lid_mat
	_lid_hinge.add_child(lid_mesh)
	
	# Accent Military Stencil Stripe
	var stripe := MeshInstance3D.new()
	var stripe_box := BoxMesh.new()
	stripe_box.size = Vector3(0.84, 0.04, 0.15)
	stripe.mesh = stripe_box
	stripe.position = Vector3(0,.065,0)
	var st_mat := StandardMaterial3D.new()
	st_mat.albedo_color = Color(0.9, 0.75, 0.25) # Gold / Warning yellow
	st_mat.metallic = 0.2
	st_mat.roughness = 0.3
	stripe.material_override = st_mat
	lid_mesh.add_child(stripe)

func _sync_open_state() -> void:
	if _inventory == null or not is_instance_valid(_inventory): return
	var claimed: bool = _inventory.has_claimed_reward("cache:"+chest_id)
	if claimed == is_opened: return
	is_opened = claimed
	if _marker: _marker.visible = not claimed
	if _open_tween != null and _open_tween.is_running(): _open_tween.kill()
	if _lid_hinge != null: _lid_hinge.rotation_degrees.x = -70.0 if is_opened else 0.0

func get_interaction_prompt() -> String:
	if is_opened:
		return ""
	var key := "E"
	if InputMap.has_action("interact"):
		var events := InputMap.action_get_events("interact")
		if not events.is_empty() and events[0] is InputEventKey:
			key = OS.get_keycode_string(events[0].physical_keycode if events[0].physical_keycode!=0 else events[0].keycode)
	if loot_type == "shotgun":
		return "[%s] Open weapons case · Benelli M4" % key
	return "[%s] Recover supplies · %d scrap + medkit" % [key,loot_amount]

func interact(player: Node) -> void:
	if is_opened:
		return
	var game = get_tree().root.find_child("ZombieGame", true, false)
	var inv = game.get("inventory") if game else null
	var hud = game.get("hud") if game else null
	if inv == null: return
	var awarded: bool = inv.claim_reward("cache:"+chest_id,15,loot_amount if loot_type!="shotgun" else 0,{} if loot_type=="shotgun" else {"medkit":1})
	if not awarded:
		_sync_open_state()
		return
	is_opened = true

	_play_open_sound()
	_animate_open()
	if loot_type == "shotgun":
		inv.unlock_weapon("shotgun")
		player.switch_weapon_slot(2)
	chest_opened.emit(chest_id, loot_type)

	if hud:
		if loot_type == "shotgun":
			hud.call("show_banner_message", "BENELLI M4 EQUIPPED · 3 to switch back · R to load shells", 4.5)
		else:
			hud.call("show_banner_message", "+%d Scrap & +1 Field Medkit recovered!" % loot_amount, 3.5)

func _animate_open() -> void:
	if _lid_hinge:
		_lid_hinge.rotation_degrees.x = 0.0
		_open_tween = create_tween()
		_open_tween.tween_property(_lid_hinge, "rotation_degrees:x", -70.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _play_open_sound() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var asp := AudioStreamPlayer.new()
	asp.bus = "SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	asp.stream = gen
	add_child(asp)
	asp.play()
	var pb = asp.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var frames := int(22050.0 * 0.22)
		for i in range(frames):
			var t := float(i) / 22050.0
			var env := exp(-t * 12.0)
			# Metallic latch click + creak sound
			var click := exp(-t * 70.0) * (randf() * 2.0 - 1.0) * 0.6
			var creak := sin(t * 320.0 * TAU) * 0.25 * env
			var sample := click + creak
			pb.push_frame(Vector2(sample, sample))
	var tween := asp.create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(asp.queue_free)
