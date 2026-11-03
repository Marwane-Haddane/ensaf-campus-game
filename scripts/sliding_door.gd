extends "res://scripts/interactive_door.gd"
## Separate solid leaves slide parallel to the fixed reception glazing.
var slide_distance: float = 0.0
var _closing: bool = false

func configure_sliding(title: String, centre: Vector3, width: float, height: float) -> void:
	super.configure(title,centre,width,height,true)
	slide_distance = width*0.5+0.04
	for leaf: Dictionary in leaves:
		leaf["closed_position"] = (leaf.pivot as Node3D).position
	set_meta("opening_direction","two lateral sliding panels")
	set_meta("opening_angle_degrees",0.0)
	set_meta("motion_kind","sliding")
	_apply_fraction()

func toggle(player: CharacterBody3D = null) -> bool:
	_closing = is_open
	return super.toggle(player)

func _apply_fraction() -> void:
	for leaf: Dictionary in leaves:
		var pivot: Node3D = leaf.pivot
		pivot.rotation = Vector3.ZERO
		pivot.position = leaf.get("closed_position",pivot.position)+Vector3(-float(leaf.direction)*slide_distance*open_fraction,0,0)

func _player_in_sweep(player: CharacterBody3D) -> bool:
	var point: Vector3 = to_local(player.global_position)
	if point.y < -0.9 or point.y > opening_height+0.9: return false
	if _closing:
		return absf(point.x)<opening_width*0.5+0.29 and absf(point.z)<0.33
	# Opening moves away from the passage. Guard the two sliding pockets only.
	return absf(point.x)>opening_width*0.5-0.05 and absf(point.x)<opening_width*0.5+slide_distance+0.29 and absf(point.z)<0.30

func get_prompt() -> String:
	if Time.get_ticks_msec()<_feedback_until: return feedback.replace("swinging door","sliding panels")
	if is_animating: return "Closing…" if _closing else "Opening…"
	return "Press E to close" if is_open else "Press E to open"
