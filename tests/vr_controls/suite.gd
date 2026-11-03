extends SceneTree
## Acceptance APIs below are proposed contracts, not existing implementation claims.
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
		check(false, "roadmap component exists: " + path)
		return null
	var object = load(path).new()
	for method in methods:
		if not object.has_method(method):
			check(false, path + " implements " + method)
			if object is Node: object.free()
			return null
	check(true, "component acceptance interface: " + path)
	return object

func run():
	test_current_speed_units()
	test_planar_locomotion()
	test_turning()
	test_menu_router()
	test_settings()
	test_main_menu_wiring()
	print("\nRED VR controls: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)

func test_current_speed_units():
	# Detached production script: assign only the controller it needs; never run
	# ready/physics, real capture, normal startup or physical controller polling.
	var player = load("res://scripts/player/player_vr.gd").new()
	var tracker = XRControllerTracker.new()
	tracker.name = &"vr_fixture_left"
	tracker.set_input(&"primary", Vector2(0, -1))
	XRServer.add_tracker(tracker)
	var stick = XRController3D.new()
	stick.tracker = tracker.name
	root.add_child(stick)
	player.left_controller = stick
	player.movement_speed = 2.0
	var input: Vector2 = player._get_movement_input()
	check(input.is_equal_approx(Vector2(0, -1)), "production movement input is unitless so speed is applied exactly once")
	player.free()
	stick.queue_free()
	XRServer.remove_tracker(tracker)

func test_planar_locomotion():
	var motion = component("res://scripts/player/vr_locomotion.gd", ["desired_velocity"])
	if motion == null: return
	var forward: Vector3 = motion.desired_velocity(Vector2(0, -1), Basis.IDENTITY, 2.0, 0.1)
	check(forward.is_equal_approx(Vector3(0, 0, -2)), "left stick forward moves exactly 2 m/s along headset yaw")
	var pitched = Basis(Vector3.RIGHT, deg_to_rad(70.0))
	var tilted: Vector3 = motion.desired_velocity(Vector2(0, -1), pitched, 2.0, 0.1)
	check(absf(tilted.y) < 0.00001 and absf(tilted.length() - 2.0) < 0.001, "head pitch never adds vertical movement or changes speed")
	var rotated = Basis(Vector3.UP, PI * 0.5)
	check(motion.desired_velocity(Vector2(0, -1), rotated, 2.0, 0.1).is_equal_approx(Vector3(-2, 0, 0)), "head yaw changes movement direction")
	var diagonal: Vector3 = motion.desired_velocity(Vector2(1, -1), Basis.IDENTITY, 2.0, 0.1)
	check(absf(diagonal.length() - 2.0) < 0.001, "diagonal stick input cannot multiply movement speed")
	check(motion.desired_velocity(Vector2(0.01, 0), Basis.IDENTITY, 2.0, 0.1) == Vector3.ZERO, "radial dead zone suppresses drift")
	var vertical: Vector3 = motion.desired_velocity(Vector2(0, -1), Basis(Vector3.RIGHT, PI * 0.5), 2.0, 0.1)
	check(vertical.is_finite() and absf(vertical.y) < 0.001 and absf(vertical.length() - 2.0) < 0.001, "near-vertical gaze retains last valid planar direction")
	if motion is Node: motion.free()

func test_turning():
	var turn = component("res://scripts/player/vr_turn_controller.gd", ["step", "reset", "pivot_transform"])
	if turn == null: return
	check(is_equal_approx(turn.step(1.0, 0.016, "snap", 30.0, 60.0), deg_to_rad(-30)), "right deflection snaps right once")
	check(is_zero_approx(turn.step(1.0, 0.5, "snap", 30.0, 60.0)), "held stick never repeats snap by default")
	turn.step(0.0, 0.016, "snap", 30.0, 60.0)
	check(not is_zero_approx(turn.step(1.0, 0.016, "snap", 30.0, 60.0)), "neutral stick rearms snap")
	turn.reset()
	var total := 0.0
	for i in 60: total += turn.step(1.0, 1.0 / 60, "smooth", 30.0, 60.0)
	check(absf(total - deg_to_rad(-60)) < 0.001, "smooth turn integrates selected degrees/second exactly once")
	var pivot = Vector3(0.8, 0, -0.4)
	var changed: Transform3D = turn.pivot_transform(Transform3D.IDENTITY, pivot, PI * 0.5)
	check((changed * pivot).is_equal_approx(pivot), "turning keeps room-scale headset floor pivot stationary")
	if turn is Node: turn.free()

func test_menu_router():
	var input = component("res://scripts/player/vr_input_router.gd", ["menu_toggle", "reset"])
	if input == null: return
	check(input.menu_toggle(true, false, false), "left lower button opens the shared menu")
	check(not input.menu_toggle(true, false, false), "held left button does not toggle repeatedly")
	input.reset()
	check(input.menu_toggle(false, true, false), "right lower button opens the same shared menu")
	input.reset()
	check(input.menu_toggle(true, true, false), "simultaneous A/X press produces one toggle")
	check(not input.menu_toggle(true, true, false), "simultaneous held buttons cannot immediately close the menu")
	input.reset()
	check(not input.menu_toggle(true, false, true), "modal/text input suppresses controller menu intent")
	check(not input.menu_toggle(true, false, false), "suppressed held press requires release before reactivation")
	if input is Node: input.free()

func test_settings():
	var save = root.get_node("SaveData")
	var definitions = {
		"vr.turn_mode": "snap", "vr.snap_angle": 30.0, "vr.smooth_turn_rate": 60.0,
		"vr.move_speed": 2.0, "vr.move_dead_zone": 0.1, "vr.turn_dead_zone": 0.3,
		"vr.comfort_vignette": false, "vr.snap_blink": false,
		"vr.seated_mode": false, "vr.jump_enabled": false,
		"input.xr_main_menu_action": "ax_button"}
	for id in definitions:
		var definition: Dictionary = save.registry.get_definition(id)
		check(not definition.is_empty() and definition.get("default") == definitions[id], "registry exposes roadmap VR setting/default: " + id)
		if not definition.is_empty():
			check(save.store.get_value(id) == definitions[id], "VR preference flows into typed store: " + id)
	var mode: Dictionary = save.registry.get_definition("vr.turn_mode")
	if not mode.is_empty():
		check(save.store.set_value("vr.turn_mode", "smooth"), "smooth turning can be selected through store")
		check(not save.store.set_value("vr.turn_mode", "invalid"), "invalid turn mode is rejected")
		check(save.store.save_settings(), "VR settings persist in isolated fixture path")
		save.store.reset_value("vr.turn_mode")
		save.store.load_settings()
		check(save.store.get_value("vr.turn_mode") == "smooth", "VR turning preference survives reload")

func test_main_menu_wiring():
	var source = FileAccess.get_file_as_string("res://scripts/player/player_vr.gd")
	check(not 'right_controller.is_button_pressed("ax_button") and is_on_floor()' in source,
		"right lower face button is not still bound to jump")
	var scene = FileAccess.get_file_as_string("res://evidence/player_vr.tscn.txt")
	var wired = scene.contains("res://scenes/GUI/vr_gui.tscn") or scene.contains("res://scenes/GUI/menue.tscn") or source.contains("res://scenes/GUI/vr_gui.tscn") or source.contains("res://scenes/GUI/menue.tscn")
	check(wired, "VR player actually loads a shared main-menu viewport, not only the emote wheel")
	var action_map = FileAccess.get_file_as_string("res://evidence/openxr_action_map.tres.txt")
	check(action_map.contains('resource_name = "ax_button"') and action_map.contains("/user/hand/left/input/x/click") and action_map.contains("/user/hand/right/input/a/click"), "existing OpenXR map supplies both lower A/X defaults")
