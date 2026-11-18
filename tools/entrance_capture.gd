extends SceneTree
## Captures the cream entrance sign from the plaza (and the atrium glass) for QA.
##   godot --path . --resolution 1280x720 --script res://tools/entrance_capture.gd -- --campus-quality=high --out=res://art_audit/after/x
const VIEWS := {
	"sign_15m": [Vector3(-14.0, 0.0, 15.0), Vector3(-14.0, 3.7, 0.2)],
	"sign_25m": [Vector3(-10.0, 0.0, 25.0), Vector3(-14.0, 3.5, 0.2)],
	"sign_zoom": [Vector3(-14.0, 0.0, 15.0), Vector3(-14.0, 3.55, 0.2), 14.0],
	"atrium_glass": [Vector3(30.0, 0.0, 14.0), Vector3(26.0, 4.0, -2.0)],
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := "res://art_audit/after/entrance_capture"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	while not game.ready_to_play:
		await process_frame
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game._resume()
	for overlay: String in ["menu", "menu_shade"]:
		if is_instance_valid(game.get(overlay)):
			game.get(overlay).hide()
	if is_instance_valid(game.pause_menu):
		game.pause_menu.hide_menu()
	var stats: Dictionary = game.get_node("CampusRuntime").stats
	print("ENTRANCE_SIGN ", JSON.stringify(stats.get("entrance_sign", {})), " quality=", stats.get("quality"))
	for view: String in VIEWS:
		game.player.transform.basis = Basis.IDENTITY
		game.pitch = 0.0
		game.camera.transform.basis = Basis.IDENTITY
		game.player.velocity = Vector3.ZERO
		game.player.global_position = VIEWS[view][0] + Vector3(0, 1.25, 0)
		game.camera.look_at(VIEWS[view][1], Vector3.UP)
		var default_fov: float = game.camera.fov
		if VIEWS[view].size() > 2:
			game.camera.fov = VIEWS[view][2]
		for i in range(20):
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/" + view + ".png"))
		game.camera.fov = default_fov
	print("ENTRANCE_CAPTURE_DONE")
	quit(0)
