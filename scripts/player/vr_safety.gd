extends RefCounted
## Physics queries exclude the local body; never rewrite a tracked local pose.

func clearance(body: CharacterBody3D, floor_position: Vector3, height: float, radius: float) -> bool:
	if not floor_position.is_finite() or not is_finite(height) or not is_finite(radius): return false
	var shape = CapsuleShape3D.new()
	shape.radius = clampf(radius - 0.005, 0.05, 0.8)
	shape.height = maxf(shape.radius * 2, height - 0.01)
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, floor_position + Vector3.UP * height * 0.5)
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func resize_capsule(body: CharacterBody3D, node: CollisionShape3D, height: float) -> bool:
	if not node.shape is CapsuleShape3D or not is_finite(height): return false
	var capsule: CapsuleShape3D = node.shape
	height = clampf(height, capsule.radius * 2, 2.6)
	if height > capsule.height and not clearance(body, body.global_position, height, capsule.radius): return false
	capsule.height = height
	node.position.y = height * 0.5
	return true

func head_obstructed(body: CharacterBody3D, position: Vector3) -> bool:
	if not position.is_finite(): return true
	var sphere = SphereShape3D.new()
	sphere.radius = 0.1
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform.origin = position
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	return not body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func destination(body: CharacterBody3D, ray_origin: Vector3, direction: Vector3, height: float, radius: float) -> Dictionary:
	if not ray_origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.001: return {}
	var ray = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + direction.normalized() * 8, body.collision_mask, [body.get_rid()])
	var hit = body.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.85: return {}
	if absf(hit.position.y - body.global_position.y) > 1.5: return {}
	return hit if clearance(body, hit.position + Vector3.UP * 0.02, height, radius) else {}

func commit_teleport(body: CharacterBody3D, origin: XROrigin3D, head: Node3D, destination_floor: Vector3):
	var horizontal = head.global_position - body.global_position
	horizontal.y = 0
	var old_origin = origin.global_position
	var old_body = body.global_position
	body.global_position = destination_floor
	origin.global_position = old_origin + destination_floor - old_body - horizontal
	body.velocity = Vector3.ZERO
