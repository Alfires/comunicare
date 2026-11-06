extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	if ok: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)
func run():
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame; await process_frame; await physics_frame
	var world = current_scene
	var kitchen = world.get_node_or_null("Island/House/Kitchen")
	check(kitchen != null, "usable kitchen replaces reserved counter")
	if kitchen == null:
		world.queue_free(); await process_frame; finish(); return
	check(kitchen.items.size() == 8, "eight exact movable kitchen belongings")
	var anchor = Node3D.new(); world.add_child(anchor)
	for id in kitchen.items:
		var item = kitchen.items[id]
		check(item is RigidBody3D and item.mass <= 1 and item.mass > 0, "bounded physical kitchenware: " + id)
		check(item.get_node_or_null("AuthoredModel") != null, "kitchenware uses premade geometry rather than primitive placeholders: " + id)
		var home: Transform3D = kitchen.homes[id]
		anchor.global_position = item.global_position + Vector3(0, 0.2, 0)
		check(world.local_pickups.request_grab(id, "virtual", anchor), "shared offline pickup: " + id)
		anchor.position.x -= 0.1; world.local_pickups._process(0.016)
		check(world.local_pickups.release_grip("virtual"), "shared offline drop: " + id)
		check(world.local_pickups.reset_local_item(id) and item.global_transform.is_equal_approx(home), "own-home reset: " + id)
	check(kitchen.set_faucet(true) and kitchen.water.visible, "faucet changes visible water")
	check(kitchen.set_heat(2) and kitchen.heat_level == 2 and kitchen.hob.visible, "hob high changes visible state")
	check(not kitchen.set_heat(3), "invalid heat rejected")
	check(kitchen.set_heat(1) and kitchen.hob.visible, "hob low visible")
	check(kitchen.set_storage(true) and kitchen.storage_open, "storage door opens")
	check(kitchen.set_storage(false) and not kitchen.storage_open, "storage door closes within bounds")
	var blocker = StaticBody3D.new(); world.add_child(blocker)
	var block_shape = CollisionShape3D.new(); block_shape.shape = BoxShape3D.new(); block_shape.shape.size = Vector3(0.3, 0.5, 0.3)
	blocker.add_child(block_shape); blocker.global_position = kitchen.get_parent().to_global(Vector3(5.5, 0.4, -4.2))
	await physics_frame
	check(not kitchen.set_storage(true), "storage motion rejects an obstructed door path")
	blocker.queue_free(); await physics_frame
	check(kitchen.set_fridge(true) and kitchen.fridge_open, "fridge storage opens visibly")
	check(kitchen.set_fridge(false) and not kitchen.fridge_open, "fridge storage closes within bounds")
	# Real prop resting must be stable, not only successful service calls.
	var plate = kitchen.items["kitchen.Plate"]
	for frame in 60: await physics_frame
	check(plate.global_position.y > kitchen.global_position.y + 0.85 and plate.linear_velocity.length() < 0.5,
		"placed kitchenware settles on counter without falling or violent motion")
	kitchen.reset_kitchen()
	check(not kitchen.water.visible and not kitchen.hob.visible and kitchen.heat_level == 0, "reset shuts down water and heat")
	check(world.local_pickups.local_actions.has("kitchen.faucet") and world.local_pickups.local_actions.has("kitchen.fridge"), "kitchen supports existing reachable-world activation path")
	if OS.get_environment("ISLAND_LAYOUT_RENDERED") == "1":
		kitchen.set_faucet(true); kitchen.set_heat(1)
		var camera = Camera3D.new(); world.add_child(camera)
		camera.look_at_from_position(Vector3(27, 2.3, -17), Vector3(30, 1, -23))
		await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("/tmp/opencode/island-kitchen.png") == OK, "rendered working kitchen captured")
	anchor.queue_free()
	kitchen.set_faucet(true); kitchen.set_heat(2)
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame; await process_frame
	var fresh = current_scene.get_node("Island/House/Kitchen")
	check(not fresh.water.visible and fresh.heat_level == 0 and fresh.items.size() == 8, "reload shuts down old appliances and restores complete inventory")
	current_scene.queue_free(); await process_frame; await process_frame
	print("Welcome layout: %s passed, %s failed (kitchen)" % [passed, failed]); quit(1 if failed else 0)
func finish():
	print("Welcome layout: %s passed, %s failed (kitchen)" % [passed, failed]); quit(1 if failed else 0)
