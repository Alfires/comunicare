extends RefCounted
## Rest-pose camera anchor in the model parent's coordinates, including nested rigs.
static func eye_position(model: Node3D) -> Vector3:
	var rig = preload("res://scripts/assets/humanoid_animation.gd").new()._skeleton(model)
	if rig != null:
		var mapping: Dictionary = model.get_meta("humanoid_bones", {})
		var eyes: Array[Vector3] = []
		for role in ["leftEye", "rightEye"]:
			var index = rig.find_bone(str(mapping.get(role, "")))
			if index >= 0: eyes.append(_to_parent(model, rig, rig.get_bone_global_rest(index).origin))
		if not eyes.is_empty():
			var center = Vector3.ZERO
			for eye in eyes: center += eye
			if center.is_finite(): return center / eyes.size()
		for name in [str(mapping.get("head", "")), "Head", "head", "mixamorig_Head"]:
			var index = rig.find_bone(name)
			if index >= 0:
				var head = _to_parent(model, rig, rig.get_bone_global_rest(index).origin)
				if head.is_finite() and head.y > 0: return head
	var boxes: Array = []
	_bounds(model, Transform3D.IDENTITY, boxes)
	if not boxes.is_empty():
		var box: AABB = boxes[0]
		return Vector3(box.get_center().x, box.position.y + box.size.y * 0.92, box.get_center().z)
	return Vector3(0, 1.6, 0)

static func _to_parent(model: Node3D, rig: Node3D, point: Vector3) -> Vector3:
	var transform = rig.transform
	var parent = rig.get_parent()
	while parent != null and parent != model.get_parent():
		if parent is Node3D: transform = parent.transform * transform
		parent = parent.get_parent()
	return transform * point

static func _bounds(node: Node, transform: Transform3D, boxes: Array):
	if node is Node3D: transform *= node.transform
	if node is MeshInstance3D and node.mesh != null and not node.get_meta("first_person_derivative", false):
		var box: AABB = transform * node.get_aabb()
		if box.position.is_finite() and box.size.is_finite():
			if boxes.is_empty(): boxes.append(box)
			else: boxes[0] = boxes[0].merge(box)
	for child in node.get_children(): _bounds(child, transform, boxes)
