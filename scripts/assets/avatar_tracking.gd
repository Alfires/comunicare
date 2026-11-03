extends SkeletonModifier3D
## Final-pose tracking override after animation. Targets are external to avatar.
var humanoid: Dictionary = {}
var head_target: Node3D
var left_target: Node3D
var right_target: Node3D
var calibration: Dictionary = {}

func configure(mapping: Dictionary, head: Node3D, left: Node3D, right: Node3D):
	humanoid = mapping.duplicate()
	head_target = head
	left_target = left
	right_target = right
	calibration.clear()
	var rig = get_skeleton()
	if rig == null: return
	for role in ["head", "leftHand", "rightHand"]:
		var index = rig.find_bone(humanoid.get(role, ""))
		if index >= 0:
			calibration[role] = rig.get_bone_global_rest(index).basis.get_rotation_quaternion()

func _process_modification():
	var rig = get_skeleton()
	if rig == null: return
	if _tracked(head_target): _set_target(rig, "head", head_target, true)
	for side in ["left", "right"]:
		var target = left_target if side == "left" else right_target
		if not _tracked(target): continue
		_solve_arm(rig, side, target)
		_set_target(rig, side + "Hand", target, false)

func _tracked(target: Node3D) -> bool:
	return is_instance_valid(target) and (not target is XRNode3D or target.get_is_active())

func _set_target(rig: Skeleton3D, role: String, target: Node3D, position: bool):
	var index = rig.find_bone(humanoid.get(role, ""))
	if index < 0: return
	var desired = rig.global_transform.affine_inverse() * target.global_transform
	var parent = rig.get_bone_parent(index)
	var parent_pose = rig.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var current = rig.get_bone_global_pose(index)
	current.basis = desired.basis.orthonormalized() * Basis(calibration.get(role, Quaternion.IDENTITY))
	if position: current.origin = desired.origin
	var local = parent_pose.affine_inverse() * current
	rig.set_bone_pose_rotation(index, local.basis.get_rotation_quaternion())
	if position: rig.set_bone_pose_position(index, local.origin)

func _rotate_toward(rig: Skeleton3D, bone: int, child: int, destination: Vector3):
	var pose = rig.get_bone_global_pose(bone)
	var from = rig.get_bone_global_pose(child).origin - pose.origin
	var to = destination - pose.origin
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001: return
	var rotation = Quaternion(from.normalized(), to.normalized())
	var global_rotation = rotation * pose.basis.get_rotation_quaternion()
	var parent = rig.get_bone_parent(bone)
	var parent_rotation = rig.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	rig.set_bone_pose_rotation(bone, parent_rotation.inverse() * global_rotation)

func _solve_arm(rig: Skeleton3D, side: String, target: Node3D):
	var upper = rig.find_bone(humanoid.get(side + "UpperArm", ""))
	var lower = rig.find_bone(humanoid.get(side + "LowerArm", ""))
	var hand = rig.find_bone(humanoid.get(side + "Hand", ""))
	if upper < 0 or lower < 0 or hand < 0: return
	var start = rig.get_bone_global_pose(upper).origin
	var elbow = rig.get_bone_global_pose(lower).origin
	var wrist = rig.get_bone_global_pose(hand).origin
	var destination = rig.to_local(target.global_position)
	var a = start.distance_to(elbow)
	var b = elbow.distance_to(wrist)
	if a < 0.001 or b < 0.001: return
	var direction = destination - start
	var distance = clampf(direction.length(), absf(a - b) + 0.001, a + b - 0.001)
	if direction.length() < 0.001: return
	direction = direction.normalized()
	var pole = elbow - start
	pole -= direction * pole.dot(direction)
	if pole.length_squared() < 0.0001:
		pole = Vector3.DOWN - direction * Vector3.DOWN.dot(direction)
	if pole.length_squared() < 0.0001: pole = Vector3.FORWARD.cross(direction)
	var along = (a * a - b * b + distance * distance) / (2 * distance)
	var height = sqrt(maxf(0, a * a - along * along))
	var elbow_target = start + direction * along + pole.normalized() * height
	_rotate_toward(rig, upper, lower, elbow_target)
	_rotate_toward(rig, lower, hand, start + direction * distance)
