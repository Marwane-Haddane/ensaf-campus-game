extends SceneTree
## Where does frame time go? GPU vs CPU render vs game scripts, per view.
## Godot --path . -s tools/frame_profile.gd -- --campus-quality=low
## Read-only: every toggle is reverted before the next one.
const Harness = preload("res://tools/antigravity/preview_harness.gd")
const VIEW_IDS := ["glazed_entrance", "security", "cream_front", "cream_exterior_45", "plaza"]
var game: Node3D
var vp_rid: RID


func _init() -> void:
	call_deferred("_run")


func _measure() -> Dictionary:
	for _i in range(10):
		await process_frame
	var cpu := 0.0
	var gpu := 0.0
	var frame := 0.0
	var proc := 0.0
	var n := 15
	for _i in range(n):
		var t := Time.get_ticks_usec()
		await process_frame
		frame += float(Time.get_ticks_usec() - t) / 1000.0
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	return {"frame_ms": snappedf(frame / n, 0.1), "render_cpu_ms": snappedf(cpu / n, 0.1),
		"gpu_ms": snappedf(gpu / n, 0.1), "process_ms": snappedf(proc / n, 0.1),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))}


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
	vp_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
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
	_collect(root, nodes)
	var env: Environment = null
	for n in nodes:
		if n is WorldEnvironment:
			env = n.environment
	var geo: Array = nodes.filter(func(n): return n is GeometryInstance3D)
	var transparent: Array = geo.filter(func(n): return _is_transparent(n))
	var canvas: Array = nodes.filter(func(n): return n is CanvasItem and n.visible and n.get_parent() is CanvasLayer)
	var scripted: Array = nodes.filter(func(n): return n.get_script() != null and n.is_processing())
	var report := {"scene": {"transparent": transparent.size(), "processing_scripts": scripted.size(),
		"processing_script_names": scripted.map(func(n): return str(n.name)).slice(0, 40),
		"env": _env_info(env)}, "views": {}}
	print("FRAME_PROFILE_SCENE ", JSON.stringify(report.scene))
	for id: String in VIEW_IDS:
		_set_view(id)
		var r := {"base": await _measure()}
		root.scaling_3d_scale = 0.5
		r["half_res"] = await _measure()
		root.scaling_3d_scale = 1.0
		root.msaa_3d = Viewport.MSAA_DISABLED
		r["msaa_off"] = await _measure()
		root.msaa_3d = Viewport.MSAA_2X
		for n in transparent:
			n.set_meta("_v", n.visible)
			n.visible = false
		r["no_transparent"] = await _measure()
		for n in transparent:
			n.visible = n.get_meta("_v")
		if env:
			var saved := [env.glow_enabled, env.ssao_enabled, env.fog_enabled, env.ssr_enabled, env.sdfgi_enabled, env.volumetric_fog_enabled, env.adjustment_enabled]
			env.glow_enabled = false
			env.fog_enabled = false
			env.adjustment_enabled = false
			r["no_env_fx"] = await _measure()
			env.glow_enabled = saved[0]
			env.fog_enabled = saved[2]
			env.adjustment_enabled = saved[6]
		for n in canvas:
			n.set_meta("_v", n.visible)
			n.visible = false
		r["no_ui"] = await _measure()
		for n in canvas:
			n.visible = n.get_meta("_v")
		game.set_process(false)
		r["no_game_process"] = await _measure()
		game.set_process(true)
		report.views[id] = r
		print("FRAME_PROFILE_VIEW ", id, " ", JSON.stringify(r))
	var out := "res://art_audit/work/03_draws/frame_profile.json"
	FileAccess.open(out, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("FRAME_PROFILE_DONE")
	quit(0)


func _env_info(env: Environment) -> Dictionary:
	if env == null:
		return {}
	return {"glow": env.glow_enabled, "ssao": env.ssao_enabled, "fog": env.fog_enabled,
		"adjustment": env.adjustment_enabled, "sky": env.background_mode, "tonemap": env.tonemap_mode}


func _is_transparent(n: GeometryInstance3D) -> bool:
	var mesh: Mesh = n.mesh if n is MeshInstance3D else (n.multimesh.mesh if n is MultiMeshInstance3D and n.multimesh else null)
	if mesh == null:
		return false
	for i in range(mesh.get_surface_count()):
		var m: Material = n.material_override if n.material_override else (n.get_active_material(i) if n is MeshInstance3D else mesh.surface_get_material(i))
		if m is BaseMaterial3D and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
		if m is ShaderMaterial and not bool(m.get_meta("campus_opaque", false)):
			return true
	return false
