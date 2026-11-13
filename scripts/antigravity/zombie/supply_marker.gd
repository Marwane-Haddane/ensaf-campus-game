extends RefCounted
## Short-range, world-occluded labels for field supplies.

static func attach(parent: Node3D, title: String, tint: Color, height: float, distance: float) -> Label3D:
	var marker := Label3D.new()
	marker.text = title
	marker.font_size = 44
	marker.outline_size = 13
	marker.modulate = tint
	marker.outline_modulate = Color("171219")
	marker.pixel_size = 0.003
	marker.position.y = height
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.visibility_range_end = distance
	parent.add_child(marker)
	return marker
