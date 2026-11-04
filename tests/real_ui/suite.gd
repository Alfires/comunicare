extends SceneTree
## Production autoloads/scenes; real TLS/ENet. Signal-level actions labelled as such.
var passed := 0
var failed := 0
var service
var relay
var host
var menu
var browser
var timeline: Array = []
var elapsed := 0.0

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	timeline.append({"at_ms": Time.get_ticks_msec(), "passed": value, "check": title})
	if value: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func _process(delta):
	elapsed += delta
	if service != null: service.poll()
	if relay != null: relay.handle_events()
	if host != null and host.connection != null: host.handle_events()
	if elapsed > 75: print("UI watchdog expired"); quit(2)
	return false

func wait_until(predicate: Callable, seconds: float = 5.0) -> bool:
	var until = Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < until: await process_frame
	return predicate.call()

func button(node: Node, title: String):
	for child in node.find_children("*", "Button", true, false):
		if child.text == title: return child
	return null

func screenshot(name: String):
	if DisplayServer.get_name() == "headless": return
	# Focus/resize can suspend drawing on desktop backends. Never await a draw
	# signal without a timeout and turn a test screenshot into an infinite hang.
	await create_timer(0.15).timeout
	if not root.get_texture().get_image().is_empty():
		root.get_texture().get_image().save_png("user://" + name + ".png")

func run():
	root.size = Vector2i(1000, 700)
	# Exact built-in scene bytes still determine the hash, but renderer-independent
	# activation uses a trusted empty shell to avoid this world's SubViewport/Jolt
	# teardown leaks obscuring the UI membership regression. Explicit fixture boundary.
	var shell = Node3D.new()
	shell.name = "UITestWorld"
	var packed = PackedScene.new()
	packed.pack(shell)
	shell.free()
	ResourceLoader.load("res://scenes/world.tscn")
	packed.take_over_path("res://scenes/world.tscn")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var save = root.get_node("SaveData")
	check(save.load_acount(), "production account initializes only in disposable user directory")
	save.store.set_value("network.lan_discovery", false)
	var network = root.get_node("NetworkHandler")
	var private_key = Crypto.new().generate_rsa(2048)
	var cert = Crypto.new().generate_self_signed_certificate(private_key, "CN=comunicare-relay,O=Comunicare,C=DE", "20250101000000", "20350101000000")
	service = load("res://scripts/multiplayer/federation/relay_directory_service.gd").new()
	check(service.start(private_key, cert), "real UI fixture starts TLS origin")
	relay = load("res://scripts/multiplayer/relay.gd").new()
	relay.connection = ENetConnection.new()
	check(relay.connection.create_host_bound("127.0.0.1", 0) == OK, "real UI fixture starts ENet origin")
	service.set_gameplay_port(relay.connection.get_local_port())
	host = RelayPeer.new()
	host.account_key = Crypto.new().generate_rsa(2048)
	host.connect_to_relay("127.0.0.1", relay.connection.get_local_port())
	check(await wait_until(func(): return host.is_authenticated), "real host account authenticates")
	host.expected_world_revision = root.get_node("DataLoader").built_in_world_revision()
	host.create_session(0, "Real UI room", "", "default_wold")
	check(await wait_until(func(): return not host.current_session_id.is_empty()), "real host publishes instance")
	service.set_local_instances([{"origin_relay_id": service.relay_id, "origin_boot_id": service.boot_id, "instance_id": host.current_session_id,
		"world_url": "default_wold", "world_revision": host.expected_world_revision, "mode": 0, "name": "Real UI room", "description": "", "player_count": 1}])
	var directory = network.get_directory_browser()
	directory.add_trusted("127.0.0.1", service.local_port, service.relay_id, cert)
	directory.query(service.relay_id)
	check(await wait_until(func(): return directory.instances().size() == 1), "production directory client receives verified actual instance")
	menu = load("res://scenes/GUI/menue.tscn").instantiate()
	root.add_child(menu)
	menu.current_tab = 2
	browser = menu.get_node("world_explorer")
	# External catalog request is cancelled, not a substituted UI script/autoload.
	# Only loopback networking is part of this deterministic acceptance scenario.
	browser.http_request.cancel_request()
	browser._merge_relay_instances()
	browser.create_world_info_menue({"url": "default_wold"})
	await process_frame
	check(browser.get_script().resource_path == "res://scripts/GUI/world_explorer.gd", "actual production World Explorer is mounted in full menu")
	var join = button(browser.instance_list, "Join")
	check(join != null, "verified federated instance has a real UI Join button")
	if join != null: join.pressed.emit()
	check(await wait_until(func(): return network.current_session_id == host.current_session_id and not network.session_busy), "signal-level real Join callback activates acknowledged instance through actual coordinator")
	var original = network.current_session_id
	check(relay.sessions[0][0].peers.size() == 2, "origin sees both admitted accounts after UI join")
	menu.current_tab = 3
	var settings = menu.get_node("settings_menue")
	settings.select_category("Network")
	var panel
	for node in settings.category_pages.Network.get_children():
		if node.get_script() != null and node.get_script().resource_path.ends_with("relay_preferences_panel.gd"): panel = node
	check(panel != null, "real Settings Network mounts actual preferences panel")
	await screenshot("network-before-edit")
	panel.label_input.text = "Unrelated fallback"
	panel.host_input.text = "127.0.0.1"
	panel.port_input.value = 19998
	button(panel, "Add relay").pressed.emit()
	await process_frame
	check(network.current_session_id == original and network.peer.is_authenticated and network.gameplay_tunnel != null,
		"adding unrelated relay through actual Settings preserves live federated membership")
	var preferences = network.get_relay_preferences()
	var added: Dictionary = preferences.snapshot().entries.back()
	preferences.move_entry(added.entry_id, 0)
	await process_frame
	check(network.current_session_id == original, "reordering preferences preserves live federated membership")
	preferences.remove_entry(added.entry_id)
	await process_frame
	check(network.current_session_id == original, "removing unrelated fallback preserves live federated membership")
	preferences.set_blocked(service.relay_id, true)
	await process_frame
	check(network.current_session_id.is_empty() and not network.peer.is_connected_to_relay, "blocking active origin still disconnects immediately")
	await test_pointer_navigation(settings)
	# Connection timing is independent from directory refresh timing: no null
	# dereference or directory timeout while the browser has no peer yet.
	var old_peer = network.peer
	network.peer = null
	browser._attach_peer()
	browser.refreshing = true
	browser.connecting = true
	browser.refresh_started = Time.get_ticks_msec() - 11000
	browser._process(0)
	check(browser.connecting and not browser.legacy_timed_out, "offline connection wait is not treated as a directory timeout")
	browser.connecting = false
	browser.refreshing = false
	network.peer = old_peer
	await screenshot("network-after-edit")
	await cleanup(network)
	var file = FileAccess.open("user://ui-timeline.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(timeline, "  "))
	file.close()
	print("\nReal UI acceptance: %s passed, %s failed; display=%s" % [passed, failed, DisplayServer.get_name()])
	print("Signal-level membership edits plus hit-tested Network navigation; no two-window gameplay/soak claim.")
	quit(1 if failed else 0)

func test_pointer_navigation(settings):
	menu.current_tab = 3
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for dimensions in [Vector2i(640, 480), Vector2i(1000, 700)]:
		root.size = dimensions
		settings.select_category("Assets")
		await process_frame
		await process_frame
		var control: Control = settings.category_buttons.Network
		var logical = control.get_global_rect().get_center()
		var physical = root.get_final_transform() * logical
		for pressed in [true, false]:
			var event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = physical
			event.global_position = physical
			event.pressed = pressed
			Input.parse_input_event(event)
			await process_frame
		check(settings.selected_category == "Network", "hit-tested pointer selects real Network tab at " + str(dimensions))
		await screenshot("network-pointer-%sx%s" % [dimensions.x, dimensions.y])

func cleanup(network):
	if menu != null: menu.queue_free()
	if network.gameplay_tunnel != null: network.gameplay_tunnel.close(); network.gameplay_tunnel = null
	if network.peer != null:
		if network.peer.connection != null: network.peer.connection.destroy(); network.peer.connection = null
		network.peer.disconnected_from_relay()
	if network.directory_browser != null: network.directory_browser.stop()
	if network.lan_discovery != null: network.lan_discovery.stop()
	host.connection.destroy()
	host.connection = null
	service.stop()
	service = null
	relay.connection.destroy()
	relay.free()
	relay = null
	if current_scene != null: current_scene.queue_free()
	await process_frame
	await process_frame
