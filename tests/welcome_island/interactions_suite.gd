extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	if ok: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func run():
	var world = Node3D.new()
	root.add_child(world)
	var controller = load("res://scripts/worlds/world_pickup_controller.gd").new()
	root.add_child(controller)
	check(controller.has_method("activate_local"), "shared pickup controller supports explicit trusted offline activation")
	if not controller.has_method("activate_local"):
		controller.free(); world.free(); finish(); return
	var item = RigidBody3D.new()
	item.name = "CupFixture"
	var shape = CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	item.add_child(shape)
	world.add_child(item)
	item.position = Vector3(0, 1, -1)
	item.freeze = true
	var home = item.transform
	var anchor = Node3D.new()
	world.add_child(anchor)
	anchor.position = Vector3(0, 1, -0.8)
	var second = Node3D.new()
	world.add_child(second)
	second.position = anchor.position
	var toggles: Array = []
	controller.activate_local(world, {"cup": item}, {"switch": {"node": item, "action": func(): toggles.append(true)}})
	await physics_frame
	check(controller.request_grab("cup", "virtual", anchor), "desktop grip picks up without relay/auth/lease")
	check(controller.held_by_local("virtual") and item.collision_layer == 0, "held object disables collision with player")
	check(not controller.request_grab("cup", "left", second), "same item cannot be held twice")
	anchor.position.x += 0.15
	controller._process(0.016)
	check(item.global_position.is_equal_approx(anchor.global_position), "held item follows grip")
	check(controller.release_grip("virtual"), "desktop drop succeeds offline")
	check(not controller.held_by_local("virtual") and item.collision_layer == 1, "drop restores collision")
	check(item.linear_velocity == Vector3.ZERO and item.angular_velocity == Vector3.ZERO, "drop has bounded zero throw velocity")
	check(controller.request_grab("cup", "left", second), "synthetic VR left grip uses same service")
	controller.cancel_local_input()
	check(not controller.held_by_local("left"), "menu/focus cancellation releases held item")
	check(not controller.request_grab("missing", "right", anchor), "unknown item rejected")
	anchor.position = Vector3(10, 1, 0)
	check(not controller.request_grab("cup", "right", anchor), "out-of-reach item rejected")
	anchor.position = Vector3(0, 1, 1)
	var wall = StaticBody3D.new()
	var wall_shape = CollisionShape3D.new()
	wall_shape.shape = BoxShape3D.new()
	wall.add_child(wall_shape)
	world.add_child(wall)
	wall.position = Vector3(0, 1, 0)
	await physics_frame
	check(not controller.request_grab("cup", "right", anchor), "wall blocks pickup")
	check(not controller.activate_nearest(anchor, 2), "wall blocks activation")
	wall.queue_free()
	await physics_frame
	anchor.position = item.position + Vector3(0, 0, 0.2)
	check(controller.activate_nearest(anchor, 0.3) and toggles.size() == 1, "reachable switch activates once offline")
	check(controller.reset_local_item("cup") and item.transform.is_equal_approx(home), "explicit item reset restores own home")
	# Restore the near hand after reset rather than assuming item remained carried.
	anchor.position = item.position + Vector3(0, 0, 0.2)
	check(controller.request_grab("cup", "right", anchor), "synthetic VR right grip picks up")
	anchor.queue_free()
	await process_frame
	controller._process(0.016)
	check(not controller.held_by_local("right"), "lost hand releases item safely")
	controller.reset()
	check(controller.items.is_empty() and controller.anchors.is_empty(), "scene reset clears local item/anchor references")
	controller.activate(world, {"entities": {"cup": {"path": "CupFixture", "pickup": true}}}, "remote")
	check(not controller.request_grab("cup", "virtual", second), "downloaded-world activation does not grant offline authority")
	check(not controller.local_only and controller.local_actions.is_empty(), "remote activation clears local actions and authority")
	controller.reset()
	controller.free()
	world.free()
	await process_frame
	finish()

func finish():
	print("Welcome interactions: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)
