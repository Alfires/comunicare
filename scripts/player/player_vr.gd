extends XROrigin3D

@onready var xr_camera: XRCamera3D = $XRCamera3D

var left_controller: XRController3D
var right_controller: XRController3D
var vrm_model: Node3D
var skeleton: Skeleton3D

var head_bone_idx: int = -1

var left_arm_ik: TwoBoneIK3D
var right_arm_ik: TwoBoneIK3D
var left_leg_ik: TwoBoneIK3D
var right_leg_ik: TwoBoneIK3D

var left_hand_target: Node3D
var right_hand_target: Node3D
var left_pole_target: Node3D
var right_pole_target: Node3D
var left_foot_target: Node3D
var right_foot_target: Node3D
var left_leg_pole_target: Node3D
var right_leg_pole_target: Node3D

var movement_speed: float = 2.0
var turn_speed: float = 2.0
var movement_deadzone: float = 0.1

# How far in front of the eyes the avatar head sits.
# Increase if the head “dives” into the body when looking down.
var head_forward_offset: float = 0.08

var debug_timer: float = 0.0

const BONE_ALIASES := {
	"Head": ["Head", "J_Bip_C_Head", "mixamorig:Head"],
	"Hips": ["Hips", "J_Bip_C_Hips", "mixamorig:Hips"],
	"LeftHand": ["LeftHand", "J_Bip_L_Hand", "mixamorig:LeftHand"],
	"RightHand": ["RightHand", "J_Bip_R_Hand", "mixamorig:RightHand"],
	"LeftUpperArm": ["LeftArm", "J_Bip_L_UpperArm", "mixamorig:LeftArm"],
	"RightUpperArm": ["RightArm", "J_Bip_R_UpperArm", "mixamorig:RightArm"],
	"LeftForeArm": ["LeftForeArm", "LeftLowerArm", "J_Bip_L_LowerArm", "mixamorig:LeftForeArm"],
	"RightForeArm": ["RightForeArm", "RightLowerArm", "J_Bip_R_LowerArm", "mixamorig:RightForeArm"],
	"LeftUpLeg": ["LeftUpLeg", "LeftUpperLeg", "J_Bip_L_UpperLeg", "mixamorig:LeftUpLeg"],
	"RightUpLeg": ["RightUpLeg", "RightUpperLeg", "J_Bip_R_UpperLeg", "mixamorig:RightUpLeg"],
	"LeftLeg": ["LeftLeg", "LeftLowerLeg", "J_Bip_L_LowerLeg", "mixamorig:LeftLeg"],
	"RightLeg": ["RightLeg", "RightLowerLeg", "J_Bip_R_LowerLeg", "mixamorig:RightLeg"],
	"LeftFoot": ["LeftFoot", "J_Bip_L_Foot", "mixamorig:LeftFoot"],
	"RightFoot": ["RightFoot", "J_Bip_R_Foot", "mixamorig:RightFoot"],
}

var _bone_cache: Dictionary = {}

func _ready():
	print("=== XR Player Script Started ===")
	_setup_controllers()
	load_vrm_model()

func _setup_controllers():
	left_controller = find_child("LeftHand", true, false) as XRController3D
	right_controller = find_child("RightHand", true, false) as XRController3D

	if left_controller == null:
		left_controller = XRController3D.new()
		left_controller.name = "LeftHand"
		left_controller.tracker_name = "left_hand"
		add_child(left_controller)

	if right_controller == null:
		right_controller = XRController3D.new()
		right_controller.name = "RightHand"
		right_controller.tracker_name = "right_hand"
		add_child(right_controller)

	print("Controllers setup complete")

func load_vrm_model():
	print("Loading VRM model...")
	var model = await DataLoader.load_vrm_from_url(SaveData.data["plyer_model_url"])

	if model == null:
		print("ERROR: Failed to load VRM model")
		return

	vrm_model = model
	add_child(vrm_model)
	vrm_model.position = Vector3.ZERO

	skeleton = _find_skeleton(vrm_model)
	if skeleton == null:
		print("ERROR: Skeleton not found")
		return

	print("=== VRM Model Loaded ===")
	print("VRM Model bone count: %d" % skeleton.get_bone_count())

	_bone_cache.clear()
	head_bone_idx = _bone("Head")

	_print_all_bones()
	_setup_arm_ik()
	_setup_leg_ik()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result != null:
			return result
	return null

func _print_all_bones():
	print("\n=== ALL BONES ===")
	for i in range(skeleton.get_bone_count()):
		print("[%d] %s (parent: %d)" % [i, skeleton.get_bone_name(i), skeleton.get_bone_parent(i)])

func _bone(key: String) -> int:
	if _bone_cache.has(key):
		return _bone_cache[key]
	var names: Array = BONE_ALIASES.get(key, [key])
	var found := -1
	for n in names:
		var idx := skeleton.find_bone(n)
		if idx != -1:
			found = idx
			break
	if found == -1:
		push_warning("VRM rig: no bone found for '%s' (tried %s)" % [key, str(names)])
	_bone_cache[key] = found
	return found

# -------------------- target nodes --------------------

func _add_target(node_name: String) -> Node3D:
	var t := Node3D.new()
	t.name = node_name
	skeleton.add_child(t)
	return t

func _add_two_bone_ik(node_name: String, root_key: String, mid_key: String, end_key: String,
		target: Node3D, pole: Node3D, tip_length: float) -> TwoBoneIK3D:
	var root_i := _bone(root_key)
	var mid_i := _bone(mid_key)
	var end_i := _bone(end_key)
	if root_i == -1 or mid_i == -1 or end_i == -1:
		push_warning("%s skipped: missing bones" % node_name)
		return null

	var ik := TwoBoneIK3D.new()
	ik.name = node_name
	skeleton.add_child(ik)	 # must be a direct child of the Skeleton3D
	ik.set_setting_count(1)
	ik.set_root_bone(0, root_i)
	ik.set_middle_bone(0, mid_i)
	ik.set_end_bone(0, end_i)
	# Paths are relative to this modifier, not the skeleton.
	ik.set_target_node(0, ik.get_path_to(target))
	ik.set_pole_node(0, ik.get_path_to(pole))
	# Replaces the non‑existent set_use_tip_node().
	ik.set_extend_end_bone(0, tip_length > 0.0)
	if tip_length > 0.0:
		ik.set_end_bone_length(0, tip_length)
	return ik

# -------------------- arm / leg IK --------------------

func _setup_arm_ik():
	left_hand_target = _add_target("LeftHandTarget")
	right_hand_target = _add_target("RightHandTarget")
	left_pole_target = _add_target("LeftPoleTarget")
	right_pole_target = _add_target("RightPoleTarget")

	# Chain: upper arm → fore arm → hand  (shoulder → upper arm → hand would
	# make the solver treat the whole arm as one segment, so the elbow never bends.)
	left_arm_ik = _add_two_bone_ik("LeftArmIK", "LeftUpperArm", "LeftForeArm", "LeftHand",
			left_hand_target, left_pole_target, 0.08)
	right_arm_ik = _add_two_bone_ik("RightArmIK", "RightUpperArm", "RightForeArm", "RightHand",
			right_hand_target, right_pole_target, 0.08)

	print("Arm IK setup complete")

func _setup_leg_ik():
	if skeleton == null:
		return

	left_foot_target = _add_target("LeftFootTarget")
	right_foot_target = _add_target("RightFootTarget")
	left_leg_pole_target = _add_target("LeftLegPoleTarget")
	right_leg_pole_target = _add_target("RightLegPoleTarget")

	# Feet stay pinned to the rest pose in skeleton space → they travel with the
	# body instead of stretching when you stand up.
	var lf := _bone("LeftFoot")
	var rf := _bone("RightFoot")
	if lf != -1:
		left_foot_target.transform = skeleton.get_bone_global_rest(lf)
		left_leg_pole_target.transform = left_foot_target.transform * Transform3D(Basis(), Vector3(0.0, 0.4, 0.6))
	if rf != -1:
		right_foot_target.transform = skeleton.get_bone_global_rest(rf)
		right_leg_pole_target.transform = right_foot_target.transform * Transform3D(Basis(), Vector3(0.0, 0.4, 0.6))

	left_leg_ik = _add_two_bone_ik("LeftLegIK", "LeftUpLeg", "LeftLeg", "LeftFoot",
			left_foot_target, left_leg_pole_target, 0.0)
	right_leg_ik = _add_two_bone_ik("RightLegIK", "RightUpLeg", "RightLeg", "RightFoot",
			right_foot_target, right_leg_pole_target, 0.0)

	print("Leg IK setup complete")

# -------------------- process loop --------------------

func _process(delta: float):
	if skeleton == null:
		return

	_update_head_bone()
	_update_ik_targets()
	_handle_movement(delta)

	debug_timer += delta
	if debug_timer >= 2.0:
		debug_timer = 0.0
		_print_debug()

func _update_head_bone():
	if head_bone_idx == -1 or xr_camera == null or skeleton == null:
		return

	# Move the head bone along the camera’s forward direction only.
	# We project the forward vector to horizontal (zero Y) so the head never
	# slides up or down when you look up/down – it only goes forward/back.
	var camera_global = xr_camera.global_transform
	var forward = -camera_global.basis.z
	forward.y = 0
	forward = forward.normalized()

	var head_global = camera_global
	head_global.origin += forward * head_forward_offset

	skeleton.set_bone_global_pose(head_bone_idx, head_global)

func _update_ik_targets():
	if skeleton == null or left_controller == null or right_controller == null:
		return

	var skeleton_inverse := skeleton.global_transform.affine_inverse()

	# ARM IK targets (children of the skeleton → skeleton space)
	if left_hand_target:
		left_hand_target.transform = skeleton_inverse * left_controller.global_transform
	if right_hand_target:
		right_hand_target.transform = skeleton_inverse * right_controller.global_transform

	# Arm poles: outward + slightly back so elbows bend away from the body.
	var right_vec := global_transform.basis.x
	var fwd := -global_transform.basis.z
	if left_pole_target:
		left_pole_target.global_position = left_controller.global_position \
				- right_vec * 0.30 - fwd * 0.15 + Vector3.DOWN * 0.10
	if right_pole_target:
		right_pole_target.global_position = right_controller.global_position \
				+ right_vec * 0.30 - fwd * 0.15 + Vector3.DOWN * 0.10

# -------------------- movement --------------------

func _handle_movement(delta: float):
	if left_controller == null or right_controller == null:
		return

	var left_input := left_controller.get_vector2("primary")
	if left_input.length() < movement_deadzone:
		left_input = Vector2.ZERO

	var right_input := right_controller.get_vector2("primary")
	if right_input.length() < movement_deadzone:
		right_input = Vector2.ZERO

	var forward := -global_transform.basis.z
	var right := global_transform.basis.x

	var move_direction := forward * left_input.y + right * left_input.x
	if move_direction.length() > 1.0:
		move_direction = move_direction.normalized()

	global_position += move_direction * movement_speed * delta
	rotate_y(right_input.x * turn_speed * delta)

# -------------------- debug --------------------

func _print_debug():
	print("\n=== DEBUG ===")
	print("XROrigin: %s  Camera: %s" % [global_position, xr_camera.global_position])
	print("Skeleton: %s" % skeleton.global_position)
	if head_bone_idx != -1:
		var head_pose = skeleton.get_bone_global_pose(head_bone_idx)
		print("Head global origin: %s" % head_pose.origin)
	if left_hand_target:
		print("Left hand target: %s" % left_hand_target.global_position)
	if left_controller:
		print("Left controller: %s" % left_controller.global_position)
