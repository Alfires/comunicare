extends RefCounted
## Keep capsule feet fixed and validate the final volume before changing physics.
static func apply(body: CharacterBody3D, collision: CollisionShape3D, ratio: float) -> bool:
	if collision == null or not collision.shape is CapsuleShape3D or not is_finite(ratio) or ratio <= 0: return false
	var old: CapsuleShape3D = collision.shape
	var next = CapsuleShape3D.new()
	# Height first: setting a large radius on a short capsule otherwise clamps
	# height implicitly, creating cumulative size drift.
	next.height = old.height * ratio
	next.radius = old.radius * ratio
	var center = collision.position
	var feet = center.y - old.height * 0.5
	center.y = feet + next.height * 0.5
	if body.is_inside_tree():
		var query = PhysicsShapeQueryParameters3D.new()
		var probe = CapsuleShape3D.new()
		probe.height = maxf(next.height - 0.004, 0.002)
		probe.radius = maxf(next.radius - 0.002, 0.001)
		query.shape = probe
		query.transform = body.global_transform * Transform3D(collision.basis, center)
		query.collision_mask = body.collision_mask
		query.exclude = [body.get_rid()]
		if not body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return false
	collision.shape = next
	collision.position = center
	return true
