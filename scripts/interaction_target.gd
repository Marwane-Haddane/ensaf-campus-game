extends RefCounted
## Tests the centre crosshair against the computer's actual component bounds.
## A nearby object in the edge of the camera view is not an interaction target.

static func find(camera: Camera3D, player: CharacterBody3D, stations: Array[Dictionary], max_distance: float = 2.8) -> Dictionary:
	var nearest: float = max_distance
	var selected: Dictionary = {}
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_basis.z
	for station: Dictionary in stations:
		var node: Node3D = station["node"]
		var inverse: Transform3D = node.global_transform.affine_inverse()
		var local_origin: Vector3 = inverse * origin
		var local_direction: Vector3 = (inverse.basis * direction).normalized()
		var boxes: Array = []
		if station.get("kind", "pc") == "pc":
			var asset: Dictionary = station.get("asset", {})
			boxes = (asset.get("component_bounds", {}) as Dictionary).values()
		elif node.has_meta("local_bounds"):
			boxes.append(node.get_meta("local_bounds"))
		for value: Variant in boxes:
			var box: AABB = value
			# A small margin makes thin monitor edges practical to aim at.
			var local_hit: Variant = box.grow(0.015).intersects_ray(local_origin, local_direction)
			if local_hit == null: continue
			var hit_point: Vector3 = node.global_transform * (local_hit as Vector3)
			var distance: float = origin.distance_to(hit_point)
			if distance >= nearest or (hit_point-origin).dot(direction) <= 0.0: continue
			var ray := PhysicsRayQueryParameters3D.create(origin, hit_point, 1, [player.get_rid()])
			var obstruction: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(ray)
			if not obstruction.is_empty() and origin.distance_to(obstruction["position"]) < distance-0.08:
				continue
			nearest = distance
			selected = station
	return selected
