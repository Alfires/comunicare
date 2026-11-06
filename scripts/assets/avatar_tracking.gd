extends SkeletonModifier3D
## Final-pose tracking override after animation. Targets are external to avatar.
var humanoid: Dictionary = {}
var head_target: Node3D
var left_target: Node3D
var right_target: Node3D
var calibration: Dictionary = {}
var offsets: Dictionary = {}
var validity: Dictionary = {}
var weights: Dictionary = {"head": 0.0, "leftHand": 0.0, "rightHand": 0.0}
var body_solver
var body_targets: Dictionary = {}
var solved_poses: Dictionary = {}
const FADE_SECONDS = 0.2

func set_body_targets(targets: Dictionary):
	body_targets = targets.duplicate()

func set_calibration(data: Dictionary):
	offsets.clear()
	for pair in [["head", "head_offset"], ["leftHand", "left_grip_offset"], ["rightHand", "right_grip_offset"]]:
		var values = data.get(pair[1], [0, 0, 0])
		if values is Array and values.size() == 3:
			var offset = Vector3(values[0], values[1], values[2])
			if offset.is_finite() and offset.length() <= 1: offsets[pair[0]] = offset

func set_tracking_validity(values: Dictionary):
	validity = values.duplicate(true)

func tracking_weights() -> Dictionary:
	return weights.duplicate()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		body_solver = null

func configure(mapping: Dictionary, head: Node3D, left: Node3D, right: Node3D):
	humanoid = mapping.duplicate()
	if body_solver == null: body_solver = preload("res://scripts/assets/full_body_solver.gd").new()
	head_target = head
	left_target = left
	right_target = right
	calibration.clear()
	solved_poses.clear()
	var rig = get_skeleton()
	if rig == null: return
	body_solver.configure(rig, mapping)
	var reference = Basis.IDENTITY
	var ancestor: Node = rig
	while ancestor != null:
		if ancestor.has_meta("tracking_rest_frame"):
			reference = ancestor.get_meta("tracking_rest_frame")
			break
		ancestor = ancestor.get_parent()
	for role in ["head", "leftHand", "rightHand"]:
		var index = rig.find_bone(humanoid.get(role, ""))
		if index >= 0:
			calibration[role] = (reference * rig.get_bone_global_rest(index).basis).orthonormalized().get_rotation_quaternion()

func _process_modification():
	var rig = get_skeleton()
	if rig == null: return
	if body_solver != null: body_solver.solve(body_targets, 1.0 / 60.0)
	_apply_chain(rig, "head", head_target, ["head"], "")
	for side in ["left", "right"]:
		var target = left_target if side == "left" else right_target
		_apply_chain(rig, side + "Hand", target, [side + "UpperArm", side + "LowerArm", side + "Hand"], side)

func _apply_chain(rig: Skeleton3D, role: String, target: Node3D, bones: Array, side: String):
	var active = _role_tracked(role, target)
	# Hard removal intentionally releases ownership immediately; temporary invalid
	# runtime samples fade the last valid solved pose without following stale targets.
	if not is_instance_valid(target):
		weights[role] = 0.0
		solved_poses.erase(role)
		return
	var previous: float = weights.get(role, 0.0)
	var delta = get_process_delta_time()
	if delta <= 0: delta = 1.0 / 60.0
	weights[role] = move_toward(previous, 1.0 if active else 0.0, minf(delta, 0.05) / FADE_SECONDS) if solved_poses.has(role) else (1.0 if active else 0.0)
	# Keep solved history for smooth reacquisition, but do not inspect or rewrite
	# animation-owned bones once tracking has completely faded out.
	if not active and weights[role] == 0.0: return
	var base: Dictionary = {}
	var fully_tracked = active and weights[role] == 1.0
	if not fully_tracked:
		for bone in bones:
			var index = rig.find_bone(humanoid.get(bone, ""))
			if index >= 0: base[index] = rig.get_bone_pose(index)
	if active:
		if not side.is_empty(): _solve_arm(rig, side, target)
		_set_target(rig, role, target, side.is_empty())
		var pose: Dictionary = {}
		for bone in bones:
			var index = rig.find_bone(humanoid.get(bone, ""))
			if index >= 0: pose[index] = rig.get_bone_pose(index)
		solved_poses[role] = pose
		# The solver already installed the final pose. Blending it back at 100%
		# only repeats bone reads, quaternion conversions and skeleton writes.
		if fully_tracked: return
	for index in base:
		var desired: Transform3D = solved_poses.get(role, {}).get(index, base[index])
		var original: Transform3D = base[index]
		rig.set_bone_pose_rotation(index, original.basis.get_rotation_quaternion().slerp(desired.basis.get_rotation_quaternion(), weights[role]))
		rig.set_bone_pose_position(index, original.origin.lerp(desired.origin, weights[role]))

func _tracked(target: Node3D) -> bool:
	return is_instance_valid(target) and (not target is XRNode3D or target.get_is_active())

func _role_tracked(role: String, target: Node3D) -> bool:
	if not _tracked(target): return false
	var state = validity.get(role, true)
	if state is bool: return state
	return state is Dictionary and state.get("valid", false) and Time.get_ticks_msec() - int(state.get("at", 0)) <= 1000

func _set_target(rig: Skeleton3D, role: String, target: Node3D, position: bool):
	var index = rig.find_bone(humanoid.get(role, ""))
	if index < 0: return
	var desired = rig.global_transform.affine_inverse() * target.global_transform
	desired.origin += desired.basis * offsets.get(role, Vector3.ZERO)
	var parent = rig.get_bone_parent(index)
	var parent_pose = rig.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var current = rig.get_bone_global_pose(index)
	current.basis = desired.basis.orthonormalized() * Basis(calibration.get(role, Quaternion.IDENTITY))
	if position: current.origin = desired.origin
	var local = parent_pose.affine_inverse() * current
	var rest = rig.get_bone_rest(index)
	var rotation = local.basis.get_rotation_quaternion()
	# Conservative per-rig fallback cones prevent extreme tracker twists. These
	# are safety bounds, not calibrated anatomical limits for every avatar.
	var rest_rotation = rest.basis.get_rotation_quaternion()
	var angle = rest_rotation.angle_to(rotation)
	var limit = deg_to_rad(85 if role == "head" else 100)
	if angle > limit: rotation = rest_rotation.slerp(rotation, limit / angle)
	rig.set_bone_pose_rotation(index, rotation)
	if position:
		# Translation safety bound is in world metres, not imported skeleton units.
		var world_scale = maxf(rig.global_basis.get_scale().abs().length() / sqrt(3.0), 0.0001)
		var maximum = clampf(rest.origin.length() * world_scale * 0.5, 0.05, 0.2) / world_scale
		rig.set_bone_pose_position(index, rest.origin + (local.origin - rest.origin).limit_length(maximum))

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
	var destination = rig.to_local(target.global_transform * offsets.get(side + "Hand", Vector3.ZERO))
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
