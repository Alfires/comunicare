extends RefCounted
## Move collision body toward physical head floor location, compensating origin.
func reconcile(body: CharacterBody3D, origin: XROrigin3D, head: Node3D) -> Vector3:
	if not body.is_inside_tree() or not origin.is_inside_tree() or not head.global_position.is_finite(): return Vector3.ZERO
	var difference = head.global_position - body.global_position
	difference.y = 0
	if difference.length() < 0.001: return Vector3.ZERO
	# Bound recenter/provider discontinuities; repeated normal frames converge.
	difference = difference.limit_length(0.5)
	var before = body.global_position
	var tracked_origin = origin.global_transform
	body.move_and_collide(difference)
	origin.global_transform = tracked_origin
	return body.global_position - before
