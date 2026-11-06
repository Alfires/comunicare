extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	if ok: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)
func run():
	root.set_meta("home_action_hints", false)
	var player = CharacterBody3D.new(); player.add_to_group("player"); root.add_child(player)
	var identity = player.get_instance_id()
	for cycle in 3:
		change_scene_to_file("res://scenes/world.tscn")
		await process_frame; await process_frame; await physics_frame
		var world = current_scene
		check(player.get_instance_id() == identity and get_nodes_in_group("player").size() == 1 and player.position == Vector3(0,1,0), "home entry preserves player at middle: " + str(cycle))
		var kitchen = world.get_node("Island/House/Kitchen")
		var lights = world.get_node("Island/House/RoomLighting")
		check(kitchen.items.size() == 8 and kitchen.items.values().all(func(item): return item.get_node_or_null("AuthoredModel") != null), "complete premade kitchenware available without help")
		lights.set_zone("Kitchen", false, 0.5, "warm")
		kitchen.set_faucet(true); kitchen.set_heat(2); kitchen.reset_kitchen()
		check(not kitchen.water.visible and kitchen.heat_level == 0 and lights.zones.Kitchen.light.light_energy == 0, "kitchen reset does not change lighting ownership")
		var ship = world.get_node("PondShip"); ship.set_physics_process(false)
		player.position = Vector3(16, 0.1, 23)
		check(ship.board(player), "ship available with Help/highlights disabled")
		ship.drive(Vector2.ZERO, false); ship.drive(Vector2(0, 1), false)
		for tick in 20: ship.step(1.0/60)
		ship.return_to_dock()
		check(not player.has_meta("home_ship") and player.velocity == Vector3.ZERO, "ship reset clears rider before world transition")
		check(not root.get_meta("home_action_hints"), "home never forces hints back on")
	player.queue_free(); current_scene.queue_free(); await process_frame; await process_frame
	print("Welcome layout: %s passed, %s failed (combined home acceptance)" % [passed, failed]); quit(1 if failed else 0)
