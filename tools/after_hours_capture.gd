extends SceneTree
## After Hours mood QA captures (roadmap item #8).
##   godot --path . --resolution 1280x720 --script res://tools/after_hours_capture.gd -- --campus-quality=medium --out=res://art_audit/after/x
## Views are fixed camera eye/target pairs; the player is frozen so the camera stays put.
const VIEWS := {
	"arrival": [Vector3(-27.0, 2.95, -85.0), Vector3(-29.0, 2.6, -100.0)],
	"extraction_gate": [Vector3(-25.0, 2.9, -84.0), Vector3(-19.0, 1.8, -70.0)],
	"plaza_west": [Vector3(-22.0, 2.9, -90.0), Vector3(-40.0, 2.0, -84.0)],
	"overview": [Vector3(-8.0, 22.0, -66.0), Vector3(-26.0, 1.0, -92.0)],
	"glazed_side": [Vector3(-26.0, 2.9, -92.0), Vector3(-8.0, 2.6, -100.0)],
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := "res://art_audit/after/after_hours_capture"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var game: Node3D = (load("res://scenes/antigravity/zombie/zombie_game.tscn") as PackedScene).instantiate()
	game.set("launcher_managed", false)
	root.add_child(game)
	var frames := 0
	while not bool(game.get("initialization_finished")) and frames < 6000:
		await process_frame
		frames += 1
	print("AH_READY ", game.get("ready_to_play"), " ", game.get("initialization_error"))
	var player: Node3D = game.get("player")
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	if player:
		player.set_physics_process(false)
		player.set_process(false)
	var hud: Node = game.get("hud")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	for view: String in VIEWS:
		var eye: Vector3 = VIEWS[view][0]
		camera.global_position = eye
		camera.look_at(VIEWS[view][1], Vector3.UP)
		for i in range(30):
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/" + view + ".png"))
	var stats := {"fps": Engine.get_frames_per_second(), "draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "prims": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
	print("AH_CAPTURE_DONE ", JSON.stringify(stats))
	quit(0)
