extends SceneTree

var passed := 0
var failed := 0

func _initialize():
	call_deferred("run")

func check(value: bool, title: String):
	if value:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func component(path: String, methods: Array):
	if not ResourceLoader.exists(path):
		check(false, "roadmap tracking component exists: " + path)
		return null
	var object = load(path).new()
	for method in methods:
		if not object.has_method(method):
			check(false, path + " implements " + method)
			if object is Node: object.free()
			return null
	return object

func fixture_rig() -> Skeleton3D:
	var rig = Skeleton3D.new()
	for name in ["Pelvis", "Spine", "Head", "UpperL", "LowerL", "HandL", "UpperR", "LowerR", "HandR", "ThighL", "ShinL", "FootL", "ThighR", "ShinR", "FootR"]:
		rig.add_bone(name)
	var parents = [-1, 0, 1, 1, 3, 4, 1, 6, 7, 0, 9, 10, 0, 12, 13]
	var offsets = [Vector3(0, 1, 0), Vector3(0, 0.3, 0), Vector3(0, 0.3, 0),
		Vector3(0.2, 0.1, 0), Vector3(0.3, 0, 0), Vector3(0.3, 0, 0),
		Vector3(-0.2, 0.1, 0), Vector3(-0.3, 0, 0), Vector3(-0.3, 0, 0),
		Vector3(0.1, -0.1, 0), Vector3(0, -0.4, 0), Vector3(0, -0.4, 0),
		Vector3(-0.1, -0.1, 0), Vector3(0, -0.4, 0), Vector3(0, -0.4, 0)]
	for index in parents.size():
		rig.set_bone_parent(index, parents[index])
		rig.set_bone_rest(index, Transform3D(Basis.IDENTITY, offsets[index]))
	rig.reset_bone_poses()
	return rig

func fixture_map() -> Dictionary:
	return {"hips": "Pelvis", "spine": "Spine", "head": "Head",
		"leftUpperArm": "UpperL", "leftLowerArm": "LowerL", "leftHand": "HandL",
		"rightUpperArm": "UpperR", "rightLowerArm": "LowerR", "rightHand": "HandR",
		"leftUpperLeg": "ThighL", "leftLowerLeg": "ShinL", "leftFoot": "FootL",
		"rightUpperLeg": "ThighR", "rightLowerLeg": "ShinR", "rightFoot": "FootR"}

func run():
	test_existing_camera_independence()
	test_existing_singularities()
	test_rig_validation()
	test_calibration()
	test_tracker_roles()
	test_fbt_solver()
	print("\nRED tracking: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)

func test_existing_camera_independence():
	var rig = fixture_rig()
	root.add_child(rig)
	var head = Node3D.new()
	var hand = Node3D.new()
	root.add_child(head)
	root.add_child(hand)
	head.position = Vector3(0.05, 1.65, -0.1)
	hand.position = Vector3(0.55, 1.2, -0.2)
	var camera_pose = head.global_transform
	var tracking = load("res://scripts/assets/avatar_tracking.gd").new()
	rig.add_child(tracking)
	tracking.configure(fixture_map(), head, hand, null)
	tracking._process_modification()
	check(head.global_transform.is_equal_approx(camera_pose), "existing IK never moves headset target")
	check(rig.get_bone_global_pose(5).origin.distance_to(hand.position) < 0.02, "existing reachable controller target baseline remains valid")
	check(tracking.has_method("set_calibration"), "tracking modifier accepts explicit calibrated grip/head offsets")
	check(tracking.has_method("set_tracking_validity"), "tracking modifier supports per-chain age/loss/reacquisition policy")
	rig.free()
	head.free()
	hand.free()

func test_rig_validation():
	var adapter = component("res://scripts/assets/humanoid_rig_adapter.gd", ["validate_mapping"])
	if adapter == null: return
	var rig = fixture_rig()
	var mapping = fixture_map()
	var report: Dictionary = adapter.validate_mapping(rig, mapping)
	check(report.get("valid", false), "declared humanoid with correct chains validates")
	var duplicate = mapping.duplicate()
	duplicate.rightHand = duplicate.leftHand
	check(not adapter.validate_mapping(rig, duplicate).get("valid", true), "duplicate tracked bone assignment rejected")
	var missing = mapping.duplicate()
	missing.erase("head")
	check(not adapter.validate_mapping(rig, missing).get("valid", true), "missing required head reported")
	var bad_parent = fixture_rig()
	bad_parent.set_bone_parent(5, 0)
	check(not adapter.validate_mapping(bad_parent, mapping).get("valid", true), "wrist outside its elbow chain is rejected")
	bad_parent.free()
	rig.set_bone_rest(4, Transform3D.IDENTITY)
	check(not adapter.validate_mapping(rig, mapping).get("valid", true), "zero-length arm chain rejected before IK")
	rig.free()
	if adapter is Node: adapter.free()

func test_calibration():
	var calibration = component("res://scripts/assets/tracking_calibration.gd", ["configure", "save_calibration", "load_calibration"])
	if calibration == null: return
	calibration.configure("res://calibration.json", "account-a", "a".repeat(64))
	var data = {"schema": 1, "eye_height": 1.65, "scale": 1.0,
		"head_offset": [0.0, 0.0, 0.0], "left_grip_offset": [0.0, 0.0, 0.0], "right_grip_offset": [0.0, 0.0, 0.0]}
	check(calibration.save_calibration(data), "valid calibration saves to isolated owner/avatar scope")
	check(calibration.load_calibration().get("eye_height") == 1.65, "calibration round-trips eye height")
	var invalid = data.duplicate(true)
	invalid.scale = -1.0
	check(not calibration.save_calibration(invalid), "negative avatar scale cannot replace valid calibration")
	check(calibration.load_calibration().get("scale") == 1.0, "rejected calibration preserves the last valid stored values")
	var corrupt_file = FileAccess.open("res://corrupt-calibration.json", FileAccess.WRITE)
	corrupt_file.store_string("broken json")
	corrupt_file.close()
	calibration.configure("res://corrupt-calibration.json", "account-a", "a".repeat(64))
	check(calibration.load_calibration().is_empty(), "corrupt calibration reports unavailable rather than adopting data")
	check(not calibration.save_calibration(data) and FileAccess.get_file_as_string("res://corrupt-calibration.json") == "broken json", "corrupt calibration is preserved rather than silently overwritten")
	calibration.configure("res://calibration.json", "account-b", "a".repeat(64))
	check(calibration.load_calibration().is_empty(), "another account cannot adopt calibration")
	calibration.configure("res://calibration.json", "account-a", "b".repeat(64))
	check(calibration.load_calibration().is_empty(), "changed avatar revision cannot adopt incompatible calibration")
	if calibration is Node: calibration.free()

func test_tracker_roles():
	var roles = component("res://scripts/assets/tracker_role_provider.gd", ["update_sample", "assign", "targets", "clear"])
	if roles == null: return
	roles.update_sample("temporary-head", Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0)), true, 1000)
	check(roles.assign("head", "temporary-head"), "available tracker can be explicitly assigned to head role")
	check(roles.targets(1100).has("head"), "fresh assigned target is available")
	check(not roles.targets(3000).has("head"), "stale tracker expires instead of freezing pose")
	check(not roles.assign("leftFoot", "missing-device"), "missing tracker cannot pretend to supply FBT")
	check(not roles.assign("rightHand", "temporary-head"), "one device cannot silently represent two different tracked roles")
	roles.update_sample("temporary-head", Transform3D.IDENTITY, false, 1200)
	check(not roles.targets(1250).has("head"), "explicit tracking loss overrides a still-fresh timestamp")
	roles.update_sample("temporary-head", Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0)), true, 1300)
	check(roles.targets(1350).has("head"), "reacquired assigned tracker becomes available without stale pose history")
	check(roles.available(1350).has("temporary-head"), "fresh runtime samples appear in setup choices")
	roles.unassign("head")
	check(not roles.targets(1350).has("head"), "explicit unassignment returns role to animation fallback")
	roles.clear()
	check(roles.targets(1100).is_empty(), "disconnect clears all ephemeral tracker samples")
	if roles is Node: roles.free()

func test_fbt_solver():
	var solver = component("res://scripts/assets/full_body_solver.gd", ["configure", "solve"])
	if solver == null: return
	var rig = fixture_rig()
	root.add_child(rig)
	solver.configure(rig, fixture_map())
	var targets = {"hips": Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)),
		"leftFoot": Transform3D(Basis.IDENTITY, Vector3(0.1, 0.1, -0.1)),
		"rightFoot": Transform3D(Basis.IDENTITY, Vector3(-0.1, 0.1, -0.1))}
	solver.solve(targets, 1.0 / 60)
	check(rig.get_bone_global_pose(11).origin.distance_to(targets.leftFoot.origin) < 0.04, "optional tracked left foot solves within calibrated reach")
	check(rig.get_bone_global_pose(14).origin.distance_to(targets.rightFoot.origin) < 0.04, "optional tracked right foot solves within calibrated reach")
	solver.solve({}, 1.0 / 60)
	check(rig.get_bone_global_pose(11).is_finite(), "missing FBT subset falls back safely without invalid transforms")
	rig.free()
	if solver is Node: solver.free()

func test_existing_singularities():
	var rig = fixture_rig()
	root.add_child(rig)
	var target = Node3D.new()
	root.add_child(target)
	var tracking = load("res://scripts/assets/avatar_tracking.gd").new()
	rig.add_child(tracking)
	tracking.configure(fixture_map(), null, target, null)
	var shoulder = rig.get_bone_global_pose(3).origin
	for position in [shoulder, shoulder + Vector3(10, 0, 0), shoulder + Vector3(0, -0.4, 0), shoulder + Vector3(0, 0, -0.4)]:
		rig.reset_bone_poses()
		target.position = position
		tracking._process_modification()
		var finite := true
		for bone in rig.get_bone_count(): finite = finite and rig.get_bone_global_pose(bone).is_finite()
		check(finite, "existing IK keeps finite poses for singular/unreachable target " + str(position))
		check(rig.get_bone_global_pose(5).origin.distance_to(shoulder) <= 0.601, "unreachable controller target does not stretch the arm")
	var right_before = rig.get_bone_pose_rotation(6)
	tracking.left_target = null
	tracking._process_modification()
	check(rig.get_bone_pose_rotation(6).is_equal_approx(right_before), "missing left tracker never modifies opposite arm")
	check(tracking.has_method("tracking_weights"), "per-chain fallback exposes inspectable tracking blend weights")
	if tracking.has_method("tracking_weights"):
		var weights: Dictionary = tracking.tracking_weights()
		check(weights.get("leftHand", -1) == 0.0, "lost hand tracker blends back to animation rather than holding stale tracking weight")
	rig.free()
	target.free()
