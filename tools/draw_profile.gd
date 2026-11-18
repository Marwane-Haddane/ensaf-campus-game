extends SceneTree
## Draw-call breakdown for art_audit roadmap item 3. Read-only: toggles are reverted.
## Godot --path . -s tools/draw_profile.gd -- --campus-quality=low [--out=res://art_audit/work/03_draws/profile.json]
const Harness = preload("res://tools/antigravity/preview_harness.gd")
const VIEW_IDS := ["plaza", "reception", "cream_front", "auditorium_rear"]
var game: Node3D
var report := {}


func _init() -> void:
	call_deferred("_run")


func _measure(frames: int = 12) -> Dictionary:
	for _i in range(8):
		await process_frame
		RenderingServer.force_draw(false)
	var start := Time.get_ticks_usec()
	for _i in range(frames):
		await process_frame
		RenderingServer.force_draw(false)
	var ms := float(Time.get_ticks_usec() - start) / 1000.0 / frames
	return {"ms": snappedf(ms, 0.01), "draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))}


func _collect(node: Node, out: Array) -> void:
	out.append(node)
	for c in node.get_children():
		_collect(c, out)


func _set_view(id: String) -> void:
	for v: Dictionary in Harness.VIEWS:
		if v.id != id:
			continue
		game.player.velocity = Vector3.ZERO
		game.player.transform.basis = Basis.IDENTITY
		game.pitch = 0.0
		game.camera.rotation = Vector3.ZERO
		if v.spawn != "" and game.SPAWNS.has(v.spawn):
			game._spawn(v.spawn)
		else:
			game.player.global_position = v.eye - Vector3(0, 0.65, 0)
			game.camera.look_at(v.target, Vector3.UP)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_2X
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	while not game.ready_to_play:
		await process_frame
	game._resume()
	for n in ["menu", "menu_shade"]:
		if is_instance_valid(game.get(n)):
			game.get(n).hide()
	if is_instance_valid(game.pause_menu):
		game.pause_menu.hide_menu()

	var nodes: Array = []
	_collect(game, nodes)
	var lights: Array = nodes.filter(func(n): return n is Light3D)
	var local_lights: Array = lights.filter(func(n): return n is OmniLight3D or n is SpotLight3D)
	var geo: Array = nodes.filter(func(n): return n is GeometryInstance3D)
	var transparent: Array = geo.filter(func(n): return n is MeshInstance3D and n.mesh != null and _is_transparent(n))
	report["scene"] = {
		"lights_total": lights.size(), "local_lights": local_lights.size(),
		"local_lights_visible": local_lights.filter(func(n): return n.visible).size(),
		"local_shadow_lights": local_lights.filter(func(n): return n.shadow_enabled).size(),
		"directional_shadow": lights.filter(func(n): return n is DirectionalLight3D and n.shadow_enabled).size(),
		"mesh_instances": geo.filter(func(n): return n is MeshInstance3D).size(),
		"multimesh_instances": geo.filter(func(n): return n is MultiMeshInstance3D).size(),
		"transparent_mesh_instances": transparent.size(),
		"cast_shadow_on": geo.filter(func(n): return n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF).size(),
		"surfaces_total": geo.reduce(func(a, n): return a + _surfaces(n), 0),
	}
	# Biggest surface counts by owner name prefix (first word of node name / parent).
	var groups := {}
	for n in geo:
		var key := str(n.get_parent().name) if n.get_parent() else "-"
		groups[key] = int(groups.get(key, 0)) + _surfaces(n)
	var top := groups.keys()
	top.sort_custom(func(a, b): return groups[a] > groups[b])
	report["surfaces_by_parent"] = top.slice(0, 25).map(func(k): return [k, groups[k]])
	print("DRAW_PROFILE_SCENE ", JSON.stringify(report.scene))

	report["views"] = {}
	for id: String in VIEW_IDS:
		_set_view(id)
		var r := {"base": await _measure()}
		for n in lights.filter(func(n): return n is DirectionalLight3D):
			n.set_meta("_s", n.shadow_enabled)
			n.shadow_enabled = false
		r["no_sun_shadow"] = await _measure()
		for n in lights.filter(func(n): return n is DirectionalLight3D):
			n.shadow_enabled = n.get_meta("_s")
		for n in local_lights:
			n.set_meta("_v", n.visible)
			n.visible = false
		r["no_local_lights"] = await _measure()
		for n in local_lights:
			n.visible = n.get_meta("_v")
		for n in transparent:
			n.set_meta("_v", n.visible)
			n.visible = false
		r["no_transparent"] = await _measure()
		for n in transparent:
			n.visible = n.get_meta("_v")
		for n in geo:
			n.set_meta("_c", n.cast_shadow)
			if n.get_aabb().size.length() < 1.5:
				n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r["small_no_cast"] = await _measure()
		for n in geo:
			n.cast_shadow = n.get_meta("_c")
		report.views[id] = r
		print("DRAW_PROFILE_VIEW ", id, " ", JSON.stringify(r))

	var out := "res://art_audit/work/03_draws/profile.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	FileAccess.open(out, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("DRAW_PROFILE_DONE ", out)
	quit(0)


func _surfaces(n: GeometryInstance3D) -> int:
	if n is MeshInstance3D and n.mesh:
		return n.mesh.get_surface_count()
	if n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh:
		return n.multimesh.mesh.get_surface_count()
	return 0


func _is_transparent(n: MeshInstance3D) -> bool:
	for i in range(n.mesh.get_surface_count()):
		var m := n.get_active_material(i)
		if m is BaseMaterial3D and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
	return false
