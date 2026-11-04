extends SceneTree
var passed := 0
var failed := 0

class Appearance extends Node3D:
	var user_name := ""
	var requested: Array = []
	func load_player_model(url: String): requested.append(url)

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	if value: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func coordinator():
	var node = load("res://scripts/multiplayer/network_handler.gd").new()
	node.peer = load("res://fixtures/recording_peer.gd").new()
	node.peer.current_session_id = "old"
	node.current_session_id = "old"
	node.peer.session_result.connect(node._on_session_result)
	root.add_child(node)
	return node

func run():
	test_profile_appearance()
	test_unmatched_result()
	test_stream_validation()
	await test_replacement_during_prepare()
	await test_connection_recovery()
	print("\nRED client reliability: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)

func test_connection_recovery():
	var network = root.get_node("NetworkHandler")
	check(network.has_method("ensure_relay_connected"), "coordinator exposes retryable relay connection")
	if not network.has_method("ensure_relay_connected"): return
	var unavailable: Array = []
	network.relay_ip = "127.0.0.1"
	var reservation = ENetConnection.new()
	reservation.create_host_bound("127.0.0.1", 0)
	network.relay_port = reservation.get_local_port()
	reservation.destroy()
	_capture_connection(network, unavailable)
	network.authentication_deadline = Time.get_ticks_msec() - 1
	await process_frame
	await process_frame
	check(unavailable == [false] and not network.connection_in_progress, "unavailable relay times out without leaving reconnect latched")
	check("127.0.0.1" in network.last_session_error and "relay" in network.last_session_error.to_lower(), "connection failure identifies endpoint and recovery instead of generic disconnected")
	var server = load("res://scripts/multiplayer/relay.gd").new()
	server.connection = ENetConnection.new()
	check(server.connection.create_host_bound("127.0.0.1", 0) == OK, "connection recovery fixture binds loopback relay")
	network.relay_ip = "127.0.0.1"
	network.relay_port = server.connection.get_local_port()
	var completed: Array = []
	_capture_connection(network, completed)
	_capture_connection(network, completed)
	var deadline = Time.get_ticks_msec() + 5000
	while completed.size() < 2 and Time.get_ticks_msec() < deadline:
		server.handle_events()
		await process_frame
	check(completed == [true, true] and server.key_mapping.size() == 1, "concurrent reconnect requests share one authenticated connection")
	check(network.last_session_error.is_empty(), "successful retry clears stale disconnected error")
	network.peer.peer.peer_disconnect()
	deadline = Time.get_ticks_msec() + 2000
	while network.peer.is_connected_to_relay and Time.get_ticks_msec() < deadline:
		server.handle_events()
		await process_frame
	completed.clear()
	_capture_connection(network, completed)
	deadline = Time.get_ticks_msec() + 5000
	while completed.is_empty() and Time.get_ticks_msec() < deadline:
		server.handle_events()
		await process_frame
	check(completed == [true], "disconnected startup connection can authenticate again without restarting game")
	if network.peer != null:
		network.peer.connection.destroy()
		network.peer.connection = null
		network.peer.disconnected_from_relay()
	server.connection.destroy()
	server.free()

func _capture_connection(network: Node, completed: Array):
	completed.append(await network.ensure_relay_connected())

func test_profile_appearance():
	var node = coordinator()
	var actor = Appearance.new()
	actor.name = "7"
	node.add_child(actor)
	var label = Label3D.new()
	label.name = "user_name"
	actor.add_child(label)
	var key = Crypto.new().generate_rsa(2048)
	var service = load("res://scripts/profile/profile_service.gd").new()
	service.configure(key, "res://never-saved-remote.cfg")
	var fields: Dictionary = service.local.duplicate(true)
	fields["profile.username"] = "Remote Alice"
	fields["profile.avatar_url"] = "https://example.invalid/alice.vrm"
	service._sign(fields)
	fields.peer_id = 7
	node._on_profiles_updated("old", [fields])
	check(actor.user_name == "Remote Alice", "baseline verified profile updates remote display name")
	check(actor.requested == [fields["profile.avatar_url"]], "verified public profile applies its avatar URL to the matching remote actor")
	node._on_profiles_updated("old", [fields])
	check(actor.requested.size() == 1, "unchanged profile snapshot never duplicates appearance load")
	var before = actor.requested.size()
	node._on_profiles_updated("another-instance", [fields])
	check(actor.requested.size() == before, "another instance profile cannot load appearance")
	node.free()
	root.get_node("SaveData").profile.clear_remote_profiles()

func test_unmatched_result():
	var node = coordinator()
	node.pending_operation = "join"
	node.pending_id = "wanted"
	node.pending_deadline = Time.get_ticks_msec() + 60000
	node.peer.on_packet(SessionResult.create({"operation": "join", "session_id": "unrelated",
		"world_url": "default_wold", "success": true, "message": ""}).encode())
	check(node.current_session_id == "old", "coordinator ignores unrelated join acknowledgement")
	check(node.peer.current_session_id == "old", "transport must not commit an acknowledgement rejected by coordinator")
	check(node.pending_id == "wanted" and node.pending_operation == "join", "unrelated result does not finish current request")
	node.free()

func capture_join(node: Node, completed: Array):
	completed.append(await node.join_session("target", "default_wold"))

func test_stream_validation():
	var peer = RelayPeer.new()
	peer.current_session_id = "old"
	var poses: Array = []
	var voices: Array = []
	peer.player_data.connect(func(value): poses.append(value))
	peer.voice_data.connect(func(value): voices.append(value))
	peer.on_packet(PlayerData.create(7, Vector3(NAN, 0, 0), Vector3.ZERO).encode())
	check(poses.is_empty(), "nonfinite movement cannot reach remote scene transforms")
	peer.on_packet(PackedByteArray([PacketInfo.PACKET_TYPE.VOICE_DATA, 7, 1]))
	check(voices.is_empty(), "odd PCM byte count cannot reach voice decoder")
	peer.on_packet(PackedByteArray([255]))
	check(true, "unknown network packet type is quietly ignored")

func test_replacement_during_prepare():
	var node = coordinator()
	var loader = root.get_node("DataLoader")
	loader.hold_prepare = true
	loader.activated = 0
	var old_peer = node.peer
	var completed: Array = []
	capture_join(node, completed)
	var replacement = load("res://fixtures/recording_peer.gd").new()
	replacement.current_session_id = "replacement-home"
	# Keep the legacy test from hanging: any wrongly issued join still reaches
	# the production coordinator, allowing the assertion to expose the mutation.
	replacement.session_result.connect(node._on_session_result)
	node.peer = replacement
	loader.prepared.emit()
	for i in 5: await process_frame
	check(replacement.joins.is_empty(), "staged join cannot migrate onto a replacement connection")
	check(completed == [false] and loader.activated == 0, "connection replacement cancels stale preparation before activation")
	check(old_peer.joins.is_empty(), "abandoned connection is not sent the old join either")
	loader.hold_prepare = false
	node.queue_free()
	await process_frame
