extends SceneTree
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	print("PASS: " if ok else "FAIL: ", title)
	if not ok: failed += 1
func run():
	var robot = preload("res://scripts/assets/default_robot.gd").create()
	check(robot != null and not robot.get_meta("humanoid_bones", {}).is_empty(), "bundled default robot has humanoid bone mapping without network")
	var reader = load("res://scripts/assets/humanoid_animation.gd").new()
	for role in ["walk", "run", "jump", "dance", "interact"]:
		check(reader.bind_clip(load("res://scripts/assets/default_animations.gd").clip(role), robot) != null, "default robot binds animation: " + role)
	var rig = reader._skeleton(robot)
	check(load("res://scripts/assets/humanoid_rig_adapter.gd").new().validate_mapping(rig, robot.get_meta("humanoid_bones")).valid, "default robot has complete valid tracking chains")
	root.add_child(robot)
	var mapping: Dictionary = robot.get_meta("humanoid_bones")
	var targets: Array = []
	var complete = ["head", "leftHand", "rightHand"].all(func(role): return mapping.has(role))
	if complete:
		for role in ["head", "leftHand", "rightHand"]:
			var target = Node3D.new()
			root.add_child(target)
			target.global_position = rig.global_transform * rig.get_bone_global_rest(rig.find_bone(mapping[role])).origin
			targets.append(target)
		var head_index = rig.find_bone(mapping.head)
		var neutral_basis = (rig.global_basis * rig.get_bone_global_rest(head_index).basis).orthonormalized()
		var tracking = load("res://scripts/assets/avatar_tracking.gd").new()
		rig.add_child(tracking)
		tracking.configure(mapping, targets[0], targets[1], targets[2])
		tracking._process_modification()
		var solved_basis = (rig.global_basis * rig.get_bone_global_pose(head_index).basis).orthonormalized()
		check(neutral_basis.get_rotation_quaternion().angle_to(solved_basis.get_rotation_quaternion()) < 0.03, "neutral headset preserves robot head facing instead of flipping it")
		targets[0].global_position += Vector3(0.02, 0.02, -0.02)
		targets[0].rotation.y = 0.25
		for index in [1, 2]: targets[index].global_position += Vector3(0, 0.015, -0.015)
		tracking._process_modification()
		var head_position = rig.global_transform * rig.get_bone_global_pose(head_index).origin
		check(head_position.distance_to(targets[0].global_position) < 0.01, "default robot head follows headset position")
		var moved_basis = (rig.global_basis * rig.get_bone_global_pose(head_index).basis).orthonormalized()
		check((Basis(Vector3.UP, 0.25) * neutral_basis).get_rotation_quaternion().angle_to(moved_basis.get_rotation_quaternion()) < 0.03, "default robot head follows headset yaw in world space")
		for index in [1, 2]:
			var role = "leftHand" if index == 1 else "rightHand"
			var wrist = rig.global_transform * rig.get_bone_global_pose(rig.find_bone(mapping[role])).origin
			check(wrist.distance_to(targets[index].global_position) < 0.025, "default robot wrist follows controller: " + role)
		for target in targets: target.free()
	robot.free()
	var path = "res://scripts/assets/local_mirror.gd"
	check(ResourceLoader.exists(path), "local mirror component exists")
	if not ResourceLoader.exists(path): quit(1); return
	var mirror = load(path).new()
	root.add_child(mirror)
	var camera = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 1.5, 2)
	mirror.source_camera = camera
	check(mirror.has_method("desktop_grab_hit"), "mirror shares exact desktop interaction test with hover")
	if mirror.has_method("desktop_grab_hit"):
		camera.position = Vector3(0, 0, 2.1)
		check(mirror.desktop_grab_hit(camera) == null, "mirror outside camera reach cannot highlight")
		camera.position.z = 1.9
		check(mirror.desktop_grab_hit(camera) != null, "mirror in camera reach can highlight and interact")
		camera.rotation.y = PI / 2
		check(mirror.desktop_grab_hit(camera) == null, "nearby mirror not under aim cannot highlight")
		camera.rotation = Vector3.ZERO
	check(mirror.has_method("can_grab_at"), "VR mirror hover shares grab surface predicate")
	if mirror.has_method("can_grab_at"):
		check(not mirror.can_grab_at(Vector3(0, 0, 0.31), 0.3), "VR mirror outside grip reach cannot highlight")
		check(mirror.can_grab_at(Vector3(0, 0, 0.29), 0.3), "VR mirror inside grip reach can highlight")
		mirror.held_grip = "left"
		check(not mirror.can_grab_at(Vector3.ZERO, 0.3), "held mirror is not advertised as another grab target")
		mirror.held_grip = ""
	camera.position = Vector3(0, 1.5, 2)
	mirror._process(0.016)
	check(is_equal_approx(mirror.reflection_camera.global_position.z, -2), "mirror reflects camera position across plane")
	check(mirror.viewport.world_3d == root.world_3d, "mirror renders the real local world")
	check(mirror.find_children("*", "CollisionObject3D", true, false).is_empty(), "mirror creates no physics bodies or areas")
	mirror.resize_by(10)
	check(mirror.dimensions.x <= 3.0, "mirror resizing stays bounded")
	check(mirror.has_method("set_dimensions"), "mirror supports independent X and Y sizing")
	if mirror.has_method("set_dimensions"):
		mirror.set_dimensions(Vector2(2.5, 0.8))
		check(mirror.dimensions.is_equal_approx(Vector2(2.5, 0.8)), "mirror may be wide and short rather than uniform scale")
		check(absf(float(mirror.viewport.size.x) / mirror.viewport.size.y - 2.5 / 0.8) < 0.03, "reflection render target preserves resized aspect ratio")
	check(mirror.has_method("set_quality"), "mirror exposes bounded render quality")
	if mirror.has_method("set_quality"):
		mirror.set_quality("low")
		var low: Vector2i = mirror.viewport.size
		mirror.set_quality("high")
		check(mirror.viewport.size.x > low.x and mirror.viewport.size.y > low.y, "higher quality increases reflection resolution")
		mirror.set_quality("invalid")
		check(maxi(mirror.viewport.size.x, mirror.viewport.size.y) <= 1536, "invalid quality cannot create unbounded viewport")
	var hand = Node3D.new()
	root.add_child(hand)
	hand.global_position = mirror.to_global(Vector3(0.9, 0.2, 0.02))
	check(mirror.try_grab(hand, "virtual", 0.3), "any point on mirror surface can be grabbed")
	check(mirror.get("handle") == null, "separate handle is removed")
	check("FRONT_FACING" in mirror.panel.material_override.shader.code and "vec3(0.12" in mirror.panel.material_override.shader.code, "mirror back uses solid dark gray rather than reflection")
	var before = mirror.global_position
	hand.global_position += Vector3(1, 0, 0)
	mirror._process(0.016)
	check(mirror.global_position.distance_to(before + Vector3.RIGHT) < 0.001, "grab moves mirror without physics simulation")
	check(mirror.release("virtual"), "handle releases without throw or network state")
	hand.global_position = mirror.to_global(Vector3(0, 0, -0.02))
	check(mirror.try_grab(hand, "left", 0.3), "mirror back surface is also grabbable")
	mirror.release("left")
	hand.global_position = mirror.to_global(Vector3(5, 5, 0))
	check(not mirror.try_grab(hand, "left", 0.3), "outside mirror bounds cannot grab")
	var controller = load("res://scripts/assets/animation_controller.gd").new()
	var layout = controller._wheel_layout()
	check(layout.groups.root.entries.any(func(entry): return entry.type == "group" and entry.name == "Mirror"), "emote wheel includes Mirror subgroup")
	check(controller._mirror_actions().has("__mirror_width__") and controller._mirror_actions().has("__mirror_height__"), "Mirror subgroup has separate X and Y popup actions")
	var wheel = load("res://scripts/GUI/emote_wheel.gd").new()
	root.add_child(wheel)
	wheel.open(layout, controller.emote_catalog())
	check(wheel.has_method("open_value_popup"), "wheel exposes reusable numeric circular popup")
	if wheel.has_method("open_value_popup"):
		var changed: Array = []
		wheel.open_value_popup("Width X", 1.0, 0.4, 3.0, 0.01, "m", func(value): changed.append(value))
		wheel.value_dial.set_fraction(0.5)
		check(is_equal_approx(changed.back(), 1.7), "X popup maps half-turn to width midpoint")
		wheel.open_value_popup("Height Y", 1.5, 0.6, 4.5, 0.01, "m", func(value): changed.append(value))
		wheel.value_dial.set_fraction(1.0)
		check(is_equal_approx(changed.back(), 4.5), "separate Y popup maps to height maximum")
		wheel.open_value_popup("Volume", 20.0, 0.0, 100.0, 1.0, "%", func(value): changed.append(value))
		wheel.value_dial.set_fraction(0.25)
		check(is_equal_approx(changed.back(), 25.0), "same popup supports unrelated bounded numeric controls")
		check(wheel.visible and wheel.size_popup, "size interaction keeps emote menu open")
		wheel.pointer_direction = Vector2(0.5, 0)
		wheel.size_pointer(true)
		wheel.select_direction(Vector2(0, 0.8))
		wheel.size_pointer(false)
		check(not wheel.size_dragging and wheel.visible, "release ends circular drag without dismissing menu")
		wheel.back()
		check(not wheel.size_popup and wheel.visible, "popup Back returns to wheel without closing it")
	controller.wheel = wheel
	controller._choose_emote("__cancel_emote__")
	check(wheel.visible, "return to movement does not close emote menu")
	controller.local_mirror = mirror
	controller._choose_emote("__mirror_toggle__")
	check(wheel.visible, "mirror toggle does not close emote menu")
	controller.local_mirror = null
	wheel.queue_free()
	controller.free()
	mirror.free(); hand.free(); camera.free()
	print("Mirror failures: ", failed)
	quit(1 if failed else 0)
