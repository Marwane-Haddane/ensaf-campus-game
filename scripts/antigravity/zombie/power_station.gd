extends StaticBody3D
## A breaker cabinet with two independently installable, saved components.

signal component_installed(part_id: String)
signal power_restored

const Geometry = preload("res://scripts/antigravity/zombie/prop_geometry.gd")
const PARTS := ["item_power_fuse", "item_power_relay"]
const PART_NAMES := ["Main Fuse", "Control Relay"]

var mission: RefCounted
var inventory: RefCounted
var is_activated := false
var _components: Array[Node3D] = []
var _leds: Array[StandardMaterial3D] = []
var _status: Label3D
var _aimed_part := 0

func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 1 | 8
	collision_mask = 0
	_build_cabinet()
	sync_state()

func _build_cabinet() -> void:
	var shell := Geometry.metal(Color("777b85"))
	var edge := Geometry.metal(Color("454959"))
	var recess := Geometry.metal(Color("21212b"), 0.1)
	var hardware := Geometry.metal(Color("c4bcb0"), 0.55)
	var hazard := Geometry.metal(Color("d3aa2f"), 0.1)
	Geometry.box(self, Vector3(1.16, 1.29, 0.32), Vector3(0, 0.05, -0.13), shell)
	Geometry.box(self, Vector3(1.22, 0.09, 0.38), Vector3(0, 0.71, -0.12), edge)
	Geometry.box(self, Vector3(1.27, 0.10, 0.46), Vector3(0, -0.63, -0.11), edge)
	Geometry.box(self, Vector3(1.06, 0.13, 0.04), Vector3(0, -0.48, 0.05), recess)
	for i in range(6):
		var stripe := Geometry.box(self, Vector3(0.095, 0.094, 0.018), Vector3(-0.43 + i * 0.17, -0.48, 0.077), hazard)
		stripe.rotation.z = -0.34
	for x in [-0.53, 0.53]:
		for y in [-0.35, 0.56]:
			var bolt := Geometry.cylinder(self, 0.025, 0.02, Vector3(x, y, 0.056), hardware)
			bolt.rotation.x = PI / 2.0
	for i in range(4):
		Geometry.box(self, Vector3(0.014, 0.035, 0.17), Vector3(0.584, 0.44 - i * 0.075, -0.11), recess)
	for y in [-0.44, -0.28]:
		var pipe := Geometry.cylinder(self, 0.047, 0.30, Vector3(0.71, y, -0.14), edge)
		pipe.rotation.z = PI / 2.0
		Geometry.box(self, Vector3(0.08, 0.14, 0.13), Vector3(0.85, y, -0.14), hardware)
	_status = Label3D.new()
	_status.position = Vector3(0, 0.57, 0.07)
	_status.font_size = 36
	_status.pixel_size = 0.003
	_status.outline_size = 4
	add_child(_status)
	for i in range(PARTS.size()):
		var x := -0.26 if i == 0 else 0.26
		Geometry.box(self, Vector3(0.43, 0.59, 0.06), Vector3(x, -0.02, 0.058), edge)
		Geometry.box(self, Vector3(0.34, 0.49, 0.05), Vector3(x, -0.02, 0.092), recess)
		for y in [-0.20, 0.16]:
			Geometry.box(self, Vector3(0.17, 0.042, 0.056), Vector3(x, y, 0.129), hardware)
		var led := Geometry.metal(Color("ffbb54"), 0.0)
		led.emission_enabled = true
		led.emission_energy_multiplier = 0.38
		_leds.append(led)
		Geometry.box(self, Vector3(0.17, 0.064, 0.042), Vector3(x, 0.38, 0.085), recess)
		Geometry.box(self, Vector3(0.128, 0.038, 0.02), Vector3(x, 0.38, 0.112), led)
		var part := Node3D.new()
		part.position = Vector3(x, -0.02, 0.17)
		add_child(part)
		_components.append(part)
		if i == 0:
			Geometry.cylinder(part, 0.07, 0.32, Vector3.ZERO, hazard)
			for y in [-0.155, 0.155]:
				Geometry.cylinder(part, 0.082, 0.06, Vector3(0, y, 0), hardware)
		else:
			Geometry.box(part, Vector3(0.23, 0.24, 0.12), Vector3.ZERO, hazard)
			for offset in [-0.07, 0.0, 0.07]:
				Geometry.box(part, Vector3(0.03, 0.17, 0.028), Vector3(offset, 0, 0.07), edge)
	var work_light := OmniLight3D.new()
	work_light.position = Vector3(0, 0.65, 0.5)
	work_light.light_color = Color("ffdfb0")
	work_light.light_energy = 0.48
	work_light.omni_range = 2.0
	add_child(work_light)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.24, 1.42, 0.54)
	var collider := CollisionShape3D.new()
	collider.position = Vector3(0, 0.04, -0.05)
	collider.shape = shape
	add_child(collider)

func get_interaction_prompt() -> String:
	if is_activated:
		return "Substation Grid • Online"
	var states := "%s: %s  /  %s: %s" % [PART_NAMES[0], _part_state(0), PART_NAMES[1], _part_state(1)]
	var index := _next_part()
	if index >= 0:
		return "[%s] Install %s\n%s" % [_interact_key(), PART_NAMES[index], states]
	return "Substation Grid • Offline\n" + states

func set_interaction_point(hit_position: Vector3) -> void:
	_aimed_part = 1 if to_local(hit_position).x > 0.08 else 0

func _next_part() -> int:
	if _part_state(_aimed_part) == "Ready":
		return _aimed_part
	var other := 1 - _aimed_part
	return other if _part_state(other) == "Ready" else -1

func _part_state(index: int) -> String:
	if is_activated or (mission != null and PARTS[index] in mission.installed_power_parts):
		return "Installed"
	return "Ready" if inventory != null and inventory.has_item(PARTS[index]) else "Missing"

func _interact_key() -> String:
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey:
			var code: Key = event.physical_keycode if event.physical_keycode else event.keycode
			if code:
				return OS.get_keycode_string(code)
	return "E"

func interact(_player: Node) -> void:
	if is_activated or mission == null or inventory == null:
		return
	var index := _next_part()
	if index < 0:
		return
	var id: String = PARTS[index]
	if not inventory.remove_item(id):
		return
	mission.installed_power_parts.append(id)
	is_activated = mission.installed_power_parts.size() == PARTS.size()
	_refresh_cabinet()
	if is_activated:
		power_restored.emit()
	else:
		component_installed.emit(id)

func sync_state() -> void:
	is_activated = mission != null and mission.power_restored
	_aimed_part = 0
	_refresh_cabinet()

func _refresh_cabinet() -> void:
	for i in range(_components.size()):
		var installed := _part_state(i) == "Installed"
		_components[i].visible = installed
		var color := Color("62e7ad") if installed else Color("ffbb54")
		_leds[i].albedo_color = color
		_leds[i].emission = color
	_status.text = "GRID ONLINE" if is_activated else "GRID OFFLINE"
	_status.modulate = Color("62e7ad") if is_activated else Color("ffcf83")
