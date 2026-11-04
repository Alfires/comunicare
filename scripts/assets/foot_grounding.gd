extends RefCounted
## Local world contact correction; no camera or body locomotion authority.
var contacts: Dictionary = {}

func clear():
	contacts.clear()

func resolve(role: String, target: Transform3D, space: PhysicsDirectSpaceState3D, exclude: Array, mask: int) -> Transform3D:
	if not target.is_finite():
		contacts.erase(role)
		return target
	var query = PhysicsRayQueryParameters3D.create(target.origin + Vector3.UP * 0.12, target.origin - Vector3.UP * 0.15, mask, exclude)
	var hit = space.intersect_ray(query)
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.7 or target.origin.y - hit.position.y > 0.12:
		contacts.erase(role)
		return target
	var point: Vector3 = hit.position + hit.normal * 0.025
	var previous: Dictionary = contacts.get(role, {})
	# Hold contact in collider-local space so moving platforms carry the plant.
	if not previous.is_empty() and is_instance_valid(previous.collider) and previous.collider == hit.collider:
		var planted: Vector3 = previous.collider.global_transform * previous.local_point
		if Vector2(planted.x - point.x, planted.z - point.z).length() < 0.02 and absf(planted.y - point.y) < 0.03:
			point = planted
	if hit.collider is Node3D:
		contacts[role] = {"collider": hit.collider, "local_point": hit.collider.global_transform.affine_inverse() * point}
	var normal: Vector3 = hit.normal
	var forward = -target.basis.z
	forward -= normal * forward.dot(normal)
	if forward.length_squared() < 0.001: forward = Vector3.FORWARD - normal * Vector3.FORWARD.dot(normal)
	forward = forward.normalized()
	return Transform3D(Basis(forward.cross(normal).normalized(), normal, -forward), point)
