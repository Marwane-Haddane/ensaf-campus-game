@tool
extends SceneTree

func _init() -> void:
	print("--- Testing load of converted .tscn files ---")
	var paths = [
		"res://assets/antigravity/zombie/models/pistol_hands.scn",
		"res://assets/antigravity/zombie/models/Zombie_Basic.scn",
		"res://assets/antigravity/zombie/models/Zombie_Chubby.scn",
		"res://assets/antigravity/zombie/models/Characters_Shaun.scn",
		"res://assets/antigravity/zombie/props/Vehicle_Pickup.scn"
	]
	for p in paths:
		var scene: PackedScene = load(p)
		if not scene:
			print("FAILED to load: ", p)
			continue
		var inst = scene.instantiate()
		print("Loaded ", p, " -> root node: ", inst.name, " type: ", inst.get_class())
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if ap:
			print("  Animations (", ap.get_animation_list().size(), "): ", ap.get_animation_list())
		inst.queue_free()
	quit(0)
