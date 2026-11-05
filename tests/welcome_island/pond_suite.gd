extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	if ok: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)
func run():
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await physics_frame
	await physics_frame
	var world = current_scene
	var pond = world.get_node_or_null("Island/PondWater")
	check(pond != null, "island contains bounded pond water")
	if pond == null:
		world.queue_free(); await process_frame; finish(); return
	check(world.get_node_or_null("Island/DockDeck") != null, "accessible physical dock replaces reserve")
	check(pond.get_meta("teleport_disabled", false), "water explicitly disallows teleport landings")
	var body = CharacterBody3D.new()
	var player_shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.9
	player_shape.shape = capsule
	player_shape.position.y = 0.95
	body.add_child(player_shape)
	root.add_child(body)
	body.add_to_group("player")
	body.position = Vector3(23, 0, 23)
	var safety = load("res://scripts/player/vr_safety.gd").new()
	check(safety.destination(body, Vector3(23, 3, 23), Vector3.DOWN, 1.9, 0.35).is_empty(), "production teleport ray rejects water surface")
	var space = world.get_world_3d().direct_space_state
	var bed = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(23, -1, 23), Vector3(23, -5, 23), 1, [pond.get_rid()]))
	check(not bed.is_empty() and bed.position.y < -1.5, "pond has sealed physical bed beneath water")
	var ship_clear := true
	for index in 24:
		var angle = index * TAU / 24
		var point = Vector3(25 + cos(angle) * 6, -0.8, 23 + sin(angle) * 6)
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point - Vector3.UP * 4, 1))
		if hit.is_empty() or hit.position.y > -1.2: ship_clear = false
	check(ship_clear, "central pond reserves a clear twelve-metre ship turning area")
	var dry := true
	for index in 72:
		var angle = index * TAU / 72
		var point = Vector3(23 + cos(angle) * 17, 4, 23 + sin(angle) * 15)
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point - Vector3.UP * 8, 1))
		if hit.is_empty() or absf(hit.position.y) > 0.1: dry = false
	check(dry, "continuous dry shoreline perimeter stays on same island")
	var dock_clear := true
	for index in 17:
		var point = Vector3(9 + index * 0.5, 3, 23)
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point - Vector3.UP * 6, 1))
		if hit.is_empty() or absf(hit.position.y) > 0.1: dock_clear = false
	check(dock_clear, "level dock extends from dry bank over pond")
	var dock_start = Vector3(8.5, 0.05, 23)
	body.position = dock_start
	for frame in 115:
		body.velocity = Vector3(4, -1, 0)
		body.move_and_slide()
		await physics_frame
	check(body.position.x > 15.5 and body.position.x < 17 and body.position.y > -0.1,
		"physical player walks from bank to dock end without falling or reset")
	var surface = pond.get_node_or_null("Surface")
	check(surface != null and surface.mesh is ArrayMesh, "water uses shore-clipped surface instead of cylinder side wall")
	check(surface != null and surface.material_override is ShaderMaterial,
		"water uses restrained world-space ripple finish")
	check(world.has_method("recover_from_pond"), "water recovery uses trusted shared reset")
	if world.has_method("recover_from_pond"):
		for index in 3:
			body.position = Vector3(23, -1, 23)
			body.velocity = Vector3(1, -5, 1)
			world.recover_from_pond(body)
			await process_frame
			check(body.position == Vector3(9, 1, 23) and body.velocity == Vector3.ZERO, "safe stopped bank recovery: " + str(index))
		var wall = StaticBody3D.new()
		var shape = CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		wall.add_child(shape); world.add_child(wall)
		wall.position = Vector3(9, 1, 23)
		await physics_frame
		world.recover_from_pond(body)
		await process_frame
		check(body.position == Vector3(0, 1, 0), "blocked bank recovery falls back to center spawn")
		wall.queue_free()
		await physics_frame
		body.position = Vector3(23, -0.8, 23)
		for frame in 6: await physics_frame
		check(body.position == Vector3(9, 1, 23), "real water Area body entry triggers recovery without manual callback")
		for frame in 6: await physics_frame
		check(body.position == Vector3(9, 1, 23), "bank recovery remains outside water without repeated reset loop")
	if OS.get_environment("ISLAND_LAYOUT_RENDERED") == "1":
		var camera = Camera3D.new(); world.add_child(camera)
		camera.look_at_from_position(Vector3(4, 8, 38), Vector3(23, -0.5, 23))
		await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("/tmp/opencode/island-pond.png") == OK, "rendered pond/dock screenshot captured")
	body.queue_free(); world.queue_free()
	await process_frame; await process_frame
	finish()
func finish():
	print("Welcome layout: %s passed, %s failed (pond)" % [passed, failed])
	quit(1 if failed else 0)
