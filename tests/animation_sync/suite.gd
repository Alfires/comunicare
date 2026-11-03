extends SceneTree

const Reader = preload("res://scripts/assets/humanoid_animation.gd")
const Defaults = preload("res://scripts/assets/default_animations.gd")
const Animator = preload("res://scripts/assets/avatar_animator.gd")
var passed := 0
var failed := 0

class Coordinator extends Node:
	var peer
	var current_session_id := "test"
	var session_busy := false

class Remote extends Node3D:
	var avatar: Node3D

func _initialize():
	call_deferred("run")

func check(value: bool, title: String):
	if value:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func fixture() -> PackedByteArray:
	var binary = PackedFloat32Array([0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.3826834, 0.0, 0.9238795]).to_byte_array()
	var json = {"asset": {"version": "2.0"}, "nodes": [{"name": "Hips"}],
		"extensions": {"VRMC_vrm_animation": {"specVersion": "1.0", "humanoid": {"humanBones": {"hips": {"node": 0}}}}},
		"buffers": [{"byteLength": binary.size()}],
		"bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": 8}, {"buffer": 0, "byteOffset": 8, "byteLength": 32}],
		"accessors": [{"bufferView": 0, "componentType": 5126, "count": 2, "type": "SCALAR"},
			{"bufferView": 1, "componentType": 5126, "count": 2, "type": "VEC4"}],
		"animations": [{"name": "Turn", "samplers": [{"input": 0, "output": 1}],
			"channels": [{"sampler": 0, "target": {"node": 0, "path": "rotation"}}]}]}
	return pack(json, binary)

func pack(json: Dictionary, binary: PackedByteArray) -> PackedByteArray:
	var text = JSON.stringify(json).to_utf8_buffer()
	while text.size() % 4:
		text.append(32)
	var bytes = PackedByteArray()
	bytes.resize(20)
	bytes.encode_u32(0, 0x46546c67)
	bytes.encode_u32(4, 2)
	bytes.encode_u32(8, 28 + text.size() + binary.size())
	bytes.encode_u32(12, text.size())
	bytes.encode_u32(16, 0x4e4f534a)
	bytes.append_array(text)
	var chunk = PackedByteArray()
	chunk.resize(8)
	chunk.encode_u32(0, binary.size())
	chunk.encode_u32(4, 0x004e4942)
	bytes.append_array(chunk)
	bytes.append_array(binary)
	return bytes

func run():
	var reader = Reader.new()
	var bytes = fixture()
	var parsed = reader.read_bytes(bytes)
	check(not parsed.is_empty() and parsed.clips[0].name == "Turn", "runtime VRMA parser reads real GLB channels")
	if parsed.is_empty():
		quit(1)
		return
	check(parsed.clips[0].duration == 1.0 and parsed.clips[0].tracks[0].bone == "hips", "clip duration and humanoid mapping retained")
	check(reader.read_bytes(bytes.slice(0, 24)).is_empty(), "truncated binary rejected quietly")
	var doc = reader.document(bytes)
	doc.json.buffers[0].uri = "file:///etc/passwd"
	check(reader.read_bytes(pack(doc.json, doc.binary)).is_empty(), "external URI rejected")
	doc.json.buffers[0].erase("uri")
	doc.json.animations[0].channels[0].target.path = "translation"
	check(reader.read_bytes(pack(doc.json, doc.binary)).is_empty(), "unsupported root motion rejected explicitly")
	doc.json.animations[0].channels[0].target.path = "rotation"
	doc.json.accessors[1].count = 99999999
	check(reader.read_bytes(pack(doc.json, doc.binary)).is_empty(), "oversized accessor rejected before allocation")
	var avatar = Node3D.new()
	var skeleton = Skeleton3D.new()
	skeleton.name = "Rig"
	avatar.add_child(skeleton)
	skeleton.add_bone("MappedHips")
	skeleton.set_bone_rest(0, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3.ZERO))
	avatar.set_meta("humanoid_bones", {"hips": "MappedHips"})
	root.add_child(avatar)
	var bound = reader.bind_clip(parsed.clips[0], avatar)
	check(bound != null and bound.track_get_path(0) == NodePath("Rig:MappedHips"), "retarget uses validated metadata instead of source node name")
	check(bound.track_get_key_value(0, 0).is_equal_approx(skeleton.get_bone_rest(0).basis.get_rotation_quaternion()), "retarget preserves target rest rotation")
	var source = parsed.clips[0].duplicate(true)
	source.tracks[0].source_rest = Quaternion(Vector3.UP, 0.7)
	var converted = reader.bind_clip(source, avatar)
	var rest_rotation = skeleton.get_bone_rest(0).basis.get_rotation_quaternion()
	var axis_conversion = rest_rotation.inverse() * source.tracks[0].source_rest
	var expected = rest_rotation * axis_conversion * source.tracks[0].keys[1].rotation * axis_conversion.inverse()
	check(converted.track_get_key_value(0, 1).is_equal_approx(expected), "hierarchical rest-axis conversion applied to imported rotation deltas")
	var animator = Animator.new()
	avatar.add_child(animator)
	animator.attach(avatar)
	check(animator.play_clip(parsed.clips[0], true, 1.0, 0.5), "dedicated AnimationPlayer starts imported clip")
	animator.player.advance(0.1)
	check(animator.player.current_animation_position > 0.5, "playhead advances from requested offset")
	animator.set_paused(true)
	check(not animator.player.is_playing(), "pause freezes player")
	animator.stop()
	check(not animator.player.is_playing(), "stop applies reset and stops player")
	for id in Defaults.IDS:
		var clip = Defaults.clip(id)
		check(not clip.is_empty() and clip.duration > 0 and not clip.tracks.is_empty(), "offline CC0 default: " + id)
	avatar.free()
	await test_ui(bytes)
	await test_controller(parsed)
	await test_network()
	print("\nAnimation contracts: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)

func test_ui(bytes: PackedByteArray):
	var loader = root.get_node("DataLoader")
	loader.get_asset_cache().initialize("res://cache")
	var menu = load("res://scenes/GUI/animation_menue.tscn").instantiate()
	root.add_child(menu)
	check(menu.selected.item_count == 8, "actual animation page exposes all offline defaults")
	var file = FileAccess.open("res://motion.vrma", FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	await menu.import_file("res://motion.vrma")
	check(menu.selected.item_count == 9 and menu.selected.selected == 8, "actual file import validates and selects user clip")
	check(not menu.share.button_pressed, "newly imported file never silently grants redistribution consent")
	check(not loader.animation_import_busy and loader.animation_thread == null, "runtime animation worker is joined without blocking main loop")
	menu.play()
	check("No compatible avatar" in menu.status.text, "actual player reports absent avatar rather than pretending success")
	menu.queue_free()
	await process_frame
	menu = load("res://scenes/GUI/animation_menue.tscn").instantiate()
	root.add_child(menu)
	for i in 100:
		if menu.selected.item_count == 9:
			break
		await process_frame
	check(menu.selected.item_count == 9, "managed imported library restores when page reopens")
	menu.queue_free()
	await process_frame

func test_controller(parsed: Dictionary):
	var network = Coordinator.new()
	network.peer = RelayPeer.new()
	network.peer.session_peers = [7]
	root.add_child(network)
	var remote = Remote.new()
	remote.name = "7"
	remote.avatar = Node3D.new()
	var skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	skeleton.add_bone("Hips")
	remote.avatar.add_child(skeleton)
	remote.avatar.set_meta("humanoid_bones", {"hips": "Hips"})
	remote.add_child(remote.avatar)
	network.add_child(remote)
	var controller = load("res://scripts/assets/animation_controller.gd").new()
	root.add_child(controller)
	controller.configure(network, null)
	controller.transport = network.peer
	controller.automatic_motion = false
	controller.assets[parsed.hash] = {"parsed": parsed}
	var value = {"op": "state", "session_id": "test", "version": 1, "peer_id": 7,
		"generation": "a".repeat(32), "sequence": 1, "action": "play", "offset": 0.5,
		"speed": 1.0, "loop": true, "duration": 1.0, "builtin": "", "hash": parsed.hash,
		"size": 1024, "clip": 0, "started": controller.now()}
	controller.receive(value)
	check(controller.remote_animators.has(7), "production client controller attaches remote animation layer")
	check(controller.remote_animators[7].player.current_animation_position >= 0.5, "production receiver seeks late-loaded motion to current playhead")
	value.sequence = 2
	value.action = "pause"
	controller.receive(value)
	check(not controller.remote_animators[7].player.is_playing(), "production receiver applies pause")
	value.session_id = "other"
	value.sequence = 3
	value.action = "play"
	controller.receive(value)
	check(controller.remote_states[7].sequence == 2, "production receiver rejects another instance's state")
	controller.clear()
	check(controller.remote_states.is_empty() and controller.assets.is_empty(), "client transition removes motion and asset session state")
	controller.queue_free()
	network.queue_free()
	await process_frame

func pump(server: Node, clients: Array, seconds: float = 0.25):
	var deadline = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		server.handle_events()
		for client in clients:
			client.handle_events()
		await create_timer(0.003).timeout

func test_network():
	var server = load("res://scripts/multiplayer/relay.gd").new()
	server.connection = ENetConnection.new()
	check(server.connection.create_host_bound("127.0.0.1", 0) == OK, "animation relay binds isolated loopback")
	var clients: Array = []
	var messages: Array = [[], [], []]
	for i in 3:
		var client = RelayPeer.new()
		client.account_key = Crypto.new().generate_rsa(2048)
		client.animation_data.connect(func(value): messages[i].append(value))
		client.connect_to_relay("127.0.0.1", server.connection.get_local_port())
		clients.append(client)
	await pump(server, clients, 0.8)
	check(clients.all(func(client): return client.is_authenticated and client.animation_supported), "three real clients negotiate authenticated animation capability")
	clients[0].create_session(0, "Room", "", "default_wold")
	clients[2].create_session(0, "Other", "", "default_wold")
	await pump(server, clients)
	clients[1].join_session(clients[0].current_session_id, "default_wold")
	await pump(server, clients)
	var state = {"op": "state", "version": 1, "sequence": 1, "action": "play", "offset": 0.25,
		"speed": 1.0, "loop": true, "duration": 2.0, "builtin": "wave", "hash": "",
		"library": "comunicare.procedural.v1", "session_id": clients[0].current_session_id, "peer_id": 254}
	clients[0].send_animation(state)
	await pump(server, clients)
	var received = messages[1].filter(func(value): return value.get("op") == "state")
	check(received.size() == 1, "reliable animation reaches exact-instance participant")
	check(messages[2].filter(func(value): return value.get("op") == "state").is_empty(), "same-world different instance receives no animation")
	var owner = int(received[0].peer_id) if not received.is_empty() else -1
	check(owner != 254 and server.animations.states.has(owner), "relay derives actor from authenticated transport, not claimed ID")
	clients[0].send_animation(state)
	await pump(server, clients)
	check(messages[1].filter(func(value): return value.get("op") == "state").size() == 1, "duplicate sequence rejected")
	clients[1].send_animation({"op": "snapshot", "session_id": clients[1].current_session_id})
	await pump(server, clients)
	check(messages[1].filter(func(value): return value.get("op") == "state").size() == 2, "late-load snapshot preserves latest state")
	clients[1].send_animation({"op": "clock", "nonce": Time.get_ticks_msec()})
	await pump(server, clients)
	check(not messages[1].filter(func(value): return value.get("op") == "clock" and value.has("time")).is_empty(), "monotonic relay clock sampling available")
	var data = fixture()
	var digest = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(data)
	var hash = digest.finish().hex_encode()
	state.sequence = 2
	state.builtin = ""
	state.hash = hash
	state.size = data.size()
	state.clip = 0
	state.duration = 1.0
	clients[0].send_animation(state)
	await pump(server, clients)
	clients[1].send_animation({"op": "request", "session_id": clients[1].current_session_id, "owner": owner, "hash": hash})
	await pump(server, clients)
	var requests = messages[0].filter(func(value): return value.get("op") == "request")
	check(requests.size() == 1, "local asset bytes require explicit receiver request")
	var recipient = int(requests[0].requester) if not requests.is_empty() else -1
	clients[0].send_animation({"op": "chunk", "session_id": clients[0].current_session_id, "target": recipient,
		"hash": hash, "offset": 0, "bytes": Marshalls.raw_to_base64(data)})
	await pump(server, clients)
	var chunks = messages[1].filter(func(value): return value.get("op") == "chunk")
	check(chunks.size() == 1 and Marshalls.base64_to_raw(chunks[0].bytes) == data, "requested bounded animation bytes forwarded without relay persistence")
	check(server.animations.requests.is_empty(), "completed transfer leaves no relay queue")
	state.sequence = 3
	state.action = "pause"
	clients[0].send_animation(state)
	await pump(server, clients)
	check(server.animations.states[owner].action == "pause", "reliable pause replaces latest state")
	var old_session: String = clients[2].current_session_id
	var target_index = server.get_session_index(clients[0].current_session_id)
	server.sessions[target_index][0].world_revision = "b".repeat(64)
	clients[2].expected_world_revision = "c".repeat(64)
	clients[2].join_session(clients[0].current_session_id, "default_wold")
	await pump(server, clients)
	check(clients[2].current_session_id == old_session, "world revision mismatch preserves previous membership")
	clients[2].expected_world_revision = "b".repeat(64)
	clients[2].join_session(clients[0].current_session_id, "default_wold")
	await pump(server, clients)
	check(clients[2].current_session_id == clients[0].current_session_id, "matching pinned revision permits ordinary admission")
	clients[0].peer.peer_disconnect()
	await pump(server, clients)
	check(not server.animations.states.has(owner) and not server.animations.supported.has(owner)
		and not server.animations.generations.has(owner), "disconnect erases actor state, capability and generation")
	for client in clients:
		client.connection.destroy()
	await pump(server, [], 0.1)
	server.connection.destroy()
	server.free()
