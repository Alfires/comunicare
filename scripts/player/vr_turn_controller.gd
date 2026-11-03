extends RefCounted
var armed := true
var dead_zone := 0.3

func reset():
	armed = true

func step(axis: float, delta: float, mode: String, snap_degrees: float, smooth_degrees_per_second: float) -> float:
	if not is_finite(axis) or not is_finite(delta) or delta <= 0: return 0
	axis = clampf(axis, -1, 1)
	if absf(axis) <= dead_zone:
		armed = true
		return 0
	if mode == "smooth":
		return -signf(axis) * (absf(axis) - dead_zone) / (1 - dead_zone) * deg_to_rad(clampf(smooth_degrees_per_second, 15, 180)) * delta
	if mode == "snap" and armed and absf(axis) >= 0.7:
		armed = false
		return -signf(axis) * deg_to_rad(clampf(snap_degrees, 15, 90))
	return 0

func pivot_transform(rig_transform: Transform3D, floor_pivot: Vector3, yaw: float) -> Transform3D:
	var rotation = Basis(Vector3.UP, yaw)
	return Transform3D(rotation * rig_transform.basis, floor_pivot + rotation * (rig_transform.origin - floor_pivot))
