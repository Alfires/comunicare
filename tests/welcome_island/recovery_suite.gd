extends SceneTree
var passed := 0
var failed := 0
class PlayerProbe extends CharacterBody3D:
	var calls := 0
	func set_player_pos(value: Vector3):
		calls += 1
		global_position = value
		velocity = Vector3.ZERO

func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	if ok: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func run():
	var player = PlayerProbe.new()
	player.add_to_group("player")
	root.add_child(player)
	var head = Node3D.new()
	head.position = Vector3(0.2, 1.7, -0.1)
	head.rotation.y = 0.3
	player.add_child(head)
	var tracking = head.transform
	player.position = Vector3(30, 40, 10)
	player.velocity = Vector3(3, -12, 1)
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	await preload("res://streaming_wait.gd").complete(current_scene)
	var world = current_scene
	check(player.position == Vector3(0, 1, 0) and player.velocity == Vector3.ZERO, "direct home load applies shared spawn and clears player motion")
	check(world.has_method("return_player_to_spawn"), "home exposes trusted return-to-spawn action")
	check(world.has_method("register_recoverable"), "home exposes item recovery registration")
	if world.has_method("register_recoverable"):
		var item = RigidBody3D.new()
		world.add_child(item)
		var home = Transform3D(Basis.from_euler(Vector3(0, 0.4, 0)), Vector3(-4, 2, 3))
		check(world.register_recoverable(item, home), "item home registered separately from player spawn")
		for index in 3:
			player.position = Vector3(10, -40, 2)
			player.velocity = Vector3(5, -10, 4)
			world._on_area_3d_body_entered(player)
			await process_frame
			check(player.position == Vector3(0, 1, 0) and player.velocity == Vector3.ZERO, "fall recovery clears motion: " + str(index))
			check(head.transform == tracking, "fall recovery preserves tracked local head transform: " + str(index))
		item.position = Vector3(10, -40, 4)
		item.linear_velocity = Vector3(1, 2, 3)
		item.angular_velocity = Vector3(2, 3, 4)
		world._on_area_3d_body_entered(item)
		await process_frame
		check(item.transform.is_equal_approx(home), "lost item returns to its own home, not player head")
		check(item.linear_velocity == Vector3.ZERO and item.angular_velocity == Vector3.ZERO, "item recovery clears linear and angular velocity")
		var unknown = RigidBody3D.new()
		world.add_child(unknown)
		unknown.position = Vector3(20, -40, 20)
		world._on_area_3d_body_entered(unknown)
		await process_frame
		check(not is_instance_valid(unknown), "unregistered lost bodies removed instead of spawning at player's head")
		check(not world.register_recoverable(item, Transform3D(Basis.IDENTITY, Vector3(INF, 0, 0))), "nonfinite item homes rejected")
		var item_id = item.get_instance_id()
		item.queue_free()
		await process_frame
		check(not world.recoverable_homes.has(item_id), "deleted items leave no recovery reference")
		world.return_player_to_spawn(player)
		check(get_nodes_in_group("player").size() == 1 and player.get_parent() == root, "menu-style return preserves one root player")
	var contract_path = "res://scripts/worlds/welcome_island/home_contract.gd"
	check(ResourceLoader.exists(contract_path), "shared spawn/revision contract exists")
	if ResourceLoader.exists(contract_path):
		var contract = load(contract_path)
		var revision = contract.revision()
		check(revision.length() == 64 and contract.revision() == revision, "built-in revision deterministic")
		var path = "res://scripts/worlds/welcome_island/layout.gd"
		var original = FileAccess.get_file_as_string(path)
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(original + "\n# revision test fixture\n")
		file.close()
		check(contract.revision() != revision, "script dependency edit changes built-in revision")
		file = FileAccess.open(path, FileAccess.WRITE); file.store_string(original); file.close()
		file = FileAccess.open("res://unrelated.txt", FileAccess.WRITE); file.store_string("unrelated"); file.close()
		check(contract.revision() == revision, "unrelated file does not change revision")
		path = "res://scenes/worlds/welcome_island/layout.tscn"
		original = FileAccess.get_file_as_string(path)
		file = FileAccess.open(path, FileAccess.WRITE); file.store_string(original + "\n"); file.close()
		check(contract.revision() != revision, "subscene edit changes built-in revision")
		file = FileAccess.open(path, FileAccess.WRITE); file.store_string(original); file.close()
		path = "res://assets/welcome_island/textures/sparse_grass/sparse_grass_diff_1k.jpg"
		var bytes = FileAccess.get_file_as_bytes(path)
		file = FileAccess.open(path, FileAccess.WRITE); file.store_buffer(bytes + PackedByteArray([0])); file.close()
		check(contract.revision() != revision, "shipped texture edit changes built-in revision")
		file = FileAccess.open(path, FileAccess.WRITE); file.store_buffer(bytes); file.close()
	if OS.get_environment("ISLAND_LAYOUT_RENDERED") == "1":
		var camera = Camera3D.new()
		player.add_child(camera)
		camera.position = Vector3(0, 0.7, 0)
		camera.rotation_degrees.y = -45
		for index in 3:
			player.position = Vector3(2, -40, 0)
			player.velocity = Vector3(2, -10, 0)
			world._on_area_3d_body_entered(player)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			check(player.position == Vector3(0, 1, 0) and player.velocity == Vector3.ZERO,
				"rendered repeated recovery returns stopped camera root: " + str(index))
		check(root.get_texture().get_image().save_png("/tmp/opencode/island-recovery.png") == OK,
			"rendered recovery screenshot saved")
	player.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	print("Welcome layout: %s passed, %s failed (recovery)" % [passed, failed])
	quit(1 if failed else 0)
