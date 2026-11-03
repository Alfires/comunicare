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

class LocalPlayer extends CharacterBody3D:
	var avatar_model: Node3D

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
	var walk = Defaults.clip("walk")
	var upper_tracks: Dictionary = {}
	for track in walk.tracks:
		upper_tracks[track.bone] = track
	check(upper_tracks.has("leftLowerArm") and upper_tracks.has("rightLowerArm") and upper_tracks.has("chest"),
		"bundled walk includes elbows and chest, not only straight T-pose shoulder swings")
	check(walk.get("provenance", {}).get("author") == "Quaternius", "default walk uses licensed third-party animation data, not procedural recipes")
	await test_authored_upper_body()
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
		check(absf(clip.duration - AnimationState.DURATIONS[id]) < 0.00001, "wire duration matches authored clip: " + id)
	avatar.free()
	await test_ui(bytes)
	await test_wheel()
	await test_controller(parsed)
	await test_automatic_playback()
	await test_network()
	print("\nAnimation contracts: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)

func test_authored_upper_body():
	var walk = Defaults.clip("walk")
	for bone in ["leftUpperArm", "rightUpperArm", "leftLowerArm", "rightLowerArm", "leftHand", "rightHand", "chest"]:
		var tracks = walk.tracks.filter(func(track): return track.bone == bone)
		check(tracks.size() == 1 and tracks[0].keys.size() > 20, "authored full-body walk has sampled " + bone + " motion")
		if tracks.is_empty(): continue
		var first: Quaternion = tracks[0].keys[0].rotation
		var maximum := 0.0
		for key in tracks[0].keys:
			maximum = maxf(maximum, first.angle_to(key.rotation))
		check(maximum > 0.01, "walk changes " + bone + " rather than holding the rest pose")
	if not FileAccess.file_exists("res://real-avatar.vrm"):
		print("SKIP: optional real VRM fixture; set AVATAR_FIXTURE to a permitted local avatar")
		return
	var avatar = await root.get_node("DataLoader")._load_model_from_file("res://real-avatar.vrm")
	check(avatar != null, "production loader imports real VRM regression fixture")
	if avatar == null: return
	root.add_child(avatar)
	var animator = Animator.new()
	avatar.add_child(animator)
	animator.attach(avatar)
	check(animator.play_clip(walk, true, 1.0, 0.25), "third-party full-body walk binds to real VRM metadata")
	var skeleton = Reader.new()._skeleton(avatar)
	var mapping: Dictionary = avatar.get_meta("humanoid_bones")
	for side in ["left", "right"]:
		var arm = skeleton.find_bone(mapping[side + "UpperArm"])
		var hand = skeleton.find_bone(mapping[side + "Hand"])
		animator.player.advance(0)
		var offset = skeleton.get_bone_global_pose(hand).origin - skeleton.get_bone_global_pose(arm).origin
		check(offset.y < -0.15, "real VRM " + side + " hand drops below shoulder instead of T-posing")
		var initial_hand = skeleton.get_bone_global_pose(hand).origin
		animator.player.seek(0.7, true)
		animator.player.advance(0)
		check(initial_hand.distance_to(skeleton.get_bone_global_pose(hand).origin) > 0.02,
			"real VRM " + side + " hand moves through the walking cycle")
		animator.player.seek(0.25, true)
	avatar.queue_free()
	await process_frame

func test_automatic_playback():
	var network = Coordinator.new()
	root.add_child(network)
	var body = LocalPlayer.new()
	var avatar = Node3D.new()
	var skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	var mapping: Dictionary = {}
	for bone in ["hips", "head", "spine", "leftHand", "rightHand", "leftFoot", "rightFoot", "leftUpperArm", "rightUpperArm", "leftLowerArm", "rightLowerArm", "leftUpperLeg", "rightUpperLeg", "leftLowerLeg", "rightLowerLeg"]:
		skeleton.add_bone(bone)
		mapping[bone] = bone
	avatar.add_child(skeleton)
	avatar.set_meta("humanoid_bones", mapping)
	body.avatar_model = avatar
	body.add_child(avatar)
	root.add_child(body)
	body.add_to_group("player")
	var controller = load("res://scripts/assets/animation_controller.gd").new()
	root.add_child(controller)
	controller.configure(network, null)
	controller._update_locomotion()
	check(controller.local_state.get("kind") == "locomotion" and controller.local_state.get("action") == "resolved", "actual equipped synthetic avatar receives automatic resolved playback without menu")
	check(controller.request_emote("builtin:dance") and controller.local_state.kind == "emote", "emote request uses same actual avatar animation layer")
	var layer = controller.local_animator
	body.velocity = Vector3(1, 0, 0)
	controller._update_locomotion()
	check(controller.active_emote.is_empty() and controller.local_state.kind == "locomotion" and controller.local_animator == layer, "movement interrupts emote and restores automatic state on same layer")
	controller.queue_free()
	body.queue_free()
	network.queue_free()
	await process_frame

func test_wheel():
	var layout = load("res://scripts/assets/emote_layout.gd").new()
	layout.configure("res://wheel.json")
	var group = layout.add_group("root", "Many dances")
	var catalog: Dictionary = {}
	for i in 17:
		layout.add_emote(group, "dance:%s" % i, "Dance %s" % i)
		catalog["dance:%s" % i] = {"name": "Dance %s" % i}
	check(layout.page_count(group) == 4, "17 entries paginate into four five-content pages")
	var sectors = layout.sectors(group, 0)
	check(sectors.size() == 8 and sectors[3].type == "next" and sectors[4].type == "indicator" and sectors[5].type == "previous", "paging replaces three in-wheel sectors, never adds footer buttons")
	check(sectors[5].disabled and not sectors[3].disabled, "first-page Previous disabled, Next enabled")
	check(layout.sectors(group, 3)[3].disabled, "last-page Next disabled")
	var wheel = load("res://scripts/GUI/emote_wheel.gd").new()
	root.add_child(wheel)
	wheel.open(layout, catalog, false)
	var changes: Array = []
	wheel.emote_selected.connect(func(id): changes.append(id))
	var group_sector = layout.groups.root.entries.size() - 1
	wheel.activate_sector(group_sector)
	check(wheel.group == group and changes.is_empty(), "entering a group navigates without choosing an emote")
	wheel.activate_sector(3)
	check(wheel.page == 1 and wheel.hovered == -1 and changes.is_empty(), "Next pages inside circle and clears selection without animation")
	wheel.activate_sector(4)
	check(changes.is_empty() and wheel.page == 1, "page indicator is non-activating")
	wheel.activate_sector(0)
	check(changes == ["dance:5"], "content wedge selects correct stable action on page two")
	wheel.back()
	check(wheel.group == "root" and wheel.page == 0, "Back restores parent page")
	var nested = layout.add_group(group, "Nested")
	check(not nested.is_empty(), "groups can contain more groups")
	var candidate = layout.groups.duplicate(true)
	candidate[nested].entries.append({"type": "group", "id": "root", "name": "Cycle"})
	check(not layout.commit(candidate), "cyclic nested group graph rejected")
	var restored = load("res://scripts/assets/emote_layout.gd").new()
	restored.configure("res://wheel.json")
	check(restored.groups.has(nested) and restored.groups[group].entries.size() == 18, "nested layout and ordered entries persist")
	for count in [0, 1, 5, 8, 9, 10, 11, 17]:
		var candidate_layout = load("res://scripts/assets/emote_layout.gd").new()
		candidate_layout.groups.root.entries.clear()
		for i in count:
			candidate_layout.groups.root.entries.append({"type": "emote", "id": str(i), "name": str(i)})
		var expected = int(ceil(count / 5.0)) if count > 8 else 1
		check(candidate_layout.page_count("root") == expected and candidate_layout.sectors("root", 0).size() == 8,
			"eight-sector pagination boundary: %s entries" % count)
	var broken_file = FileAccess.open("res://broken-wheel.json", FileAccess.WRITE)
	broken_file.store_string("not json")
	broken_file.close()
	var broken = load("res://scripts/assets/emote_layout.gd").new()
	broken.configure("res://broken-wheel.json")
	check(not broken.writable and FileAccess.get_file_as_string("res://broken-wheel.json") == "not json", "corrupt wheel preserved while default layout remains usable")
	wheel.dismiss()
	wheel.queue_free()
	await process_frame

func test_ui(bytes: PackedByteArray):
	var loader = root.get_node("DataLoader")
	loader.get_asset_cache().initialize("res://cache")
	var configuration = loader.get_avatar_configuration()
	configuration.configure("test-account", "res://avatar.json", loader)
	var menu = load("res://scenes/GUI/animation_menue.tscn").instantiate()
	root.add_child(menu)
	check(menu.draft_sources.is_empty() and not menu.has_method("play"), "source-only avatar editor has no manual player")
	var file = FileAccess.open("res://motion.vrma", FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	await menu.add_source("res://motion.vrma", false)
	check(menu.draft_sources.size() == 1, "actual file import adds external source to draft")
	check(not menu.draft_sources[0].share, "newly imported file never silently grants redistribution consent")
	check(not loader.animation_import_busy and loader.animation_thread == null, "runtime animation worker is joined without blocking main loop")
	await menu.apply()
	check(configuration.emotes.size() == 3 and configuration.sources.size() == 1, "Apply resolves non-basic clip without changing locomotion defaults")
	menu.queue_free()
	await process_frame
	menu = load("res://scenes/GUI/animation_menue.tscn").instantiate()
	root.add_child(menu)
	check(menu.draft_sources.size() == 1, "applied source configuration restores when page reopens")
	var disk = load("res://scripts/assets/avatar_configuration.gd").new()
	root.add_child(disk)
	disk.configure("test-account", "res://avatar.json", loader)
	for i in 100:
		if disk.emotes.size() == 3: break
		await process_frame
	check(disk.sources.size() == 1 and disk.emotes.size() == 3, "account-scoped sources and role catalog restore from disk")
	disk.queue_free()
	var editor = load("res://scripts/GUI/emote_layout_editor.gd").new()
	menu.add_child(editor)
	editor.configure(configuration)
	check(editor.group_choice.item_count == 3, "actual wheel editor exposes root, Dances and applied imported actions group")
	editor.queue_free()
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
	check(controller.resolve_motion(true, Vector3.ZERO, 1000) == "idle", "automatic state starts idle without opening a menu")
	check(controller.resolve_motion(true, Vector3(2, 0, 0), 1100) == "walk", "movement resolves automatic walk")
	check(controller.resolve_motion(false, Vector3(0, 2, 0), 1200) == "jump", "upward airborne state resolves jump")
	check(controller.resolve_motion(false, Vector3(0, -2, 0), 1300) == "fall", "descending airborne state resolves fall")
	check(controller.resolve_motion(true, Vector3.ZERO, 1400) == "land" and controller.resolve_motion(true, Vector3.ZERO, 1800) == "idle", "landing transition expires and returns to idle")
	controller.assets[parsed.hash] = {"parsed": parsed}
	var value = {"op": "state", "session_id": "test", "version": 2, "peer_id": 7,
		"generation": "a".repeat(32), "sequence": 1, "action": "resolved", "kind": "emote", "role": "turn", "mask": "full", "avatar_revision": "", "configuration_revision": 0, "offset": 0.5,
		"speed": 1.0, "loop": true, "duration": 1.0, "builtin": "", "hash": parsed.hash,
		"size": 1024, "clip": 0, "started": controller.now()}
	controller.receive(value)
	check(controller.remote_animators.has(7), "production client controller attaches remote animation layer")
	check(controller.remote_animators[7].player.current_animation_position >= 0.5, "production receiver seeks late-loaded motion to current playhead")
	value.sequence = 2
	value.action = "pause"
	controller.receive(value)
	check(controller.remote_states[7].sequence == 1, "production receiver rejects legacy manual pause")
	value.session_id = "other"
	value.sequence = 3
	value.action = "resolved"
	controller.receive(value)
	check(controller.remote_states[7].sequence == 1, "production receiver rejects another instance's state")
	check(not controller.has_method("pause") and not controller.has_method("play"), "controller exposes no parallel manual player API")
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
	var state = {"op": "state", "version": 2, "sequence": 1, "action": "resolved", "kind": "emote", "role": "dance", "mask": "full", "avatar_revision": "", "configuration_revision": 0, "offset": 0.25,
		"speed": 1.0, "loop": true, "duration": 1.0, "builtin": "dance", "hash": "",
		"library": Defaults.LIBRARY, "session_id": clients[0].current_session_id, "peer_id": 254}
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
	state.model_hash = "d".repeat(64)
	state.model_size = data.size()
	clients[0].send_animation(state)
	await pump(server, clients)
	clients[1].send_animation({"op": "request", "asset_kind": "avatar", "session_id": clients[1].current_session_id, "owner": owner, "hash": state.model_hash})
	await pump(server, clients)
	var model_requests = messages[0].filter(func(value): return value.get("op") == "request" and value.get("asset_kind") == "avatar")
	check(model_requests.size() == 1, "same resolved state authorizes separately bounded custom model delivery")
	clients[0].send_animation({"op": "chunk", "asset_kind": "avatar", "session_id": clients[0].current_session_id, "target": recipient,
		"hash": state.model_hash, "offset": 0, "bytes": Marshalls.raw_to_base64(data)})
	await pump(server, clients)
	check(messages[1].filter(func(value): return value.get("op") == "chunk" and value.get("asset_kind") == "avatar").size() == 1, "model chunks retain asset kind through ephemeral relay")
	state.sequence = 4
	state.action = "pause"
	clients[0].send_animation(state)
	await pump(server, clients)
	check(server.animations.states[owner].action == "resolved" and server.animations.states[owner].sequence == 3, "relay rejects manual pause rather than creating another animation stream")
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
