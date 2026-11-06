extends RefCounted
## Physics queries exclude the local body; never rewrite a tracked local pose.
var clearance_shape := CapsuleShape3D.new()
var clearance_query := PhysicsShapeQueryParameters3D.new()
var head_shape := SphereShape3D.new()
var head_query := PhysicsShapeQueryParameters3D.new()

func _init():
	head_shape.radius = 0.1
	head_query.shape = head_shape
	clearance_query.shape = clearance_shape

func clearance(body: CharacterBody3D, floor_position: Vector3, height: float, radius: float) -> bool:
	if not floor_position.is_finite() or not is_finite(height) or not is_finite(radius) or height <= 0 or radius <= 0 or height > 8 or radius > 3: return false
	var shape = clearance_shape
	# Reset radius first because this query object is reused between sizes.
	shape.radius = maxf(radius - 0.005, 0.001)
	shape.height = maxf(shape.radius * 2, height - 0.01)
	var query = clearance_query
	query.transform = Transform3D(Basis.IDENTITY, floor_position + Vector3.UP * height * 0.5)
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func resize_capsule(body: CharacterBody3D, node: CollisionShape3D, height: float) -> bool:
	if not node.shape is CapsuleShape3D or not is_finite(height): return false
	var capsule: CapsuleShape3D = node.shape
	height = clampf(height, capsule.radius * 2, 8.0)
	# Tracking noise is not a meaningful crouch. Reassigning shape dimensions
	# wakes/rebuilds physics geometry and triggers needless clearance queries.
	if absf(height - capsule.height) < 0.005: return true
	var feet = node.position.y - capsule.height * 0.5
	var floor_position = body.global_transform * Vector3(node.position.x, feet, node.position.z)
	if height > capsule.height and not clearance(body, floor_position, height, capsule.radius): return false
	capsule.height = height
	node.position.y = feet + height * 0.5
	return true

func head_obstructed(body: CharacterBody3D, position: Vector3) -> bool:
	if not position.is_finite(): return true
	var query = head_query
	query.transform.origin = position
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	return not body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func destination(body: CharacterBody3D, ray_origin: Vector3, direction: Vector3, height: float, radius: float) -> Dictionary:
	if not ray_origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.001: return {}
	var ray = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + direction.normalized() * 8, body.collision_mask, [body.get_rid()])
	ray.collide_with_areas = true
	var hit = body.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.85: return {}
	if hit.collider.get_meta("teleport_disabled", false): return {}
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
