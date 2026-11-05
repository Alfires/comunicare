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
	for name in ["LeftBench", "LeftCushions", "PicnicTable", "ShoreBench", "HerbBedOne", "HerbBedTwo"]:
		check(world.get_node_or_null("Island/" + name) != null, "side spaces include " + name)
	var body = CharacterBody3D.new(); root.add_child(body)
	var safety = load("res://scripts/player/vr_safety.gd").new()
	for point in [Vector3(24, 0.05, -12), Vector3(24, 0.05, -18), Vector3(20, 0.05, -21), Vector3(26, 0.05, -21), Vector3(29, 0.05, -23), Vector3(-29, 0.05, -12), Vector3(35, 0.05, 0)]:
		check(safety.clearance(body, point, 1.9, 0.35), "standing/seated-route capsule clearance: " + str(point))
	var shape = CollisionShape3D.new(); shape.shape = CapsuleShape3D.new(); shape.shape.radius = 0.35; shape.shape.height = 1.9
	shape.position.y = 0.95; body.add_child(shape)
	body.position = Vector3(24, 0.05, -10)
	for frame in 120:
		body.velocity = Vector3(0, -1, -4); body.move_and_slide(); await physics_frame
	check(body.position.z < -17 and body.position.y > -0.1, "physics capsule enters house through accessible flush doorway")
	check(not safety.clearance(body, Vector3(16, 0.05, -20), 1.9, 0.35), "wall negative control blocks capsule")
	check(house.find_children("*", "Label3D", true, false).is_empty(), "house contains no tutorial labels")
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
