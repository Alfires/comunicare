extends SceneTree

const SERVICE = "res://scripts/profile/profile_service.gd"
const IDENTITY = "res://scripts/profile/identity_authenticator.gd"
const PROFILE_SCENE = "res://scenes/GUI/profile_menue.tscn"
var passed := 0
var failed := 0
var deferred_groups: Array = []

func _initialize():
	call_deferred("run")

func check(ok: bool, title: String):
	if ok:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func require_methods(object: Object, methods: Array, title: String) -> bool:
	var missing: Array = []
	for method in methods:
		if not object.has_method(method):
			missing.append(method)
	check(missing.is_empty(), title + ("; missing " + str(missing) if not missing.is_empty() else ""))
	return missing.is_empty()

func feature(path: String, title: String):
	var exists = ResourceLoader.exists(path)
	check(exists, title)
	return load(path).new() if exists else null

func dispose(object):
	if object is Node:
		object.free()

func run():
	await test_header()
	await test_home_navigation()
	test_settings_separation()
	test_profile_service()
	test_profile_modes()
	test_identity_authentication()
	test_instance_exchange()
	await test_profile_wire()
	await test_profile_editor_drafts()
	await test_layout_and_preview()
	test_account_key_migration()
	print("\nProfile contracts: %d passed, %d failed; %d dependent groups not run" % [passed, failed, deferred_groups.size()])
	for group in deferred_groups:
		print("NOT RUN (missing prerequisite): ", group)
	quit(1 if failed else 0)

func test_home_navigation():
	var home = load("res://scenes/GUI/home_menue.tscn").instantiate()
	root.add_child(home)
	for dimensions in [Vector2i(1000, 700), Vector2i(640, 480)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var grid = home.get_node("VBoxContainer/MenuGrid")
		var status = home.get_node("VBoxContainer/Status")
		var tiles = grid.get_children()
		check(grid.columns == 2 and tiles.size() == 4, "Home has exactly four options in a two-column grid at " + str(dimensions))
		check(grid.position.y >= status.position.y + status.size.y and grid.size.y > home.size.y * 0.5,
			"Home grid fills remaining space below status at " + str(dimensions))
		check(absf(tiles[0].size.x - tiles[1].size.x) <= 1 and absf(tiles[0].size.y - tiles[2].size.y) <= 1
			and tiles[1].position.x > tiles[0].position.x and tiles[2].position.y > tiles[0].position.y,
			"Home tiles form equal 2x2 cells at " + str(dimensions))
		check(tiles[2].get_child_count() == 0 and tiles[3].get_child_count() == 0 and not tiles[2] is Button and not tiles[3] is Button,
			"bottom Home tiles remain empty non-actionable placeholders")
	home.get_node("VBoxContainer/MenuGrid/ActiveInstance").pressed.emit()
	check(home.submenu_kind == "share_session_menue" and is_instance_valid(home.submenu_page)
		and home.get_node("Submenu").visible and not home.get_node("VBoxContainer").visible,
		"Home Active Instance button opens actual instance scene as a subpage")
	home.get_node("Submenu/Back").pressed.emit()
	check(home.submenu_page == null and home.get_node("VBoxContainer").visible,
		"subpage Back restores Home grid and releases page")
	home.get_node("VBoxContainer/MenuGrid/ActiveInstance").pressed.emit()
	home.hide()
	check(home.submenu_page == null and home.submenu_kind.is_empty(), "hiding Home closes subpage and avoids stale subscriptions")
	home.free()

func profile_buttons(home: Node) -> Array:
	var matches: Array = []
	for button in home.find_children("*", "Button", true, false):
		if "profile" in button.name.to_lower() or "account" in button.name.to_lower():
			matches.append(button)
	return matches

func test_header():
	# Test actual parent padding, not just an isolated Home control.
	var menu = TabContainer.new()
	menu.set_script(load("res://scripts/GUI/menue.gd"))
	var panel = StyleBoxFlat.new()
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	menu.add_theme_stylebox_override("panel", panel)
	menu.size = Vector2(900, 600)
	var home = load("res://scenes/GUI/home_menue.tscn").instantiate()
	menu.add_child(home)
	root.add_child(menu)
	var buttons = profile_buttons(home)
	check(buttons.size() == 1, "Home has one separate profile/account button")
	var microphone: Button = home.get_node("VBoxContainer/HBoxContainer/Microphone")
	check(microphone.text.is_empty() and microphone.icon != null, "existing microphone stays icon-only")
	for dimensions in [Vector2(900, 600), Vector2(640, 480)]:
		menu.size = dimensions
		await process_frame
		await process_frame
		check(is_equal_approx(microphone.get_global_rect().end.x, menu.get_global_rect().end.x),
			"microphone remains flush right at " + str(dimensions))
		if buttons.size() == 1:
			var button: Button = buttons[0]
			check(is_equal_approx(button.get_global_rect().position.x, menu.get_global_rect().position.x)
				and is_equal_approx(button.global_position.y, microphone.global_position.y),
				"profile button is flush top-left at " + str(dimensions))
	if buttons.size() == 1:
		var button: Button = buttons[0]
		check(button.text.is_empty() and button.icon != null, "profile has default icon without visible text")
		check(button.custom_minimum_size.x >= 48 and button.custom_minimum_size.y >= 48,
			"profile button has an accessible hit area")
		check(not button.tooltip_text.is_empty() and not button.get_signal_connection_list("pressed").is_empty(),
			"real Home ready wires profile button and tooltip")
		button.pressed.emit()
		var opened = home.profile_panel
		check(is_instance_valid(opened) and opened.is_editable(), "Home profile button opens actual owner editor")
		button.pressed.emit()
		check(home.profile_panel == opened, "repeated profile click reuses one panel")
		opened.cancel_edit()
		check(home.get_node("VBoxContainer").visible, "Cancel returns to Home")
	else:
		deferred_groups.append("profile button icon, placement and signal wiring")
	menu.free()
	check(panel.content_margin_left == 12 and panel.content_margin_right == 12,
		"header placement never mutates shared theme padding")

func test_settings_separation():
	var scene = load("res://scenes/GUI/settings_menue.tscn").instantiate()
	root.add_child(scene)
	check(not scene.category_buttons.has("Profile"), "general Settings has no Profile sidebar category")
	var profile_fields: Array = []
	for id in scene.controls:
		if str(id).begins_with("profile."):
			profile_fields.append(id)
	check(profile_fields.is_empty(), "general Settings has no editable name/avatar/icon/description fields")
	check(scene.category_buttons.has("Audio") and scene.category_buttons.has("Controls"),
		"removing Profile does not remove ordinary settings categories")
	scene.free()

func key_pair() -> CryptoKey:
	# Ephemeral keys in memory only, never SaveData.create_acount()/key.save().
	return Crypto.new().generate_rsa(2048)

func digest(bytes: PackedByteArray) -> PackedByteArray:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish()

func fields(name: String = "Alice") -> Dictionary:
	return {"profile.username": name, "profile.description": "Hello\nWorld",
		"profile.icon_source": "", "profile.avatar_url": "https://example.test/avatar.vrm"}

func test_profile_service():
	var service = feature(SERVICE, "dedicated key-owned profile service exists")
	if service == null:
		deferred_groups.append("profile ownership, atomic saves, validation and persistence")
		return
	if not require_methods(service, ["configure", "get_local_fingerprint", "get_profile", "can_edit", "save_profile", "load_profile"], "profile service contract"):
		deferred_groups.append("profile service behavior")
		dispose(service)
		return
	var alice = key_pair()
	var bob = key_pair()
	service.configure(alice, "res://alice-profile.cfg")
	var owner: String = service.get_local_fingerprint()
	check(not owner.is_empty() and service.can_edit(owner), "matching private key grants local profile ownership")
	check(service.get_profile(owner).get("profile.description") == ""
		and service.get_profile(owner).get("profile.icon_source") == "", "new identity gets empty description and bundled-icon selection")
	check(service.save_profile(owner, fields()), "owner can save all four profile fields")
	check(service.get_profile(owner).get("profile.description") == "Hello\nWorld", "multiline profile description is preserved")
	var snapshot: Dictionary = service.get_profile(owner).duplicate(true)
	var invalid = fields("Changed")
	invalid["profile.avatar_url"] = "file:///private/model.vrm"
	check(not service.save_profile(owner, invalid) and service.get_profile(owner) == snapshot,
		"one invalid field rejects whole profile without partial name change")
	for invalid_value in ["", "   ", "\n\t"]:
		invalid = fields(invalid_value)
		check(not service.save_profile(owner, invalid), "blank/control-only display name is rejected: " + str(invalid_value))
	invalid = fields()
	invalid["profile.description"] = "x".repeat(1025)
	check(not service.save_profile(owner, invalid), "description over 1024 characters rejected")
	var second = load(SERVICE).new()
	second.configure(bob, "res://bob-profile.cfg")
	var other: String = second.get_local_fingerprint()
	check(not second.can_edit(owner) and not second.save_profile(owner, fields("Impersonated")),
		"another private key cannot edit Alice even through direct service call")
	check(not service.can_edit(other) and not service.save_profile(other, fields()), "owner cannot write arbitrary other account records")
	var restarted = load(SERVICE).new()
	restarted.configure(alice, "res://alice-profile.cfg")
	check(restarted.load_profile() and restarted.get_local_fingerprint() == owner
		and restarted.get_profile(owner).get("profile.username") == "Alice", "same key restores profile after restart")
	var wrong_account = load(SERVICE).new()
	wrong_account.configure(bob, "res://alice-profile.cfg")
	wrong_account.load_profile()
	check(wrong_account.get_profile(other).get("profile.username") != "Alice", "loading another account's file never adopts its profile identity")
	for object in [service, second, restarted, wrong_account]:
		dispose(object)

func test_profile_modes():
	var exists = ResourceLoader.exists(PROFILE_SCENE)
	check(exists, "separate profile menu scene exists")
	if not exists or not ResourceLoader.exists(SERVICE):
		deferred_groups.append("real profile owner/visitor UI and full public-key display")
		return
	var service = load(SERVICE).new()
	if not service.has_method("configure") or not service.has_method("cache_remote_profile"):
		check(false, "profile UI needs configured service and authenticated remote cache")
		dispose(service)
		return
	var alice = key_pair()
	var bob = key_pair()
	service.configure(alice, "res://ui-profile.cfg")
	var bob_key = bob.save_to_string(true)
	var remote: Dictionary = fields("Bob")
	remote["public_key"] = bob_key
	var remote_id: String = service.cache_remote_profile("room", bob_key, remote)
	var scene = load(PROFILE_SCENE).instantiate()
	root.add_child(scene) # real ready; service explicitly injected for this view
	if require_methods(scene, ["open_profile", "is_editable", "get_displayed_public_key", "cancel_edit"], "profile scene owner/viewer API"):
		scene.open_profile(service, service.get_local_fingerprint())
		check(scene.is_editable(), "own profile opens in owner-edit mode")
		check(scene.edit_buttons.size() == 4 and scene.edit_buttons.values().all(func(button): return button.visible)
			and not scene.edit_button.visible, "owner has individual edit buttons, not a global editor")
		check(scene.edit_buttons.values().all(func(button): return button.text.is_empty() and button.icon != null),
			"all element edit buttons are icon-only")
		scene.cancel_edit()
		var requests_before = root.get_node("DataLoader").avatar_requests.size()
		scene.open_profile(service, remote_id)
		check(root.get_node("DataLoader").avatar_requests.size() == requests_before + 1
			and scene.avatar_preview.model != null, "opening another user's profile automatically loads avatar preview")
		check(not scene.is_editable(), "another account opens read-only")
		check(not scene.edit_button.visible and not scene.open_editor(), "visitor cannot open editor directly")
		check(scene.get_displayed_public_key() == bob_key, "visitor can inspect actual full public key, not only fingerprint")
		var editable := false
		for control in scene.find_children("*", "LineEdit", true, false):
			if control.is_visible_in_tree() and control.editable:
				editable = true
		for control in scene.find_children("*", "TextEdit", true, false):
			if control.is_visible_in_tree() and control.editable:
				editable = true
		check(not editable, "visitor has no visible editable text fields")
	scene.free()
	dispose(service)

func test_account_key_migration():
	var save = load("res://scripts/settings/save_data.gd").new()
	save.settings_path = "res://legacy-account.cfg"
	save.key_path = "res://broken-account.key"
	var file = FileAccess.open(save.key_path, FileAccess.WRITE)
	file.store_string("broken private key")
	file.close()
	Engine.print_error_messages = false
	var loaded: bool = save.load_acount()
	Engine.print_error_messages = true
	check(not loaded and FileAccess.get_file_as_string(save.key_path) == "broken private key",
		"corrupt existing account key is never silently regenerated")
	save.key = key_pair()
	var config = ConfigFile.new()
	config.set_value("settings", "profile.username", "Migrated name")
	config.set_value("settings", "profile.avatar_url", "https://example.test/migrated.vrm")
	config.save(save.settings_path)
	save.laod_data()
	var public_key = save.key.save_to_string(true)
	save.initialize_profile("res://migrated-profile.cfg")
	check(save.profile.local["profile.username"] == "Migrated name"
		and save.profile.local["profile.avatar_url"] == "https://example.test/migrated.vrm"
		and save.key.save_to_string(true) == public_key, "legacy profile migrates without changing account key")
	save.free()

func test_identity_authentication():
	var auth = feature(IDENTITY, "relay proof-of-key-possession authenticator exists")
	if auth == null:
		deferred_groups.append("challenge/signature/replay/connection-bound authentication")
		return
	if not require_methods(auth, ["issue_challenge", "verify_response", "get_identity", "expire_challenges", "disconnect_peer"], "authenticator API"):
		deferred_groups.append("authentication behavior")
		dispose(auth)
		return
	var alice = key_pair()
	var bob = key_pair()
	var public_key = alice.save_to_string(true)
	var challenge: PackedByteArray = auth.issue_challenge(1, public_key)
	var signature = Crypto.new().sign(HashingContext.HASH_SHA256, digest(challenge), alice)
	check(not challenge.is_empty() and auth.verify_response(1, signature), "valid private-key signature authenticates connection")
	check(auth.get_identity(1).get("public_key") == public_key, "verified connection resolves to canonical public key")
	check(not auth.verify_response(1, signature), "consumed challenge cannot be replayed")
	challenge = auth.issue_challenge(2, public_key)
	var forged = Crypto.new().sign(HashingContext.HASH_SHA256, digest(challenge), bob)
	check(not auth.verify_response(2, forged) and auth.get_identity(2).is_empty(), "claimed victim public key without private key does not authenticate")
	challenge = auth.issue_challenge(3, bob.save_to_string(true))
	signature = Crypto.new().sign(HashingContext.HASH_SHA256, digest(challenge), bob)
	check(not auth.verify_response(4, signature), "signature from another connection is rejected")
	auth.expire_challenges()
	check(not auth.verify_response(3, signature), "expired challenge rejected")
	auth.disconnect_peer(1)
	check(auth.get_identity(1).is_empty(), "disconnect removes authenticated identity")
	dispose(auth)

func test_instance_exchange():
	var relay = load("res://scripts/multiplayer/relay.gd").new()
	if not require_methods(relay, ["authenticate_peer", "publish_profile", "get_profiles_for_peer"], "relay authenticated same-instance profile API"):
		deferred_groups.append("same-instance public keys, unauthorized publish, departure cleanup and discovery privacy")
		relay.free()
		return
	# authenticate_peer consumes already-verified identity; tests of proof of
	# possession live above. This adapter must never accept a client auth packet.
	var alice = key_pair()
	var bob = key_pair()
	var carol = key_pair()
	relay.authenticate_peer(1, alice.save_to_string(true))
	relay.authenticate_peer(2, bob.save_to_string(true))
	relay.authenticate_peer(3, carol.save_to_string(true))
	for record in [
		{"session_id": "one", "peers": [1, 2], "owners": [1]},
		{"session_id": "two", "peers": [3], "owners": [3]},
	]:
		record.mode = 0
		record.world_url = "https://example.test/same-world.cne"
		record.name = "Same world"
		record.description = ""
		relay.sessions.append([record])
	# The relay derives owner from its verified mapping; profile dictionary has
	# no private material and cannot select the author using a peer ID/name.
	check(relay.publish_profile(1, fields()) and relay.publish_profile(2, fields("Bob")), "authenticated owners publish profiles")
	var visible: Array = relay.get_profiles_for_peer(1)
	var bob_visible := false
	var carol_visible := false
	for profile in visible:
		bob_visible = bob_visible or profile.get("public_key") == bob.save_to_string(true)
		carol_visible = carol_visible or profile.get("public_key") == carol.save_to_string(true)
	check(bob_visible and not carol_visible, "same-instance user sees Bob's full key, not another instance of same world")
	check(relay.get_profiles_for_peer(99).is_empty() and not relay.publish_profile(99, fields()), "unauthenticated connections cannot fetch or publish profiles")
	var spoof = fields("Fake Bob")
	spoof["public_key"] = bob.save_to_string(true)
	check(not relay.publish_profile(1, spoof), "payload cannot publish changes as another authenticated owner")
	var discovery_text = JSON.stringify(relay.get_public_session())
	check(not "public_key" in discovery_text and not "PRIVATE KEY" in JSON.stringify(visible), "discovery omits account keys and profile exchange never leaks private keys")
	relay.remove_user_from_session(2, 0)
	var departed_visible := false
	for profile in relay.get_profiles_for_peer(1):
		departed_visible = departed_visible or profile.get("public_key") == bob.save_to_string(true)
	check(not departed_visible, "departed member's profile/key no longer queryable through instance")
	relay.free()

func pump(relay: Node, clients: Array, rounds: int = 30):
	for index in rounds:
		relay.handle_events()
		for client in clients:
			client.handle_events()
		await create_timer(0.005).timeout

func test_profile_wire():
	var relay = load("res://scripts/multiplayer/relay.gd").new()
	relay.connection = ENetConnection.new()
	var error = relay.connection.create_host_bound("127.0.0.1", 0)
	check(error == OK, "profile wire test starts loopback relay")
	if error != OK:
		relay.free()
		return
	var clients: Array = []
	var services: Array = []
	for index in 3:
		var key = key_pair()
		var service = load(SERVICE).new()
		service.configure(key, "res://wire-%d.cfg" % index)
		service.save_profile(service.get_local_fingerprint(), fields("User %d" % index))
		services.append(service)
		var client = RelayPeer.new()
		client.account_key = key
		client.connect_to_relay("127.0.0.1", relay.connection.get_local_port())
		clients.append(client)
	await pump(relay, clients)
	check(clients.all(func(client): return client.is_authenticated), "real challenge/signature packets authenticate three different accounts")
	for index in 3:
		clients[index].publish_profile(services[index].local)
	clients[0].create_session(0, "One", "", "https://example.test/world.cne")
	clients[2].create_session(0, "Two", "", "https://example.test/world.cne")
	await pump(relay, clients)
	clients[1].join_session(clients[0].current_session_id)
	await pump(relay, clients)
	check(clients[0].profiles.size() == 2 and clients[1].profiles.size() == 2 and clients[2].profiles.size() == 1,
		"real snapshots expose keys only to members of same instance")
	var identity = load("res://scripts/profile/profile_identity.gd")
	check(clients[0].profiles.all(func(profile): return identity.verify_profile(profile)),
		"every published profile in wire snapshot verifies owner signature")
	var tampered = services[0].local.duplicate(true)
	tampered["profile.username"] = "Forged"
	clients[0].publish_profile(tampered)
	await pump(relay, clients)
	check(clients[1].profiles.all(func(profile): return profile.get("profile.username") != "Forged"),
		"relay rejects tampered profile signature on actual wire")
	services[0].save_profile(services[0].get_local_fingerprint(), fields("Updated"))
	clients[0].publish_profile(services[0].local)
	await pump(relay, clients)
	var found := false
	for profile in clients[1].profiles:
		found = found or profile.get("profile.username") == "Updated"
	check(found, "signed profile update reaches another member without reconnect")
	var duplicate = RelayPeer.new()
	duplicate.account_key = clients[0].account_key
	duplicate.connect_to_relay("127.0.0.1", relay.connection.get_local_port())
	clients.append(duplicate)
	await pump(relay, clients)
	check(not duplicate.is_authenticated, "second simultaneous connection with same key is rejected")
	clients[1].join_session(clients[2].current_session_id)
	await pump(relay, clients)
	check(clients[0].profiles.size() == 1 and clients[1].profiles.size() == 2,
		"session switch replaces old profiles and notifies departed room")
	var old_session = clients[0].current_session_id
	clients[1].on_packet(AccountPacket.create(PacketInfo.PACKET_TYPE.PROFILES_SNAPSHOT,
		{"session_id": old_session, "profiles": [services[0].local]}).encode())
	check(clients[1].profiles.size() == 2, "late snapshot from previous instance is ignored")
	var unauthenticated = RelayPeer.new()
	unauthenticated.connect_to_relay("127.0.0.1", relay.connection.get_local_port())
	clients.append(unauthenticated)
	await pump(relay, clients)
	var count = relay.sessions.size()
	CreateSession.create({"mode": 0, "name": "Attack", "description": "", "world_url": "default_wold"}).sent(unauthenticated.peer)
	await pump(relay, clients)
	check(relay.sessions.size() == count and unauthenticated.current_session_id.is_empty(),
		"unauthenticated raw create packet is denied at relay")
	for client in clients:
		client.peer.peer_disconnect()
	await pump(relay, clients)
	check(relay.key_mapping.is_empty() and relay.public_profiles.is_empty(), "disconnect removes relay account/profile mappings")
	for client in clients:
		client.connection.destroy()
	for service in services:
		dispose(service)
	relay.connection.destroy()
	relay.free()

func test_profile_editor_drafts():
	var service = load(SERVICE).new()
	service.configure(key_pair(), "res://draft.cfg")
	var owner = service.get_local_fingerprint()
	service.save_profile(owner, fields())
	var scene = load(PROFILE_SCENE).instantiate()
	root.add_child(scene)
	scene.open_profile(service, owner)
	scene.edit_buttons["profile.username"].pressed.emit()
	var editor = scene.editor
	editor.controls["profile.username"].text = "Discarded"
	editor.cancel_edit()
	check(service.local["profile.username"] == "Alice", "cancel discards draft without publishing profile")
	check(scene.visible and not editor.visible, "cancel closes only popup and retains profile view")
	scene.open_editor()
	editor.controls["profile.username"].text = "New Alice"
	check(editor.save_edit() and service.local["profile.username"] == "New Alice", "real owner editor saves all fields")
	check(scene.body.get_node("Identity/NameColumn/Name").text == "New Alice" and not editor.visible, "save refreshes display and closes popup")
	scene.open_editor()
	editor.controls["profile.username"].text = "Stale draft"
	service.save_profile(owner, fields("External change"))
	check(not editor.save_edit() and service.local["profile.username"] == "External change", "dirty draft cannot overwrite newer profile revision")
	check(editor.get_node("ErrorPopup").visible and editor.controls["profile.username"].text == "Stale draft", "error popup preserves edit draft")
	editor.cancel_edit()
	scene.open_editor()
	editor.controls["profile.username"].text = "Dirty"
	editor.request_cancel()
	check(editor.visible and editor.confirm_discard.visible, "dirty popup close asks before discarding")
	editor.cancel_edit()
	scene.open_editor()
	check(scene.editor == editor, "Edit reuses one popup")
	check(editor.controls.keys() == ["profile.username"] and editor.avatar_preview == null and editor.picture == null,
		"name popup contains only name input without account/media panels")
	editor.cancel_edit()
	scene.open_editor("profile.icon_source")
	var before = service.local.duplicate(true)
	var image = Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	image.save_png("res://selected-icon.png")
	editor.selected_file_kind = "profile.icon_source"
	editor._file_selected("res://selected-icon.png")
	check(editor.picture.texture != null and service.local == before
		and editor.controls["profile.icon_source"].text == before["profile.icon_source"], "file image previews without changing saved/shared source")
	editor.cancel_edit()
	scene.free()
	await process_frame
	dispose(service)

func test_layout_and_preview():
	var service = load(SERVICE).new()
	service.configure(key_pair(), "res://layout-profile.cfg")
	service.save_profile(service.get_local_fingerprint(), fields())
	var scene = load(PROFILE_SCENE).instantiate()
	root.add_child(scene)
	scene.open_profile(service, service.get_local_fingerprint())
	for dimensions in [Vector2i(1000, 700), Vector2i(640, 480)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var back: Button = scene.get_node("Content/Details/Header/Back")
		var picture: TextureRect = scene.body.get_node("Identity/ImageColumn/Picture")
		var name: Label = scene.body.get_node("Identity/NameColumn/Name")
		var description: Label = scene.body.get_node("DescriptionRow/Description")
		check(back.text.is_empty() and back.icon != null and back.global_position == scene.global_position,
			"simple back arrow is top-left at " + str(dimensions))
		check(picture.global_position.y >= back.get_global_rect().end.y
			and name.global_position.x >= picture.get_global_rect().end.x
			and description.global_position.y >= picture.get_global_rect().end.y,
			"picture/name row and description follow requested layout at " + str(dimensions))
		check(name.size.x > 40 and name.autowrap_mode == TextServer.AUTOWRAP_OFF
			and name.tooltip_text == "Alice", "username has readable width without character-by-character wrapping at " + str(dimensions))
		check(scene.avatar_preview.global_position.x >= scene.get_node("Content/Details").get_global_rect().end.x
			and scene.avatar_preview.get_global_rect().end.x <= scene.get_global_rect().end.x + 1,
			"3D preview remains on right beside all details at " + str(dimensions))
		check(scene.avatar_preview.size.x <= scene.size.x * 0.26,
			"avatar preview uses at most a quarter of profile width at " + str(dimensions))
		for pair in [[picture, scene.edit_buttons["profile.icon_source"]], [name, scene.edit_buttons["profile.username"]],
			[description, scene.edit_buttons["profile.description"]]]:
			check(pair[1].global_position.x >= pair[0].get_global_rect().end.x
				and pair[1].global_position.y < pair[0].get_global_rect().end.y,
				"pencil follows its content on same row at " + str(dimensions))
	var preview = scene.avatar_preview
	var preview_generation = preview.generation
	var avatar_requests = root.get_node("DataLoader").avatar_requests.size()
	scene._refresh()
	check(preview.generation == preview_generation and root.get_node("DataLoader").avatar_requests.size() == avatar_requests,
		"unchanged profile refresh does not restart an already loaded avatar")
	check(preview.viewport.transparent_bg and preview.get_theme_stylebox("panel") is StyleBoxEmpty,
		"avatar preview has transparent viewport and no panel background")
	check(not preview.get_node("Layout/Load").visible and preview.get_node("Layout/Controls/ZoomIn").visible
		and not preview.get_node("Layout/Controls/Reset").visible, "preview exposes rotation and zoom without extra menus")
	scene.edit_buttons["profile.description"].pressed.emit()
	check(scene.editor.controls.keys() == ["profile.description"], "element Edit opens only its own field")
	scene.editor.controls["profile.description"].text = "Changed description"
	scene.editor.save_edit()
	check(service.local["profile.username"] == "Alice" and service.local["profile.description"] == "Changed description",
		"single-field editing preserves other profile values")
	preview.loader = func(_url):
		var model = Node3D.new()
		var mesh = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.scale = Vector3(1, 3, 1)
		mesh.position = Vector3(3, 2, 1)
		model.add_child(mesh)
		return model
	await preview.load_preview()
	check(preview.model != null and preview.viewport.own_world_3d
		and preview.viewport.world_3d != root.world_3d, "preview loads independent model in own World3D")
	check(preview.camera.position.is_finite() and preview.camera.position.z > 0, "transformed mesh framing produces finite camera")
	preview._zoom(0.5)
	preview.pivot.rotate_y(0.5)
	preview.reset_view()
	check(preview.zoom == 1 and is_equal_approx(absf(preview.pivot.rotation.y), PI), "preview starts/reset faces front toward camera")
	var profile_before: Dictionary = service.local.duplicate(true)
	var bytes_received: Array = []
	preview.bytes_loader = func(bytes):
		bytes_received.append(bytes)
		return Node3D.new()
	var file = FileAccess.open("res://local-preview.vrm", FileAccess.WRITE)
	file.store_buffer(PackedByteArray([1, 2, 3, 4]))
	file.close()
	check(await preview.load_file("res://local-preview.vrm") and bytes_received == [PackedByteArray([1, 2, 3, 4])],
		"local VRM selection loads file bytes into preview")
	check(service.local == profile_before and preview.source == "local-preview", "local preview does not modify signed profile or public avatar URL")
	var failures: Array = []
	preview.failed.connect(func(message): failures.append(message))
	check(not await preview.load_file("res://wrong.gd") and failures.size() == 1, "preview rejects non-VRM files")
	preview.hide()
	check(preview.model == null and preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"hiding preview frees model and disables rendering")
	preview.show()
	var late_results: Array = []
	preview.set_source("https://example.test/old.vrm")
	preview.loader = func(_url):
		await create_timer(0.01).timeout
		var result = Node3D.new()
		late_results.append(result)
		return result
	preview.load_preview()
	preview.set_source("https://example.test/new.vrm")
	await create_timer(0.03).timeout
	await process_frame
	check(preview.model == null and late_results.size() == 1 and not is_instance_valid(late_results[0]),
		"stale preview request cannot install model after source changes")
	var visitor_key = key_pair().save_to_string(true)
	var visitor_id = service.cache_remote_profile("room", visitor_key, fields("Visitor"))
	scene.open_profile(service, visitor_id)
	service.clear_remote_profiles()
	check(scene.snapshot.is_empty() and scene.avatar_preview.model == null and not scene.edit_button.visible,
		"visitor departure clears picture/details/model and owner actions")
	scene.free()
	await process_frame
	dispose(service)
