extends RefCounted
const ROLES = ["head", "leftHand", "rightHand", "hips", "leftFoot", "rightFoot", "leftKnee", "rightKnee", "chest", "leftElbow", "rightElbow"]
var samples: Dictionary = {}
var assignments: Dictionary = {}

func update_sample(id: String, pose: Transform3D, valid: bool, msec: int):
	if id.is_empty() or id.length() > 256 or msec < int(samples.get(id, {}).get("at", -1)): return
	samples[id] = {"pose": pose, "valid": valid and pose.is_finite(), "at": msec}

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
