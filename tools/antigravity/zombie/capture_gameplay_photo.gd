extends SceneTree

func _init() -> void:
	call_deferred("_start")

func _start() -> void:
	root.size = Vector2i(1280, 720)
	var scene_path := "res://scenes/antigravity/zombie/zombie_game.tscn"
	var game_scene: PackedScene = load(scene_path)
	if not game_scene:
		print("Failed to load zombie_game.tscn")
		quit(1)
		return

	var game: Node3D = game_scene.instantiate() as Node3D
	game.set("launcher_managed", false)
	root.add_child(game)

	# Wait for game to finish initialization
	var timeout := 0
	while not bool(game.get("initialization_finished")) and timeout < 600:
		await process_frame
		timeout += 1

	# Let game settle and render world for 20 frames
	for i in range(20):
		await process_frame

	var img = root.get_texture().get_image()
	var save_path = ProjectSettings.globalize_path("res://tools/antigravity/zombie/photos/04_player_first_person_live_game.png")
	var err = img.save_png(save_path)
	print("Gameplay snapshot saved: ", save_path, " [", err, "]")
	quit(0)
