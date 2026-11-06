extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	if ok: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)
func run():
	var start = Time.get_ticks_msec()
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame; await physics_frame; await physics_frame
	var world = current_scene
	var landscape = world.get_node_or_null("Island/Landscape")
	check(landscape != null, "island has original composed landscape rather than bare graybox")
	if landscape == null:
		world.queue_free(); await process_frame; finish(); return
	check(landscape.get_node("Trees").get_child_count() >= 20, "grove and side destinations have trees")
	check(landscape.get_node("Rocks").get_child_count() >= 16, "shore and underside have individual authored rocks")
	check(landscape.get_node("EdgeBorders").get_child_count() >= 12, "perimeter has readable protective borders")
	var underside = world.get_node_or_null("Island/RockUnderside")
	check(underside != null and underside.mesh is ArrayMesh, "island underside is an authored irregular mesh, not a primitive cone")
	if underside != null:
		var arrays = underside.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var finite := true
		for point in vertices:
			if not point.is_finite(): finite = false
		check(vertices.size() > 200 and finite, "underside has bounded finite sculpted geometry")
	check(landscape.get_node("Trees").find_children("*", "MeshInstance3D", true, false).all(func(node): return node.visibility_range_end > 0), "tree visibility range bounded")
	check(world.find_children("*", "OmniLight3D", true, false).filter(func(light): return light.shadow_enabled).size() <= 2, "at most two shadowed local lights")
	check(world.find_children("*", "Label3D", true, false).is_empty(), "finished scene has no tutorial billboards")
	var floor_hit = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 3, 0), Vector3(0, -3, 0)))
	check(not floor_hit.is_empty() and absf(floor_hit.position.y) < 0.1, "landscaping preserves center spawn floor")
	print("LOAD METRIC: ", Time.get_ticks_msec() - start, " ms (includes test frame waits)")
	if OS.get_environment("ISLAND_LAYOUT_RENDERED") == "1":
		var camera = Camera3D.new(); world.add_child(camera)
		var views = {"spawn": [Vector3(0, 1.7, 0), Vector3(-20, 2, -25)], "overview": [Vector3(65, 70, 80), Vector3.ZERO], "grove": [Vector3(-8, 3, -22), Vector3(0, 2, -36)], "underside": [Vector3(65, -20, 70), Vector3(0, -10, 0)]}
		for name in views:
			camera.look_at_from_position(views[name][0], views[name][1])
			for frame in 10: await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("/tmp/opencode/island-landscape-" + name + ".png") == OK, "rendered composition: " + name)
			print("RENDER METRIC ", name, ": draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			var frames: Array[float] = []
			for sample in 60:
				var start_us = Time.get_ticks_usec()
				await process_frame
				frames.append((Time.get_ticks_usec() - start_us) / 1000.0)
			frames.sort()
			print("FRAME METRIC ", name, ": median_ms=", frames[30], " p95_ms=", frames[56], " video_bytes=", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	world.queue_free(); await process_frame; await process_frame
	finish()
func finish():
	print("Welcome layout: %s passed, %s failed (landscape)" % [passed, failed]); quit(1 if failed else 0)
