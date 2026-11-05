extends SceneTree

const Identity = preload("res://scripts/profile/profile_identity.gd")
const WORLD = "https://worlds.example/shared.cne"
const MENU = "res://scenes/GUI/share_session_menue.tscn"
var passed := 0
var failed := 0
var deferred_groups: Array = []
var sequence := 0
var network: Node
var save: Node
var bob_service
var bob := ""
var alice := ""

func _initialize():
	call_deferred("run")

func check(ok: bool, title: String):
	if ok:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func prerequisite(ok: bool, title: String, group: String) -> bool:
	check(ok, title)
	if not ok:
		deferred_groups.append(group)
	return ok

func has_property(object: Object, property: String) -> bool:
	for info in object.get_property_list():
		if info.name == property:
			return true
	return false

func run():
	network = root.get_node("NetworkHandler")
	save = root.get_node("SaveData")
	alice = save.profile.get_local_fingerprint()
	bob_service = load("res://scripts/profile/profile_service.gd").new()
	bob_service.configure(Crypto.new().generate_rsa(2048), "res://unused-bob.cfg")
	bob_service.local["profile.username"] = "Bob"
	bob_service.local["profile.avatar_url"] = "https://avatars.example/bob.vrm"
	bob_service._sign(bob_service.local)
	bob = bob_service.get_local_fingerprint()
	test_labels()
	await test_menu_existing_entry_points()
	await test_coordinator_and_connected_menu()
	await test_editor_and_confirmation()
	test_relay_baseline_and_validation()
	test_snapshot_validation()
	test_local_moderation_persistence()
	await test_wire_management()
	print("\nActive Instance contracts: %d passed, %d failed; %d dependent groups not run" % [passed, failed, deferred_groups.size()])
	for group in deferred_groups:
		print("NOT RUN (missing prerequisite): ", group)
	quit(1 if failed else 0)

func test_labels():
	var state = load("res://scenes/GUI/home_menue.tscn").get_state()
	var title := ""
	var metadata := ""
	for i in state.get_node_count():
		for j in state.get_node_property_count(i):
			var property = str(state.get_node_property_name(i, j))
			if str(state.get_node_name(i)) == "ActiveInstance" and property == "text":
				title = str(state.get_node_property_value(i, j))
			if str(state.get_node_name(i)) == "ActiveInstance" and property == "tooltip_text":
				metadata = str(state.get_node_property_value(i, j))
	check(title == "Active Instance", "shared desktop/VR Home option is titled Active Instance")
	check(not metadata.is_empty(), "Active Instance Home option explains its action")
	var desktop = FileAccess.get_file_as_string("res://scene_inputs/player_desktop.txt")
	check(not 'tab_2/title = "Share Session"' in desktop and not 'tab_2/title = "Session Share"' in desktop,
		"desktop inherited override cannot restore the old tab label")
	var vr = FileAccess.get_file_as_string("res://scene_inputs/player_vr.txt")
	check(not 'tab_2/title = "Share Session"' in vr and not 'tab_2/title = "Session Share"' in vr,
		"VR player has no obsolete session-tab override")

func all_nodes(node: Node) -> Array:
	var found: Array = [node]
	for child in node.get_children():
		if not child.is_queued_for_deletion():
			found.append_array(all_nodes(child))
	return found

func button(node: Node, text: String):
	for child in all_nodes(node):
		if child is Button and child.text == text:
			return child
	return null

func row(node: Node, fingerprint: String):
	for child in all_nodes(node):
		if child.get_meta("fingerprint", "") == fingerprint:
			return child
	return null

func row_ids(node: Node) -> Array:
	var result: Array = []
	for child in all_nodes(node):
		if child.has_meta("fingerprint"):
			result.append(str(child.get_meta("fingerprint")))
	result.sort()
	return result

func texts(node: Node) -> String:
	var result := ""
	for child in all_nodes(node):
		if child is Label or child is Button or child is LineEdit or child is TextEdit:
			result += str(child.text) + "\n"
	return result

func menu() -> Control:
	var scene = load(MENU).instantiate()
	root.add_child(scene)
	return scene

func install_legacy_membership():
	network.peer = RelayPeer.new()
	network.peer.is_connected_to_relay = true
	network.peer.is_authenticated = true
	network.peer.current_session_id = "A"
	network.peer.session_peers = [2]
	network.current_session_id = "A"
	network.session_busy = false
	var profile = bob_service.local.duplicate(true)
	profile.peer_id = 2
	save.profile.replace_remote_profiles("A", [profile])

func snapshot(revision: int = 1, local_role: String = "admin") -> Dictionary:
	return {"session_id": "A", "revision": revision, "world_url": WORLD,
		"name": "Test room", "description": "Room description", "mode": PacketInfo.MODE.PUBLIC,
		"members": [{"peer_id": 1, "fingerprint": alice, "role": local_role},
			{"peer_id": 2, "fingerprint": bob, "role": "member"}]}

func test_menu_existing_entry_points():
	install_legacy_membership()
	var scene = menu()
	await process_frame
	var code = scene.get_node_or_null("VBoxContainer/HBoxContainer/session_id")
	check(code != null and code.text == "A", "opening menu immediately displays acknowledged active session code")
	var expected = [alice, bob]
	expected.sort()
	check(row_ids(scene) == expected, "opening menu lists self and remote participant exactly once by fingerprint")
	check("Alice" in texts(scene) and "Bob" in texts(scene), "roster uses verified profile names, not placeholder peer IDs")
	var bob_row = row(scene, bob)
	check(bob_row != null and button(bob_row, "Bob") != null, "remote player's name is a clickable profile button")
	check("Players (2)" in texts(scene), "header count includes the local participant")
	network._on_relay_disconnected()
	await process_frame
	check(row_ids(scene).is_empty(), "disconnect clears all player rows")
	var copy_button = button(scene, "Copy code")
	check(copy_button != null and copy_button.disabled, "Copy code is disabled with no active instance")
	check("No active instance" in texts(scene), "disconnect shows an explicit no-active-instance state")
	scene.free()

func test_coordinator_and_connected_menu():
	var supports_state = has_property(network, "active_instance") \
		and network.has_signal("active_instance_changed") and network.has_method("_on_instance_snapshot")
	if not prerequisite(supports_state,
		"real coordinator exposes authoritative active-instance state and snapshot entry point",
		"coordinator ordering, live menu, profile navigation and admin controls"):
		return
	install_legacy_membership()
	network.call("_on_instance_snapshot", snapshot())
	var scene = menu()
	await process_frame
	check("Test room" in texts(scene) and "Room description" in texts(scene), "instance metadata appears above roster")
	var initial = network.get("active_instance").duplicate(true)
	var other = snapshot(9)
	other.session_id = "B"
	other.name = "Wrong instance"
	network.call("_on_instance_snapshot", other)
	check(network.get("active_instance") == initial, "same-world different-session snapshot is ignored")
	var latest = snapshot(3)
	latest.name = "Latest title"
	network.call("_on_instance_snapshot", latest)
	network.call("_on_instance_snapshot", snapshot(2))
	check(network.get("active_instance").get("name") == "Latest title", "older instance revision cannot overwrite newer state")
	var malformed = snapshot(99)
	malformed.members = "not a roster"
	network.call("_on_instance_snapshot", malformed)
	check(network.get("active_instance") == latest, "malformed snapshot cannot replace usable authoritative state")
	var same_revision = latest.duplicate(true)
	same_revision.name = "Conflicting replay"
	network.call("_on_instance_snapshot", same_revision)
	check(network.get("active_instance") == latest, "conflicting replay of an installed revision is ignored")
	check("Latest title" in texts(scene), "open menu reflects new instance metadata without reopening")
	var bob_row = row(scene, bob)
	check(bob_row != null, "live authoritative roster creates Bob's row")
	if bob_row != null:
		var hide_avatar = button(bob_row, "Hide avatar")
		check(hide_avatar != null, "remote roster row offers client-only Hide avatar")
		if hide_avatar != null:
			hide_avatar.pressed.emit()
			check(network.get_avatar_visibility().is_hidden(bob), "roster hide applies identity policy")
			check(button(row(scene, bob), "Show avatar") != null, "roster immediately reflects hidden state")
			button(row(scene, bob), "Show avatar").pressed.emit()
			check(not network.get_avatar_visibility().is_hidden(bob), "roster Show avatar reverses local hide")
			bob_row = row(scene, bob)
		for action in ["Kick", "Ban", "Make admin"]:
			check(button(bob_row, action) != null and not button(bob_row, action).disabled,
				"admin sees enabled " + action + " beside eligible member")
		var profile_button = button(bob_row, "Bob")
		check(profile_button != null, "Bob has an actual clickable name button")
		if profile_button != null:
			profile_button.pressed.emit()
			await process_frame
			var panels: Array = []
			for child in all_nodes(scene):
				if child.has_method("get_displayed_public_key"):
					panels.append(child)
			check(panels.size() == 1 and panels[0].profile_owner == bob and not panels[0].is_editable(),
				"clicking Bob opens exactly his existing read-only account profile")
			if panels.size() == 1:
				panels[0]._close()
				check(scene.is_visible_in_tree(), "profile Back returns to Active Instance")
	var self_row = row(scene, alice)
	check(self_row != null and button(self_row, "Kick") == null and button(self_row, "Ban") == null,
		"self row offers no self-kick or self-ban")
	if self_row != null:
		var self_button = button(self_row, "Alice")
		# A You marker may be included in the clickable name itself.
		if self_button == null:
			for child in all_nodes(self_row):
				if child is Button and "Alice" in child.text:
					self_button = child
		check(self_button != null, "self participant name is also clickable")
		if self_button != null:
			self_button.pressed.emit()
			var own_panel = null
			for child in all_nodes(scene):
				if child.has_method("get_displayed_public_key") and child.is_visible_in_tree():
					own_panel = child
			check(own_panel != null and own_panel.profile_owner == alice and own_panel.is_editable(),
				"self row opens owner-editable profile without granting remote edit rights")
			if own_panel != null:
				own_panel._close()
	save.profile.clear_remote_profiles()
	await process_frame
	var expected = [alice, bob]
	expected.sort()
	check(row_ids(scene) == expected and "Players (2)" in texts(scene),
		"missing signed remote profile retains placeholder member and complete player count")
	var updated_profile = bob_service.local.duplicate(true)
	updated_profile["profile.username"] = "Alice"
	updated_profile.revision += 1
	bob_service._sign(updated_profile)
	updated_profile.peer_id = 2
	save.profile.replace_remote_profiles("A", [updated_profile])
	await process_frame
	check(row_ids(scene) == expected, "two identical display names remain separate fingerprint-keyed members")
	network.call("_on_instance_snapshot", snapshot(4, "member"))
	await process_frame
	check(button(scene, "Kick") == null and button(scene, "Ban") == null and button(scene, "Make admin") == null,
		"losing admin rights immediately removes moderation controls")
	check(button(scene, "Save") == null or button(scene, "Save").disabled,
		"ordinary member cannot save instance metadata")
	var departed = snapshot(5, "member")
	departed.members = [departed.members[0]]
	network.call("_on_instance_snapshot", departed)
	check(row(scene, bob) == null and "Players (1)" in texts(scene), "membership departure updates list/count without waiting for profiles")
	scene.free()
	scene = menu()
	await process_frame
	check(row_ids(scene) == [alice], "reopening renders latest roster without duplicate subscriptions/rows")
	network._on_relay_disconnected()
	check(network.get("active_instance").is_empty() and row_ids(scene).is_empty(), "disconnect clears authoritative state and open menu")
	scene.free()

func room(id: String, members: Array, admins: Array) -> Dictionary:
	return {"session_id": id, "world_url": WORLD, "mode": PacketInfo.MODE.PUBLIC,
		"name": "Test room", "description": "Room description", "peers": members, "owners": admins}

func test_editor_and_confirmation():
	install_legacy_membership()
	var sink = load("res://fixtures/request_sink.gd").new()
	var connection = ENetConnection.new()
	connection.create_host(1)
	sink.peer = connection.connect_to_host("127.0.0.1", 9)
	sink.is_authenticated = true
	sink.is_connected_to_relay = true
	sink.current_session_id = "A"
	network.peer = sink
	network._on_instance_snapshot(snapshot())
	var scene = menu()
	await process_frame
	sink.sent.clear()
	button(scene, "Edit instance").pressed.emit()
	scene.name_input.text = "Unsaved"
	button(scene, "Cancel").pressed.emit()
	check(sink.sent.is_empty() and not scene.editor.visible and network.active_instance.name == "Test room",
		"actual editor Cancel discards draft without sending a request")
	button(scene, "Edit instance").pressed.emit()
	scene.name_input.text = " "
	button(scene, "Save").pressed.emit()
	check(sink.sent.is_empty() and scene.editor.visible, "actual Save rejects blank name locally and preserves editor")
	scene.name_input.text = "Saved title"
	scene.description_input.text = "Saved description"
	scene.type_input.select(1)
	button(scene, "Save").pressed.emit()
	check(sink.sent.size() == 1 and sink.sent[0].action == "update_metadata" and sink.sent[0].session_id == "A" \
		and sink.sent[0].expected_revision == 1 and sink.sent[0].changes == {"name": "Saved title", "description": "Saved description", "mode": 1},
		"real Save sends exact metadata draft through production coordinator")
	check(scene.save_button.disabled and network.active_instance.name == "Test room", "pending Save disables repeats without optimistic metadata mutation")
	var request_id = sink.sent[0].request_id
	network._on_instance_result({"request_id": "unrelated", "session_id": "A", "success": true})
	check(not network.management_pending.is_empty(), "unmatched management result cannot finish pending Save")
	network._on_instance_result({"request_id": request_id, "session_id": "A", "success": false, "message": "Rejected by relay"})
	check(scene.editor.visible and scene.name_input.text == "Saved title" and "Rejected" in scene.status.text,
		"rejected Save preserves draft and displays relay error")
	button(scene, "Cancel").pressed.emit()
	button(scene, "Edit instance").pressed.emit()
	scene.name_input.text = "My draft"
	var changed = snapshot(2)
	changed.name = "Other admin's edit"
	network._on_instance_snapshot(changed)
	check(scene.name_input.text == "My draft" and scene.save_button.disabled, "concurrent edit preserves dirty draft but blocks stale Save")
	button(scene, "Cancel").pressed.emit()
	button(scene, "Edit instance").pressed.emit()
	check(scene.name_input.text == changed.name, "reopening editor reloads current authoritative metadata")
	check(not scene.type_input.is_item_disabled(2) and not scene.type_input.is_item_disabled(3) \
		and not scene.type_input.is_item_disabled(4), "Friends, Friends+ and Request types are selectable in real instance editor")
	var join_token = "b".repeat(64)
	sink.on_packet(AccountPacket.create(PacketInfo.PACKET_TYPE.JOIN_REQUEST, {"token": join_token,
		"session_id": "A", "fingerprint": bob}).encode())
	check(button(scene.request_list, "Allow") != null and button(scene.request_list, "Decline") != null,
		"real request packet renders Allow and Decline actions for instance admin")
	sink.on_packet(AccountPacket.create(PacketInfo.PACKET_TYPE.JOIN_REQUEST, {"token": join_token,
		"session_id": "A", "closed": true}).encode())
	check(scene.request_list.get_child_count() == 0, "closed request packet removes stale admin approval row")
	button(scene, "Cancel").pressed.emit()
	sink.sent.clear()
	var target_row = row(scene, bob)
	button(target_row, "Ban").pressed.emit()
	check(scene.confirmation.visible and bob in scene.confirmation.dialog_text and sink.sent.is_empty(),
		"Ban button asks confirmation with stable identity before sending")
	scene.confirmation.confirmed.emit()
	check(sink.sent.size() == 1 and sink.sent[0].action == "ban" and sink.sent[0].target_fingerprint == bob \
		and sink.sent[0].target_peer_id == 2, "confirmed Ban sends exact selected account and peer guard")
	network.management_pending.deadline = 0
	network._process(0)
	check(network.management_pending.is_empty() and network.active_instance.is_empty() and "outcome unknown" in network.instance_status,
		"management timeout removes actionable stale permissions and reports uncertain outcome")
	check(sink.sent.size() == 2 and sink.sent[1].action == "refresh", "timeout requests resync instead of replaying mutation")
	network._on_instance_snapshot(changed)
	check(network.active_instance == changed and network.snapshot_deadline == 0, "authoritative refresh restores usable state after timeout")
	network._on_instance_evicted({"session_id": "A", "reason": "banned"})
	check(network.current_session_id.is_empty() and network.active_instance.is_empty() and save.profile.remote.is_empty() \
		and network.get_child_count() == 0 and sink.is_connected_to_relay, "real coordinator eviction clears profiles/avatars/state while preserving relay")
	scene.free()
	connection.destroy()

func test_relay_baseline_and_validation():
	# No tree insertion: production _ready() would bind the normal relay port.
	var relay = load("res://scripts/multiplayer/relay.gd").new()
	relay.sessions = [[room("A", [1, 2], [1])], [room("B", [3], [3])]]
	var summaries = relay.get_public_session()
	check(summaries.size() == 2 and summaries[0].session_id != summaries[1].session_id,
		"baseline: same world URL retains two separate instance identities")
	check(summaries.all(func(value): return not value.has("peers") and not value.has("owners") and not value.has("bans")),
		"baseline: public discovery does not leak roster, admin IDs or bans")
	relay.remove_user_from_session(1, 0)
	check(relay.sessions[0][0].owners == [2], "baseline: last admin departure promotes remaining participant")
	var metadata = room("new", [], [])
	metadata.name = " \t "
	check(not relay.valid_creation(metadata), "instance name validation rejects whitespace-only names")
	metadata.name = "a".repeat(129)
	check(not relay.valid_creation(metadata), "baseline: oversized name is rejected")
	metadata.name = "Valid"
	metadata.description = "a".repeat(2049)
	check(not relay.valid_creation(metadata), "baseline: oversized description is rejected")
	relay.free()

func pump(relay: Node, clients: Array, rounds: int = 30):
	for i in rounds:
		relay.handle_events()
		for client in clients:
			client.handle_events()
		await create_timer(0.003).timeout

func test_snapshot_validation():
	check(InstanceState.valid(snapshot()), "snapshot validator accepts complete bounded state")
	for invalid in ["z".repeat(64), "a".repeat(63), "", 42]:
		var state = snapshot()
		state.members[0].fingerprint = invalid
		check(not InstanceState.valid(state), "invalid fingerprint rejected without decoder/runtime errors: " + str(invalid))
	var duplicate = snapshot()
	duplicate.members.append(duplicate.members[0].duplicate())
	check(not InstanceState.valid(duplicate), "duplicate membership identities cannot inflate roster/count")
	var bad_id = snapshot()
	bad_id.members[0].peer_id = 0.5
	check(not InstanceState.valid(bad_id), "fractional wire peer ID is rejected")
	var bad_role = snapshot()
	bad_role.members[0].role = "owner"
	check(not InstanceState.valid(bad_role), "unknown role is rejected rather than granting permissions")

func test_local_moderation_persistence():
	var client = RelayPeer.new()
	client.account_key = save.key
	client.configure_moderation("res://moderation-test.cfg")
	var policy_id = "a".repeat(64)
	client.moderation_policy[policy_id] = {bob: true}
	check(client._save_moderation(), "client-owned ban policy writes to isolated local store")
	var restored = RelayPeer.new()
	restored.account_key = save.key
	restored.configure_moderation("res://moderation-test.cfg")
	check(restored.moderation_policy == client.moderation_policy, "client moderation history survives client restart")
	var other = RelayPeer.new()
	other.account_key = bob_service.private_key
	other.configure_moderation("res://moderation-test.cfg")
	check(not other.moderation_error.is_empty() and other.moderation_policy.is_empty() and not other._save_moderation(),
		"wrong account cannot adopt or overwrite local moderation history")
	var corrupt = FileAccess.open("res://bad-moderation.cfg", FileAccess.WRITE)
	corrupt.store_string("broken config [")
	corrupt.close()
	other.configure_moderation("res://bad-moderation.cfg")
	check(not other.moderation_error.is_empty() and not other._save_moderation() \
		and FileAccess.get_file_as_string("res://bad-moderation.cfg") == "broken config [",
		"corrupt moderation store is preserved and blocks automatic admission approval")

func fingerprint(client) -> String:
	return Identity.fingerprint(client.account_key.save_to_string(true))

func peer_id(relay: Node, client) -> int:
	for id in relay.key_mapping:
		if relay.key_mapping[id].fingerprint == fingerprint(client):
			return int(id)
	return -1

func request(client, action: String, session: String, revision: int, target = null, changes: Dictionary = {}, request_id: String = "") -> Dictionary:
	sequence += 1
	var payload = {"request_id": request_id if not request_id.is_empty() else "test-%d" % sequence,
		"session_id": session, "expected_revision": revision, "action": action, "changes": changes}
	if target != null:
		payload.target_fingerprint = target.fingerprint
		payload.target_peer_id = target.peer_id
	var bytes = PackedByteArray([PacketInfo.PACKET_TYPE.get("INSTANCE_REQUEST")])
	bytes.append_array(JSON.stringify(payload).to_utf8_buffer())
	client.peer.send(0, bytes, ENetPacketPeer.FLAG_RELIABLE)
	return payload

func response(client, payload: Dictionary) -> Dictionary:
	for value in client.received.get("INSTANCE_RESULT", []):
		if value.get("request_id") == payload.request_id and value.get("session_id") == payload.session_id:
			return value
	return {}

func revision(client) -> int:
	return int(client.latest("INSTANCE_SNAPSHOT").get("revision", -1))

func allowed(client, payload: Dictionary) -> bool:
	return response(client, payload).get("success") == true

func denied(client, payload: Dictionary) -> bool:
	var result = response(client, payload)
	return result.get("success") == false and not str(result.get("error_code", "")).is_empty()

func test_wire_management():
	var files_before = list_files("res://")
	var relay = load("res://scripts/multiplayer/relay.gd").new()
	relay.connection = ENetConnection.new()
	if relay.connection.create_host_bound("127.0.0.1", 0) != OK:
		push_error("Could not bind loopback test relay")
		relay.free()
		return
	var clients: Array = []
	for i in 4:
		var client = load("res://fixtures/recording_peer.gd").new()
		client.account_key = Crypto.new().generate_rsa(2048)
		client.connect_to_relay("127.0.0.1", relay.connection.get_local_port())
		clients.append(client)
	for attempt in 100:
		await pump(relay, clients, 1)
		if clients.all(func(client): return client.is_authenticated):
			break
	if not clients.all(func(client): return client.is_authenticated):
		push_error("Four loopback clients could not authenticate")
	else:
		check(true, "baseline: four real ENet clients authenticate with ephemeral accounts")
		clients[0].create_session(PacketInfo.MODE.PUBLIC, "Room A", "First", WORLD)
		clients[2].create_session(PacketInfo.MODE.PUBLIC, "Room B", "Second", WORLD)
		await pump(relay, clients)
		var a: String = clients[0].current_session_id
		var b: String = clients[2].current_session_id
		check(not a.is_empty() and not b.is_empty() and a != b, "baseline: real relay creates distinct instances of the same world")
		clients[1].join_session(a, WORLD)
		clients[3].join_session(a, WORLD)
		await pump(relay, clients)
		check(clients[0].session_peers.size() == 2 and clients[2].session_peers.is_empty(),
			"baseline: membership exchange is confined to exact instance")
		var available := true
		for name in ["INSTANCE_REQUEST", "INSTANCE_RESULT", "INSTANCE_SNAPSHOT", "INSTANCE_EVICTED"]:
			if not prerequisite(PacketInfo.PACKET_TYPE.has(name), "protocol declares " + name, name + " wire-dependent contracts"):
				available = false
		if available:
			await exercise_management(relay, clients, a, b)
	for client in clients:
		if client.peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
			client.peer.peer_disconnect()
	await pump(relay, clients)
	for client in clients:
		client.connection.destroy()
	relay.connection.destroy()
	relay.free()
	check(list_files("res://") == files_before, "loopback relay lifecycle creates no persistent project data")

func list_files(path: String) -> Array:
	var result: Array = []
	for file in DirAccess.get_files_at(path):
		result.append(path.path_join(file))
	for directory in DirAccess.get_directories_at(path):
		if directory != ".godot":
			result.append_array(list_files(path.path_join(directory)))
	result.sort()
	return result

func exercise_management(relay: Node, clients: Array, a: String, b: String):
	var admin = clients[0]
	var member = clients[1]
	var outsider = clients[2]
	var target = clients[3]
	var voices: Array = []
	var target_voices: Array = []
	var outside_voices: Array = []
	member.voice_data.connect(func(value): voices.append(value.audio))
	target.voice_data.connect(func(value): target_voices.append(value.audio))
	outsider.voice_data.connect(func(value): outside_voices.append(value.audio))
	var samples = PackedFloat32Array([0.0, 0.125, -0.125, 0.25, -0.25])
	VoiceData.create(255, samples).sent(target.peer)
	await pump(relay, clients)
	check(voices.size() == 1 and voices[0].size() == samples.size() and outside_voices.is_empty(),
		"voice packets reach same-instance client but not another instance")
	var target_info = {"fingerprint": fingerprint(target), "peer_id": peer_id(relay, target)}
	var state = admin.latest("INSTANCE_SNAPSHOT")
	var members: Array = state.get("members", [])
	var expected = [fingerprint(admin), fingerprint(member), fingerprint(target)]
	expected.sort()
	var actual: Array = []
	for value in members:
		actual.append(value.get("fingerprint"))
	actual.sort()
	if not prerequisite(state.get("session_id") == a and actual == expected and revision(admin) >= 0,
		"wire snapshot includes complete authoritative roster including recipient, with revision",
		"management mutations requiring an initial authoritative snapshot"):
		return
	check(outsider.latest("INSTANCE_SNAPSHOT").get("session_id") == b, "other same-world instance receives only its own snapshot")
	var initial = state.duplicate(true)
	for action in ["kick", "ban", "make_admin", "update_metadata"]:
		var payload = request(member, action, a, revision(admin), target_info, {"name": "Forged"})
		await pump(relay, clients)
		check(denied(member, payload) and admin.latest("INSTANCE_SNAPSHOT") == initial,
			"relay denies non-admin " + action + " without changing state")
	var payload = request(outsider, "kick", a, revision(admin), target_info)
	await pump(relay, clients)
	check(denied(outsider, payload) and admin.latest("INSTANCE_SNAPSHOT") == initial, "admin from another instance cannot moderate this instance")
	for action in ["kick", "ban"]:
		payload = request(admin, action, a, revision(admin), {"fingerprint": fingerprint(admin), "peer_id": peer_id(relay, admin)})
		await pump(relay, clients)
		check(denied(admin, payload) and admin.latest("INSTANCE_SNAPSHOT") == initial, "relay rejects self-" + action)
	payload = request(admin, "unknown_action", a, revision(admin), target_info)
	await pump(relay, clients)
	check(denied(admin, payload) and admin.latest("INSTANCE_SNAPSHOT") == initial, "unknown management action is rejected without mutation")
	var wrong_identity = target_info.duplicate()
	wrong_identity.fingerprint = fingerprint(outsider)
	payload = request(admin, "kick", a, revision(admin), wrong_identity)
	await pump(relay, clients)
	check(denied(admin, payload) and admin.latest("INSTANCE_SNAPSHOT") == initial, "peer ID plus wrong fingerprint cannot redirect moderation")
	payload = request(admin, "update_metadata", a, revision(admin), null, {"name": " ", "description": "Invalid"})
	await pump(relay, clients)
	check(denied(admin, payload) and admin.latest("INSTANCE_SNAPSHOT") == initial, "metadata update uses strict shared name validation")
	for changes in [{"name": "a".repeat(129)}, {"description": "a".repeat(2049)}, {"mode": 999}, {"name": 42}]:
		payload = request(admin, "update_metadata", a, revision(admin), null, changes)
		await pump(relay, clients)
		check(denied(admin, payload) and admin.latest("INSTANCE_SNAPSHOT") == initial,
			"invalid metadata is rejected atomically: " + str(changes.keys()))
	payload = request(admin, "update_metadata", a, revision(admin), null, {"world_url": "https://worlds.example/other.cne"})
	await pump(relay, clients)
	check(denied(admin, payload) and admin.latest("INSTANCE_SNAPSHOT") == initial, "metadata cannot change immutable world identity")
	var old_revision = revision(admin)
	payload = request(admin, "update_metadata", a, old_revision, null, {"name": "Renamed", "description": "Edited", "mode": PacketInfo.MODE.PRIVAT})
	await pump(relay, clients)
	state = admin.latest("INSTANCE_SNAPSHOT")
	check(allowed(admin, payload) and state.get("name") == "Renamed" and state.get("description") == "Edited" \
		and state.get("mode") == PacketInfo.MODE.PRIVAT and revision(admin) > old_revision,
		"admin edits name, description and type with correlated acknowledgement and newer revision")
	check(member.latest("INSTANCE_SNAPSHOT") == state and outsider.latest("INSTANCE_SNAPSHOT").get("name") == "Room B",
		"metadata propagates only to exact-instance participants")
	GetPublicSessions.create([]).sent(outsider.peer)
	await pump(relay, clients)
	check(outsider.public_session.all(func(value): return value.session_id != a), "public-to-private edit removes instance from discovery")
	payload = request(admin, "update_metadata", a, old_revision, null, {"name": "Stale"})
	await pump(relay, clients)
	check(denied(admin, payload) and admin.latest("INSTANCE_SNAPSHOT") == state, "stale admin revision cannot overwrite a concurrent edit")
	payload = request(admin, "update_metadata", a, revision(admin), null, {"mode": PacketInfo.MODE.PUBLIC})
	await pump(relay, clients)
	check(allowed(admin, payload), "admin can restore Public without changing session identity")
	GetPublicSessions.create([]).sent(outsider.peer)
	await pump(relay, clients)
	var visible := false
	for value in outsider.public_session:
		if value.session_id == a:
			visible = value.name == "Renamed" and value.description == "Edited" and not value.has("members")
	check(visible, "restored public instance advertises edited metadata without member roster")
	payload = request(admin, "make_admin", a, revision(admin), {"fingerprint": fingerprint(member), "peer_id": peer_id(relay, member)})
	await pump(relay, clients)
	var promoted := false
	for value in member.latest("INSTANCE_SNAPSHOT").get("members", []):
		if value.get("fingerprint") == fingerprint(member):
			promoted = value.get("role") == "admin"
	check(allowed(admin, payload) and promoted, "Make admin updates target's relay-owned role")
	var promotion_revision = revision(admin)
	payload = request(admin, "make_admin", a, promotion_revision, {"fingerprint": fingerprint(member), "peer_id": peer_id(relay, member)})
	await pump(relay, clients)
	check(denied(admin, payload) and revision(admin) == promotion_revision, "promoting an existing admin is rejected without revision churn")
	payload = request(member, "kick", a, revision(member), target_info)
	await pump(relay, clients)
	check(allowed(member, payload) and relay.get_user_in_session(target_info.peer_id) == -1,
		"promoted admin can kick target out of exact instance")
	check(target.latest("INSTANCE_EVICTED").get("reason") == "kicked" and target.is_connected_to_relay \
		and target.current_session_id.is_empty() and target.session_peers.is_empty(),
		"kick clears victim membership and reports reason without disconnecting relay")
	var before = voices.size()
	VoiceData.create(255, samples).sent(target.peer)
	VoiceData.create(255, samples).sent(member.peer)
	await pump(relay, clients)
	check(voices.size() == before and target_voices.is_empty(), "evicted client can neither send nor receive instance voice on real wire")
	target.join_session(a, WORLD)
	await pump(relay, clients)
	check(target.current_session_id == a, "kicked account may explicitly rejoin")
	var ban_revision = revision(admin)
	payload = request(admin, "ban", a, ban_revision, target_info)
	await pump(relay, clients)
	check(allowed(admin, payload) and target.latest("INSTANCE_EVICTED").get("reason") == "banned", "ban removes target with explicit eviction reason")
	var after_ban = revision(admin)
	request(admin, "ban", a, ban_revision, target_info, {}, payload.request_id)
	await pump(relay, clients)
	check(allowed(admin, payload) and revision(admin) == after_ban, "same request ID retry does not apply ban twice or increment revision")
	var key = target.account_key
	var departed_fingerprint = fingerprint(target)
	var departed_key = key.save_to_string(true)
	var departed_id = target_info.peer_id
	check(admin.moderation_policy.values().any(func(value): return value.has(departed_fingerprint)),
		"ban history is held by moderator client before target disconnect")
	check(not relay.instance_results.is_empty(), "disconnect test starts with populated management caches")
	target.peer.peer_disconnect()
	await pump(relay, clients)
	check(not relay.key_mapping.has(departed_id) and not relay.public_profiles.has(departed_id) \
		and not relay.authenticator.identities.has(departed_id) and not relay.authenticator.challenges.has(departed_id),
		"disconnect deletes authentication, profile and challenge mappings")
	check(relay.instance_results.is_empty() and not relay.instance_rates.has(departed_id),
		"disconnect removes cross-user management payloads and departed rate state")
	var serialized = JSON.stringify([relay.sessions, relay.key_mapping, relay.public_profiles, relay.instance_results,
		relay.instance_rates, relay.admissions, relay.authenticator.identities, relay.authenticator.challenges])
	check(not departed_fingerprint in serialized and not departed_key in serialized,
		"no disconnected account key/fingerprint remains in relay application collections")
	check(relay.sessions.all(func(value): return not value[0].get("bans", {}).has(departed_fingerprint)),
		"relay deletes even in-memory ban record on account disconnect")
	target.connection.destroy()
	var reconnect = load("res://fixtures/recording_peer.gd").new()
	reconnect.account_key = key
	reconnect.connect_to_relay("127.0.0.1", relay.connection.get_local_port())
	clients[3] = reconnect
	await pump(relay, clients, 100)
	check(reconnect.is_authenticated, "banned account may still authenticate to relay")
	reconnect.join_session(a, WORLD)
	await pump(relay, clients)
	check(reconnect.current_session_id.is_empty() and relay.get_user_in_session(peer_id(relay, reconnect)) == -1,
		"client-owned moderator policy rejects banned account after fresh relay authentication")
	check(relay.admissions.is_empty(), "completed admission leaves no pending candidate records")
	reconnect.join_session(b, WORLD)
	await pump(relay, clients)
	check(reconnect.current_session_id == b, "instance ban does not prohibit a different instance of the same world")
	var saved_policy = member.moderation_policy.duplicate(true)
	member.moderation_policy.clear()
	outsider.join_session(a, WORLD)
	await pump(relay, clients)
	check(outsider.current_session_id == b and relay.admissions.is_empty(),
		"missing moderator policy fails closed and preserves candidate's previous instance")
	member.moderation_policy = saved_policy
	member.service_admissions = false
	outsider.join_session(a, WORLD)
	await pump(relay, clients)
	check(relay.admissions.size() == 1 and outsider.current_session_id == b,
		"pending candidate is unadmitted until every current admin approves")
	for value in relay.admissions.values():
		value.deadline = 0
	await pump(relay, clients)
	check(relay.admissions.is_empty() and outsider.current_session_id == b,
		"unavailable moderator admission times out without exposing instance membership")
	outsider.join_session(a, WORLD)
	await pump(relay, clients)
	var outsider_fingerprint = fingerprint(outsider)
	outsider.peer.peer_disconnect()
	await pump(relay, clients)
	check(relay.admissions.is_empty() and not outsider_fingerprint in JSON.stringify([relay.sessions, relay.key_mapping, relay.admissions]),
		"candidate disconnect clears pending admissions and identifying cross-references")
	member.service_admissions = true
	var name = "Private author identity"
	payload = request(admin, "update_metadata", a, revision(admin), null, {"name": name, "description": "Private author text"})
	await pump(relay, clients)
	var admin_server_peer = relay.peers[peer_id(relay, admin)]
	admin.peer.peer_disconnect()
	await pump(relay, clients)
	var remaining_index = relay.get_session_index(a)
	check(remaining_index != -1 and relay.sessions[remaining_index][0].name == "Active instance" \
		and relay.sessions[remaining_index][0].description.is_empty(),
		"departed author's instance name/description are cleared while instance survives")
	var available = relay.availabil_peer_ids.size()
	relay.peer_disconnected(admin_server_peer)
	check(relay.availabil_peer_ids.size() == available, "disconnect cleanup is idempotent and cannot double-release peer ID")
	var fresh = load("res://scripts/multiplayer/relay.gd").new()
	check(fresh.sessions.is_empty() and fresh.key_mapping.is_empty() and fresh.instance_results.is_empty() \
		and fresh.admissions.is_empty(), "fresh relay has no persisted account/session/moderation history")
	fresh.free()
