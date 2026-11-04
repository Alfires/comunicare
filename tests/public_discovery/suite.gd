extends SceneTree

const WORLD_A = "https://worlds.example/park.cne?version=1"
const WORLD_B = "https://worlds.example/park.cne?version=2"
const PUBLIC = 0
var passed := 0
var failed := 0
var network: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, name: String, detail: String = "") -> void:
	if ok:
		passed += 1
		print("PASS: ", name)
	else:
		failed += 1
		print("FAIL: ", name, " — ", detail)

func session(id: String, url: String = WORLD_A, mode: int = PUBLIC) -> Dictionary:
	return {
		"session_id": id, "world_url": url, "mode": mode,
		"name": "Room " + id, "description": "Test instance",
		"owners": [1], "peers": [1, 2],
	}

func catalog_world(url: String, title: String = "Park") -> Dictionary:
	return {"url": url, "name": title, "description": "Test world", "iamges": []}

func explorer(catalog: Array = []) -> Control:
	var scene = load("res://scenes/GUI/world_explorer.tscn").instantiate()
	scene.set_script(load("res://fixtures/world_explorer.gd"))
	root.add_child(scene)
	scene.worlds_list = catalog.duplicate(true)
	return scene

func buttons(node: Node) -> Array:
	var found: Array = []
	if node is Button and not node.is_queued_for_deletion():
		found.append(node)
	for child in node.get_children():
		if not child.is_queued_for_deletion():
			found.append_array(buttons(child))
	return found

func cards(scene: Node) -> Array:
	return buttons(scene.world_listing)

func rows(node: Node) -> Array:
	var found: Array = []
	if node.has_meta("session_id") and not node.is_queued_for_deletion():
		found.append(node)
	for child in node.get_children():
		if not child.is_queued_for_deletion():
			found.append_array(rows(child))
	return found

func row_ids(scene: Node) -> Array:
	var ids: Array = []
	for row in rows(scene):
		ids.append(row.get_meta("session_id"))
	ids.sort()
	return ids

func open_first_world(scene: Node):
	var world_cards = cards(scene)
	if not world_cards.is_empty():
		world_cards[0].pressed.emit()

func make_relay() -> Node:
	# Do not add to the tree: _ready() would open the real relay port.
	return load("res://scripts/multiplayer/relay.gd").new()

func run() -> void:
	network = root.get_node("NetworkHandler")
	test_protocol_and_relay_filter()
	test_relay_lifecycle()
	test_unknown_worlds()
	test_instance_submenu()
	test_hide_current_instance_and_total()
	test_refresh()
	test_visibility_and_validation()
	test_catalog_race()
	test_join_selected_instance()
	test_relay_join_rules()
	await test_real_coordinator()
	await test_transition_failures()
	await test_loopback_relay()
	await test_real_loader()
	print("\nDiscovery contracts: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func test_hide_current_instance_and_total():
	network.current_session_id = "alice"
	var scene = explorer([catalog_world(WORLD_A)])
	scene.load_sessions([session("alice"), session("bob")])
	check(scene.status.text.is_empty(), "discovery menu does not display a public-instance total")
	open_first_world(scene)
	check(row_ids(scene) == ["bob"], "current instance is hidden while other instances of the same world remain visible")
	scene.load_sessions([session("alice")])
	check(rows(scene).is_empty() and cards(scene).size() == 2,
		"own instance alone produces no instance row without hiding its world")
	network.current_session_id = ""
	scene.load_sessions([session("alice")])
	check(row_ids(scene) == ["alice"], "instance becomes visible again after leaving it")
	scene.free()

func test_protocol_and_relay_filter():
	var relay = make_relay()
	for mode in range(5):
		relay.sessions.append([session("mode-%d" % mode, WORLD_A, mode)])
	var public_sessions = relay.get_public_session()
	check(public_sessions.size() == 1 and public_sessions[0].session_id == "mode-0",
		"relay returns PUBLIC only (not PRIVAT/FRIENDS/FRIENDSP/REQUEST)")
	var decoded = GetPublicSessions.create_from_data(GetPublicSessions.create(public_sessions).encode())
	check(decoded.sessions == public_sessions, "public discovery packet round-trips session identities and URLs")
	check(not public_sessions[0].has("peers") and not public_sessions[0].has("owners"),
		"discovery sends a public summary, not internal membership IDs", "peers/owners leaked")
	relay.free()

func test_relay_lifecycle():
	var relay = make_relay()
	relay.sessions = [[session("occupied")]]
	# ENetPacketPeer is abstract; obtain an unserviced local connection handle.
	# No server is started and no event loop/packets are serviced.
	var connection = ENetConnection.new()
	connection.create_host(1)
	var peer = connection.connect_to_host("127.0.0.1", 9)
	relay.peer_connected(peer)
	check(relay.get_user_in_session(peer.get_meta("id")) == -1,
		"connecting to relay does not auto-join another person's instance", "new peer was inserted into first session")
	relay.free()
	connection.destroy()

	relay = make_relay()
	var current = session("current")
	current.peers = [7]
	relay.sessions = [[current]]
	relay.on_packed(7, JoinSession.create("missing").encode())
	check(relay.get_user_in_session(7) != -1,
		"joining a vanished instance preserves current membership", "current instance removed before target validation")
	relay.free()

	relay = make_relay()
	var empty = session("empty")
	empty.peers = []
	relay.sessions = [[empty]]
	check(relay.get_public_session().is_empty(),
		"empty instances are not discoverable", "empty public instance advertised")
	relay.free()

func test_unknown_worlds():
	var scene = explorer()
	scene.load_sessions([session("alice"), session("bob"), session("carol", WORLD_B)])
	check(cards(scene).size() == 3,
		"uncatalogued public URLs appear, grouped once per URL, plus built-in home",
		"expected Park v1, Park v2 and home; got %d cards" % cards(scene).size())
	scene.free()

func test_relay_join_rules():
	var relay = load("res://fixtures/recording_relay.gd").new()
	relay.authenticate_peer(7, Crypto.new().generate_rsa(2048).save_to_string(true))
	var old = session("old")
	old.peers = [7]
	var target = session("target", WORLD_B)
	relay.sessions = [[old], [target]]
	relay.on_packed(7, JoinSession.create("target", WORLD_A).encode())
	check(not relay.results.back().success and relay.get_user_in_session(7) == 0,
		"relay rejects changed world URL before leaving old room")
	target.mode = PacketInfo.MODE.PRIVAT
	relay.on_packed(7, JoinSession.create("target", WORLD_B).encode())
	check(not relay.results.back().success and relay.get_user_in_session(7) == 0,
		"knowing a private room ID does not authorize joining")
	target.mode = PUBLIC
	relay.on_packed(7, JoinSession.create("target", WORLD_B).encode())
	check(relay.results.back().success and relay.sessions.size() == 1 \
		and relay.sessions[0][0].session_id == "target" and 7 in target.peers,
		"successful join survives removal of old room before target index")
	relay.on_packed(7, JoinSession.create("target", WORLD_B).encode())
	check(target.peers.count(7) == 1, "rejoining current instance does not duplicate membership")
	var info = {"mode": PUBLIC, "name": "Hosted", "description": "Test", "world_url": WORLD_A}
	relay.on_packed(7, CreateSession.create(info).encode())
	check(relay.get_user_in_session(7) == 1 and not 7 in target.peers \
		and relay.results.back().world_url == WORLD_A, "hosting switches membership once and advertises actual URL")
	info.world_url = "file:///invalid"
	relay.on_packed(7, CreateSession.create(info).encode())
	check(not relay.results.back().success and relay.sessions.size() == 2,
		"invalid creation metadata does not disturb membership")
	relay.free()

func coordinator() -> Node:
	var node = load("res://scripts/multiplayer/network_handler.gd").new()
	var fake = load("res://fixtures/relay_peer.gd").new()
	node.peer = fake
	fake.session_result.connect(node._on_session_result)
	fake.on_disconnected_from_relay.connect(node._on_relay_disconnected)
	root.add_child(node)
	return node

func test_real_coordinator():
	var loader = root.get_node("DataLoader")
	loader.activated = 0
	loader.loaded_urls.clear()
	var node = coordinator()
	var result: bool = await node.join_session("bob", WORLD_A)
	check(result and node.current_session_id == "bob" and node.peer.sent_joins == ["bob"] \
		and node.peer.sent_creates.is_empty() and loader.loaded_urls == [WORLD_A] and loader.activated == 1,
		"real coordinator stages world, joins acknowledged ID and never hosts")
	node.peer.accepted = false
	result = await node.join_session("rejected", WORLD_B)
	check(not result and node.current_session_id == "bob" and loader.activated == 1,
		"join rejection preserves active world and session")
	loader.fail_prepare = true
	result = await node.join_session("broken-world", WORLD_B)
	check(not result and node.peer.sent_joins.size() == 2,
		"failed world preparation sends no join request")
	loader.fail_prepare = false
	node.peer.accepted = true
	result = await node.host_world(WORLD_B)
	check(result and node.peer.sent_creates.size() == 1 and node.peer.sent_creates[0].url == WORLD_B,
		"explicit hosting creates exactly one instance with the selected URL")
	await process_frame
	node.free()

	node = coordinator()
	node.peer.auto_respond = false
	var completed: Array = []
	_capture_join(node, completed)
	var second: bool = await node.join_session("second", WORLD_B)
	check(not second and node.peer.sent_joins == ["waiting"], "concurrent joins are rejected")
	check(loader.activated == 2, "world activation waits for matching acknowledgement")
	node._on_session_result({"operation": "join", "session_id": "wrong", "success": true, "world_url": WORLD_A})
	check(completed.is_empty(), "unrelated join acknowledgement is ignored")
	node.peer.disconnected_from_relay()
	check(completed == [false] and node.current_session_id.is_empty(), "disconnect cancels a pending join")
	await process_frame
	node.free()

func test_transition_failures():
	var loader = root.get_node("DataLoader")
	var node = coordinator()
	loader.fail_activate = true
	var result: bool = await node.join_session("activation-failure", WORLD_A)
	check(not result and not node.peer.is_connected_to_relay and node.current_session_id.is_empty(),
		"activation failure disconnects rather than leaving wrong-world membership active")
	loader.fail_activate = false
	await process_frame
	node.free()
	node = coordinator()
	node.peer.auto_respond = false
	var timed_out: Array = []
	_capture_join(node, timed_out)
	node.pending_deadline = 0
	node._process(0)
	check(timed_out == [false] and not node.session_busy and not node.peer.is_connected_to_relay,
		"pending join timeout disconnects and ends the transition with a failure")
	await process_frame
	node.free()

func _capture_join(node: Node, completed: Array):
	completed.append(await node.join_session("waiting", WORLD_A))

func pump_relay(relay: Node, clients: Array, rounds: int = 20):
	for round_index in rounds:
		relay.handle_events()
		for client in clients:
			client.handle_events()
		await create_timer(0.005).timeout

func test_loopback_relay():
	var relay = make_relay()
	relay.connection = ENetConnection.new()
	var error = relay.connection.create_host_bound("127.0.0.1", 0)
	check(error == OK, "loopback relay starts on an ephemeral port")
	if error != OK:
		relay.free()
		return
	var clients: Array = []
	for index in 3:
		var client = RelayPeer.new()
		client.account_key = Crypto.new().generate_rsa(2048)
		client.connect_to_relay("127.0.0.1", relay.connection.get_local_port())
		clients.append(client)
	await pump_relay(relay, clients)
	check(clients.all(func(client): return client.is_connected_to_relay), "three real clients connect without joining any room")
	clients[0].create_session(PUBLIC, "Alice", "Alice's room", WORLD_A)
	clients[1].create_session(PUBLIC, "Bob", "Bob's room", WORLD_A)
	await pump_relay(relay, clients)
	GetPublicSessions.create([]).sent(clients[2].peer)
	await pump_relay(relay, clients)
	check(clients[2].public_session.size() == 2,
		"real discovery packet returns both public hosts of the same world")
	var scene = explorer()
	scene.load_sessions(clients[2].public_session)
	for card in cards(scene):
		if card.tooltip_text == WORLD_A:
			card.pressed.emit()
	check(cards(scene).size() == 2 and rows(scene).size() == 2,
		"live relay snapshot produces one world card with two instance rows plus home")
	scene.free()
	var bob_id := ""
	for value in clients[2].public_session:
		if value.name == "Bob":
			bob_id = value.session_id
	var replies: Array = []
	clients[2].session_result.connect(func(value): replies.append(value))
	clients[2].join_session(bob_id, WORLD_A)
	await pump_relay(relay, clients)
	check(not replies.is_empty() and replies.back().success and replies.back().session_id == bob_id \
		and clients[2].session_peers.size() == 1 and clients[0].session_peers.is_empty(),
		"real join acknowledges Bob's identity and keeps Alice in a separate room")
	# Re-create at the SAME content URL while another member keeps the previous
	# instance alive. URL grouping must not replace or merge either session.
	var alice_id: String = clients[0].current_session_id
	clients[1].create_session(PUBLIC, "Bob second", "Another instance, same content", WORLD_A)
	await pump_relay(relay, clients)
	var second_bob_id: String = clients[1].current_session_id
	check(not second_bob_id.is_empty() and second_bob_id != bob_id and second_bob_id != alice_id,
		"creating another instance of the same world allocates a distinct acknowledged session ID")
	check(clients[2].current_session_id == bob_id and clients[2].session_peers.is_empty(),
		"same-world creation leaves previous instance alive for its remaining member without merging membership")
	GetPublicSessions.create([]).sent(clients[2].peer)
	await pump_relay(relay, clients)
	var active_ids: Array = []
	for value in clients[2].public_session:
		if value.world_url == WORLD_A: active_ids.append(value.session_id)
	active_ids.sort()
	var expected_ids: Array = [alice_id, bob_id, second_bob_id]
	expected_ids.sort()
	check(active_ids == expected_ids,
		"wire discovery lists ALL three active public instances of one world, including newly created and surviving instances")
	check(clients[2].public_session.all(func(value): return value.player_count == 1),
		"each same-world instance reports its own participant count rather than a combined world total")
	scene = explorer()
	scene.load_sessions(clients[2].public_session)
	scene.create_world_info_menue({"url": WORLD_A})
	check(row_ids(scene) == active_ids and rows(scene).size() == 3,
		"World Explorer renders every active public session as a separate row under one world")
	scene.free()
	clients[1].create_session(PacketInfo.MODE.PRIVAT, "Private Bob", "Hidden", WORLD_B)
	await pump_relay(relay, clients)
	GetPublicSessions.create([]).sent(clients[2].peer)
	await pump_relay(relay, clients)
	check(clients[2].public_session.size() == 2 and clients[2].public_session.all(func(value): return value.mode == PUBLIC),
		"private replacement stays hidden while old public room persists with its remaining participant")
	check(clients[2].public_session.all(func(value): return value.session_id != second_bob_id),
		"empty same-world replacement disappears from discovery without removing the two surviving public instances")
	for client in clients:
		client.peer.peer_disconnect()
	await pump_relay(relay, clients)
	check(relay.sessions.is_empty(), "disconnecting every participant removes all public and private rooms")
	for client in clients:
		client.connection.destroy()
	relay.connection.destroy()
	relay.free()

func test_real_loader():
	var loader = load("res://scripts/startup/data_loader.gd").new()
	root.add_child(loader)
	var path = "res://test-world.cne"
	var zip = ZIPPacker.new()
	zip.open(path)
	zip.start_file("manifest.json")
	zip.write_file('{"format":"comunicare.world","schema_version":1,"world_id":"fixture","release":"1","requires":{"world_api":1,"script_api":1},"main_scene":"world.tscn"}'.to_utf8_buffer())
	zip.close_file()
	zip.start_file("world.tscn")
	zip.write_file('[gd_scene format=3]\n[node name="TestWorld" type="Node3D"]\n'.to_utf8_buffer())
	zip.close_file()
	zip.close()
	var created_before = network.created
	check(loader.prepare_world(path, "res://unused/").get("scene") is PackedScene,
		"safe format stages through real DataLoader")
	var staged: Dictionary = loader.prepare_world(path, "res://extracted/")
	check(not staged.is_empty() and network.created == created_before and current_scene == null,
		"real loader stages valid archive without hosting or changing scene")
	check(not loader._safe_archive_path("../escape") and not loader._safe_archive_path("/absolute") \
		and not loader._safe_archive_path("res://escape"), "archive extraction rejects paths outside staging directory")
	var ok: bool = await loader.activate_world(staged)
	check(ok and current_scene != null and current_scene.name == "TestWorld" and network.created == created_before,
		"real world activation changes scene without creating a session")
	check(not await loader.load_world_from_url("file:///invalid"), "invalid URL fails without downloading or hosting")
	var legacy = ZIPPacker.new()
	legacy.open("res://legacy.cne")
	legacy.start_file("manifest.json")
	legacy.write_file('{"main_scene":"world.tscn"}'.to_utf8_buffer())
	legacy.close_file()
	legacy.start_file("world.tscn")
	legacy.write_file('[gd_scene format=3]\n[node name="Legacy" type="Node3D"]\n'.to_utf8_buffer())
	legacy.close_file()
	legacy.close()
	check(loader.prepare_world("res://legacy.cne", "res://legacy-content/").is_empty(),
		"real loader rejects legacy executable-scene format rather than bypassing safe parser")
	loader.free()

func test_instance_submenu():
	var scene = explorer([catalog_world(WORLD_A)])
	scene.load_sessions([session("alice"), session("bob"), session("carol", WORLD_B)])
	open_first_world(scene)
	check(row_ids(scene) == ["alice", "bob"],
		"world info lists every public instance for its exact URL only", str(row_ids(scene)))
	var descriptive := false
	for row in rows(scene):
		if row.get_meta("session_id") == "alice":
			for child in row.find_children("*", "Label", true, false):
				if "Room alice" in child.text:
					descriptive = true
	check(descriptive, "instance row displays its advertised name", "Room alice not displayed")
	scene.free()

func test_refresh():
	var scene = explorer([catalog_world(WORLD_A)])
	scene.load_sessions([session("alice"), session("bob")])
	scene.load_sessions([session("bob")])
	check(cards(scene).size() == 2,
		"repeated snapshots never duplicate home or catalog cards", "%d cards" % cards(scene).size())
	open_first_world(scene)
	check(row_ids(scene) == ["bob"], "refresh replaces instances instead of appending stale entries", str(row_ids(scene)))
	var row_ids_before_refresh = row_ids(scene)
	scene.load_sessions([])
	check(rows(scene).is_empty() and row_ids_before_refresh == ["bob"],
		"empty snapshot removes previously visible rows from an already-open info menu")
	check(cards(scene).size() == 2, "catalog worlds remain available with zero public instances")
	scene.free()

	scene = explorer()
	scene.load_sessions([session("alice")])
	scene.load_sessions([])
	check(cards(scene).size() == 1,
		"discovery-only worlds disappear when their last instance disappears", "%d cards" % cards(scene).size())
	scene.free()

func test_visibility_and_validation():
	var scene = explorer([catalog_world(WORLD_A)])
	var snapshot: Array = [session("public")]
	for mode in range(1, 5):
		snapshot.append(session("hidden-%d" % mode, WORLD_A, mode))
	var missing_mode = session("missing-mode")
	missing_mode.erase("mode")
	snapshot.append(missing_mode)
	snapshot.append(session("public")) # Duplicate session ID, not another row.
	snapshot.append(session(""))
	snapshot.append(session("bad-url", "file:///etc/passwd"))
	scene.load_sessions(snapshot)
	open_first_world(scene)
	check(row_ids(scene) == ["public"],
		"client fails closed on non-public/missing mode, deduplicates IDs, rejects invalid identity/URL",
		str(row_ids(scene)))
	scene.free()

	scene = explorer([catalog_world(WORLD_A)])
	scene.load_sessions([session("home-room", "default_wold")])
	for button in cards(scene):
		if button.text == "Comunicare Home":
			button.pressed.emit()
	check(row_ids(scene) == ["home-room"], "built-in default_wold instances use the same submenu")
	scene.free()

func test_catalog_race():
	var scene = explorer()
	scene.load_sessions([session("alice")])
	var catalog_json = JSON.stringify([catalog_world(WORLD_A)])
	scene._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(), catalog_json.to_utf8_buffer())
	open_first_world(scene)
	check(row_ids(scene) == ["alice"],
		"late catalog HTTP response does not erase the latest relay snapshot", str(row_ids(scene)))
	scene.free()

func test_join_selected_instance():
	network.reset()
	root.get_node("DataLoader").loaded_urls.clear()
	var scene = explorer([catalog_world(WORLD_A)])
	scene.load_sessions([session("alice"), session("bob")])
	open_first_world(scene)
	var clicked := false
	for row in rows(scene):
		if row.get_meta("session_id") == "bob":
			for button in buttons(row):
				if button.text.to_lower() == "join":
					button.pressed.emit()
					clicked = true
					break
	check(clicked and network.joined == ["bob"],
		"clicking Bob's Join targets Bob's session ID, not Alice or the world URL", str(network.joined))
	check(clicked and root.get_node("DataLoader").loaded_urls == [WORLD_A],
		"joining an instance loads that instance's advertised world URL")
	check(clicked and network.created == 0,
		"joining an existing instance never creates a new session")
	scene.free()
