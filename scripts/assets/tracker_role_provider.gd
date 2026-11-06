extends RefCounted
const ROLES = ["head", "leftHand", "rightHand", "hips", "leftFoot", "rightFoot", "leftKnee", "rightKnee", "chest", "leftElbow", "rightElbow"]
var samples: Dictionary = {}
var assignments: Dictionary = {}

func update_sample(id: String, pose: Transform3D, valid: bool, msec: int):
	if id.is_empty() or id.length() > 256 or msec < 0 or msec < int(samples.get(id, {}).get("at", -1)): return
	if not samples.has(id) and samples.size() >= 256:
		var oldest := ""
		for candidate in samples:
			if candidate in assignments.values(): continue
			if oldest.is_empty() or samples[candidate].at < samples[oldest].at: oldest = candidate
		if oldest.is_empty(): return
		samples.erase(oldest)
	samples[id] = {"pose": pose, "valid": valid and pose.is_finite() and absf(pose.basis.determinant()) > 0.000001, "at": msec}

func assign(role: String, id: String) -> bool:
	if role not in ROLES or not samples.has(id) or not samples[id].valid: return false
	for other in assignments:
		if other != role and assignments[other] == id: return false
	assignments[role] = id
	return true

func targets(now: int) -> Dictionary:
	var result: Dictionary = {}
	for role in assignments:
		var sample: Dictionary = samples.get(assignments[role], {})
		if not sample.is_empty() and sample.valid and now >= sample.at and now - sample.at <= 1000:
			result[role] = sample.pose
	return result

func clear():
	samples.clear()
	assignments.clear()

func available(now: int) -> Array:
	var result: Array = []
	for id in samples:
		if samples[id].valid and now >= samples[id].at and now - samples[id].at <= 1000: result.append(id)
	return result

func unassign(role: String):
	assignments.erase(role)
