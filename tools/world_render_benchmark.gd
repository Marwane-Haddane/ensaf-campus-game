extends SceneTree
## Bounded, warmed native-renderer probe. Always draws when the tool window is minimized.
var game

func _init() -> void:
	call_deferred("run_probe")

func run_probe() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	while not game.ready_to_play:
		await process_frame
	game._resume()
	game.set_physics_process(false)
	var results: Array = []
	for destination: String in ["Security training area", "Reception / response desk"]:
		game._spawn(destination)
		for mode: String in ["4x", "2x", "2x_sun_only"]:
			root.msaa_3d = Viewport.MSAA_4X if mode == "4x" else Viewport.MSAA_2X
			game.set_process(mode != "2x_sun_only")
			if mode == "2x_sun_only":
				for light: SpotLight3D in game.contact_lights:
					light.shadow_enabled = false
			for frame: int in range(20):
				await process_frame
				RenderingServer.force_draw(false)
			var draw_usec: int = 0
			var started: int = Time.get_ticks_usec()
			for frame: int in range(30):
				await process_frame
				var before: int = Time.get_ticks_usec()
				RenderingServer.force_draw(false)
				draw_usec += Time.get_ticks_usec() - before
			var elapsed: float = float(Time.get_ticks_usec() - started) / 1000000.0
			var record: Dictionary = {"destination": destination,"mode":mode,"fps":30.0/elapsed,"forced_draw_ms":float(draw_usec)/30000.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
			results.append(record)
			print("RENDER_PROBE ", JSON.stringify(record))
		game.set_process(true)
	var file := FileAccess.open("res://tools/world_render_benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	game.queue_free()
	await process_frame
	quit()
