extends SceneTree

var passed := 0
var failed := 0
const WORLD = "https://worlds.example/startup.cne"

func _initialize():
	call_deferred("run")

func check(ok: bool, name: String):
	if ok:
		passed += 1
		print("PASS: ", name)
	else:
		failed += 1
		print("FAIL: ", name)

func browser() -> Control:
	var scene = load("res://scenes/GUI/world_explorer.tscn").instantiate()
	scene.set_script(load("res://fixtures/startup_world_explorer.gd"))
	root.add_child(scene)
	return scene

func run():
	var handler = root.get_node("NetworkHandler")
	check(handler.get_script().resource_path == "res://scripts/multiplayer/network_handler.gd",
		"startup tests use the real NetworkHandler autoload, not a fake")
	var scene = browser()
	check(scene.catalog_requested and scene.catalog_callback_ready,
		"real ready connects catalog callback before requesting data")
	check(scene.discovery_peer == null and scene.status.text == "Relay disconnected",
		"real ready safely opens browser before a peer exists")
	check(scene.world_listing.get_child_count() == 1, "startup renders home without HTTP or relay")
	scene.create_world_info_menue({"url": "default_wold"})
	scene.get_node("WorldInfo/Back").pressed.emit()
	check(not scene.info.visible and scene.get_node("VBoxContainer").visible,
		"real ready wires Back button")
	scene.create_world_info_menue({"url": "default_wold"})
	scene.reset.emit()
	check(scene.selected_url.is_empty() and not scene.info.visible, "real ready wires menu reset")
	scene.free()

	var waiting = RelayPeer.new()
	handler.peer = waiting
	scene = browser()
	check(scene.discovery_peer == waiting and scene.status.text == "Connecting to relay…" and not scene.refreshing,
		"startup attaches an unconnected peer without sending discovery")
	check(waiting.on_public_session.is_connected(scene.load_sessions) and waiting.connected.is_connected(scene._on_reload_pressed),
		"real startup subscribes to discovery and connection signals")
	scene._attach_peer()
	check(waiting.on_public_session.get_connections().size() == 1,
		"reattaching does not duplicate discovery subscriptions")
	var replacement = RelayPeer.new()
	handler.peer = replacement
	scene._process(0)
	check(scene.discovery_peer == replacement and waiting.on_public_session.get_connections().is_empty(),
		"process attaches replacement peer and unsubscribes old peer")
	waiting.on_public_session.emit([{"session_id": "stale", "mode": 0, "world_url": WORLD}])
	check(scene.instances.is_empty(), "old peer cannot repopulate browser after replacement")
	scene.free()
	check(replacement.on_public_session.get_connections().is_empty()
		and replacement.connected.get_connections().is_empty()
		and replacement.on_disconnected_from_relay.get_connections().is_empty(),
		"closing browser removes every discovery lifecycle subscription")
	handler.peer = null

	await test_live_startup(handler)
	print("\nDiscovery startup: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func pump(relay: Node, rounds: int = 25):
	for index in rounds:
		relay.handle_events()
		await create_timer(0.005).timeout

func test_live_startup(handler: Node):
	var relay = load("res://scripts/multiplayer/relay.gd").new()
	relay.connection = ENetConnection.new()
	var error = relay.connection.create_host_bound("127.0.0.1", 0)
	check(error == OK, "startup integration binds loopback relay")
	if error != OK:
		relay.free()
		return
	handler.relay_port = relay.connection.get_local_port()
	var scene = browser()
	# Exercise the real create_peer coroutine and real autoload _process polling.
	handler.create_peer()
	await pump(relay)
	check(handler.peer.is_connected_to_relay and scene.discovery_peer == handler.peer,
		"browser opened before real create_peer follows the new live connection")
	check(not scene.refreshing and scene.status.text.is_empty(),
		"connection triggers real discovery request and empty response without showing totals")
	handler.create_session(WORLD)
	await pump(relay)
	check(not handler.current_session_id.is_empty(), "real startup hosting records acknowledged session identity")
	scene.get_node("VBoxContainer/HBoxContainer/reload").pressed.emit()
	await pump(relay)
	check(scene.instances.size() == 1 and not scene.refreshing, "scene Reload button retrieves actual hosted instance")
	scene.create_world_info_menue({"url": WORLD})
	check(scene.instance_list.get_child_count() == 1 and not scene.instance_list.get_child(0).has_meta("session_id"),
		"real autoload identity hides own hosted instance after actual discovery")
	var connected_peer = handler.peer
	scene.free()
	scene = browser()
	check(scene.discovery_peer == connected_peer and scene.refreshing,
		"opening browser with an already-connected peer immediately requests discovery")
	await pump(relay)
	check(scene.instances.size() == 1 and connected_peer.on_public_session.get_connections().size() == 1,
		"reopening receives discovery once without duplicate callbacks")
	# Model a silent relay: expire the UI timer without a ten-second sleep.
	scene._on_reload_pressed()
	scene.refresh_started = Time.get_ticks_msec() - 10001
	scene._process(0)
	check(scene.instances.is_empty() and scene.refreshing and "timed out" in scene.status.text,
		"discovery timeout clears stale rows while keeping one request outstanding")
	await pump(relay)
	check(scene.instances.size() == 1 and not scene.refreshing, "late reliable discovery response recovers after timeout")
	connected_peer.peer.peer_disconnect()
	connected_peer.disconnected_from_relay()
	check(scene.instances.is_empty() and scene.status.text == "Relay disconnected"
		and handler.current_session_id.is_empty(), "disconnect clears actual autoload identity and browser state")
	handler.peer = null
	scene._process(0)
	check(scene.discovery_peer == null, "browser safely detaches when real autoload clears its peer")
	scene.free()
	connected_peer.connection.destroy()
	relay.connection.destroy()
	relay.free()
