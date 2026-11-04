extends SceneTree
## Acceptance APIs below are proposed contracts, not existing implementation claims.
var passed := 0
var failed := 0

class TrackingPlayer extends Node:
	var tracker_roles = preload("res://scripts/assets/tracker_role_provider.gd").new()
	var rig_report = {"valid": false, "errors": ["fixture missing rig"]}

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
	test_viewport_coordinates()
	test_pointer_capture()
	test_comfort_state()
	test_text_entry()
	test_tracking_setup()
	await test_room_scale()
	await test_safety_and_teleport()
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
	var backward: Vector3 = motion.desired_velocity(Vector2(0, 1), Basis.IDENTITY, 2.0, 0.1)
	check(backward.is_equal_approx(Vector3(0, 0, 2)), "backward input does not reverse an unrelated axis")
	var analog: Vector3 = motion.desired_velocity(Vector2(0, -0.55), Basis.IDENTITY, 2.0, 0.1)
	check(absf(analog.length() - 1.0) < 0.001, "analog magnitude is remapped continuously outside radial dead zone")
	var rolled: Vector3 = motion.desired_velocity(Vector2(1, 0), Basis(Vector3.FORWARD, 0.8), 2.0, 0.1)
	check(rolled.is_equal_approx(Vector3(2, 0, 0)), "head roll does not tilt or slow rightward ground motion")
	check(motion.desired_velocity(Vector2.ZERO, Basis.IDENTITY, 2.0, 0.1) == Vector3.ZERO, "released movement input requests zero velocity")
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
	turn.reset()
	check(is_zero_approx(turn.step(0.2, 0.016, "snap", 30.0, 60.0)), "subthreshold turn input cannot snap")
	check(is_equal_approx(turn.step(-1.0, 0.016, "snap", 45.0, 60.0), deg_to_rad(45)), "left snap respects selected angle and sign")
	check(is_zero_approx(turn.step(1.0, 0.016, "snap", 45.0, 60.0)), "crossing directly from left to right must rearm through neutral")
	for rate in [30, 72, 90, 120]:
		turn.reset()
		var angle := 0.0
		for i in rate: angle += turn.step(-1.0, 1.0 / rate, "smooth", 30.0, 60.0)
		check(absf(angle - deg_to_rad(60)) < 0.001, "smooth turn is frame-rate independent at %s Hz" % rate)
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
	input.menu_toggle(false, false, false)
	check(input.menu_toggle(true, false, false), "release after suppression restores next deliberate menu press")
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

func test_viewport_coordinates():
	# Exercise the actual production non-square viewport mapping, not a stub.
	var source = FileAccess.get_file_as_string("res://scripts/GUI/vr_gui.gd")
	var type_safe = not source.contains("var uv = local_point * 0.5 + Vector3")
	check(type_safe, "production viewport mapping converts its 3D hit to Vector2 before pixel multiplication")
	if not type_safe:
		print("BLOCKED: six viewport behavior assertions await removal of the known Vector3 × Vector2 runtime error")
		return
	var panel = load("res://scripts/GUI/vr_gui.gd").new()
	panel.size = Vector2(2, 1)
	panel.pixel_per_unit = 200
	var viewport = SubViewport.new()
	viewport.name = "SubViewport"
	panel.add_child(viewport)
	var mesh = MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	mesh.mesh = QuadMesh.new()
	panel.add_child(mesh)
	root.add_child(panel)
	check(panel.raycast_to_viewport_point(Vector3(0, 0, 1), Vector3.FORWARD).is_equal_approx(Vector2(200, 100)), "production non-square UI ray maps center to viewport center")
	check(panel.raycast_to_viewport_point(Vector3(0.5, 0.25, 1), Vector3.FORWARD).is_equal_approx(Vector2(300, 50)), "production ray uses actual panel width/height and inverted viewport Y")
	check(panel.raycast_to_viewport_point(Vector3(1.2, 0, 1), Vector3.FORWARD) == Vector2(-1, -1), "ray outside quad is rejected rather than injected into controls")
	check(panel.raycast_to_viewport_point(Vector3(0, 0, -1), Vector3.BACK) == Vector2(-1, -1), "back-side UI ray cannot click mirrored controls")
	check(panel.raycast_to_viewport_point(Vector3(0, 0, 1), Vector3.RIGHT) == Vector2(-1, -1), "parallel ray produces no UI hit")
	panel.position = Vector3(3, 2, -4)
	panel.rotation.y = PI * 0.5
	var origin = panel.to_global(Vector3(0, 0, 1))
	check(panel.raycast_to_viewport_point(origin, -panel.global_basis.z).is_equal_approx(Vector2(200, 100)), "transformed world-space panel keeps correct center mapping")
	panel.queue_free()

func test_pointer_capture():
	var pointer = component("res://scripts/GUI/vr_pointer_router.gd", ["hover", "press", "release", "cancel", "drain_events"])
	if pointer == null: return
	pointer.hover("right", Vector2(100, 80), true)
	pointer.press("right")
	var down: Array = pointer.drain_events()
	check(down.size() == 1 and down[0].get("pressed") == true, "UI pointer emits one owned press")
	pointer.hover("right", Vector2(-1, -1), false)
	pointer.release("right")
	var up: Array = pointer.drain_events()
	check(up.size() == 1 and up[0].get("pressed") == false, "dragging off quad still releases captured UI press")
	pointer.release("right")
	check(pointer.drain_events().is_empty(), "duplicate release cannot fire a second action")
	pointer.hover("left", Vector2(50, 40), true)
	pointer.press("left")
	pointer.drain_events()
	pointer.cancel()
	var canceled: Array = pointer.drain_events()
	check(canceled.size() == 1 and canceled[0].get("pressed") == false, "menu close or tracker loss releases held pointer once")
	pointer.press("right")
	check(pointer.drain_events().is_empty(), "invalid hit never starts a new UI press")
	if pointer is Node: pointer.free()

func test_comfort_state():
	var comfort = component("res://scripts/player/vr_comfort.gd", ["update_vignette", "reset"])
	if comfort == null: return
	comfort.reset()
	check(is_zero_approx(comfort.update_vignette(0.0, 0.0, 0.1, true)), "stationary comfort vignette stays open")
	var moving: float = comfort.update_vignette(2.0, 0.0, 0.1, true)
	check(moving > 0 and moving < 1, "movement comfort effect fades in rather than instantly blacking out")
	check(is_zero_approx(comfort.update_vignette(2.0, 90.0, 0.1, false)), "disabled comfort effect leaves view unobscured")
	comfort.reset()
	check(is_zero_approx(comfort.update_vignette(0.0, 0.0, 0.0, true)), "focus/session reset clears old comfort overlay state")
	if comfort is Node: comfort.free()

func test_text_entry():
	var script = "res://scripts/GUI/vr_keyboard.gd"
	check(ResourceLoader.exists(script), "headset menu provides a virtual keyboard")
	if not ResourceLoader.exists(script): return
	var keyboard = load(script).new()
	var field = LineEdit.new()
	root.add_child(field)
	root.add_child(keyboard)
	keyboard.edit(field)
	keyboard.type_text("https://example.org/avatar.vrm")
	check(field.text == "https://example.org/avatar.vrm", "virtual keyboard enters an avatar URL into actual LineEdit")
	keyboard.backspace()
	check(field.text.ends_with(".vr"), "virtual keyboard deletes at caret")
	field.max_length = field.text.length()
	keyboard.type_text("too long")
	check(field.text.ends_with(".vr"), "virtual keyboard respects field length limits")
	keyboard.close()
	check(not keyboard.visible, "virtual keyboard closes without leaving a visible input overlay")
	field.queue_free()
	keyboard.queue_free()

func test_tracking_setup():
	var player = TrackingPlayer.new()
	root.add_child(player)
	player.tracker_roles.update_sample("waist-fixture", Transform3D.IDENTITY, true, Time.get_ticks_msec())
	var setup = load("res://scripts/GUI/vr_tracking_setup.gd").new()
	root.add_child(setup)
	setup.configure(player)
	check(setup.choices.hips.item_count == 2, "actual setup panel lists exposed fresh tracker and untracked fallback")
	setup.choices.hips.item_selected.emit(1)
	check(player.tracker_roles.assignments.get("hips") == "waist-fixture", "actual setup selection assigns tracker through role provider")
	setup.choices.hips.item_selected.emit(0)
	check(not player.tracker_roles.assignments.has("hips"), "actual setup untracked choice removes role assignment")
	check("fixture missing rig" in setup.status.text, "tracking setup exposes rig diagnostics instead of pretending calibration succeeded")
	setup.queue_free()
	player.queue_free()

func test_room_scale():
	var path = "res://scripts/player/vr_room_scale.gd"
	check(ResourceLoader.exists(path), "room-scale capsule follows physical horizontal headset displacement")
	if not ResourceLoader.exists(path): return
	var body = CharacterBody3D.new()
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.2
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	body.add_child(shape)
	var origin = XROrigin3D.new()
	body.add_child(origin)
	var head = Node3D.new()
	origin.add_child(head)
	head.position = Vector3(0.4, 1.6, 0.1)
	root.add_child(body)
	await physics_frame
	var before = head.global_transform
	var follow = load(path).new()
	follow.reconcile(body, origin, head)
	check(Vector2(body.position.x, body.position.z).distance_to(Vector2(0.4, 0.1)) < 0.001, "room-scale body aligns with physical headset floor position")
	check(head.global_transform.is_equal_approx(before), "capsule following never changes physical headset world pose")
	var stable = body.position
	follow.reconcile(body, origin, head)
	check(body.position.is_equal_approx(stable), "physical headset displacement is not counted twice")
	var wall = StaticBody3D.new()
	var wall_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.1, 3, 3)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	wall.position = Vector3(0.8, 1.0, 0)
	root.add_child(wall)
	head.position.x += 0.6
	before = head.global_transform
	await physics_frame
	follow.reconcile(body, origin, head)
	check(body.global_position.x < 0.6, "room-scale collision body cannot follow physical head through wall")
	check(head.global_transform.is_equal_approx(before), "blocked physical walking does not push tracked headset back artificially")
	wall.queue_free()
	body.queue_free()

func test_safety_and_teleport():
	var path = "res://scripts/player/vr_safety.gd"
	check(ResourceLoader.exists(path), "VR safety validates capsule growth, head overlap and teleport clearance")
	if not ResourceLoader.exists(path): return
	var safety = load(path).new()
	var body = CharacterBody3D.new()
	var collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.2
	capsule.height = 1.2
	collider.shape = capsule
	collider.position.y = 0.6
	body.add_child(collider)
	root.add_child(body)
	var roof = StaticBody3D.new()
	var roof_collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4, 0.2, 4)
	roof_collision.shape = box
	roof.add_child(roof_collision)
	roof.position.y = 1.6
	root.add_child(roof)
	await physics_frame
	check(not safety.resize_capsule(body, collider, 2.0) and is_equal_approx(capsule.height, 1.2), "capsule cannot grow through a low ceiling")
	check(safety.resize_capsule(body, collider, 1.0), "capsule can shrink safely while crouching")
	check(safety.head_obstructed(body, Vector3(0, 1.6, 0)), "head overlap with ceiling requests protective fade")
	check(not safety.head_obstructed(body, Vector3(0, 0.8, 0)), "clear head space never requests overlap fade")
	check(not safety.clearance(body, Vector3.ZERO, 2.0, 0.2), "teleport destination under low ceiling is rejected")
	check(safety.clearance(body, Vector3(5, 0, 0), 2.0, 0.2), "empty teleport destination passes capsule clearance")
	var origin = XROrigin3D.new()
	body.add_child(origin)
	var head = Node3D.new()
	origin.add_child(head)
	head.position = Vector3(0.3, 1.6, 0.2)
	safety.commit_teleport(body, origin, head, Vector3(5, 0, 0))
	check(Vector2(head.global_position.x, head.global_position.z).distance_to(Vector2(5, 0)) < 0.001, "teleport places physical head floor pivot at selected destination")
	check(head.position.is_equal_approx(Vector3(0.3, 1.6, 0.2)), "teleport does not rewrite local headset tracking transform")
	roof.queue_free()
	body.queue_free()
