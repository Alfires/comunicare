extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	if ok: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)
func run():
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame; await physics_frame; await physics_frame
	var world = current_scene
	var ship = world.get_node_or_null("PondShip")
	check(ship != null, "working ship exists beside dock")
	if ship == null:
		world.queue_free(); await process_frame; finish(); return
	ship.set_physics_process(false)
	var rider = CharacterBody3D.new(); root.add_child(rider); rider.add_to_group("player")
	var head = Node3D.new(); rider.add_child(head); head.position = Vector3(0.2, 1.7, 0.1)
	var tracking = head.transform
	rider.position = Vector3(0, 1, 0)
	check(not ship.board(rider), "boarding rejects distant player")
	rider.position = Vector3(16, 0.1, 23)
	check(ship.board(rider), "explicit nearby boarding succeeds offline")
	check(not ship.board(rider), "double boarding rejected")
	ship.drive(Vector2.ONE, false)
	check(ship.speed == 0, "boarding requires neutral movement before propulsion")
	var yaw = rider.rotation.y
	var before = ship.position
	ship.drive(Vector2.ZERO, false)
	ship.drive(Vector2(0.5, 1), false)
	for frame in 60: ship.step(1.0 / 60)
	check(ship.position.distance_to(before) > 0.1 and ship.speed <= 1.5, "throttle moves real ship within speed limit")
	check(rider.position.distance_to(ship.position + Vector3(0, 0.8, 0)) < 0.01, "rider follows supported ship position")
	check(head.transform == tracking and rider.rotation.y == yaw, "turning never rotates tracked head or rider view")
	ship.drive(Vector2(0, INF), false)
	check(ship.speed == 0, "nonfinite input stops safely")
	ship.drive(Vector2.ONE, true)
	check(ship.speed == 0, "menu/focus suppression stops movement")
	check(not ship.disembark(), "disembark rejected away from dock")
	ship.position = Vector3(40, 9, 40); ship.rotation = Vector3(1, 2, 1)
	ship.return_to_dock()
	check(ship.position == ship.BERTH and ship.rotation == Vector3.ZERO and ship.speed == 0, "stranded or overturned ship resets to berth")
	check(rider.position == Vector3(9, 1, 23) and not rider.has_meta("home_ship"), "reset safely releases rider to bank")
	rider.position = Vector3(16, 0.1, 23); ship.board(rider)
	check(ship.disembark(), "dock disembark succeeds")
	var wall = StaticBody3D.new(); world.add_child(wall)
	var blocked_shape = CollisionShape3D.new(); blocked_shape.shape = BoxShape3D.new(); wall.add_child(blocked_shape)
	wall.position = Vector3(9, 1, 23)
	await physics_frame
	rider.position = Vector3(16, 0.1, 23)
	check(not ship.board(rider), "blocked recovery location rejects boarding")
	wall.queue_free(); await physics_frame
	rider.position = Vector3(16, 0.1, 23); ship.board(rider)
	wall = StaticBody3D.new(); world.add_child(wall)
	blocked_shape = CollisionShape3D.new(); blocked_shape.shape = BoxShape3D.new(); wall.add_child(blocked_shape)
	wall.position = Vector3(9, 1, 23)
	await physics_frame
	check(not ship.disembark(), "disembark rejects bank obstructed after boarding")
	ship.return_to_dock()
	check(rider.position == Vector3(0, 1, 0), "blocked-bank reset uses center fallback")
	wall.queue_free(); await physics_frame
	rider.position = Vector3(16, 0.1, 23); ship.board(rider)
	ship.drive(Vector2.ZERO, false)
	ship.drive(Vector2(0, 1), false)
	for frame in 1500: ship.step(1.0 / 60)
	check(Vector2((ship.position.x - 23) / 1.15, ship.position.z - 23).length() <= 8.5, "shore containment bounds prolonged input")
	ship.return_to_dock()
	rider.position = Vector3(16, 0.1, 23); ship.board(rider)
	ship.drive(Vector2.ZERO, false); ship.drive(Vector2(0, 1), false)
	ship._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(ship.speed == 0 and ship.input_rearm, "focus-loss notification stops and rearms ship")
	ship.return_to_dock()
	if OS.get_environment("ISLAND_LAYOUT_RENDERED") == "1":
		var camera = Camera3D.new(); world.add_child(camera)
		camera.look_at_from_position(Vector3(13, 4, 29), ship.position)
		await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("/tmp/opencode/island-ship.png") == OK, "rendered ship/dock captured")
	rider.queue_free(); world.queue_free(); await process_frame; await process_frame
	finish()
func finish():
	print("Welcome layout: %s passed, %s failed (ship)" % [passed, failed])
	quit(1 if failed else 0)
