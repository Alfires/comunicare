extends RefCounted
## Preserve takeoff momentum; deliberate air steering has limited acceleration.
const ACCELERATION_FACTOR := 0.1

func steer(current: Vector3, desired: Vector3, acceleration: float, delta: float) -> Vector3:
	var horizontal = Vector2(current.x, current.z)
	var target = Vector2(desired.x, desired.z)
	if not target.is_zero_approx():
		horizontal = horizontal.move_toward(target, maxf(acceleration, 0.0) * ACCELERATION_FACTOR * maxf(delta, 0.0))
	return Vector3(horizontal.x, current.y, horizontal.y)
