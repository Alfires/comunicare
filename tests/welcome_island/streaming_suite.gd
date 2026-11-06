extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	if ok: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)
func run():
	var start = Time.get_ticks_usec()
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world); current_scene = world
	var island = world.get_node("Island")
	check(island.get_node_or_null("Landmass/ContinuousTerrain") != null, "continuous terrain available synchronously")
	check(island.get_node_or_null("House") == null, "house does not block scene entry")
	check(island.get_node("Landscape/Trees").get_child_count() == 0, "vegetation does not block scene entry")
	print("STREAM ENTRY ms=", (Time.get_ticks_usec()-start)/1000.0)
	check(island.get_node_or_null("Streaming") != null, "home owns bounded streaming scheduler")
	var scheduler = island.get_node("Streaming")
	var landscape = island.get_node("Landscape")
	landscape._meadow_grass()
	var grass = landscape.get_node("MeadowGrass")
	check(grass.multimesh.visible_instance_count == 0, "grass setup does not build all 3200 placements in one callback")
	check(landscape.get("grass_cursor") == 0, "grass placement starts as resumable work")
	landscape._grass_batch()
	check(landscape.grass_cursor == 96 and grass.multimesh.visible_instance_count <= 96, "one grass slice evaluates no more than 96 candidates")
	scheduler.set_process(false)
	scheduler.jobs.clear()
	var order: Array = []
	scheduler.enqueue(Vector3(100, 0, 0), [], func(): order.append("far"))
	scheduler.enqueue(Vector3(3, 0, 0), [], func(): order.append("near"))
	scheduler._process(0)
	check(order == ["near"] and scheduler.jobs.size() == 1, "nearest job first and one attachment per frame")
	scheduler._process(0)
	check(order == ["near"], "distant scenery stays deferred")
	var player = Node3D.new(); root.add_child(player); player.add_to_group("player"); player.position.x = 100
	scheduler._process(0)
	check(order == ["near", "far"], "movement or teleport reprioritizes deferred scenery")
	player.queue_free()
	world.queue_free(); await process_frame; await process_frame
	check(get_nodes_in_group("home_kitchen").is_empty(), "removed world never attaches late kitchen")
	world = load("res://scenes/world.tscn").instantiate(); root.add_child(world); current_scene = world
	island = world.get_node("Island"); scheduler = island.streaming; scheduler.load_all = true
	var deadline = Time.get_ticks_msec() + 30000
	var bounded := true
	var max_attachment := 0
	while (not scheduler.jobs.is_empty() or not island.home_loaded) and Time.get_ticks_msec() < deadline:
		await process_frame
		bounded = bounded and scheduler.pending.size() <= scheduler.MAX_REQUESTS
		max_attachment = maxi(max_attachment, scheduler.last_attachment_usec)
	check(bounded, "threaded resource requests remain bounded")
	check(island.home_loaded and scheduler.jobs.is_empty() and scheduler.failed.is_empty(), "all queued content completes without asset failures")
	check(island.get_node("Landscape").get("grass_cursor") == 3200, "bounded grass jobs finish every deterministic candidate")
	check(world.get_node_or_null("PondShip") != null and world.local_pickups != null, "delayed kitchen and boat interactions register")
	print("STREAM COMPLETE ms=", (Time.get_ticks_usec()-start)/1000.0)
	print("STREAM MAX scheduler callback ms=", max_attachment/1000.0, " (excludes yielded house stages and GPU uploads)")
	world.queue_free(); await process_frame; await process_frame
	print("Welcome layout: %s passed, %s failed (streaming)" % [passed, failed]); quit(1 if failed else 0)
