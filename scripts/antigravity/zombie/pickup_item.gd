extends Area3D
## In-World Usable Pickup (Ammo, Medkits, Scrap, Power Components)

const Geometry = preload("res://scripts/antigravity/zombie/prop_geometry.gd")
const SupplyMarker = preload("res://scripts/antigravity/zombie/supply_marker.gd")
const SupplyVisuals = preload("res://scripts/antigravity/zombie/supply_visuals.gd")
const SUPPLY_CACHE_ID := "item_power_fuse"

signal collected(item_id: String, item_type: String, amount: int)

@export var item_id: String = "ammo_1"
@export var item_type: String = "ammo" # "ammo", "medkit", "scrap", "quest"
@export var item_name: String = "9mm Ammo Box"
@export var amount: int = 12
@export var weapon_id := ""

var _base_y: float = 0.0
var _anim_time: float = 0.0
var is_collected: bool = false
var _reduced_motion := false
var _cache_lid: Node3D
var _cache_trim: StandardMaterial3D
var _cache_tween: Tween

func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 8 # Interactable layer
	collision_mask = 0
	_base_y = position.y
	var preferences: Variant = get_parent().get("runtime_preferences")
	if preferences is Dictionary: _reduced_motion = preferences.get("reduced_motion",false)
	if item_id == SUPPLY_CACHE_ID:
		_build_supply_cache()
		set_cache_open(is_collected)
	else:
		_setup_visual()
		if item_type == "ammo":
			SupplyMarker.attach(self, "%s  +%d\nReload ammunition" % [item_name.to_upper(), amount], Color("ffbf66") if weapon_id == "shotgun" else Color("b3f2d7"), 0.55, 8)
		elif item_type == "medkit":
			SupplyMarker.attach(self, "MEDKIT\nStore for healing", Color("b3f2d7"), 0.55, 8)
		elif item_type == "scrap":
			SupplyMarker.attach(self, "SCRAP  +%d\nWorkbench upgrades" % amount, Color("ffbf66"), 0.55, 8)

func _build_supply_cache() -> void:
	var shell := Geometry.metal(Color("464e34"), 0.08)
	var rubber := Geometry.metal(Color("282930"), 0.0)
	var metal := Geometry.metal(Color("a19a89"), 0.55)
	var tape := Geometry.metal(Color("c5d93b"), 0.0)
	_cache_trim = Geometry.metal(Color("4d455d"), 0.05)
	_cache_trim.emission_enabled = true
	_cache_trim.emission = Color("866bff")
	_cache_trim.emission_energy_multiplier = 0.0
	Geometry.box(self, Vector3(0.67, 0.18, 0.39), Vector3(0, -0.025, 0), shell)
	Geometry.box(self, Vector3(0.69, 0.036, 0.41), Vector3(0, 0.07, 0), _cache_trim)
	Geometry.box(self, Vector3(0.67, 0.028, 0.39), Vector3(0, -0.115, 0), rubber)
	for x in [-0.29, 0.29]:
		for z in [-0.175, 0.175]:
			Geometry.box(self, Vector3(0.095, 0.176, 0.075), Vector3(x, -0.02, z), rubber)
	for x in [-0.20, 0.20]:
		Geometry.box(self, Vector3(0.075, 0.088, 0.044), Vector3(x, 0.024, 0.208), rubber)
		Geometry.box(self, Vector3(0.047, 0.039, 0.015), Vector3(x, 0.04, 0.234), metal)
	for x in [-0.087, 0.087]:
		Geometry.box(self, Vector3(0.025, 0.027, 0.065), Vector3(x, -0.026, 0.223), metal)
	Geometry.box(self, Vector3(0.20, 0.026, 0.030), Vector3(0, -0.026, 0.254), rubber)

	_cache_lid = Node3D.new()
	_cache_lid.position = Vector3(0, 0.085, -0.20)
	add_child(_cache_lid)
	Geometry.box(_cache_lid, Vector3(0.68, 0.054, 0.40), Vector3(0, 0.021, 0.20), rubber)
	Geometry.box(_cache_lid, Vector3(0.62, 0.024, 0.35), Vector3(0, 0.056, 0.20), shell)
	Geometry.box(_cache_lid, Vector3(0.085, 0.008, 0.35), Vector3(0, 0.072, 0.20), tape)
	for x in [-0.19, 0.19]:
		Geometry.box(_cache_lid, Vector3(0.025, 0.016, 0.32), Vector3(x, 0.075, 0.20), rubber)
	var lamp_glass := Geometry.metal(Color("ffcc80"), 0.0)
	lamp_glass.emission_enabled = true
	lamp_glass.emission = Color("ffbb63")
	Geometry.cylinder(self, 0.068, 0.035, Vector3(-0.53, -0.112, 0.01), rubber)
	Geometry.cylinder(self, 0.047, 0.103, Vector3(-0.53, -0.049, 0.01), lamp_glass)
	Geometry.cylinder(self, 0.062, 0.025, Vector3(-0.53, 0.014, 0.01), rubber)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-0.53, 0.11, 0.06)
	lamp.light_color = Color("ffcd92")
	lamp.light_energy = 0.65
	lamp.omni_range = 1.4
	add_child(lamp)
	_add_collision(Vector3(0.75, 0.34, 0.47))

func set_cache_open(opened: bool) -> void:
	if _cache_lid == null:
		return
	is_collected = opened
	collision_layer = 0 if opened else 8
	if _cache_tween and _cache_tween.is_running():
		_cache_tween.kill()
	_cache_lid.rotation_degrees.x = -78.0 if opened else 0.0
	set_focused(false)

func set_focused(focused: bool) -> void:
	if _cache_trim:
		_cache_trim.emission_energy_multiplier = 0.35 if focused and not is_collected else 0.0

func _setup_visual() -> void:
	if item_type in ["ammo", "medkit", "scrap", "weapon"]:
		SupplyVisuals.build(self, item_type, weapon_id)
		_add_collision(Vector3(0.66, 0.58, 0.65))
		if item_type == "weapon":
			SupplyMarker.attach(self, "PISTOL CASE", Color("ffbf66"), 0.55, 12)
		return

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	
	match item_type:
		"quest":
			# The glazed entrance relay is a keyed cartridge rather than a glowing cube.
			mesh_inst.free()
			Geometry.box(self, Vector3(0.24, 0.17, 0.16), Vector3.ZERO,
				Geometry.metal(Color("383848"), 0.2))
			var face := Geometry.metal(Color("d4a52e"), 0.12)
			Geometry.box(self, Vector3(0.20, 0.13, 0.02), Vector3(0, 0, 0.084), face)
			for x in [-0.057, 0.0, 0.057]:
				Geometry.cylinder(self, 0.012, 0.07, Vector3(x, -0.09, 0),
					Geometry.metal(Color("bb985e"), 0.65))
			_add_collision(Vector3(0.43, 0.37, 0.39))
			return

	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	_add_collision(box.size * 2.0)

func _add_collision(dimensions: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	col.shape = shape
	add_child(col)

func _process(delta: float) -> void:
	if is_collected or _reduced_motion or item_id == SUPPLY_CACHE_ID:
		return
	_anim_time += delta
	# Subtle hover and rotate
	position.y = _base_y + sin(_anim_time * 2.5) * 0.04
	# Keep recognizable faces and markings stable while the pickup gently bobs.

func _get_interact_key_hint() -> String:
	if InputMap.has_action("interact"):
		var events := InputMap.action_get_events("interact")
		if not events.is_empty() and events[0] is InputEventKey:
			var code = events[0].physical_keycode if events[0].physical_keycode != 0 else events[0].keycode
			if code != 0:
				return OS.get_keycode_string(code)
	return "E"

func get_interaction_prompt() -> String:
	if is_collected:
		return ""
	var k := _get_interact_key_hint()
	if item_id == SUPPLY_CACHE_ID:
		return "[%s] Open Supply Cache" % k
	match item_type:
		"weapon":
			return "[%s] Take the pistol" % k
		"ammo":
			return "[%s] Take %s (+%d)" % [k, item_name, amount]
		"medkit":
			return "[%s] Store %s (use from inventory to heal)" % [k, item_name]
		"scrap":
			return "[%s] Collect %s (+%d scrap for workbench upgrades)" % [k, item_name, amount]
		"quest":
			return "[%s] Take %s" % [k, item_name]
	return "[%s] Pick up " % k + item_name

func interact(player: Node) -> void:
	if is_collected:
		return
	
	var inventory = player.get_tree().root.find_child("ZombieGame", true, false)
	var inv = inventory.get("inventory") if inventory else null
	
	if item_type == "weapon":
		inv.unlock_weapon("pistol")
	elif item_type == "ammo":
		var wc = player.get("weapon_controller")
		if wc == null:
			return
		var accepted: int = wc.add_ammo(amount, weapon_id)
		if accepted == 0:
			if inventory:
				inventory.hud.show_banner_message("Ammo reserve full", 2.0)
			return
		amount = accepted
	elif item_type == "medkit":
		if inv and inv.has_method("add_item"):
			inv.call("add_item", "medkit", amount)
	elif item_type == "scrap":
		if inv and inv.has_method("add_item"):
			inv.call("add_item", "scrap", amount)
	elif item_type == "quest":
		if inv == null:
			return
		inv.add_item(item_id, 1)

	is_collected = true
	collision_layer = 0
	if _cache_lid:
		set_focused(false)
		if _reduced_motion:
			_cache_lid.rotation_degrees.x = -78.0
		else:
			_cache_tween = create_tween()
			_cache_tween.tween_property(_cache_lid, "rotation_degrees:x", -78.0, 0.42) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	collected.emit(item_id, item_type, amount)
	if _cache_lid:
		return
	
	# Shrink and disappear
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.001, 0.001, 0.001), 0.15)
	tween.tween_callback(queue_free)

