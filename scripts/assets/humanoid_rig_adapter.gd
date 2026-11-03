extends RefCounted

func validate_mapping(rig: Skeleton3D, mapping: Dictionary) -> Dictionary:
	var errors: Array = []
	var seen: Dictionary = {}
	for role in ["hips", "spine", "head", "leftUpperArm", "leftLowerArm", "leftHand", "rightUpperArm", "rightLowerArm", "rightHand", "leftUpperLeg", "leftLowerLeg", "leftFoot", "rightUpperLeg", "rightLowerLeg", "rightFoot"]:
		var index = rig.find_bone(str(mapping.get(role, "")))
		if index < 0:
			errors.append("Missing bone: " + role)
		elif seen.has(index): errors.append("Duplicate role assignment: " + role)
		else: seen[index] = role
	for side in ["left", "right"]:
		for chain in [["UpperArm", "LowerArm", "Hand"], ["UpperLeg", "LowerLeg", "Foot"]]:
			for i in 2:
				var parent = rig.find_bone(str(mapping.get(side + chain[i], "")))
				var child = rig.find_bone(str(mapping.get(side + chain[i + 1], "")))
				if parent < 0 or child < 0: continue
				var cursor = rig.get_bone_parent(child)
				while cursor >= 0 and cursor != parent: cursor = rig.get_bone_parent(cursor)
				if cursor != parent: errors.append("Broken chain: " + side + chain[i + 1])
				if rig.get_bone_global_rest(parent).origin.distance_to(rig.get_bone_global_rest(child).origin) < 0.001:
					errors.append("Zero length: " + side + chain[i + 1])
	for index in rig.get_bone_count():
		if not rig.get_bone_rest(index).is_finite(): errors.append("Nonfinite rest transform")
	return {"valid": errors.is_empty(), "errors": errors}
