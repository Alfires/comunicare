class_name TrackingPose
extends RefCounted
const ROLES = ["head", "leftHand", "rightHand", "hips", "leftFoot", "rightFoot"]

static func valid(value: Dictionary) -> bool:
	if value.get("version") != 1 or not AnimationState.integer(value.get("sequence"), 1, 2147483647): return false
	if not InstanceState.valid_fingerprint(value.get("avatar_revision")) or not AnimationState.integer(value.get("calibration_revision"), 0, 2147483647): return false
	var targets = value.get("targets")
	if not targets is Dictionary or targets.size() > 6: return false
	for role in targets:
		var v = targets[role]
		if role not in ROLES or not v is Array or v.size() != 7: return false
		for number in v:
			if not AnimationState.number(number, -4, 4): return false
		if Vector3(v[0], v[1], v[2]).length() > 4: return false
		if absf(Quaternion(v[3], v[4], v[5], v[6]).length_squared() - 1) > 0.02: return false
	return true

static func encode_target(pose: Transform3D) -> Array:
	var q = pose.basis.orthonormalized().get_rotation_quaternion()
	return [pose.origin.x, pose.origin.y, pose.origin.z, q.x, q.y, q.z, q.w]

static func decode_targets(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for role in values:
		var v = values[role]
		result[role] = Transform3D(Basis(Quaternion(v[3], v[4], v[5], v[6]).normalized()), Vector3(v[0], v[1], v[2]))
	return result
