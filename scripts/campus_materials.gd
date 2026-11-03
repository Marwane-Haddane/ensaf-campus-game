extends RefCounted
## Shared, bounded-cost PBR materials for the owned campus geometry.
## Textures are generated once on the CPU, then sampled by Godot's native
## Compatibility StandardMaterial3D shader. No procedural fragment noise.

var stats: Dictionary = {"materials": 0, "texture_sets": 0, "normal_texture_sets": 0, "roughness_texture_sets": 0, "texture_bytes": 0, "generation_msec": 0, "preserved_mapped": 0, "families": {}}
var _allowed_names: Dictionary = {}
var _materials: Dictionary = {}
var _texture_sets: Dictionary = {}


func configure_manifest(material_records: Array) -> void:
	for value: Variant in material_records:
		if value is Dictionary:
			_allowed_names[str((value as Dictionary).get("name", ""))] = true


func apply_to_mesh(mesh_node: MeshInstance3D, source_name: String = "") -> void:
	for index: int in range(mesh_node.mesh.get_surface_count()):
		var original: Material = mesh_node.get_active_material(index)
		var polished: Material = material_for(original, source_name)
		if polished != original:
			# Updating the runtime Mesh resource also gives MultiMesh instances the
			# same per-surface material. The GLB and imported resource on disk stay intact.
			mesh_node.mesh.surface_set_material(index, polished)
			if mesh_node.get_surface_override_material(index) != null:
				mesh_node.set_surface_override_material(index, polished)


func material_for(original: Material, _source_name: String = "") -> Material:
	if original == null or bool(original.get_meta("campus_polished", false)):
		return original
	if not original is BaseMaterial3D:
		return original
	var source: BaseMaterial3D = original as BaseMaterial3D
	# Approved props and any source with authored maps keep those maps and UVs.
	if source.albedo_texture != null or not _allowed_names.has(source.resource_name):
		stats["preserved_mapped"] = int(stats["preserved_mapped"]) + 1
		return original
	var key: int = source.get_instance_id()
	if _materials.has(key):
		return _materials[key] as Material
	var family: String = _family_for(source)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = source.resource_name
	material.albedo_color = source.albedo_color
	material.metallic = source.metallic
	material.metallic_specular = 0.5
	material.roughness = clampf(source.roughness, 0.35, 0.98)
	material.cull_mode = source.cull_mode
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.emission_enabled = source.emission_enabled
	material.emission = source.emission
	material.emission_energy_multiplier = minf(source.emission_energy_multiplier, 0.7)
	material.set_meta("campus_polished", true)
	material.set_meta("campus_material_family", family)
	material.set_meta("campus_opaque", family != "glass")
	var lowered: String = source.resource_name.to_lower()
	if family == "glass":
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.13 if "clear" in lowered or "entrance" in lowered else 0.20
		material.metallic = 0.04
		material.metallic_specular = 0.65
		material.roughness = 0.10 if "clear" in lowered else 0.16
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif family == "simple":
		# PV arrays, diffusers, projection screens, paint and signs stay cheap.
		material.roughness = maxf(0.4, source.roughness)
	elif family in ["metal", "metal_painted", "grout"]:
		# Small hardware and modeled joints benefit from a smooth constant finish.
		_configure_finish(material, family)
	else:
		var texture_kind: String = _texture_kind(family)
		var texture_set: Dictionary = _get_texture_set(texture_kind)
		material.albedo_texture = texture_set["albedo"] as Texture2D
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_triplanar_sharpness = 8.0
		material.uv1_scale = _world_scale(family)
		# Reserve the extra three normal-map reads for genuinely coarse exterior
		# relief. Painted ceilings, stone floors, wood and upholstery stay smooth.
		if texture_set.has("normal"):
			material.normal_enabled = true
			material.normal_texture = texture_set["normal"] as Texture2D
			material.normal_scale = _normal_strength(family)
		_configure_finish(material, family)
	_materials[key] = material
	stats["materials"] = _materials.size()
	var family_counts: Dictionary = stats["families"] as Dictionary
	family_counts[family] = int(family_counts.get(family, 0)) + 1
	return material


func _family_for(material: BaseMaterial3D) -> String:
	var label: String = material.resource_name.to_lower()
	if material.albedo_color.a < 0.8 or "glass" in label or "glazing" in label:
		return "glass"
	if material.emission_enabled or "photovoltaic" in label or "solar" in label or "pv " in label or "busbar" in label or "module backing" in label or "projection" in label or "flag" in label or "sign" in label or "accent" in label or "blue circular" in label:
		return "simple"
	if "mortar" in label or "grout" in label or "fine shaded joints" in label:
		return "grout"
	if "asphalt" in label:
		return "asphalt"
	if "paving" in label or "paver" in label:
		return "paving"
	if "soil" in label:
		return "soil"
	if "bark" in label or "trunk" in label:
		return "bark"
	if "lawn" in label or "grass" in label:
		return "lawn"
	if "leaf" in label or "leaves" in label or "foliage" in label:
		return "foliage"
	if "carpet" in label:
		return "carpet"
	if "fabric" in label or "upholstery" in label or "piping" in label or "curtain" in label or "acoustic finish" in label or "charcoal panels" in label or "grey seating" in label:
		return "fabric"
	if "wood" in label or "oak" in label or "cherry" in label or "veneer" in label:
		if "transverse" in label:
			return "wood_transverse"
		if "fine directional" in label or "pale oak stage" in label:
			return "wood_horizontal"
		return "wood_vertical"
	if "stainless" in label or "aluminium" in label or "aluminum" in label or "steel" in label or "anodis" in label or "anodiz" in label or "wrought" in label or "iron" in label or "hardware" in label or "silver" in label or "metal" in label or "powder-coated" in label or "entrance frame" in label or "window frame" in label:
		return "metal_painted" if "paint" in label or "coated" in label or "charcoal" in label or "black" in label or "bronze" in label else "metal"
	if "terrazzo" in label:
		return "terrazzo"
	if "floor" in label or "interior stone" in label:
		return "floor_stone"
	if "slate" in label:
		return "slate"
	if "veined" in label:
		return "veined_stone"
	if "limestone" in label:
		return "limestone"
	if "plaster" in label or "mineral" in label or "concrete" in label or "precast" in label or "facade" in label or "white" in label or "pale yellow" in label or "lower wall" in label or "cladding" in label:
		return "mineral"
	return "simple"


func _configure_finish(material: StandardMaterial3D, family: String) -> void:
	match family:
		"mineral":
			material.roughness = 0.91
			material.metallic = 0.0
		"limestone":
			material.roughness = 0.82
			material.metallic = 0.0
		"floor_stone", "terrazzo", "veined_stone":
			material.roughness = 0.48 if family != "terrazzo" else 0.60
			material.metallic = 0.0
		"slate":
			material.roughness = 0.79
			material.metallic = 0.0
		"paving":
			material.roughness = 0.94
			material.metallic = 0.0
		"asphalt", "soil", "grout":
			material.roughness = 1.0
			material.metallic = 0.0
		"wood_vertical", "wood_horizontal", "wood_transverse":
			material.roughness = 0.47
			material.metallic = 0.0
		"fabric", "carpet":
			material.roughness = 0.98
			material.metallic = 0.0
		"lawn":
			material.albedo_color = material.albedo_color.lerp(Color("60713e"), 0.27)
			material.roughness = 1.0
			material.metallic = 0.0
		"foliage":
			material.albedo_color = material.albedo_color.lerp(Color("586e35"), 0.22)
			material.roughness = 0.85
			material.metallic = 0.0
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		"bark":
			material.roughness = 0.98
			material.metallic = 0.0
		"metal":
			material.metallic = 0.78
			material.roughness = 0.30
		"metal_painted":
			material.metallic = 0.24
			material.roughness = 0.43


func _texture_kind(family: String) -> String:
	if family.begins_with("wood_"):
		return "wood_horizontal" if family == "wood_horizontal" else "wood"
	if family == "metal_painted":
		return "metal"
	return family


func _world_scale(family: String) -> Vector3:
	match family:
		"paving": return Vector3.ONE / 2.4 # Four .60 m paving units per repeat.
		"mineral": return Vector3.ONE * 1.6
		"limestone", "slate", "veined_stone": return Vector3.ONE * 1.4
		"terrazzo", "floor_stone": return Vector3.ONE * 2.0
		"wood_vertical": return Vector3(2.0, 1.0, 2.0)
		"wood_horizontal": return Vector3(1.0, 2.0, 1.0)
		"wood_transverse": return Vector3(2.0, 1.0, 1.0)
		"fabric": return Vector3.ONE * 8.0
		"carpet": return Vector3.ONE * 5.0
		"foliage": return Vector3.ONE * 1.4
		"lawn": return Vector3.ONE * 1.25
		"bark": return Vector3(3.0, 1.0, 3.0)
		"soil", "asphalt": return Vector3.ONE * 3.0
		"metal", "metal_painted": return Vector3.ONE * 4.0
	return Vector3.ONE * 2.0


func _normal_strength(family: String) -> float:
	match family:
		"paving", "bark": return 0.18
		"soil": return 0.12
	return 0.0


func _get_texture_set(kind: String) -> Dictionary:
	if _texture_sets.has(kind):
		return _texture_sets[kind] as Dictionary
	# Exact offline bake of this generator avoids long CPU pixel loops during play.
	# The procedural path below remains a recovery path if derived assets are absent.
	var baked_path := "res://assets/runtime_surfaces/"+kind+"_albedo.png"
	if ResourceLoader.exists(baked_path):
		var albedo := load(baked_path) as Texture2D
		if albedo != null:
			var textures := {"albedo":albedo}
			var bytes: int = int(albedo.get_width()*albedo.get_height()*4)
			var normal_path := "res://assets/runtime_surfaces/"+kind+"_normal.png"
			if ResourceLoader.exists(normal_path):
				textures["normal"] = load(normal_path) as Texture2D
				bytes *= 2
				stats["normal_texture_sets"] = int(stats["normal_texture_sets"])+1
			_texture_sets[kind] = textures
			stats["texture_sets"] = _texture_sets.size()
			stats["texture_bytes"] = int(stats["texture_bytes"])+bytes
			return textures
	var started: int = Time.get_ticks_msec()
	var size: int = 256 if kind in ["paving", "wood", "wood_horizontal", "bark", "lawn"] else 128
	var albedo: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var needs_normal: bool = kind in ["paving", "bark", "soil"]
	var height: Image
	if needs_normal:
		height = Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 7271
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.043
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	for y: int in range(size):
		for x: int in range(size):
			var sample: Vector3 = _sample(kind, x, y, size, noise)
			var lightness: float = clampf(sample.x, 0.25, 1.0)
			albedo.set_pixel(x, y, Color(lightness, lightness, lightness, 1.0))
			if needs_normal:
				height.set_pixel(x, y, Color(sample.y, sample.y, sample.y, 1.0))
	albedo.generate_mipmaps()
	var result: Dictionary = {
		"albedo": ImageTexture.create_from_image(albedo),
	}
	var texture_bytes: int = albedo.get_data_size()
	if needs_normal:
		height.bump_map_to_normal_map(2.0)
		height.generate_mipmaps(true)
		result["normal"] = ImageTexture.create_from_image(height)
		texture_bytes += height.get_data_size()
		stats["normal_texture_sets"] = int(stats["normal_texture_sets"]) + 1
	_texture_sets[kind] = result
	stats["texture_sets"] = _texture_sets.size()
	stats["texture_bytes"] = int(stats["texture_bytes"]) + texture_bytes
	stats["generation_msec"] = int(stats["generation_msec"]) + Time.get_ticks_msec() - started
	return result


func _tile_noise(noise: FastNoiseLite, x: float, y: float, size: float) -> float:
	var u: float = x / size
	var v: float = y / size
	return lerpf(lerpf(noise.get_noise_2d(x, y), noise.get_noise_2d(x-size, y), u), lerpf(noise.get_noise_2d(x, y-size), noise.get_noise_2d(x-size, y-size), u), v)


func _random(x: int, y: int, seed_value: int = 0) -> float:
	var value: float = sin(float(x*127+y*311+seed_value*17))*43758.5453123
	return value-floor(value)


func _sample(kind: String, x: int, y: int, size: int, noise: FastNoiseLite) -> Vector3:
	var u: float = (float(x)+0.5)/float(size)
	var v: float = (float(y)+0.5)/float(size)
	var n: float = _tile_noise(noise, float(x), float(y), float(size))
	var fine: float = _random(x, y, 13)-0.5
	var c: float = 0.94 + n*0.08 + fine*0.03
	var h: float = 0.5 + fine*0.055
	var r: float = 0.94 + n*0.05
	match kind:
		"mineral":
			c = 0.985+n*0.010+fine*0.003
			h = 0.5
		"limestone":
			# Honed pores rather than a second coursing grid: the facades already
			# contain individual stone courses, and the same finish wraps the roof.
			var sediment: float = sin(TAU*(v*43.0+n*0.15))*0.5
			var pore: float = maxf(0.0, _random(x, y, 16)-0.94)*3.0
			c = 0.982+n*0.012+sediment*0.004+fine*0.004-pore*0.01
			h = 0.5
		"slate":
			var layer: float = sin(TAU*(v*31.0+n*0.6))*0.5+0.5
			c = 0.95+n*0.025+layer*0.018+fine*0.006
			h = 0.5
		"veined_stone":
			var vein: float = pow(absf(sin(TAU*(u*3.0+v*1.0+n*0.5))), 24.0)
			c = 0.98+n*0.012-vein*0.04+fine*0.003
			h = 0.5
			r = 0.86+n*0.05
		"floor_stone", "terrazzo":
			var aggregate: float = _random(x, y, 23)
			var chip: float = 0.0
			if aggregate > (0.965 if kind == "terrazzo" else 0.985):
				chip = 0.12 if kind == "terrazzo" else 0.018
			elif aggregate < 0.02:
				chip = -0.012 if kind == "terrazzo" else -0.004
			c = 0.985+n*0.009+fine*0.003-chip
			h = 0.5
			r = 0.88+n*0.04
		"paving":
			var row: int = floori(v*4.0)
			var horizontal: float = fposmod(u*4.0+float(row%2)*0.5, 1.0)
			var vertical: float = fposmod(v*4.0, 1.0)
			var col: int = floori(u*4.0+float(row%2)*0.5)
			var edge: float = minf(minf(horizontal, 1.0-horizontal), minf(vertical, 1.0-vertical))
			var face: float = smoothstep(0.002, 0.022, edge)
			var unit_tone: float = 0.92+_random(col%4, row, 48)*0.07
			c = lerpf(0.72, unit_tone, face)+n*0.015+fine*0.010
			h = lerpf(0.33, 0.53, face)+fine*0.025
			r = 0.95+fine*0.04
		"wood", "wood_horizontal":
			var across: float = v if kind == "wood_horizontal" else u
			var along: float = u if kind == "wood_horizontal" else v
			var warp: float = sin(TAU*along)*0.07+sin(TAU*(along*3.0))*0.025
			var grain: float = pow(absf(sin(TAU*(across*47.0+warp+n*0.08))), 7.0)
			var broad_grain: float = sin(TAU*(across*9.0+warp*0.5))
			c = 0.96-grain*0.040+broad_grain*0.008+n*0.010+fine*0.003
			h = 0.5
			r = 0.89-grain*0.055+n*0.025
		"fabric", "carpet":
			var weave_x: float = sin(TAU*u*32.0)
			var weave_y: float = sin(TAU*v*32.0)
			var weave: float = weave_x*weave_y
			c = 0.98+weave*0.010+fine*0.010+n*0.008
			h = 0.5
			r = 0.99
		"asphalt", "soil":
			var pebble: float = maxf(_random(x, y, 42)-0.88, 0.0)*0.8
			c = 0.84+n*0.13+fine*0.10+pebble
			h = 0.5+fine*0.13+pebble*0.4
			r = 0.98
		"lawn":
			var blade: float = sin(TAU*(u*67.0+v*19.0+n*0.9))*0.5+0.5
			c = 0.84+n*0.16+blade*0.08+fine*0.055
			h = 0.5
			r = 1.0
		"foliage":
			c = 0.85+n*0.20+fine*0.06
			h = 0.5
			r = 0.95
		"bark":
			var channel: float = pow(absf(sin(TAU*(u*17.0+sin(TAU*v*2.0)*0.10+n*0.08))), 5.0)
			c = 0.93-channel*0.19+n*0.08+fine*0.05
			h = 0.53-channel*0.17+fine*0.035
			r = 0.98
		"metal":
			var brush: float = sin(TAU*v*53.0)
			c = 0.97+brush*0.008+fine*0.009
			h = 0.5+brush*0.008
			r = 0.90+brush*0.035+fine*0.02
		"grout":
			c = 0.93+fine*0.06
			h = 0.5
			r = 1.0
	return Vector3(clampf(c, 0.2, 1.0), clampf(h, 0.0, 1.0), clampf(r, 0.0, 1.0))


func save_debug_textures(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	for key: Variant in _texture_sets:
		var texture_set: Dictionary = _texture_sets[key] as Dictionary
		for channel: String in texture_set:
			var texture: Texture2D = texture_set[channel] as Texture2D
			texture.get_image().save_png(directory.path_join(str(key)+"-"+channel+".png"))
