extends RefCounted
## Optional target-space pelvis/feet solver. No tracker discovery or camera writes.
var skeleton: Skeleton3D
var humanoid: Dictionary = {}

func configure(rig: Skeleton3D, mapping: Dictionary):
	skeleton = rig
	humanoid = mapping.duplicate()

func solve(targets: Dictionary, delta: float):
	if not is_instance_valid(skeleton) or not is_finite(delta) or delta <= 0: return
	var hips = skeleton.find_bone(humanoid.get("hips", ""))
	if hips >= 0 and targets.get("hips") is Transform3D and targets.hips.is_finite():
		var parent = skeleton.get_bone_parent(hips)
		var parent_pose = skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
		var local = parent_pose.affine_inverse() * targets.hips
		if local.origin.length() <= 4:
			skeleton.set_bone_pose_position(hips, local.origin)
			skeleton.set_bone_pose_rotation(hips, local.basis.orthonormalized().get_rotation_quaternion())
	for side in ["left", "right"]:
		var target = targets.get(side + "Foot")
		if not target is Transform3D or not target.is_finite(): continue
		var upper = skeleton.find_bone(humanoid.get(side + "UpperLeg", ""))
		var lower = skeleton.find_bone(humanoid.get(side + "LowerLeg", ""))
		var foot = skeleton.find_bone(humanoid.get(side + "Foot", ""))
		if upper < 0 or lower < 0 or foot < 0: continue
		var start = skeleton.get_bone_global_pose(upper).origin
		var elbow = skeleton.get_bone_global_pose(lower).origin
		var end = skeleton.get_bone_global_pose(foot).origin
		var a = start.distance_to(elbow)
		var b = elbow.distance_to(end)
		var direction: Vector3 = target.origin - start
		if a < 0.001 or b < 0.001 or direction.length() < 0.001: continue
		var distance = clampf(direction.length(), absf(a - b) + 0.0001, a + b - 0.0001)
		direction = direction.normalized()
		var pole = Vector3.FORWARD - direction * Vector3.FORWARD.dot(direction)
		if pole.length_squared() < 0.0001: pole = Vector3.RIGHT
		var along = (a * a - b * b + distance * distance) / (2 * distance)
		var knee = start + direction * along + pole.normalized() * sqrt(maxf(0, a * a - along * along))
		_rotate_toward(upper, lower, knee)
		_rotate_toward(lower, foot, start + direction * distance)
		var parent = skeleton.get_bone_parent(foot)
		var basis = skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		skeleton.set_bone_pose_rotation(foot, (basis.inverse() * target.basis).orthonormalized().get_rotation_quaternion())

func _rotate_toward(bone: int, child: int, target: Vector3):
	var pose = skeleton.get_bone_global_pose(bone)
	var from = skeleton.get_bone_global_pose(child).origin - pose.origin
	var to = target - pose.origin
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001: return
	var rotation = Quaternion(from.normalized(), to.normalized()) * pose.basis.get_rotation_quaternion()
	var parent = skeleton.get_bone_parent(bone)
	var parent_rotation = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	skeleton.set_bone_pose_rotation(bone, parent_rotation.inverse() * rotation)
