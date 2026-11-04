extends SceneTree
## One actual client process: production UI, HTTP staged world and actual input.
var role := ""
var shared := ""
var port := 0
var url := ""
var menu
var passed := 0
var failed := 0

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	if value: passed += 1; print("PASS: ", role, ": ", title)
	else: failed += 1; print("FAIL: ", role, ": ", title)

func write_state(name: String, value: Variant):
	var file = FileAccess.open(shared.path_join(name + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func read_state(name: String) -> Variant:
	var path = shared.path_join(name + ".json")
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null

func wait_for(predicate: Callable, seconds: float = 10.0) -> bool:
	var deadline = Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await create_timer(0.01).timeout
	return predicate.call()

func click(control: Control):
	await process_frame
	await process_frame
	var point = root.get_final_transform() * control.get_global_rect().get_center()
	print("INPUT: ", role, " ", control.text, " rect=", control.get_global_rect(), " point=", point, " visible=", control.is_visible_in_tree(), " disabled=", control.disabled)
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func run():
	var args = OS.get_cmdline_user_args()
	role = args[0]
	shared = args[1]
	port = int(args[2])
	url = args[3]
	root.size = Vector2i(900, 650)
	var save = root.get_node("SaveData")
	check(save.load_acount(), "isolated production account initialized")
	save.data.default_avatar = ""
	var profile_fields: Dictionary = save.profile.local.duplicate(true)
	profile_fields["profile.avatar_url"] = url.get_base_dir() + "/no-avatar.vrm"
	save.profile.save_profile(save.profile.get_local_fingerprint(), profile_fields)
	save.store.set_value("cache.allow_http", true)
	save.store.set_value("network.lan_discovery", false)
	var network = root.get_node("NetworkHandler")
	var preferences = network.get_relay_preferences()
	for entry in preferences.snapshot().entries: preferences.remove_entry(entry.entry_id)
	preferences.add_entry({"entry_id": "test", "label": "Loopback relay", "host": "127.0.0.1", "port": port, "relay_id": ""})
	check(await network.create_peer(), "actual client authenticated to separate relay process")
	menu = load("res://scenes/GUI/menue.tscn").instantiate()
	root.add_child(menu)
	menu.current_tab = 2
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var browser = menu.get_node("world_explorer")
	if role == "host":
		browser.create_world_info_menue({"url": url})
		await process_frame
		await click(browser.get_node("WorldInfo/Create"))
		check(await wait_for(func(): return not network.current_session_id.is_empty() and not network.session_busy), "hit-tested Create stages actual world via loopback HTTP")
		write_state("session", {"id": network.current_session_id})
	else:
		check(await wait_for(func(): return read_state("session") != null), "other client created actual instance")
		browser._on_reload_pressed()
		check(await wait_for(func(): return browser.instances.size() > 0), "real UI directory receives hosted instance")
		browser.create_world_info_menue({"url": url})
		await process_frame
		var join
		for control in browser.instance_list.find_children("*", "Button", true, false):
			if control.text == "Join": join = control; break
		check(join != null, "real UI exposes Join for downloaded example world")
		if join != null: await click(join)
		check(await wait_for(func(): return not network.current_session_id.is_empty() and not network.session_busy), "hit-tested Join activates exact HTTP world revision")
		print("JOIN_STATE: ", role, " status=", browser.status.text, " error=", network.last_session_error, " busy=", network.session_busy, " refresh=", browser.refreshing)
	var world = current_scene
	check(world != null and world.get_node_or_null("PickupCube") != null, "actual example scene installed in this client process")
	if world == null or world.get_node_or_null("PickupCube") == null:
		finish()
		return
	var camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(3, 3, 5)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.current = true
	menu.hide()
	var pickups = root.get_node("DataLoader").get_world_pickups()
	var cube = world.get_node("PickupCube")
	if role == "host":
		check(await wait_for(func(): return network.peer.session_peers.size() == 1), "second real client is admitted to same instance")
		var hand = Node3D.new()
		world.add_child(hand)
		hand.global_position = cube.global_position + Vector3(0, 0.1, 0)
		check(pickups.request_grab("pickup-cube", "virtual", hand), "production pickup adapter requests actual loaded cube")
		check(await wait_for(func(): return pickups.held_by_local("virtual")), "origin acknowledges exclusive actual cube lease")
		hand.position = Vector3(1, 1.5, 0)
		write_state("moved", true)
		check(await wait_for(func(): return read_state("observed") != null), "other actual client observed held cube movement")
		check(pickups.release_grip("virtual"), "drop uses production relay path")
		write_state("released", true)
		await create_timer(0.3).timeout
	else:
		check(await wait_for(func(): return read_state("moved") != null), "host performed pickup and movement")
		check(await wait_for(func(): return cube.freeze and cube.global_position.distance_to(Vector3(1, 1.5, 0)) < 0.1), "second rendered scene cube follows first client's network grip")
		if DisplayServer.get_name() != "headless":
			await create_timer(0.1).timeout
			var image = root.get_texture().get_image()
			image.save_png(shared.path_join("remote-held-cube.png"))
		write_state("observed", true)
		check(await wait_for(func(): return read_state("released") != null and not cube.freeze), "remote drop restores cube physics")
	finish()

func finish():
	write_state(role + "-result", {"passed": passed, "failed": failed})
	var network = root.get_node("NetworkHandler")
	if network.peer != null:
		if network.peer.peer != null: network.peer.peer.peer_disconnect()
		await create_timer(0.2).timeout
		if network.peer.connection != null: network.peer.connection.destroy(); network.peer.connection = null
	if menu != null: menu.queue_free()
	if current_scene != null: current_scene.queue_free()
	if network.directory_browser != null: network.directory_browser.stop()
	if network.lan_discovery != null: network.lan_discovery.stop()
	if is_instance_valid(network.animation_controller): network.animation_controller.queue_free(); network.animation_controller = null
	await process_frame
	await process_frame
	print("Two client UI result: ", role, " passed=", passed, " failed=", failed)
	quit(1 if failed else 0)
