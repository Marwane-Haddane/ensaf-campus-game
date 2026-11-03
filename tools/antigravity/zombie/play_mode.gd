extends SceneTree
## Dedicated Standalone Launch Harness for Zombie RPG: After Hours (ZB-2026-001)
## Launch with: Godot_v4.3-stable_win64_console.exe --script res://tools/antigravity/zombie/play_mode.gd

func _init() -> void:
	call_deferred("_start_mode")

func _start_mode() -> void:
	DisplayServer.window_set_title("ENSA Games — Zombie RPG: After Hours (ZB-2026-001)")
	root.size = Vector2i(1280, 720)
	
	print("[Zombie RPG] Launching standalone episode ZB-2026-001...")
	var scene_path := "res://scenes/antigravity/zombie/zombie_game.tscn"
	var game_scene: PackedScene = load(scene_path)
	if game_scene == null:
		push_error("Failed to load zombie_game.tscn")
		quit(1)
		return
	
	var game: Node3D = game_scene.instantiate() as Node3D
	game.set("launcher_managed", false)
	root.add_child(game)
	
	game.connect("launcher_return_requested", func():
		print("[Zombie RPG] Return requested — exiting session.")
		quit(0)
	)
