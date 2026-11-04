extends SceneTree
var passed := 0
var failed := 0

func _initialize(): call_deferred("run")

func check(ok: bool, title: String):
	if ok:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func run():
	var path = "res://scripts/player/sprint_policy.gd"
	check(ResourceLoader.exists(path), "shared sprint policy exists")
	if not ResourceLoader.exists(path):
		quit(1)
		return
	var policy = load(path).new()
	check(policy.target_speed(3.0, true, false) == 4.5, "held sprint multiplies walking speed once")
	for i in 20: policy.target_speed(3.0, true, false)
	check(policy.target_speed(3.0, true, false) == 4.5, "sprint never compounds")
	check(policy.target_speed(3.0, false, false) == 3.0, "release returns walking target")
	check(policy.target_speed(2.0, true, true) == 2.0, "blocked input suppresses boost")
	check(policy.target_speed(2.0, true, false) == 2.0, "held sprint cannot resume after suppression")
	policy.target_speed(2.0, false, false)
	check(policy.target_speed(2.0, true, false) == 3.0, "release and repress rearms sprint")
	check(policy.target_speed(4.0, true, false) == 6.0, "configured walking speed is respected")
	await desktop_checks()
	vr_checks()
	print("Sprint: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func desktop_checks():
	for action in ["forward", "back", "left", "right", "sprint"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var player = load("res://desktop_fixture.gd").new()
	var camera = Camera3D.new()
	camera.name = "Camera3D"
	player.add_child(camera)
	root.add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("forward")
	Input.action_press("sprint")
	for i in 40: player._physics_process(0.016)
	check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), 4.5), "production desktop physics reaches sprint speed")
	Input.action_press("right")
	for i in 40: player._physics_process(0.016)
	check(absf(Vector2(player.velocity.x, player.velocity.z).length() - 4.5) < 0.001, "desktop diagonal sprint stays bounded")
	root.get_node("SaveData").voice.input_blocked = true
	player._physics_process(0.016)
	root.get_node("SaveData").voice.input_blocked = false
	for i in 40: player._physics_process(0.016)
	check(absf(Vector2(player.velocity.x, player.velocity.z).length() - 3.0) < 0.001, "rebinding suppresses sprint until release")
	Input.action_release("sprint")
	player._physics_process(0.016)
	Input.action_press("sprint")
	for i in 40: player._physics_process(0.016)
	check(absf(Vector2(player.velocity.x, player.velocity.z).length() - 4.5) < 0.001, "desktop repress restores sprint")
	player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for i in 40: player._physics_process(0.016)
	check(absf(Vector2(player.velocity.x, player.velocity.z).length() - 3.0) < 0.001, "focus loss requires sprint release even between physics frames")
	root.get_node("NetworkHandler").session_busy = true
	player._physics_process(0.016)
	check(player._movement_blocked(), "world transition suppresses desktop movement")
	root.get_node("NetworkHandler").session_busy = false
	Input.action_release("forward")
	Input.action_release("right")
	for i in 80: player._physics_process(0.016)
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.001, "sprint without direction does not move")
	Input.action_release("sprint")
	player.free()
	await process_frame

func vr_checks():
	var player = load("res://scripts/player/player_vr.gd").new()
	check(player.has_method("_sprint_speed"), "VR integrates sprint speed selection")
	if not player.has_method("_sprint_speed"):
		player.free()
		return
	var tracker = XRControllerTracker.new()
	tracker.name = &"sprint_left"
	tracker.set_pose("default", Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	tracker.set_input("primary_click", true)
	XRServer.add_tracker(tracker)
	var controller = XRController3D.new()
	controller.tracker = tracker.name
	root.add_child(controller)
	player.left_controller = controller
	check(is_equal_approx(player._sprint_speed(false, false), 3.0), "left XR primary click boosts default VR speed")
	check(is_equal_approx(player._sprint_speed(false, true), 2.0), "teleport disables sprint boost")
	check(is_equal_approx(player._sprint_speed(false, false), 2.0), "switching back requires sprint release")
	tracker.set_input("primary_click", false)
	player._sprint_speed(false, false)
	tracker.set_input("primary_click", true)
	var speed: float = player._sprint_speed(false, false)
	var motion = player.locomotion
	check(is_equal_approx(motion.desired_velocity(Vector2(1, -1), Basis.IDENTITY, speed, 0.1).length(), 3.0), "VR diagonal sprint stays bounded")
	check(is_equal_approx(motion.desired_velocity(Vector2(0, -0.55), Basis.IDENTITY, speed, 0.1).length(), 1.5), "VR analog sprint preserves magnitude scaling")
	check(motion.desired_velocity(Vector2.ZERO, Basis.IDENTITY, speed, 0.1) == Vector3.ZERO, "VR click without stick motion stays still")
	check(is_equal_approx(player._sprint_speed(true, false), 2.0), "VR blocked input suppresses sprint")
	check(is_equal_approx(player._sprint_speed(false, false), 2.0), "VR held click cannot bypass suppression")
	tracker.set_input("primary_click", false)
	player._sprint_speed(false, false)
	tracker.set_input("primary_click", true)
	root.get_node("SaveData").store.set_value("vr.move_speed", 4.0)
	check(is_equal_approx(player._sprint_speed(false, false), 6.0), "VR sprint respects configured base speed")
	root.get_node("SaveData").store.reset_value("vr.move_speed")
	controller.free()
	XRServer.remove_tracker(tracker)
	player.free()
