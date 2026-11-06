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
	var air_path = "res://scripts/player/air_control.gd"
	check(ResourceLoader.exists(air_path), "shared reduced air steering exists")
	if ResourceLoader.exists(air_path):
		var air = load(air_path).new()
		var initial = Vector3(3, 5, 0)
		var steered: Vector3 = air.steer(initial, Vector3(-3, 0, 0), 20.0, 0.1)
		check(is_equal_approx(steered.x, 2.8), "air steering uses only ten percent acceleration")
		check(steered.y == 5, "air steering preserves vertical velocity")
		check(air.steer(initial, Vector3.ZERO, 20.0, 0.1) == initial, "released air input preserves horizontal momentum")
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
	check(is_equal_approx(player.jump_force, 9.0), "desktop uses higher jump impulse")
	check(is_equal_approx(player.get_walk_speed(), 4.0), "desktop walking speed doubles for existing default settings")
	check(player.has_method("set_avatar_size"), "desktop exposes avatar size control")
	if player.has_method("set_avatar_size"):
		var collider = CollisionShape3D.new()
		collider.name = "CollisionShape3D"
		collider.shape = CapsuleShape3D.new()
		player.add_child(collider)
		var original_height: float = collider.shape.height
		player.set_avatar_size(2.0)
		check(is_equal_approx(player.get_walk_speed(), 8.0), "avatar size doubles movement speed")
		check(player.scale == Vector3.ONE and player.avatar_size == 2, "avatar size keeps physics body transform unscaled")
		check(is_equal_approx(collider.shape.height, original_height * 2), "avatar resizing scales actual capsule geometry")
		player.set_avatar_size(1.0)
		check(is_equal_approx(collider.shape.height, original_height), "size reset restores original capsule without compounding")
	var camera = Camera3D.new()
	camera.name = "Camera3D"
	player.add_child(camera)
	var third = Camera3D.new()
	third.name = "Camera3D2"
	player.add_child(third)
	root.add_child(player)
	check(player.has_method("_update_camera_position"), "desktop camera interpolates physics translation at render cadence")
	if player.has_method("_update_camera_position"):
		player.camera_rest_position = Vector3(0, 1.6, 0)
		player.camera_previous_position = Vector3.ZERO
		player.camera_current_position = Vector3(1, 0, 0)
		player.position = Vector3(1, 0, 0)
		player.camera_motion_ready = true
		player._update_camera_position(0.5)
		check(camera.global_position.is_equal_approx(Vector3(0.5, 1.6, 0)), "rendered camera sits between physics positions without visual stepping")
		check(third.position.z > 1.0 and third.global_position.x < player.global_position.x,
			"F5 camera follows interpolated player translation with a trailing offset")
		var third_before = third.position
		camera.rotation.x = 0.3
		player._update_camera_position(0.75)
		check(is_equal_approx(camera.rotation.x, 0.3), "camera smoothing never delays mouse-look rotation")
		check(not third.position.is_equal_approx(third_before), "F5 camera orbits with vertical mouse-look pitch")
		player.set_player_pos(Vector3(20, 0, 0))
		player._update_camera_position(0.5)
		check(camera.global_position.is_equal_approx(Vector3(20, 1.6, 0)), "teleport clears camera history without dragging through previous world")
		var offset = third.position - player.camera_rest_position
		player.set_avatar_size(2.0)
		check((third.position - player.camera_rest_position).is_equal_approx(offset * 2), "F5 camera orbit distance scales with avatar size")
		player.set_avatar_size(1.0)
		var switch = InputEventKey.new()
		switch.keycode = KEY_F5
		switch.pressed = true
		camera.current = true
		player._input(switch)
		check(third.current, "F5 selects following third-person camera")
		switch.echo = true
		player._input(switch)
		check(third.current, "held F5 does not rapidly alternate cameras")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("forward")
	Input.action_press("sprint")
	for i in 240: player._physics_process(0.016)
	check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), 6.0), "production desktop physics reaches shared default sprint speed")
	Input.action_press("right")
	for i in 40: player._physics_process(0.016)
	check(absf(Vector2(player.velocity.x, player.velocity.z).length() - 6.0) < 0.001, "desktop diagonal sprint stays bounded")
	root.get_node("SaveData").voice.input_blocked = true
	player._physics_process(0.016)
	root.get_node("SaveData").voice.input_blocked = false
	for i in 40: player._physics_process(0.016)
	check(absf(Vector2(player.velocity.x, player.velocity.z).length() - 4.0) < 0.001, "rebinding suppresses sprint until release")
	Input.action_release("sprint")
	player._physics_process(0.016)
	Input.action_press("sprint")
	for i in 40: player._physics_process(0.016)
	check(absf(Vector2(player.velocity.x, player.velocity.z).length() - 6.0) < 0.001, "desktop repress restores sprint")
	player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for i in 40: player._physics_process(0.016)
	check(absf(Vector2(player.velocity.x, player.velocity.z).length() - 4.0) < 0.001, "focus loss requires sprint release even between physics frames")
	root.get_node("NetworkHandler").session_busy = true
	player._physics_process(0.016)
	check(player._movement_blocked(), "world transition suppresses desktop movement")
	root.get_node("NetworkHandler").session_busy = false
	Input.action_release("forward")
	Input.action_release("right")
	for i in 80: player._physics_process(0.016)
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.001, "sprint without direction does not move")
	Input.action_release("sprint")
	player.grounded = false
	player.velocity = Vector3(2, 0, 0)
	player._physics_process(0.1)
	check(is_equal_approx(player.velocity.x, 2.0), "production desktop preserves airborne momentum without input")
	Input.action_press("left")
	player._physics_process(0.1)
	check(is_equal_approx(player.velocity.x, 1.8), "production desktop opposing air input has reduced steering")
	Input.action_release("left")
	player.grounded = true
	player.velocity = Vector3.ZERO
	Input.action_press("forward", 0.6)
	for i in 120: player._physics_process(1.0 / 60.0)
	var analog_speed = Vector2(player.velocity.x, player.velocity.z).length()
	check(analog_speed > 0.1 and analog_speed < player.get_walk_speed() * 0.8, "desktop analog input preserves magnitude instead of jumping to full speed")
	Input.action_release("forward")
	var speeds: Array = []
	for fps in [30, 60, 144]:
		player.velocity = Vector3.ZERO
		Input.action_press("forward")
		for frame in int(fps / 10): player._physics_process(1.0 / fps)
		speeds.append(Vector2(player.velocity.x, player.velocity.z).length())
		Input.action_release("forward")
	check(absf(speeds[0] - speeds[2]) < 0.1, "desktop acceleration stays consistent across physics rates")
	var before_yaw = player.rotation.y
	player.focused = false
	var mouse = InputEventMouseMotion.new()
	mouse.relative = Vector2(100, 0)
	player._input(mouse)
	check(is_equal_approx(player.rotation.y, before_yaw), "unfocused mouse events cannot rotate desktop body")
	player.free()
	await process_frame

func vr_checks():
	var player = load("res://scripts/player/player_vr.gd").new()
	check(is_equal_approx(player.jump_force, 9.0), "VR uses higher jump impulse")
	check(is_equal_approx(player.get_walk_speed(), 4.0), "VR walking speed doubles for existing default settings")
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
	check(is_equal_approx(player._sprint_speed(false, false), 6.0), "left XR primary click boosts default VR speed")
	check(is_equal_approx(player._sprint_speed(false, true), 4.0), "teleport disables sprint boost")
	check(is_equal_approx(player._sprint_speed(false, false), 4.0), "switching back requires sprint release")
	tracker.set_input("primary_click", false)
	player._sprint_speed(false, false)
	tracker.set_input("primary_click", true)
	var speed: float = player._sprint_speed(false, false)
	var motion = player.locomotion
	check(is_equal_approx(motion.desired_velocity(Vector2(1, -1), Basis.IDENTITY, speed, 0.1).length(), 6.0), "VR diagonal sprint stays bounded")
	check(is_equal_approx(motion.desired_velocity(Vector2(0, -0.55), Basis.IDENTITY, speed, 0.1).length(), 3.0), "VR analog sprint preserves magnitude scaling")
	check(motion.desired_velocity(Vector2.ZERO, Basis.IDENTITY, speed, 0.1) == Vector3.ZERO, "VR click without stick motion stays still")
	check(is_equal_approx(player._sprint_speed(true, false), 4.0), "VR blocked input suppresses sprint")
	check(is_equal_approx(player._sprint_speed(false, false), 4.0), "VR held click cannot bypass suppression")
	tracker.set_input("primary_click", false)
	player._sprint_speed(false, false)
	tracker.set_input("primary_click", true)
	root.get_node("SaveData").store.set_value("vr.move_speed", 4.0)
	check(is_equal_approx(player._sprint_speed(false, false), 12.0), "VR sprint respects configured base speed")
	root.get_node("SaveData").store.reset_value("vr.move_speed")
	var desktop = load("res://desktop_fixture.gd").new()
	var camera = Camera3D.new()
	camera.name = "Camera3D"
	desktop.add_child(camera)
	root.add_child(desktop)
	for walk_speed in [0.1, 2.0, 3.0, 5.0]:
		root.get_node("SaveData").store.set_value("vr.move_speed", walk_speed)
		check(is_equal_approx(desktop.get_walk_speed(), player.get_walk_speed()), "PC and VR read identical walking speed at %s" % walk_speed)
		check(is_equal_approx(desktop.get_walk_speed(), walk_speed * 2.0), "saved speed is scaled exactly twice, without rewriting settings")
		for running in [false, true]:
			tracker.set_input("primary_click", running)
			if running: Input.action_press("sprint")
			else: Input.action_release("sprint")
			Input.action_press("forward")
			for i in 240: desktop._physics_process(0.016)
			var vr_speed: float = motion.desired_velocity(Vector2(0, -1), Basis.IDENTITY, player._sprint_speed(false, false), 0.1).length()
			check(absf(Vector2(desktop.velocity.x, desktop.velocity.z).length() - vr_speed) < 0.001, "PC physics and full-stick VR speed match at %s, sprint=%s" % [walk_speed, running])
	Input.action_release("forward")
	Input.action_release("sprint")
	root.get_node("SaveData").store.reset_value("vr.move_speed")
	desktop.free()
	controller.free()
	XRServer.remove_tracker(tracker)
	player.free()
