extends RefCounted
## Arrival-time interpolation: wire-compatible with existing 26-byte player poses.
const DELAY = 0.1
const MAX_EXTRAPOLATION = 0.1
const TELEPORT_DISTANCE = 8.0
var samples: Array[Dictionary] = []

func push(position: Vector3, rotation: Vector3, at: float):
	if not position.is_finite() or not rotation.is_finite() or not is_finite(at): return
	if not samples.is_empty():
		if at < samples.back().at: return
		if position.distance_to(samples.back().position) > TELEPORT_DISTANCE:
			samples.clear()
		elif at == samples.back().at:
			samples.pop_back()
	samples.append({"position": position, "rotation": Quaternion.from_euler(rotation), "at": at})
	while samples.size() > 32: samples.pop_front()

func sample(at: float) -> Transform3D:
	if samples.is_empty(): return Transform3D.IDENTITY
	if not is_finite(at):
		var latest: Dictionary = samples.back()
		return Transform3D(Basis(latest.rotation), latest.position)
	var target = at - DELAY
	while samples.size() > 2 and samples[1].at <= target: samples.pop_front()
	var first: Dictionary = samples.front()
	if samples.size() == 1 or target <= first.at:
		return Transform3D(Basis(first.rotation), first.position)
	var last: Dictionary = samples[1]
	var span: float = last.at - first.at
	if span <= 0: return Transform3D(Basis(last.rotation), last.position)
	var weight = clampf((target - first.at) / span, 0, 1)
	var position: Vector3 = first.position.lerp(last.position, weight)
	if target > last.at:
		position = last.position + (last.position - first.position) / span * minf(target - last.at, MAX_EXTRAPOLATION)
	return Transform3D(Basis(first.rotation.slerp(last.rotation, weight)), position)
