extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	if ok: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func ground(world: Node3D, point: Vector3) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 8, point - Vector3.UP * 8, 1))

func clear_capsule(world: Node3D, point: Vector3) -> bool:
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.9
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.transform.origin = point + Vector3.UP * 1.05
	return world.get_world_3d().direct_space_state.intersect_shape(query).is_empty()

func run():
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await physics_frame
	await physics_frame
	var world = current_scene
	var layout = world.get_node_or_null("Island")
	check(layout != null, "built-in world contains authored island layout")
	if layout == null:
		# Legacy viewport panel has known resource cycles; detach before test exit.
		var panel = world.get_node_or_null("VRPanel")
		if panel: panel.get_node("MeshInstance3D").material_override = null
		world.queue_free()
		await process_frame
		finish(); return
	check(FileAccess.get_file_as_string("res://scenes/world.tscn").contains('uid="uid://c84iaxk0m0ws"'), "built-in scene UID preserved")
	check(layout.get_node("Spawn").position.distance_to(Vector3(0, 1, 0)) < 0.01, "spawn stays at center and legacy staging height")
	check(layout.get_node("Landmass").get_child_count() == 1, "one connected landmass collision, not detached playable platforms")
	# Flood-fill real walkable physics samples: counts alone cannot prove topology.
	var walkable := {}
	for x in range(-48, 49, 4):
		for z in range(-48, 49, 4):
			var floor_hit = ground(world, Vector3(x, 0, z))
			if not floor_hit.is_empty() and floor_hit.normal.dot(Vector3.UP) > 0.9:
				walkable[Vector2i(x, z)] = true
	var visited := {Vector2i.ZERO: true}
	var pending: Array[Vector2i] = [Vector2i.ZERO]
	while not pending.is_empty():
		var cell = pending.pop_back()
		for direction in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4)]:
			var next: Vector2i = cell + direction
			if walkable.has(next) and not visited.has(next):
				visited[next] = true
				pending.append(next)
	check(visited.size() == walkable.size() and walkable.size() > 400, "physics flood-fill finds one large connected walkable island")
	var hit = ground(world, Vector3.ZERO)
	check(not hit.is_empty() and hit.normal.dot(Vector3.UP) > 0.99 and absf(hit.position.y) < 0.02, "center spawn is dry level ground")
	check(clear_capsule(world, Vector3.ZERO), "spawn has standing capsule clearance")
	check(ground(world, Vector3(23, 0, 23)).position.y < -1.5, "pond footprint reserved as recessed dry basin")
	check(layout.find_children("*", "Label3D", true, false).is_empty(), "graybox has no in-world tutorial labels")
	var endpoints = {"House": Vector3(24, 0, -18), "LeftDeck": Vector3(-29, 0, -12), "RightGarden": Vector3(35, 0, 0), "Pond": Vector3(23, 0, 23), "Dock": Vector3(9, 0, 23), "Grove": Vector3(0, 0, -33), "Picnic": Vector3(-24, 0, 17)}
	for name in endpoints:
		var marker = layout.get_node_or_null("Places/" + name)
		check(marker != null and marker.position.distance_to(endpoints[name]) < 0.1, "reserved destination: " + name)
	# Test the actual declared routes by dense physics sampling, not marker presence.
	for name in layout.routes:
		var points: Array = layout.routes[name]
		var safe := true
		var previous := Vector3.ZERO
		for endpoint in points:
			var distance = previous.distance_to(endpoint)
			for step in range(ceili(distance / 0.5) + 1):
				var point = previous.lerp(endpoint, minf(step * 0.5 / maxf(distance, 0.01), 1))
				for offset in [-1.5, 0.0, 1.5]:
					var sample = point + Vector3(offset, 0, 0)
					var floor_hit = ground(world, sample)
					if floor_hit.is_empty() or floor_hit.normal.dot(Vector3.UP) < cos(deg_to_rad(15)) or absf(floor_hit.position.y) > 0.1 or not clear_capsule(world, sample): safe = false
			previous = endpoint
		check(safe, "broad connected dry route / synthetic teleport clearance: " + name)
	check(not clear_capsule(world, Vector3(23, 0, -27)), "negative control: house wall blocks capsule")
	check(ground(world, Vector3(80, 0, 0)).is_empty(), "negative control: space beyond island is not a platform")
	# A physical capsule walks the routes at 4 m/s, not just raycasts at destinations.
	var walker = CharacterBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.9
	collision.shape = shape
	walker.add_child(collision)
	root.add_child(walker)
	for name in layout.routes:
		walker.position = Vector3(0, 1, 0)
		var reached := true
		for target in layout.routes[name]:
			var goal: Vector3 = target + Vector3.UP
			for tick in 2000:
				if Vector2(walker.position.x - goal.x, walker.position.z - goal.z).length() < 0.2: break
				var direction = (goal - walker.position); direction.y = 0
				walker.velocity = direction.normalized() * 4 + Vector3.DOWN
				walker.move_and_slide()
				await physics_frame
			if walker.position.distance_to(goal) > 0.4: reached = false
		check(reached, "physics capsule traverses route: " + name)
	walker.queue_free()
	if OS.get_environment("ISLAND_LAYOUT_RENDERED") == "1":
		var camera = Camera3D.new()
		camera.fov = 45
		world.add_child(camera)
		for view in {"overview": [Vector3(82, 85, 95), Vector3.ZERO], "center": [Vector3(0, 1.7, 0), Vector3(24, 1, -18)], "left": [Vector3(-40, 9, 20), Vector3.ZERO], "right": [Vector3(42, 12, 36), Vector3(15, 0, 0)]}:
			var poses = {"overview": [Vector3(82, 85, 95), Vector3.ZERO], "center": [Vector3(0, 1.7, 0), Vector3(24, 1, -18)], "left": [Vector3(-40, 9, 20), Vector3.ZERO], "right": [Vector3(42, 12, 36), Vector3(15, 0, 0)]}
			camera.look_at_from_position(poses[view][0], poses[view][1])
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("/tmp/opencode/island-layout-" + view + ".png") == OK, "rendered composition view: " + view)
	world.queue_free()
	await process_frame
	await process_frame
	finish()

func finish():
	print("Welcome layout: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)
