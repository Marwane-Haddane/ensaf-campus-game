extends RefCounted
## After Hours deep-dusk dressing (roadmap item #8), all presets.
## Places the Blender kit (tools/after_hours_kit.py) at the plaza edges, away from
## enemy patrols and pickups, adds a burning barrel, a smouldering burnt car and
## warning/alarm lights. Low uses fewer lights, particles and debris.

const KIT := "res://assets/antigravity/zombie/after_hours/"
const MoodLight = preload("res://scripts/antigravity/zombie/mood_light.gd")

## [template, x, z, yaw degrees, collide, skip on low]
const PLACEMENTS: Array = [
	["SM_AH_BurntCar", -37.5, -79.5, 68.0, true, false],
	["SM_AH_JerseyBarrier", -26.8, -72.2, 8.0, true, false],
	["SM_AH_JerseyBarrier", -13.4, -72.6, -12.0, true, false],
	["SM_AH_JerseyBarrier", -29.2, -73.6, 38.0, true, true],
	["SM_AH_PlankBarricade", -12.0, -86.0, 80.0, true, false],
	["SM_AH_PlankBarricade", -39.5, -92.5, 20.0, true, true],
	["SM_AH_RubblePile", -16.8, -82.6, 0.0, false, false],
	["SM_AH_RubblePile", -33.4, -81.6, 140.0, false, true],
	["SM_AH_RubblePile", -9.5, -91.0, 60.0, false, true],
]
## [mode, x, height above ground, z, colour, energy, range, skip on low]
const LIGHTS: Array = [
	["fire", -31.5, 1.3, -86.6, Color(1.0, 0.55, 0.22), 1.8, 8.0, false],
	["fire", -37.3, 1.2, -79.3, Color(1.0, 0.45, 0.18), 1.3, 6.5, false],
	["beacon", -22.0, 1.45, -73.0, Color(1.0, 0.62, 0.12), 1.6, 6.0, false],
	["beacon", -18.0, 1.45, -73.0, Color(1.0, 0.62, 0.12), 1.6, 6.0, true],
	["alarm", -8.0, 3.6, -99.5, Color(1.0, 0.12, 0.08), 1.4, 9.0, true],
	["alarm", -33.5, 3.4, -99.5, Color(1.0, 0.12, 0.08), 1.2, 8.0, true],
]


static func install(game: Node3D, preset: String, reduced_motion: bool = false) -> Dictionary:
	var result := {"props": 0, "lights": 0, "particles": 0}
	var low := preset == "low"
	var holder := Node3D.new()
	holder.name = "AfterHoursDressing"
	game.add_child(holder)
	var meshes := _load_meshes()
	for p: Array in PLACEMENTS:
		if (low and p[5]) or not meshes.has(p[0]):
			continue
		var ground: Vector3 = game.call("_ground_point", Vector3(p[1], 2.5, p[2]), 0.0)
		var node := MeshInstance3D.new()
		node.name = str(p[0]).trim_prefix("SM_AH_")
		node.mesh = meshes[p[0]]
		holder.add_child(node)
		node.global_position = ground
		node.rotation_degrees.y = p[3]
		if p[4]:
			_add_box_collision(node)
		result.props += 1
	# Scorch marks under the fires.
	for spot: Array in [[-37.5, -79.5, 6.5], [-31.5, -86.6, 2.6]]:
		_add_scorch(game, holder, Vector3(spot[0], 2.5, spot[1]), spot[2])
	for l: Array in LIGHTS:
		if low and l[7]:
			continue
		var light := OmniLight3D.new()
		light.set_script(MoodLight)
		light.set("mode", l[0])
		light.set("base_energy", l[5])
		light.set("reduced_motion", reduced_motion)
		light.light_color = l[4]
		light.omni_range = l[6]
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		holder.add_child(light)
		var ground: Vector3 = game.call("_ground_point", Vector3(l[1], 4.5, l[3]), 0.0)
		light.global_position = Vector3(l[1], ground.y + l[2], l[3])
		result.lights += 1
	# Fire and smoke.
	var barrel_top: Vector3 = game.call("_ground_point", Vector3(-31.5, 2.5, -86.6), 0.0) + Vector3(0, 0.95, 0)
	holder.add_child(_flames(barrel_top, 0.28, 40 if low else 70))
	var car_fire: Vector3 = game.call("_ground_point", Vector3(-37.2, 2.5, -79.3), 0.0) + Vector3(0, 1.0, 0)
	holder.add_child(_flames(car_fire, 0.55, 30 if low else 60))
	holder.add_child(_smoke(car_fire + Vector3(0, 1.4, 0), 14 if low else 28))
	if not low:
		holder.add_child(_smoke(barrel_top + Vector3(0, 1.1, 0), 12))
	result.particles = 4 if not low else 3
	return result


static func _load_meshes() -> Dictionary:
	var packed := load(KIT + "after_hours_kit.glb") as PackedScene
	if packed == null:
		return {}
	var materials := {
		"AH_Concrete": _material("concrete", 1.2, true),
		"AH_BurntMetal": _material("burnt_metal", 1.0, true),
		"AH_Wood": _material("wood", 1.0, true),
		"AH_Char": _material("burnt_metal", 0.5, false, Color(0.25, 0.22, 0.2)),
	}
	var scene := packed.instantiate()
	var meshes := {}
	for child: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (child as MeshInstance3D).mesh.duplicate() as Mesh
		for s: int in range(mesh.get_surface_count()):
			var source := mesh.surface_get_material(s)
			if source and materials.has(source.resource_name):
				mesh.surface_set_material(s, materials[source.resource_name])
		meshes[str(child.name)] = mesh
	scene.free()
	return meshes


static func _material(prefix: String, repeat_m: float, normal: bool, tint := Color.WHITE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "AH_" + prefix
	material.albedo_texture = load(KIT + prefix + "_albedo.png")
	material.albedo_color = tint
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE / repeat_m
	material.roughness = 0.9
	if normal and ResourceLoader.exists(KIT + prefix + "_normal.png"):
		material.normal_enabled = true
		material.normal_texture = load(KIT + prefix + "_normal.png")
	return material


static func _add_box_collision(node: MeshInstance3D) -> void:
	var box := node.mesh.get_aabb()
	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = box.size
	shape.shape = b
	shape.position = box.get_center()
	body.add_child(shape)
	node.add_child(body)


static func _add_scorch(game: Node3D, holder: Node3D, at: Vector3, size: float) -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(KIT + "scorch.png")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	quad.material = material
	var decal := MeshInstance3D.new()
	decal.name = "Scorch"
	decal.mesh = quad
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(decal)
	decal.global_position = game.call("_ground_point", at, 0.015)


static func _flames(at: Vector3, radius: float, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Flames"
	p.amount = amount
	p.lifetime = 0.7
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.6, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.7
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6)); curve.add_point(Vector2(0.3, 1.0)); curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	p.color_ramp = ramp
	p.mesh = _particle_quad(true)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.preprocess = p.lifetime  # start fully formed, not as one fresh puff
	p.position = at
	return p


static func _smoke(at: Vector3, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = amount
	p.lifetime = 4.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = Vector3(0.25, 1, 0)
	p.spread = 15.0
	p.gravity = Vector3(0.25, 0.35, 0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4)); curve.add_point(Vector2(1, 2.6))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.30, 0.28, 0.27, 0.0))
	ramp.add_point(0.15, Color(0.30, 0.28, 0.27, 0.32))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.42, 0.40, 0.40, 0.0))
	p.color_ramp = ramp
	p.mesh = _particle_quad(false)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.preprocess = p.lifetime  # start fully formed, not as one fresh puff
	p.position = at
	return p


static func _particle_quad(additive: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	soft.gradient = g
	material.albedo_texture = soft
	material.disable_receive_shadows = true
	quad.material = material
	return quad
