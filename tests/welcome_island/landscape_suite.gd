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
	await preload("res://streaming_wait.gd").complete(current_scene)
	var world = current_scene
	var landscape = world.get_node_or_null("Island/Landscape")
	check(landscape != null, "island has original composed landscape rather than bare graybox")
	if landscape == null:
		world.queue_free(); await process_frame; finish(); return
	check(landscape.get_node("Trees").get_child_count() >= 20, "grove and side destinations have trees")
	var species := {}
	for tree in landscape.get_node("Trees").get_children(): species[tree.get_meta("species", "unknown")] = true
	check(species.has("pine") and species.has("fir"), "landscape mixes distinct realistic pine and fir silhouettes")
	check(landscape.has_node("Understory") and landscape.get_node("Understory").get_child_count() >= 30, "planted clusters include bounded fern understory and stumps")
	check(landscape.get_node("Rocks").get_child_count() >= 16, "shore and underside have individual authored rocks")
	var collision_ok := true
	var hit_count := 0
	for stone in landscape.get_node("Rocks").get_children():
		var reference = stone.get_meta("rock_collision", null)
		if not reference is WeakRef or not is_instance_valid(reference.get_ref()):
			collision_ok = false; continue
		var body = reference.get_ref()
		collision_ok = collision_ok and body.global_transform == Transform3D.IDENTITY and body.get_child(0).shape is ConvexPolygonShape3D
		var points: PackedVector3Array = body.get_child(0).shape.points
		var center = Vector3.ZERO
		for point in points: center += point
		center /= points.size()
		var query = PhysicsRayQueryParameters3D.create(center + Vector3.UP*25, center-Vector3.UP*25)
		var hit = world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == body: hit_count += 1
	check(collision_ok, "tilted rocks have unscaled world-aligned convex collision")
	check(hit_count >= 8, "physics rays hit visible rim rocks rather than passing through them")
	var tilted := 0
	for stone in landscape.get_node("Rocks").get_children():
		if absf(stone.rotation.x) + absf(stone.rotation.z) > 0.12: tilted += 1
	check(tilted >= 30, "stones have varied settled pitch and roll instead of identical upright poses")
	var ground_details = landscape.get_node_or_null("GroundDetails")
	var grass = landscape.get_node_or_null("MeadowGrass")
	check(grass is MultiMeshInstance3D and grass.multimesh.visible_instance_count > 500 and grass.multimesh.instance_count <= 3200, "short meadow grass uses one bounded shared multimesh")
	check(ground_details != null and ground_details.get_child_count() >= 50 and ground_details.get_child_count() <= 180, "bounded low planting and stone clusters fill open meadow pockets")
	if ground_details != null:
		check(ground_details.get_children().all(func(node): return landscape._planting_clear(node.position)), "new meadow accents preserve routes and destination clearances")
		check(ground_details.get_children().all(func(node): return node.position == landscape._detail_point(int(node.get_meta("placement")))), "meadow composition is deterministic across stream ordering")
	check(landscape.get_node("EdgeBorders").get_child_count() >= 12, "perimeter has readable protective borders")
	check(landscape.get_node_or_null("Roots") != null, "overhanging roots connect trees to floating rock strata")
	check(landscape.get_node_or_null("ShoreDetails") != null, "pond has composed shoreline detail beyond bare terrain")
	if landscape.has_node("Roots"):
		check(landscape.get_node("Roots").get_child_count() >= 12, "root detail has bounded authored branches")
	if landscape.has_node("ShoreDetails"):
		check(landscape.get_node("ShoreDetails").get_child_count() >= 12, "shoreline has bounded rock and plant placements")
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
		var views = {"spawn": [Vector3(0, 1.7, 0), Vector3(-20, 2, -25)], "overview": [Vector3(48, 46, 58), Vector3.ZERO], "grove": [Vector3(-8, 3, -22), Vector3(0, 2, -36)], "underside": [Vector3(65, -20, 70), Vector3(0, -10, 0)]}
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
