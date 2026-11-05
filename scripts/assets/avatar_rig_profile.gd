extends RefCounted
## Detached, data-driven rig preparation. No SceneTree, tracker or global state.
static func prepare(model: Node3D) -> Dictionary:
	var rig = preload("res://scripts/assets/humanoid_animation.gd").new()._skeleton(model)
	if rig == null: return {"frame_valid": false, "errors": ["No skeleton"]}
	var declared: Dictionary = model.get_meta("humanoid_bones", {})
	var resolved := {}
	var errors: Array = []
	var used := {}
	for role in declared:
		var name = str(declared[role])
		var index = rig.find_bone(name)
		if index < 0:
			var candidates: Array = []
			for bone in rig.get_bone_count():
				var actual = str(rig.get_bone_name(bone))
				if actual.begins_with(name + "_") and actual.trim_prefix(name + "_").is_valid_int(): candidates.append(bone)
			if candidates.size() == 1: index = candidates[0]
		if index < 0 or used.has(index):
			errors.append("Missing, ambiguous or duplicate humanoid role: " + str(role))
			continue
		resolved[role] = str(rig.get_bone_name(index))
		used[index] = true
	model.set_meta("humanoid_bones", resolved)
	var frame = Transform3D.IDENTITY
	var cursor: Node = rig
	while cursor != null:
		if cursor is Node3D: frame = cursor.transform * frame
		if cursor == model: break
		cursor = cursor.get_parent()
	var valid = cursor == model and frame.is_finite() and absf(frame.basis.determinant()) > 0.000001
	if valid: model.set_meta("tracking_rest_frame", frame.basis.orthonormalized())
	else: errors.append("Invalid/singular skeleton import transform")
	var report = {"frame_valid": valid, "errors": errors}
	model.set_meta("rig_profile", report)
	return report
