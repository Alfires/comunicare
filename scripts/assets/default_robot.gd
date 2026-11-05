extends RefCounted
## Local built-in identity remains a valid public-profile URL, never downloaded.
const URL = "https://comunicare.invalid/builtin/robot.vrm"
const LEGACY = "https://raw.githubusercontent.com/V-Sekai/godot-vrm/refs/heads/master/vrm_samples/AliciaSolid_vrm-0.51.vrm"

static func create() -> Node3D:
	var model = load("res://assets/avatars/placeholder/RobotExpressive.glb").instantiate() as Node3D
	var rig = model.find_child("*", true, false)
	for node in model.find_children("*", "Skeleton3D", true, false):
		rig = node
		break
	var mapping := {}
	if rig is Skeleton3D:
		var names = {"hips": "Hips", "spine": "Abdomen", "chest": "Torso_2", "neck": "Neck", "head": "Head_2"}
		for side in ["left", "right"]:
			var suffix = ".L" if side == "left" else ".R"
			for pair in [["Shoulder", "Shoulder"], ["UpperArm", "UpperArm"], ["LowerArm", "LowerArm"], ["Hand", "Hand"], ["UpperLeg", "UpperLeg"], ["LowerLeg", "LowerLeg"], ["Foot", "Foot"]]: names[side + pair[0]] = pair[1] + suffix
			names[side + "Hand"] = "Palm2" + suffix
			# Source foot controls are rooted independently. Preserve bind-space
			# geometry while giving the humanoid solver an actual leg chain.
			var foot = rig.find_bone("Foot" + suffix)
			var leg = rig.find_bone("LowerLeg" + suffix)
			var foot_rest = rig.get_bone_global_rest(foot)
			var parent_rest = rig.get_bone_global_rest(leg)
			rig.set_bone_parent(foot, leg)
			rig.set_bone_rest(foot, parent_rest.affine_inverse() * foot_rest)
			rig.reset_bone_pose(foot)
		for role in names:
			if rig.find_bone(names[role]) >= 0: mapping[role] = names[role]
	var bounds: Array = []
	_bounds(model, Transform3D.IDENTITY, bounds)
	if not bounds.is_empty() and bounds[0].size.y > 0:
		var factor = 1.75 / bounds[0].size.y
		model.scale *= factor
		model.position.y -= bounds[0].position.y * factor
	model.rotation.y = PI # The authored robot faces +Z; gameplay faces -Z.
	model.set_meta("vrm_legacy_orientation", true)
	model.set_meta("humanoid_bones", mapping)
	preload("res://scripts/assets/avatar_rig_profile.gd").prepare(model)
	model.set_meta("asset_revision", FileAccess.get_sha256("res://assets/avatars/placeholder/RobotExpressive.glb"))
	preload("res://scripts/assets/first_person_avatar.gd").prepare(model, {})
	return model

static func _bounds(node: Node, transform: Transform3D, result: Array):
	if node is Node3D: transform *= node.transform
	if node is MeshInstance3D:
		var box: AABB = transform * node.get_aabb()
		if result.is_empty(): result.append(box)
		else: result[0] = result[0].merge(box)
	for child in node.get_children(): _bounds(child, transform, result)
