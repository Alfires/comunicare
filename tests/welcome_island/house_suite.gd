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
	var house = world.get_node_or_null("Island/House")
	check(house != null, "house replaces three-wall reserve")
	if house == null:
		world.queue_free(); await process_frame; finish(); return
	for name in ["BedOne", "BedTwo", "Sofa", "LowTable", "KitchenReserve", "Porch", "Roof"]:
		check(house.get_node_or_null(NodePath(name)) != null, "house contains " + name)
	var exterior = house.get_node_or_null("AuthoredExterior")
	check(exterior != null, "house uses a cleared textured architectural asset instead of visible box walls")
	if exterior != null:
		check(exterior.find_children("*", "MeshInstance3D", true, false).size() > 20,
			"architectural asset retains roof/window/porch details")
		var foundation = exterior.find_children("*foundation*", "MeshInstance3D", true, false)
		check(foundation.all(func(mesh): return not mesh.visible), "imported raised foundation cannot overlap accessible app-owned floor")
	check(house.get_node("Sofa").get_meta("style_source", "") == "polyhaven.sofa_02", "lounge seating matches realistic material style")
	check(house.get_node("LowTable").get_meta("style_source", "") == "polyhaven.coffee_table_round_01", "table uses compatible realistic asset")
	check(house.get_node("BedOne").get_meta("style_source", "") == "polyhaven.vintage_day_bed", "resting furniture uses consistent realistic textured source")
	for name in ["LeftBench", "LeftCushions", "PicnicTable", "ShoreBench", "HerbBedOne", "HerbBedTwo"]:
		check(world.get_node_or_null("Island/" + name) != null, "side spaces include " + name)
	var body = CharacterBody3D.new(); root.add_child(body)
	var safety = load("res://scripts/player/vr_safety.gd").new()
	for point in [Vector3(24, 0.05, -12), Vector3(24, 0.05, -18), Vector3(20, 0.05, -21), Vector3(26, 0.05, -21), Vector3(29, 0.05, -23), Vector3(-29, 0.05, -12), Vector3(35, 0.05, 0)]:
		check(safety.clearance(body, point, 1.9, 0.35), "standing/seated-route capsule clearance: " + str(point))
	var shape = CollisionShape3D.new(); shape.shape = CapsuleShape3D.new(); shape.shape.radius = 0.35; shape.shape.height = 1.9
	shape.position.y = 0.95; body.add_child(shape)
	var test_roof = StaticBody3D.new()
	var roof_shape = CollisionShape3D.new()
	var roof_box = BoxShape3D.new()
	roof_box.size = Vector3(4, 0.2, 4)
	roof_shape.shape = roof_box
	test_roof.add_child(roof_shape)
	world.add_child(test_roof)
	test_roof.position = Vector3(0, 2.5, 0)
	shape.shape.height = 3.0
	shape.position.y = 1.5
	await physics_frame
	check(not house._rest_clear(body, Vector3(0, 0.1, 0)), "rest clearance uses enlarged player's real capsule under ceiling")
	shape.shape.height = 1.9
	shape.position.y = 0.95
	test_roof.queue_free()
	await physics_frame
	body.position = Vector3(24, 0.05, -10)
	for frame in 120:
		body.velocity = Vector3(0, -1, -4); body.move_and_slide(); await physics_frame
	check(body.position.z < -17 and body.position.y > -0.1, "physics capsule enters house through accessible flush doorway")
	check(not safety.clearance(body, house.to_global(Vector3(house.get_node("LeftWall").position.x, 0.05, 0)), 1.9, 0.35), "wall negative control blocks capsule")
	check(house.find_children("*", "Label3D", true, false).is_empty(), "house contains no tutorial labels")
	var details = house.get_node_or_null("ArchitecturalDetailCollision")
	check(details != null, "visible window and porch details have matching static collision")
	if details != null:
		check(details.find_children("*", "CollisionShape3D", true, false).size() > 8, "architectural detail collision covers several visible fixtures")
	# Collision wall planes must remain within 25 cm of the rendered house shell.
	var shell = house.get_node("AuthoredExterior").find_children("*hollow*", "MeshInstance3D", true, false)
	check(not shell.is_empty(), "adapted rendered wall shell remains inspectable")
	if not shell.is_empty():
		var rendered_bounds: AABB = house.global_transform.affine_inverse() * shell[0].global_transform * shell[0].mesh.get_aabb()
		for mesh in shell:
			rendered_bounds = rendered_bounds.merge(house.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb())
		check(absf(rendered_bounds.position.x - house.get_node("LeftWall").position.x) < 0.25 and absf(rendered_bounds.end.x - house.get_node("RightWall").position.x) < 0.25,
			"side collision walls align with visible architectural shell")
	check(house.has_method("rest_at"), "resting furniture supports deliberate rest/leave actions")
	if house.has_method("rest_at"):
		body.add_to_group("player")
		var head = Node3D.new(); body.add_child(head); head.position = Vector3(0.2, 1.6, -0.1)
		var tracked = head.transform
		body.position = Vector3.ZERO
		check(not house.rest_at("BedOne", body), "rest rejects distant user")
		body.global_position = house.get_node("BedOne").global_position + Vector3(0, 0.05, 2)
		var original_process = body.is_physics_processing()
		check(house.rest_at("BedOne", body), "explicit nearby bed rest succeeds")
		check(head.transform == tracked and not body.is_physics_processing(), "rest preserves tracked pose while suppressing synthetic walking")
		check(house.leave_rest(body) and body.is_physics_processing() == original_process, "leave rest restores movement at validated exit")
		check(not body.has_meta("home_rest"), "leaving rest clears owner reference")
		body.global_position = house.get_node("BedOne").global_position + Vector3(0, 0.05, 2)
		house.rest_at("BedOne", body)
		var blocker = StaticBody3D.new(); world.add_child(blocker)
		var blocked_shape = CollisionShape3D.new(); blocked_shape.shape = BoxShape3D.new()
		blocked_shape.shape.size = Vector3(1, 2, 1); blocker.add_child(blocked_shape)
		blocker.global_position = house.get_node("BedOne").global_position + Vector3(0, 1, 2)
		await physics_frame
		check(house.leave_rest(body) and body.global_position == Vector3(0,1,0), "blocked rest exit uses clear center fallback")
		blocker.queue_free(); await physics_frame
		body.global_position = house.get_node("BedOne").global_position + Vector3(0, 0.05, 2)
		check(house.rest_at("BedOne", body) and not house.rest_at("BedTwo", body), "rest cannot attach the same user twice")
		world.return_player_to_spawn(body)
		check(not body.has_meta("home_rest") and body.global_position == Vector3(0,1,0), "return home releases rest before resetting spawn")
	if OS.get_environment("ISLAND_LAYOUT_RENDERED") == "1":
		var camera = Camera3D.new(); world.add_child(camera)
		var views = {"outside": [Vector3(10, 9, -3), Vector3(24, 1, -20)], "inside": [Vector3(24, 1.7, -14), Vector3(24, 1, -24)], "left": [Vector3(-38, 5, -3), Vector3(-29, 0.5, -12)]}
		for name in views:
			camera.look_at_from_position(views[name][0], views[name][1]); await process_frame; await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("/tmp/opencode/island-house-" + name + ".png") == OK, "rendered furnished space: " + name)
	body.queue_free(); world.queue_free(); await process_frame; await process_frame
	finish()
func finish():
	print("Welcome layout: %s passed, %s failed (house)" % [passed, failed])
	quit(1 if failed else 0)
