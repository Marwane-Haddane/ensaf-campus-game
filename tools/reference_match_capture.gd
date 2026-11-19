extends SceneTree
## Captures building B and D views that match the user's real-life photo set.
##   godot --path . --resolution 1280x720 --script res://tools/reference_match_capture.gd -- --campus-quality=medium --out=res://art_audit/reference_match/before
const VIEWS := {
	"d_garden_palms": [Vector3(-12.0, 0.3, -58.0), Vector3(-4.0, 5.0, -95.0)],
	"d_front": [Vector3(-2.0, 0.3, -66.0), Vector3(-2.0, 6.0, -95.0)],
	"d_corner": [Vector3(-34.0, 0.3, -76.0), Vector3(-10.0, 5.0, -100.0)],
	"d_hall": [Vector3(-3.4, 1.85, -130.0), Vector3(-3.4, 3.0, -110.0)],
	"b_front": [Vector3(-8.0, 0.0, 17.0), Vector3(-8.0, 4.0, 0.0)],
	"b_front_oblique": [Vector3(6.0, 0.0, 13.0), Vector3(-9.0, 4.0, 0.0)],
	"b_entrance": [Vector3(-9.0, 0.0, 5.6), Vector3(-9.0, 4.2, 0.0)],
	"b_tower_oblique": [Vector3(4.0, 0.0, 5.4), Vector3(-6.0, 4.6, 0.0)],
	"b_courtyard": [Vector3(-29.5, 0.6, -13.0), Vector3(-15.0, 3.0, -13.0)],
	"b_gallery": [Vector3(-16.1, 6.9, -22.1), Vector3(-30.0, 7.5, -16.0)],
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := "res://art_audit/reference_match/before"
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
	for overlay: String in ["menu", "menu_shade", "hud", "training_ui"]:
		var node = game.get(overlay)
		if node is CanvasItem and is_instance_valid(node):
			node.hide()
	if is_instance_valid(game.pause_menu):
		game.pause_menu.hide_menu()
	for child in game.find_children("*", "CanvasLayer", true, false):
		child.visible = false
	for view: String in VIEWS:
		game.player.transform.basis = Basis.IDENTITY
		game.pitch = 0.0
		game.camera.transform.basis = Basis.IDENTITY
		game.player.velocity = Vector3.ZERO
		game.player.global_position = VIEWS[view][0] + Vector3(0, 1.25, 0)
		game.camera.look_at(VIEWS[view][1], Vector3.UP)
		for i in range(24):
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/" + view + ".png"))
	print("REFERENCE_MATCH_CAPTURE_DONE")
	quit(0)
