extends RefCounted
var last_forward := Vector3.FORWARD

func desired_velocity(stick: Vector2, head_basis: Basis, speed: float, dead_zone: float) -> Vector3:
	if not stick.is_finite() or not head_basis.is_finite() or not is_finite(speed): return Vector3.ZERO
	var forward = -head_basis.z
	forward.y = 0
	if forward.length_squared() > 0.0001: last_forward = forward.normalized()
	var magnitude = minf(stick.length(), 1.0)
	var zone = clampf(dead_zone, 0, 0.95)
	if magnitude <= zone: return Vector3.ZERO
	var direction = stick.normalized()
	var right = last_forward.cross(Vector3.UP)
	return (right * direction.x - last_forward * direction.y) * maxf(speed, 0) * (magnitude - zone) / (1.0 - zone)
