@tool
extends SceneTree

func _init() -> void:
	var s: PackedScene = load("res://assets/antigravity/zombie/models/pistol_hands.scn")
	var inst = s.instantiate()
	_print_tree(inst, "")
	inst.queue_free()
	quit(0)

func _print_tree(node: Node, indent: String) -> void:
	print(indent, node.name, " (", node.get_class(), ")")
	for c in node.get_children():
		_print_tree(c, indent + "  ")
