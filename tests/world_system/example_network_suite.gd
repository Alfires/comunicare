extends SceneTree
## Two separately constructed example worlds, real ENet relay/clients, real adapters.
const Builder = preload("res://scripts/worlds/world_builder.gd")
const Pickups = preload("res://scripts/worlds/world_pickup_controller.gd")
var passed := 0
var failed := 0
var server: Node
var clients: Array = []
var adapters: Array = []

class Coordinator extends Node:
	var peer: RelayPeer
	var current_session_id := ""

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	if value:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func pump(seconds: float = 0.3):
	var deadline = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		server.handle_events()
		for client in clients:
			if client.connection != null: client.handle_events()
		for adapter in adapters: adapter._process(0.01)
		await create_timer(0.01).timeout

func run():
	server = load("res://scripts/multiplayer/relay.gd").new()
	server.connection = ENetConnection.new()
	check(server.connection.create_host_bound("127.0.0.1", 0) == OK, "example end-to-end relay binds an isolated UDP port")
	for index in 2:
		var client = RelayPeer.new()
		client.account_key = Crypto.new().generate_rsa(2048)
		client.connect_to_relay("127.0.0.1", server.connection.get_local_port())
		clients.append(client)
	await pump(0.8)
	check(clients.all(func(client): return client.is_authenticated and client.world_supported), "two actual clients authenticate and negotiate item transport")
	var built = Builder.new().build_package("res://packages/simple-world.cworld")
	check(built.ok, "real-network test builds the actual example archive")
	if not built.ok:
		print(built.error)
		quit(1)
		return
	clients[0].expected_world_revision = built.revision
	clients[0].create_session(0, "Example test", "", "https://example.invalid/simple-world.cworld")
	await pump()
	clients[1].expected_world_revision = built.revision
	clients[1].join_session(clients[0].current_session_id, "https://example.invalid/simple-world.cworld")
	await pump()
	check(not clients[0].current_session_id.is_empty() and clients[0].current_session_id == clients[1].current_session_id, "both clients join the same exact pinned example instance")
	var worlds: Array = []
	var views: Array = []
	var coordinators: Array = []
	var hands: Array = []
	for index in 2:
		var view = SubViewport.new()
		view.own_world_3d = true
		view.size = Vector2i(640, 480)
		root.add_child(view)
		views.append(view)
		var world = built.scene.instantiate()
		view.add_child(world)
		worlds.append(world)
		var coordinator = Coordinator.new()
		coordinator.peer = clients[index]
		coordinator.current_session_id = clients[index].current_session_id
		coordinators.append(coordinator)
		var adapter = Pickups.new()
		adapter.configure(coordinator, world)
		adapter.activate(world, built.document, built.revision)
		adapters.append(adapter)
		var hand = Node3D.new()
		world.add_child(hand)
		hands.append(hand)
	await pump(0.5)
	check(worlds[0].get_world_3d() != worlds[1].get_world_3d(), "clients have independent physics worlds and scene objects")
	var cube_a = worlds[0].get_node("PickupCube")
	var cube_b = worlds[1].get_node("PickupCube")
	hands[0].global_position = cube_a.global_position + Vector3(0, 0.1, 0)
	check(adapters[0].request_grab("pickup-cube", "virtual", hands[0]), "desktop requests the actual example cube via production adapter")
	await pump()
	check(adapters[0].held_by_local("virtual") and cube_a.freeze and cube_b.freeze, "real relay acknowledgement installs exclusive hold in both scene copies")
	hands[0].global_position = Vector3(1, 1.4, 0.5)
	await pump(0.5)
	check(cube_a.global_position.distance_to(hands[0].global_position) < 0.02, "desktop world cube follows local virtual hand")
	check(cube_b.global_position.distance_to(hands[0].global_position) < 0.08, "second client's actual cube follows poses received over UDP")
	check(not adapters[1].request_grab("pickup-cube", "left", hands[1]), "remote VR grip cannot steal the desktop-held object")
	hands[0].global_position = Vector3(1.3, 1.6, 0.5)
	adapters[0]._process(0.001)
	check(adapters[0].release_grip("virtual"), "desktop sends release through real transport")
	await pump()
	var relay_item = server.world_items.instances[clients[0].current_session_id].items["pickup-cube"]
	check(Vector2(relay_item.position[0], relay_item.position[2]).distance_to(Vector2(hands[0].global_position.x, hands[0].global_position.z)) < 0.02,
		"release publishes final held position even between periodic pose updates")
	check(not cube_a.freeze and cube_b.freeze, "release simulates on elected physics owner and freezes receiving replica")
	await pump(0.5)
	check(cube_a.global_position.distance_to(cube_b.global_position) < 0.2, "dropped item physics continues syncing after release")
	hands[1].global_position = cube_b.global_position + Vector3(0, 0.1, 0)
	check(adapters[1].request_grab("pickup-cube", "left", hands[1]), "VR-style left grip can acquire released example cube")
	await pump()
	hands[1].global_position = Vector3(-1, 1.5, 0)
	await pump(0.5)
	check(adapters[1].held_by_local("left") and cube_a.global_position.distance_to(hands[1].global_position) < 0.08, "reverse VR-to-desktop carrying reaches the other actual world")
	check(adapters[1].release_grip("left"), "second holder releases before physics authority departure")
	await pump(0.2)
	adapters[1].snapshot_elapsed = 0.0
	clients[0].peer.peer_disconnect()
	await pump(0.5)
	check(adapters[1].physics_owner == clients[1].world_peer_id, "departing physics publisher transfers authority immediately without snapshot timeout")
	await pump(0.3)
	check(not cube_b.freeze and adapters[1].states.get("pickup-cube", {}).get("holder", -2) == -1, "new physics publisher simulates released item")
	clients[1].peer.peer_disconnect()
	await pump(0.4)
	check(server.sessions.is_empty() and server.world_items.instances.is_empty(), "last departure removes relay instance and all item state")
	for adapter in adapters:
		adapter.reset()
		adapter.free()
	adapters.clear()
	for coordinator in coordinators: coordinator.free()
	for view in views: view.free()
	for client in clients: client.connection.destroy()
	server.connection.destroy()
	server.free()
	print("\nExample real-network integration: %s passed, %s failed" % [passed, failed])
	print("Real UDP and independent scene/physics copies; controller poses are automated, not hardware input or visual certification.")
	quit(1 if failed else 0)
