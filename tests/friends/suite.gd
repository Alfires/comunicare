extends SceneTree

const Service = preload("res://scripts/profile/friend_service.gd")
const Identity = preload("res://scripts/profile/profile_identity.gd")
var passed := 0
var failed := 0
var keys: Array = []
var services: Array = []
var clients: Array = []
var relay: Node

func _initialize():
	call_deferred("run")

func check(ok: bool, text: String):
	if ok:
		passed += 1
		print("PASS: ", text)
	else:
		failed += 1
		print("FAIL: ", text)

func run():
	for i in 3:
		keys.append(Crypto.new().generate_rsa(2048))
		var service = Service.new()
		service.configure(keys[i], "res://friends-%d.cfg" % i)
		services.append(service)
	test_storage()
	test_consent()
	test_additional_contracts()
	await test_network()
	await test_ui()
	print("\nFriends contracts: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func fp(i: int) -> String:
	return Identity.fingerprint(keys[i].save_to_string(true))

func test_storage():
	var a = services[0]
	check(a.add_contact(keys[1].save_to_string(true), "Bob"), "save public-key contact locally")
	check(a.add_contact(keys[1].save_to_string(true)) and a.contacts().size() == 1, "duplicate key does not duplicate contact")
	check(a.relationship(fp(1)).is_empty(), "saving contact does not create request or friendship")
	check(not a.add_contact(keys[0].save_to_string(true)) and not a.add_contact(keys[1].save_to_string(false)), "self and private-key input rejected")
	var restored = Service.new()
	restored.configure(keys[0], "res://friends-0.cfg")
	check(restored.contacts().size() == 1 and restored.label(fp(1)) == "Bob", "contacts and local nickname survive signed-store reload")
	var wrong = Service.new()
	wrong.configure(keys[2], "res://friends-0.cfg")
	check(wrong.write_blocked and wrong.contacts().is_empty(), "wrong account cannot adopt contacts file")
	var text = FileAccess.get_file_as_string("res://friends-0.cfg")
	check(not "PRIVATE KEY" in text, "persistent friend store never contains private key")
	var corrupt = FileAccess.open("res://corrupt.cfg", FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	wrong.configure(keys[2], "res://corrupt.cfg")
	check(wrong.write_blocked and not wrong.add_contact(keys[1].save_to_string(true)) \
		and FileAccess.get_file_as_string("res://corrupt.cfg") == "broken", "corrupt store preserved instead of overwritten")

func test_consent():
	var a = services[0]
	var b = services[1]
	check(a.send_request(fp(1)) and not a.is_friend(fp(1)), "sending request alone never grants friendship")
	var request: Dictionary = a.state.outbox.values()[0]
	b.receive({"op": "event", "event": request})
	check(b.relationship(fp(0)).status == "incoming" and not b.is_friend(fp(0)), "verified request requires recipient acceptance")
	var forged = FriendEvent.create(keys[2], keys[0].save_to_string(true), "accept", request)
	check(not FriendEvent.valid(forged), "third party cannot accept someone else's request")
	check(b.act(fp(0), "accept") and not b.is_friend(fp(0)), "local acceptance waits for durable sender receipt")
	var acceptance: Dictionary = b.state.outbox.values()[0]
	a.receive({"op": "event", "event": acceptance})
	b.receive({"op": "receipt", "event_id": acceptance.event_id, "actor": keys[0].save_to_string(true)})
	check(a.is_friend(fp(1)) and b.is_friend(fp(0)), "matching signed request and acceptance establish mutual friendship")
	check(a.act(fp(1), "revoke") and not a.is_friend(fp(1)), "remove friend revokes locally immediately")
	a.receive({"op": "event", "event": acceptance})
	check(not a.is_friend(fp(1)), "late acceptance cannot resurrect revoked relationship")
	var revoke: Dictionary = a.state.outbox.values().filter(func(value): return value.kind == "revoke")[0]
	b.receive({"op": "event", "event": revoke})
	check(not b.is_friend(fp(0)), "signed revocation removes remote friendship")
	check(a.block(fp(1)) and a.block(fp(1), false) and not a.is_friend(fp(1)), "unblock does not restore old friendship")
	# Fresh request after terminal state; discard delivered test outboxes via receipts.
	for service in services:
		for event in service.state.outbox.values().duplicate():
			service.receive({"op": "receipt", "event_id": event.event_id, "actor": event.recipient})

func pump(rounds: int = 30):
	for i in rounds:
		relay.handle_events()
		for client in clients:
			client.handle_events()
		await create_timer(0.003).timeout

func test_additional_contracts():
	var a = Service.new()
	var b = Service.new()
	a.configure(keys[0], "res://cross-a.cfg")
	b.configure(keys[1], "res://cross-b.cfg")
	a.add_contact(keys[1].save_to_string(true))
	b.add_contact(keys[0].save_to_string(true))
	a.send_request(fp(1))
	b.send_request(fp(0))
	var left: Dictionary = a.state.outbox.values()[0]
	var right: Dictionary = b.state.outbox.values()[0]
	a.receive({"op": "event", "event": right})
	b.receive({"op": "event", "event": left})
	check(not a.is_friend(fp(1)) and not b.is_friend(fp(0)) and a.relationship(fp(1)).status == "incoming",
		"crossed signed requests still require explicit acceptance")
	a.act(fp(1), "accept")
	var acceptance: Dictionary = a.state.outbox.values().filter(func(value): return value.kind == "accept")[0]
	b.receive({"op": "event", "event": acceptance})
	a.receive({"op": "receipt", "event_id": acceptance.event_id, "actor": keys[1].save_to_string(true)})
	check(a.is_friend(fp(1)) and b.is_friend(fp(0)), "explicit acceptance resolves crossed requests")
	a.act(fp(1), "revoke")
	check(not a.is_friend(fp(1)) and a.relationship(fp(1)).is_empty(), "removal closes every active relationship for the account pair")
	var changed_event = left.duplicate(true)
	changed_event.recipient = keys[2].save_to_string(true)
	check(not FriendEvent.valid(changed_event), "altered signed recipient is rejected")
	var extra = left.duplicate(true)
	extra.extra = "unsigned data"
	check(not FriendEvent.valid(extra), "unsigned extra event fields are rejected")
	var original = FileAccess.get_file_as_string("res://cross-a.cfg")
	var parsed = JSON.parse_string(original)
	parsed.data.preferred_status = "offline"
	var file = FileAccess.open("res://tampered.cfg", FileAccess.WRITE)
	file.store_string(JSON.stringify(parsed))
	file.close()
	var tampered = Service.new()
	tampered.configure(keys[0], "res://tampered.cfg")
	check(tampered.write_blocked, "signed store detects edited status/contact data")
	var failure = Service.new()
	failure.configure(keys[0], "res://missing-directory/friends.cfg")
	check(not failure.add_contact(keys[1].save_to_string(true)) and failure.contacts().is_empty(),
		"write failure does not mutate usable local contacts")
	b.block(fp(0))
	var fresh = FriendEvent.create(keys[0], keys[1].save_to_string(true), "request")
	b.receive({"op": "event", "event": fresh})
	check(not b.state.relationships.has(fresh.relationship_id), "blocked accounts cannot fill incoming inbox")
	var c = Service.new()
	c.configure(keys[2], "res://decline.cfg")
	var invitation = FriendEvent.create(keys[0], keys[2].save_to_string(true), "request")
	c.receive({"op": "event", "event": invitation})
	check(c.act(fp(0), "decline") and not c.is_friend(fp(0)) and c.relationship(fp(0)).is_empty(),
		"explicit decline closes incoming request without friendship")
	check(c.send_request(fp(0)) and c.act(fp(0), "cancel") and c.relationship(fp(0)).is_empty(),
		"sender can cancel its own queued request")
	c.set_status("do_not_disturb")
	check(not c.notifications_allowed() and c.state.outbox.size() > 0, "DND disables social interruptions without deleting queued actions")

func test_network():
	relay = load("res://scripts/multiplayer/relay.gd").new()
	relay.connection = ENetConnection.new()
	if relay.connection.create_host_bound("127.0.0.1", 0) != OK:
		push_error("Loopback bind failed")
		return
	for i in 3:
		var client = RelayPeer.new()
		client.account_key = keys[i]
		client.friend_service = services[i]
		client.connect_to_relay("127.0.0.1", relay.connection.get_local_port())
		clients.append(client)
	await pump(100)
	check(clients.all(func(client): return client.is_authenticated) and services.all(func(service): return service.supported), "real relay authenticates accounts and negotiates social capability")
	clients[0].create_session(0, "A", "", "default_wold")
	clients[1].create_session(0, "B", "", "default_wold")
	await pump()
	check(clients[0].current_session_id != clients[1].current_session_id, "friends exchange can cross separate instances")
	check(services[0].send_request(fp(1)), "fresh friendship request queued on sender client")
	await pump()
	check(services[1].relationship(fp(0)).status == "incoming" and not services[0].is_friend(fp(1)), "real encoded request delivered without unilateral friendship")
	check(services[1].act(fp(0), "accept"), "recipient explicitly accepts actual delivered request")
	await pump()
	check(services[0].is_friend(fp(1)) and services[1].is_friend(fp(0)), "wire delivery and durable receipts complete both sides")
	var before_count = services[1].state.relationships.size()
	var impersonated = FriendEvent.create(keys[0], keys[1].save_to_string(true), "request")
	clients[2]._send_social({"op": "event", "event": impersonated})
	clients[2]._send_social({"op": "publish", "status": "online", "generation": services[2].generation, "actor": keys[0].save_to_string(true)})
	var malformed = PackedByteArray([PacketInfo.PACKET_TYPE.SOCIAL_DATA])
	malformed.append_array("not json".to_utf8_buffer())
	clients[2].peer.send(0, malformed, ENetPacketPeer.FLAG_RELIABLE)
	await pump()
	check(services[1].state.relationships.size() == before_count, "relay rejects signed event sent from the wrong authenticated actor and malformed wire input")
	services[0].refresh()
	services[1].refresh()
	await pump()
	check(services[0].status(fp(1)) == "Online" and services[1].status(fp(0)) == "Online", "both current authorizations enable Online presence")
	check(services[0].has_method("friend_session"), "friend presence exposes authenticated session location")
	if services[0].has_method("friend_session"):
		var location: Dictionary = services[0].friend_session(fp(1))
		check(location.get("session_id") == clients[1].current_session_id and location.get("name") == "B", "accepted friend sees exact public session identity and name")
		check(services[2].friend_session(fp(1)).is_empty(), "unrelated account cannot query friend location")
		var location_index = relay.get_session_index(clients[1].current_session_id)
		relay.sessions[location_index][0].mode = PacketInfo.MODE.PRIVAT
		services[0].refresh(); services[1].refresh()
		await pump()
		check(services[0].friend_session(fp(1)).is_empty(), "private instance location is not disclosed through friend presence")
		relay.sessions[location_index][0].mode = PacketInfo.MODE.PUBLIC
		services[0].refresh(); services[1].refresh()
		await pump()
		services[0].presence[fp(1)].received = -20000
		check(services[0].friend_session(fp(1)).is_empty(), "expired location cannot remain joinable")
		services[0].refresh(); services[1].refresh()
		await pump()
	check(services[2].presence.is_empty(), "unrelated connected account receives no friend presence")
	var join_location: Dictionary = services[0].friend_session(fp(1))
	if not join_location.is_empty():
		clients[0].join_session(join_location.session_id, join_location.world_url)
		await pump()
		check(clients[0].current_session_id == clients[1].current_session_id, "real friend location joins exact instance over authenticated ENet")
		clients[0].create_session(0, "A again", "", "default_wold")
		await pump()
		services[0].refresh(); services[1].refresh()
		await pump()
	var initial_presence: Dictionary = services[0].presence[fp(1)].duplicate()
	services[0].receive({"op": "presence", "subject": fp(1), "generation": "old-connection", "sequence": 99999, "status": "offline"})
	services[0].receive({"op": "presence", "subject": fp(1), "generation": services[0].generation, "sequence": 0, "status": "offline"})
	check(services[0].presence[fp(1)] == initial_presence, "old connection and out-of-order presence cannot override current state")
	var proof = services[0].relationship(fp(1)).record
	clients[2]._send_social({"op": "authorize", "generation": services[2].generation,
		"proof": {"request": proof.request, "accept": proof.accept}})
	await pump()
	check(services[2].presence.is_empty(), "unrelated authenticated account cannot replay another pair's presence proof")
	var retained_grant: Dictionary = relay.social.grants.duplicate(true)
	services[0].presence[fp(1)].received = -20000
	services[0].next_sync = Time.get_ticks_msec() + 10000
	services[0].tick()
	check(services[0].status(fp(1)) == "Status unavailable", "expired friend presence is not presented as live Online")
	services[0].refresh()
	await pump()
	check(not retained_grant.is_empty() and services[0].status(fp(1)) == "Online", "fresh authorized refresh recovers expired presence")
	await test_instance_access()
	services[1].set_status("do_not_disturb")
	await pump()
	check(services[0].status(fp(1)) == "Do Not Disturb", "DND updates live friend status")
	services[1].set_status("offline")
	await pump()
	check(services[0].status(fp(1)) == "Offline" and clients[1].is_authenticated, "appear offline hides presence without disconnecting game")
	if services[0].has_method("friend_session"):
		check(services[0].friend_session(fp(1)).is_empty(), "appear offline removes joinable location immediately")
	var restored = Service.new()
	restored.configure(keys[1], "res://friends-1.cfg")
	check(restored.state.preferred_status == "offline" and restored.is_friend(fp(0)) and restored.presence.is_empty(), "restart preserves friend/preference but never restores live presence")
	services[1].set_status("online")
	await pump()
	var old_fp = fp(1)
	clients[1].peer.peer_disconnect()
	await pump()
	check(services[0].status(old_fp) == "Offline", "subject disconnect updates surviving friend's status")
	check(services[0].friend_session(old_fp).is_empty(), "subject disconnect clears surviving friend's join location")
	var data = JSON.stringify([relay.social.publications, relay.social.grants, relay.social.pending, relay.key_mapping])
	check(not old_fp in data and not keys[1].save_to_string(true) in data, "disconnect removes social identity/proof references from relay")
	check(services[1].status(fp(0)) == "Status unavailable" and services[1].is_friend(fp(0)), "viewer disconnect clears live status but preserves friendship locally")
	check(services[1].friend_session(fp(0)).is_empty(), "viewer disconnect never exposes cached join location")
	services[1].act(fp(0), "revoke")
	var revoked_count = services[1].state.outbox.size()
	var reconnect = RelayPeer.new()
	reconnect.account_key = keys[1]
	reconnect.friend_service = services[1]
	clients[1].connection.destroy()
	clients[1] = reconnect
	reconnect.connect_to_relay("127.0.0.1", relay.connection.get_local_port())
	await pump(100)
	check(revoked_count > 0 and not services[0].is_friend(fp(1)) and not services[1].is_friend(fp(0)),
		"client-local offline revocation retries on reconnect before presence is reauthorized")
	check(services[1].state.outbox.is_empty(), "durable recipient receipt removes delivered revocation from local outbox")
	for client in clients:
		if client.peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
			client.peer.peer_disconnect()
	await pump()
	check(relay.social.publications.is_empty() and relay.social.grants.is_empty() and relay.social.pending.is_empty() and relay.social.rates.is_empty(), "last disconnect leaves no relay social state")
	for client in clients:
		client.connection.destroy()
	relay.connection.destroy()
	relay.free()

func test_join_ui(scene):
	var a = Service.new()
	var b = Service.new()
	a.configure(keys[0], "res://join-ui-a.cfg")
	b.configure(keys[1], "res://join-ui-b.cfg")
	a.add_contact(keys[1].save_to_string(true), "Join target")
	a.send_request(fp(1))
	var request: Dictionary = a.state.outbox.values()[0]
	b.receive({"op": "event", "event": request})
	b.act(fp(0), "accept")
	var accepted: Dictionary = b.state.outbox.values()[0]
	a.receive({"op": "event", "event": accepted})
	a.attach(func(_packet): pass, true)
	var location = {"session_id": "exact-friend-instance", "world_url": "default_wold", "name": "Friend room"}
	a.receive({"op": "presence", "subject": fp(1), "status": "online", "generation": a.generation, "sequence": 1, "location": location})
	var save = root.get_node("SaveData")
	var network = root.get_node("NetworkHandler")
	save.friends = a
	scene._bind_service()
	var join: Button
	for node in scene.find_children("*", "Button", true, false):
		if node.text == "Join friend": join = node
	check(join != null and not join.disabled, "actual Friends UI offers enabled Join friend for fresh public location")
	if join != null:
		join.pressed.emit()
		check(network.join_calls.size() == 1 and network.join_calls[0].session_id == location.session_id and network.join_calls[0].world_url == "default_wold", "Join friend button routes exact identity/content into coordinator")
	scene._render()
	check(scene.find_children("*", "Button", true, false).any(func(button): return button.text == "Same instance" and button.disabled), "already joined friend is marked Same instance instead of rejoining")
	network.current_session_id = ""
	network.session_busy = true
	await scene._join_friend(fp(1))
	check(network.join_calls.size() == 1, "busy transition blocks duplicate join request")
	network.session_busy = false
	network.join_result = false
	await scene._join_friend(fp(1))
	check("admission denied" in scene.status_label.text, "join rejection displays coordinator error instead of false success")
	var before = network.join_calls.size()
	a.presence[fp(1)].received = -20000
	await scene._join_friend(fp(1))
	check(network.join_calls.size() == before and "expired" in scene.status_label.text, "stale button click rechecks location and never joins expired instance")
	a.receive({"op": "presence", "subject": fp(1), "status": "online", "generation": a.generation, "sequence": 2, "location": location})
	var malformed = location.duplicate()
	malformed.world_url = "file:///private/world"
	a.receive({"op": "presence", "subject": fp(1), "status": "online", "generation": a.generation, "sequence": 3, "location": malformed})
	check(a.friend_session(fp(1)).is_empty(), "invalid location content URL clears joinability rather than retaining older target")
	a.receive({"op": "presence", "subject": fp(1), "status": "online", "generation": a.generation, "sequence": 4, "location": location})
	var copied = a.friend_session(fp(1))
	copied.session_id = "tampered-copy"
	check(a.friend_session(fp(1)).session_id == location.session_id, "location descriptor is a copy and UI cannot mutate presence ownership")
	var changes: Array = []
	a.changed.connect(func(): changes.append(true))
	a.receive({"op": "presence", "subject": fp(1), "status": "online", "generation": a.generation, "sequence": 5, "location": location})
	check(changes.is_empty() and a.presence[fp(1)].sequence == 5, "unchanged presence heartbeat refreshes freshness without rebuilding Friends UI")
	a.presence[fp(1)].received = -20000
	a.receive({"op": "presence", "subject": fp(1), "status": "online", "generation": a.generation, "sequence": 6, "location": location})
	check(changes.size() == 1, "recovery from stale presence still notifies UI even with identical status")
	var moved = location.duplicate()
	moved.session_id = "other-instance"
	a.receive({"op": "presence", "subject": fp(1), "status": "online", "generation": a.generation, "sequence": 7, "location": moved})
	check(changes.size() == 2 and a.friend_session(fp(1)).session_id == moved.session_id, "real location change emits one UI refresh")
	a.receive({"op": "delivery", "event_id": "unknown-event", "status": "delivered"})
	check(not a.delivery.has("unknown-event"), "unsolicited delivery IDs cannot accumulate client state")
	a.block(fp(1))
	check(a.friend_session(fp(1)).is_empty(), "blocking friend immediately revokes join-location access")
	save.friends = services[0]
	scene._bind_service()
	network.join_result = true
	network.current_session_id = ""
	network.join_calls.clear()

func test_ui():
	var save = root.get_node("SaveData")
	save.friends = services[0]
	var scene = load("res://scenes/GUI/friends_menue.tscn").instantiate()
	if "--visual" in OS.get_cmdline_user_args():
		var viewport = SubViewport.new()
		viewport.size = Vector2i(640, 480)
		viewport.gui_embed_subwindows = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewport.add_child(scene)
		var preview = TextureRect.new()
		preview.texture = viewport.get_texture()
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(preview)
	else:
		root.add_child(scene)
	await process_frame
	var rendered: Array = scene.list.get_children().filter(func(node): return node.has_meta("fingerprint"))
	check(rendered.all(func(node): return services[0].relationship(node.get_meta("fingerprint")).get("status", "contact") != "contact" or services[0].contacts()[node.get_meta("fingerprint")].blocked),
		"Friends hides legacy contact-only records without deleting service data")
	check(not scene.find_children("*", "Button", true, false).any(func(node): return node.text == "Save contact"),
		"standalone Save contact option is removed")
	check(scene.find_children("*", "Button", true, false).any(func(node): return node.text == "Invite"), "Friends exposes Invite action")
	scene.search.text = "zz-no-such-contact"
	scene.search.text_changed.emit(scene.search.text)
	check(scene.list.get_children().all(func(node): return not node.has_meta("fingerprint")), "search hides contacts that do not match")
	scene.search.text = ""
	scene.search.text_changed.emit("")
	scene.filter_buttons.requests.pressed.emit()
	var request_states: Array = scene.list.get_children().filter(func(node): return node.has_meta("fingerprint")).map(
		func(node): return services[0].relationship(node.get_meta("fingerprint")).get("status", "contact"))
	check(scene.filter == "requests" and request_states.all(func(state): return state in ["incoming", "outgoing", "accepting"]),
		"Requests filter shows only open requests")
	scene.filter_buttons.all.pressed.emit()
	await test_join_ui(scene)
	check(scene.preference.item_count == 3, "self status selector offers Online/DND/Offline")
	var shell_script = load("res://scripts/GUI/tablet_shell.gd")
	check(shell_script.PAGES[1] == "friends" and shell_script.TITLES.friends == "Friends" and "worlds" in shell_script.PAGES
		and shell_script.SCENES.friends == "res://scenes/GUI/friends_menue.tscn",
		"Friends remains the second tablet page and Worlds is available in the rail")
	scene._open_profile(fp(1))
	check(scene.profile_panel.profile_owner == fp(1) and not scene.profile_panel.is_editable(), "friend row profile uses correct fingerprint without editing rights")
	scene.profile_panel._close()
	check(scene.layout.visible, "profile Back restores Friends page")
	var action = null
	for candidate in scene.find_children("*", "Button", true, false):
		if candidate.text == "Add public key":
			action = candidate
	action.pressed.emit()
	scene.key_input.text = keys[2].save_to_string(true)
	scene.nickname.text = "Charlie"
	scene.key_input.text_changed.emit()
	check(fp(2) in scene.key_review.text, "public-key paste preview shows canonical fingerprint")
	for candidate in scene.find_children("*", "Button", true, false):
		if candidate.text == "Send friend request":
			candidate.pressed.emit()
			break
	check(services[0].contacts().has(fp(2)) and services[0].relationship(fp(2)).get("status") == "outgoing" and not scene.add_panel.visible,
		"public key action sends friend request rather than creating standalone contact")
	scene._open_profile(fp(2))
	var request_button = null
	for candidate in scene.profile_panel.friend_actions.get_children():
		if candidate is Button and candidate.text == "Friend request sent":
			request_button = candidate
	check(request_button != null and request_button.disabled, "profile reflects pending friend request")
	if request_button != null and not request_button.disabled:
		request_button.pressed.emit()
		check(services[0].relationship(fp(2)).get("status") == "outgoing" and not services[0].is_friend(fp(2)),
			"user overview button sends request to selected account without unilateral friendship")
		var sent := false
		for candidate in scene.profile_panel.friend_actions.get_children():
			if candidate is Button and candidate.text == "Friend request sent":
				sent = candidate.disabled
		check(sent, "user overview disables duplicate requests and shows sent state")
	scene.profile_panel._close()
	scene.preference.item_selected.emit(1)
	check(services[0].state.preferred_status == "do_not_disturb", "actual Friends status selector updates persistent account preference")
	if "--visual" in OS.get_cmdline_user_args():
		await test_visual(scene)
	scene.key_input.text = "uncommitted previous-account key"
	var previous = scene.service.owner
	var temporary = Service.new()
	temporary.configure(keys[2], "res://switch.cfg")
	save.friends = temporary
	save.account_ready.emit()
	check(scene.service.owner != previous and scene.key_input.text.is_empty() and scene.list.get_children().all(func(node): return not node.has_meta("fingerprint")),
		"account switch removes previous contacts and key drafts immediately")
	scene.free()

func test_instance_access():
	var a: String = clients[0].current_session_id
	var b: String = clients[1].current_session_id
	var session: Dictionary = relay.sessions[relay.get_session_index(a)][0]
	session.mode = PacketInfo.MODE.FRIENDS
	clients[2].join_session(a, "default_wold")
	await pump()
	check(clients[2].current_session_id.is_empty(), "Friends denies unrelated authenticated account")
	clients[1].join_session(a, "default_wold")
	await pump()
	check(clients[1].current_session_id == a, "Friends permits current admin's mutually accepted friend automatically")
	# Return B to its original live instance while a spare participant holds it.
	clients[1].create_session(0, "B", "", "default_wold")
	await pump()
	b = clients[1].current_session_id
	session.mode = PacketInfo.MODE.REQUEST
	clients[1].join_session(a, "default_wold")
	await pump()
	check(clients[1].current_session_id == b and not clients[0].join_requests.is_empty(),
		"Request keeps friend in previous instance until explicit approval")
	var token: String = clients[0].join_requests.keys()[0]
	AccountPacket.create(PacketInfo.PACKET_TYPE.JOIN_DECISION, {"token": token, "allow": true}).sent(clients[2].peer)
	await pump()
	check(clients[1].current_session_id == b, "non-admin cannot approve another user's join request")
	clients[0].decide_join(token, false)
	await pump()
	check(clients[1].current_session_id == b and relay.admissions.is_empty(), "declined friend request preserves previous membership")
	clients[1].join_session(a, "default_wold")
	await pump()
	var stale_token: String = clients[0].join_requests.keys()[0]
	session.mode = PacketInfo.MODE.PRIVAT
	clients[0].decide_join(stale_token, true)
	await pump()
	check(clients[1].current_session_id == b and relay.admissions.is_empty(),
		"request approval revalidates changed instance type before admitting")
	session.mode = PacketInfo.MODE.REQUEST
	clients[1].join_session(a, "default_wold")
	await pump()
	for pending in relay.admissions.values():
		pending.deadline = 0
	await pump()
	check(clients[1].current_session_id == b and clients[0].join_requests.is_empty(),
		"expired join request preserves membership and closes admin inbox")
	clients[1].join_session(a, "default_wold")
	await pump()
	clients[0].decide_join(clients[0].join_requests.keys()[0], true)
	await pump()
	check(clients[1].current_session_id == a and clients[0].join_requests.is_empty(), "admin approval admits friend and closes request UI state")
	clients[1].create_session(0, "B", "", "default_wold")
	await pump()
	services[1].add_contact(keys[2].save_to_string(true))
	services[1].send_request(fp(2))
	await pump()
	services[2].act(fp(1), "accept")
	await pump()
	services[1].refresh()
	services[2].refresh()
	await pump()
	clients[2].join_session(a, "default_wold")
	await pump()
	check(clients[2].current_session_id.is_empty() and clients[0].join_requests.is_empty(),
		"Request refuses friend-of-friend without direct admin friendship")
	session.mode = PacketInfo.MODE.FRIENDSP
	clients[2].join_session(a, "default_wold")
	await pump()
	check(clients[2].current_session_id == a, "Friends+ admits exactly two-hop mutual friendship path")
	clients[2].create_session(0, "C", "", "default_wold")
	await pump()
	session.mode = PacketInfo.MODE.FRIENDS
	clients[2].join_session(a, "default_wold")
	await pump()
	check(clients[2].current_session_id != a, "Friends does not accidentally admit Friends+ two-hop candidate")
	var result: Array = []
	var capture = func(value):
		if value.operation == "resolve":
			result.append(value)
	clients[1].session_result.connect(capture)
	clients[1].resolve_instance(a)
	await pump()
	check(not result.is_empty() and result.back().success and result.back().world_url == "default_wold" \
		and clients[1].current_session_id != a, "authorized private-code lookup reveals world without changing membership")
	clients[1].session_result.disconnect(capture)
	session.mode = PacketInfo.MODE.PRIVAT
	clients[1].join_session(a, "default_wold")
	await pump()
	check(clients[1].current_session_id != a, "Private remains closed even to accepted friends")
	session.mode = PacketInfo.MODE.PUBLIC

func test_visual(scene: Control):
	var viewport = scene.get_viewport()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	check(scene.size == Vector2(640, 480) and scene.scroll.size.y > 100, "Friends GPU layout fits exact 640x480 with usable scrolling")
	check(scene.preference.get_global_rect().end.x <= 640 and scene.preference.size.y > 0,
		"rendered self-status selector remains in bounds")
	DirAccess.make_dir_recursive_absolute("/tmp/opencode/friends-visual")
	check(viewport.get_texture().get_image().save_png("/tmp/opencode/friends-visual/friends-640x480.png") == OK,
		"Friends display screenshot saved")
	scene._open_profile(fp(1))
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png("/tmp/opencode/friends-visual/friend-profile.png") == OK,
		"cached friend profile screenshot saved")
	scene.profile_panel._close()
