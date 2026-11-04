extends SceneTree
const Link = preload("res://scripts/multiplayer/federation/secure_relay_link.gd")
var passed := 0
var failed := 0

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	if value: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func pump(a, b, seconds: float = 0.3):
	var until = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		a.poll()
		b.poll()
		await create_timer(0.002).timeout

func run():
	var key = Crypto.new().generate_rsa(2048)
	var certificate = Crypto.new().generate_self_signed_certificate(key, "CN=relay.test,O=Comunicare,C=DE", "20250101000000", "20350101000000")
	var listener = TCPServer.new()
	check(listener.listen(0, "127.0.0.1") == OK, "secure relay test binds local TCP listener")
	var client = Link.new()
	check(client.connect_to("127.0.0.1", listener.get_local_port(), certificate, "relay.test"), "client requires explicitly trusted TLS certificate")
	var until = Time.get_ticks_msec() + 2000
	while not listener.is_connection_available() and Time.get_ticks_msec() < until: await process_frame
	var server = Link.new()
	check(server.accept_connection(listener.take_connection(), key, certificate), "server accepts TLS connection with infrastructure key")
	await pump(client, server, 1.0)
	check(client.connected() and server.connected(), "real TLS handshake validates trusted self-signed relay")
	client.send({"op": "directory", "nonce": "one"})
	server.send({"op": "hello", "boot": "new"})
	await pump(client, server)
	check(server.drain() == [{"op": "directory", "nonce": "one"}], "bounded directory request crosses actual encrypted stream")
	check(client.drain() == [{"op": "hello", "boot": "new"}], "TLS supports bidirectional framed relay messages")
	check(not client.send({"op": "oversized", "data": "x".repeat(65536)}), "oversized frames close connection before queue allocation")
	server.close()
	listener.stop()
	await test_directory_chain()
	await test_lan_datagram()
	print("\nFederation transport: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)

func test_directory_chain():
	var script = load("res://scripts/multiplayer/federation/relay_directory_service.gd")
	var services: Array = []
	var keys: Array = []
	var certs: Array = []
	for index in 3:
		var private_key = Crypto.new().generate_rsa(2048)
		var cert = Crypto.new().generate_self_signed_certificate(private_key, "CN=comunicare-relay,O=Comunicare,C=DE", "20250101000000", "20350101000000")
		var service = script.new()
		check(service.start(private_key, cert), "real federation directory relay starts: " + str(index))
		keys.append(private_key)
		certs.append(cert)
		services.append(service)
	for i in 3:
		for j in 3:
			if i != j: services[i].trust_peer(keys[j].save_to_string(true), certs[j])
	var origin = services[2]
	var summary = {"origin_relay_id": origin.relay_id, "origin_boot_id": origin.boot_id, "instance_id": "real-room", "world_url": "default_wold", "world_revision": "a".repeat(64), "mode": 0, "name": "Origin room", "description": "", "player_count": 2}
	check(origin.set_local_instances([summary]), "origin publishes strict public summary")
	check(services[0].connect_peer("127.0.0.1", services[1].local_port, services[1].relay_id), "first relay opens pinned encrypted neighbour link")
	check(services[1].connect_peer("127.0.0.1", services[2].local_port, services[2].relay_id), "middle relay opens second pinned encrypted link")
	var until = Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < until and services[0].public_instances().is_empty():
		for service in services: service.poll()
		await create_timer(0.003).timeout
	check(services[0].public_instances().size() == 1, "origin-signed public instance traverses real three-relay TLS chain")
	var game_relay = load("res://scripts/multiplayer/relay.gd").new()
	game_relay.connection = ENetConnection.new()
	game_relay.connection.create_host_bound("127.0.0.1", 0)
	origin.set_gameplay_port(game_relay.connection.get_local_port())
	var tunnel = load("res://scripts/multiplayer/federation/relay_game_tunnel.gd").new()
	check(tunnel.start("127.0.0.1", services[0].local_port, certs[0], origin.relay_id), "client opens encrypted gameplay route through first relay")
	until = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until and not tunnel.ready:
		for service in services: service.poll()
		tunnel.poll()
		await create_timer(0.003).timeout
	check(tunnel.ready, "three-relay gameplay tunnel establishes one origin endpoint")
	var player = RelayPeer.new()
	player.account_key = Crypto.new().generate_rsa(2048)
	player.connect_to_relay("127.0.0.1", tunnel.local_port)
	until = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until and not player.is_authenticated:
		for service in services: service.poll()
		tunnel.poll()
		game_relay.handle_events()
		player.handle_events()
		await create_timer(0.003).timeout
	check(player.is_authenticated, "real account authenticates end-to-end across three encrypted relay hops")
	player.expected_world_revision = "a".repeat(64)
	player.create_session(0, "Federated gameplay", "", "default_wold")
	until = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and player.current_session_id.is_empty():
		for service in services: service.poll()
		tunnel.poll()
		game_relay.handle_events()
		player.handle_events()
		await create_timer(0.003).timeout
	check(not player.current_session_id.is_empty() and game_relay.sessions.size() == 1, "actual origin alone acknowledges membership over federated tunnel")
	var tunnel_two = load("res://scripts/multiplayer/federation/relay_game_tunnel.gd").new()
	tunnel_two.start("127.0.0.1", services[1].local_port, certs[1], origin.relay_id)
	until = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until and not tunnel_two.ready:
		for service in services: service.poll()
		tunnel.poll()
		tunnel_two.poll()
		game_relay.handle_events()
		player.handle_events()
		await create_timer(0.003).timeout
	var second = RelayPeer.new()
	second.account_key = Crypto.new().generate_rsa(2048)
	second.connect_to_relay("127.0.0.1", tunnel_two.local_port)
	until = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until and not second.is_authenticated:
		for service in services: service.poll()
		tunnel.poll()
		tunnel_two.poll()
		game_relay.handle_events()
		player.handle_events()
		second.handle_events()
		await create_timer(0.003).timeout
	second.expected_world_revision = "a".repeat(64)
	second.join_session(player.current_session_id, "default_wold")
	until = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and second.current_session_id.is_empty():
		for service in services: service.poll()
		tunnel.poll()
		tunnel_two.poll()
		game_relay.handle_events()
		player.handle_events()
		second.handle_events()
		await create_timer(0.003).timeout
	check(second.is_authenticated and second.current_session_id == player.current_session_id, "users through different ingress relays share one origin-admitted instance")
	var received: Array = []
	second.world_data.connect(func(message): received.append(message))
	player.send_world({"op": "grab", "session_id": player.current_session_id, "revision": "a".repeat(64), "entity": "cube", "grip": "virtual", "sequence": 1, "epoch": 0})
	until = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and received.is_empty():
		for service in services: service.poll()
		tunnel.poll()
		tunnel_two.poll()
		game_relay.handle_events()
		player.handle_events()
		second.handle_events()
		await create_timer(0.003).timeout
	check(received.any(func(message): return message.get("op") == "item" and message.get("entity") == "cube"), "actual item ownership crosses different encrypted ingress routes")
	second.connection.destroy()
	tunnel_two.close()
	player.connection.destroy()
	tunnel.close()
	game_relay.connection.destroy()
	game_relay.free()
	var browser = load("res://scripts/multiplayer/federation/relay_directory_client.gd").new()
	browser.add_trusted("127.0.0.1", services[0].local_port, services[0].relay_id, certs[0])
	browser.add_trusted("127.0.0.1", services[2].local_port, services[2].relay_id, certs[2])
	check(browser.query(services[0].relay_id) and browser.query(services[2].relay_id), "anonymous client opens two simultaneous verified directory links")
	until = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and browser.instances().is_empty():
		for service in services: service.poll()
		browser.poll()
		await create_timer(0.003).timeout
	check(browser.instances().size() == 1 and browser.links.size() == 2, "client deduplicates real direct/federated instance without account publication")
	browser.set_blocks([origin.relay_id], [])
	check(browser.instances().is_empty(), "user origin block suppresses remote result through allowed directory relay")
	browser.stop()
	services[0].set_blocked(origin.relay_id, true)
	check(services[0].public_instances().is_empty(), "operator origin block purges indirect real-network directory sighting")
	for service in services: service.stop()
	check(services.all(func(service): return service.links.is_empty() and service.public_instances().is_empty()), "directory shutdown clears links and live summaries")

func test_lan_datagram():
	var receiver = load("res://scripts/multiplayer/federation/lan_relay_transport.gd").new()
	check(receiver.start(true, [], {}, 0), "LAN transport binds an isolated discovery socket")
	var sender = PacketPeerUDP.new()
	sender.set_dest_address("127.0.0.1", receiver.socket.get_local_port())
	sender.put_packet(JSON.stringify({"version": 1, "relay_id": "a".repeat(64), "boot_id": "live-boot", "label": "Actual UDP hint", "host": "source", "port": 7375}).to_utf8_buffer())
	var until = Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until and receiver.model.candidates().is_empty():
		receiver.poll()
		await create_timer(0.003).timeout
	check(receiver.model.candidates().size() == 1, "actual local UDP advertisement becomes unverified LAN candidate")
	check(receiver.model.instances().is_empty(), "actual UDP hint never creates an unverified joinable instance")
	sender.close()
	receiver.stop()
