extends StaticBody3D
## Field Workbench for RPG Upgrades (Armor & Magazine Capacity)

signal upgrade_menu_opened

var workbench_mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 1 | 8
	collision_mask = 0
	_build_visual()

func _build_visual() -> void:
	workbench_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.25,.09,.75)
	workbench_mesh.mesh = box
	workbench_mesh.position.y = .38
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.25, 0.2) # Wood / steel workbench
	mat.roughness = 0.7
	workbench_mesh.material_override = mat
	add_child(workbench_mesh)
	# Keep the original footprint, but give the workbench an actual worktop,
	# legs and shelf instead of an opaque block across the walking route.
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(.15,.19,.20)
	steel.metallic = .65
	steel.roughness = .48
	for x: float in [-.51,.51]:
		for z: float in [-.26,.26]:
			var leg := MeshInstance3D.new()
			var leg_box := BoxMesh.new()
			leg_box.size = Vector3(.06,.8,.06)
			leg.mesh = leg_box
			leg.position = Vector3(x,-.065,z)
			leg.material_override = steel
			add_child(leg)
	var shelf := MeshInstance3D.new()
	var shelf_box := BoxMesh.new()
	shelf_box.size = Vector3(1.07,.045,.59)
	shelf.mesh = shelf_box
	shelf.position.y = -.23
	shelf.material_override = steel
	add_child(shelf)
	var mat_pad := MeshInstance3D.new()
	var pad_box := BoxMesh.new()
	pad_box.size = Vector3(.60,.012,.42)
	mat_pad.mesh = pad_box
	mat_pad.position = Vector3(.15,.435,0)
	var pad := StandardMaterial3D.new()
	pad.albedo_color = Color(.10,.23,.22)
	pad.roughness = .9
	mat_pad.material_override = pad
	add_child(mat_pad)
	
	var col := CollisionShape3D.new()
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(1.25,.95,.75)
	col.shape = col_shape
	col.position.y = -.02
	add_child(col)

func _get_interact_key_hint() -> String:
	if InputMap.has_action("interact"):
		var events := InputMap.action_get_events("interact")
		if not events.is_empty() and events[0] is InputEventKey:
			var code = events[0].physical_keycode if events[0].physical_keycode != 0 else events[0].keycode
			if code != 0:
				return OS.get_keycode_string(code)
	return "E"

func get_interaction_prompt() -> String:
	var game = get_tree().root.find_child("ZombieGame", true, false)
	var inv = game.get("inventory") if game else null
	var scrap = inv.get_item_count("scrap") if inv else 0
	var owned: bool = inv != null and inv.has_upgrade("upgrade_armor") and inv.has_upgrade("upgrade_extended_mag")
	return "[%s] Workbench · upgrades installed" % _get_interact_key_hint() if owned else "[%s] Workbench · %d scrap · protection or capacity" % [_get_interact_key_hint(), scrap]

func interact(player: Node) -> void:
	upgrade_menu_opened.emit()
