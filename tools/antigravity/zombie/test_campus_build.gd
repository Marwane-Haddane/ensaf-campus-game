@tool
extends SceneTree

func _init() -> void:
	var cr_script = load("res://scripts/campus_runtime.gd")
	var cr = cr_script.new()
	root.add_child(cr)
	
	var manifest_path = "res://assets/runtime_campus/manifest.json"
	if FileAccess.file_exists(manifest_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary and parsed.has("chunks"):
			print("Loading chunks from manifest (count: ", parsed.chunks.size(), ")...")
			var t_load = Time.get_ticks_msec()
			for chunk_path in parsed.chunks:
				var res = load(chunk_path)
				if res:
					cr.prepared_sections.append(res)
			print("Chunks loaded in ", Time.get_ticks_msec() - t_load, " ms")
	
	print("Building CampusRuntime with prepared_sections...")
	var t0 = Time.get_ticks_msec()
	cr.build()
	while not bool(cr.stats.get("ready", false)) and cr.build_error == "":
		await process_frame
	print("CampusRuntime ready in ", Time.get_ticks_msec() - t0, " ms! Ready=", cr.stats.get("ready"), " mesh_nodes=", cr.stats.get("mesh_nodes"))
	cr.queue_free()
	quit(0)
