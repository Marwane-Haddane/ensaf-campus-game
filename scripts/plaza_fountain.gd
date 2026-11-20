extends RefCounted
## Classical three-tier fountain (user supplied, baked by tools/export_fountain.py:
## 1.19M source triangles -> ~74k, one stone + one water surface).
## Stands on the open forecourt between the plaza palm row and the auditorium
## entrance; collision is three cheap cylinders, never the carved mesh.

const MODEL := "res://assets/props/fountain/fountain.glb"
const CENTRE := Vector3(-37.5, 0.0, -90.5)
const WATER_SHADER := "res://shaders/fountain_water.gdshader"

static func install(parent: Node3D, centre: Vector3 = CENTRE) -> Node3D:
	var packed := load(MODEL) as PackedScene
	if packed == null:
		push_warning("Fountain model missing: " + MODEL)
		return null
	var root := Node3D.new()
	root.name = "PlazaFountain"
	parent.add_child(root)
	var query := PhysicsRayQueryParameters3D.create(centre + Vector3.UP * 4.0, centre - Vector3.UP * 4.0, 1)
	var ground: Dictionary = parent.get_world_3d().direct_space_state.intersect_ray(query)
	root.position = Vector3(centre.x, ground["position"].y if not ground.is_empty() else 0.3, centre.z)
	var model := packed.instantiate() as Node3D
	root.add_child(model)
	_dress(model)
	# Basin wall (r 3.0, 0.62 m tall), the pedestal column and the lower bowl.
	var body := StaticBody3D.new()
	body.name = "FountainCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for spec: Array in [[3.0, 0.62, 0.31], [0.55, 3.5, 1.75], [1.55, 0.35, 1.55]]:
		var shape := CylinderShape3D.new()
		shape.radius = spec[0]
		shape.height = spec[1]
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = spec[2]
		body.add_child(collision)
	return root

## Stone casts shadows; the water is a gently moving, non-shadowing transparent sheet.
static func _dress(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.lod_bias = 0.5
		if mesh_node.name.contains("Water"):
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if ResourceLoader.exists(WATER_SHADER):
				var water := ShaderMaterial.new()
				water.shader = load(WATER_SHADER)
				mesh_node.material_override = water
	for child: Node in node.get_children():
		_dress(child)
