extends SceneTree
## Production autoloads/scenes; real TLS/ENet. Signal-level actions labelled as such.
var passed := 0
var failed := 0
var service
var relay
var host
var menu
var browser
var timeline: Array = []
var elapsed := 0.0
var soak_seconds := 0

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	timeline.append({"at_ms": Time.get_ticks_msec(), "passed": value, "check": title})
	if value: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func _process(delta):
	elapsed += delta
	if service != null: service.poll()
	if relay != null: relay.handle_events()
	if host != null and host.connection != null: host.handle_events()
	if elapsed > 75 + soak_seconds: print("UI watchdog expired"); quit(2)
	return false

func wait_until(predicate: Callable, seconds: float = 5.0) -> bool:
	var until = Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < until: await process_frame
	return predicate.call()

func button(node: Node, title: String):
	for child in node.find_children("*", "Button", true, false):
		if child.text == title: return child
	return null

func screenshot(name: String):
	if DisplayServer.get_name() == "headless": return
	if OS.get_environment("COMUNICARE_UI_NO_SCREENSHOTS") == "1": return
	# Focus/resize can suspend drawing on desktop backends. Never await a draw
	# signal without a timeout and turn a test screenshot into an infinite hang.
	await create_timer(0.15).timeout
	var image = root.get_texture().get_image()
	if not image.is_empty(): image.save_png("user://" + name + ".png")

func run():
	soak_seconds = maxi(0, int(OS.get_environment("COMUNICARE_UI_SOAK_SECONDS")))
	root.size = Vector2i(1000, 700)
	# Exact built-in scene bytes still determine the hash, but renderer-independent
	# activation uses a trusted empty shell to avoid this world's SubViewport/Jolt
	# teardown leaks obscuring the UI membership regression. Explicit fixture boundary.
	var shell = Node3D.new()
	shell.name = "UITestWorld"
	var packed = PackedScene.new()
	packed.pack(shell)
	shell.free()
	if OS.get_environment("COMUNICARE_UI_ORIGINAL_WORLD") != "1": packed.take_over_path("res://scenes/world.tscn")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var save = root.get_node("SaveData")
	root.get_node("DataLoader").get_asset_cache().enabled = false
	check(save.load_acount(), "production account initializes only in disposable user directory")
	# Never publish a default internet avatar to the local host/remote actor path.
	save.data.default_avatar = ""
	var local_fields: Dictionary = save.profile.local.duplicate(true)
	local_fields["profile.avatar_url"] = "http://127.0.0.1:1/no-avatar.vrm"
	save.profile.save_profile(save.profile.get_local_fingerprint(), local_fields)
	save.store.set_value("network.lan_discovery", false)
	var network = root.get_node("NetworkHandler")
	var private_key = Crypto.new().generate_rsa(2048)
	var cert = Crypto.new().generate_self_signed_certificate(private_key, "CN=comunicare-relay,O=Comunicare,C=DE", "20250101000000", "20350101000000")
	service = load("res://scripts/multiplayer/federation/relay_directory_service.gd").new()
	check(service.start(private_key, cert), "real UI fixture starts TLS origin")
	relay = load("res://scripts/multiplayer/relay.gd").new()
	relay.connection = ENetConnection.new()
	check(relay.connection.create_host_bound("127.0.0.1", 0) == OK, "real UI fixture starts ENet origin")
	service.set_gameplay_port(relay.connection.get_local_port())
	host = RelayPeer.new()
	host.account_key = save.key
	host.connect_to_relay("127.0.0.1", relay.connection.get_local_port())
	check(await wait_until(func(): return host.is_authenticated), "real host account authenticates")
	host.expected_world_revision = root.get_node("DataLoader").built_in_world_revision()
	host.create_session(0, "Real UI room", "", "default_wold")
	check(await wait_until(func(): return not host.current_session_id.is_empty()), "real host publishes instance")
	service.set_local_instances([{"origin_relay_id": service.relay_id, "origin_boot_id": service.boot_id, "instance_id": host.current_session_id,
		"world_url": "default_wold", "world_revision": host.expected_world_revision, "mode": 0, "name": "Real UI room", "description": "", "player_count": 1}])
	var directory = network.get_directory_browser()
	directory.add_trusted("127.0.0.1", service.local_port, service.relay_id, cert)
	directory.query(service.relay_id)
	check(await wait_until(func(): return directory.instances().size() == 1), "production directory client receives verified actual instance")
	menu = load("res://scenes/GUI/menue.tscn").instantiate()
	root.add_child(menu)
	menu.current_tab = 2
	browser = menu.page("worlds")
	# External catalog request is cancelled, not a substituted UI script/autoload.
	# Only loopback networking is part of this deterministic acceptance scenario.
	browser.http_request.cancel_request()
	browser._merge_relay_instances()
	browser.create_world_info_menue({"url": "default_wold"})
	await process_frame
	check(browser.get_script().resource_path == "res://scripts/GUI/world_explorer.gd", "actual production World Explorer is mounted in full menu")
	var join = button(browser.instance_list, "Join")
	check(join != null, "verified federated instance has a real UI Join button")
	if join != null: join.pressed.emit()
	check(await wait_until(func(): return network.current_session_id == host.current_session_id and not network.session_busy), "signal-level real Join callback activates acknowledged instance through actual coordinator")
	var original = network.current_session_id
	check(relay.sessions[0][0].peers.size() == 2, "origin sees both admitted accounts after UI join")
	check(save.get("temporary_identity") == true and network.peer.account_key.save_to_string(true) != host.account_key.save_to_string(true), "duplicate saved identity automatically retries with distinct temporary window key")
	var original_key = CryptoKey.new()
	check(original_key.load(save.key_path) == OK and original_key.save_to_string(true) == host.account_key.save_to_string(true), "temporary window never overwrites original saved private key")
	check(save.profile.get_local_fingerprint() != load("res://scripts/profile/profile_identity.gd").fingerprint(host.account_key.save_to_string(true)), "temporary window profile ownership belongs only to new key")
	check(host.is_authenticated and host.is_connected_to_relay and host.current_session_id == network.current_session_id, "first saved-account window stays connected beside temporary second window")
	var temporary_owner = save.profile.get_local_fingerprint()
	check(save.profile.memory_only and save.friends.memory_only and save.friends.state.contacts.is_empty(), "temporary identity has memory-only profile and fresh contacts")
	check(not FileAccess.file_exists("user://profiles/" + temporary_owner + ".cfg") and not FileAccess.file_exists("user://friends/" + temporary_owner + ".cfg"), "temporary account creates no durable profile/contact store")
	var retained_key = save.key.save_to_string(true)
	check(not save.use_temporary_identity() and save.key.save_to_string(true) == retained_key, "temporary identity cannot rotate repeatedly after another authentication denial")
	var joined_peer = network.peer
	var same_summary: Dictionary = directory.instances()[0].duplicate(true)
	check(await network.join_remote_instance(same_summary), "same-origin rejoin succeeds without duplicate-account authentication")
	check(network.peer == joined_peer and relay.sessions[0][0].peers.size() == 2, "same-origin join reuses authenticated transport without duplicate membership")
	var old_instance: String = host.current_session_id
	host.create_session(0, "Second UI room", "", "default_wold")
	check(await wait_until(func(): return host.current_session_id != old_instance), "same origin hosts distinct second instance")
	var second_summary = same_summary.duplicate(true)
	second_summary.instance_id = host.current_session_id
	check(await network.join_remote_instance(second_summary), "same-origin instance switch admits on existing authenticated transport")
	check(network.peer == joined_peer and network.current_session_id == host.current_session_id and relay.sessions.size() == 1,
		"same-origin switch deletes empty previous room without duplicate account/membership")
	original = network.current_session_id
	same_summary = second_summary
	service.set_local_instances([second_summary])
	# Closing the actual browser while its async callback runs must not cancel
	# the stable coordinator or resume into freed Control state.
	menu.current_tab = 2
	browser.create_world_info_menue({"url": "default_wold"})
	var joining = button(browser.instance_list, "Join")
	if joining != null: joining.pressed.emit()
	menu.queue_free()
	await process_frame
	check(await wait_until(func(): return not network.session_busy), "closing full menu during join leaves coordinator recoverable")
	menu = load("res://scenes/GUI/menue.tscn").instantiate()
	root.add_child(menu)
	browser = menu.page("worlds")
	check(network.current_session_id == original, "menu recreation does not lose acknowledged membership")
	# Forced loss is detected by the production process, not a hand-written
	# disconnected label. Restore through fresh origin authentication afterward.
	network.gameplay_tunnel.link.close()
	network.gameplay_tunnel.link.last_error = "UI fixture injected route loss"
	check(await wait_until(func(): return network.current_session_id.is_empty() and not network.session_busy), "route failure clears real coordinator membership and busy state")
	# Let origin process disconnect/liveness before reauthenticating this account.
	var owner: String = save.profile.get_local_fingerprint()
	check(await wait_until(func(): return not relay.key_mapping.values().any(func(value): return value.fingerprint == owner), 12.0), "origin eventually removes lost-route account rather than restoring stale authorization")
	check(await network.join_remote_instance(same_summary), "fresh join recovers after route failure without restarting UI")
	original = network.current_session_id
	menu.current_tab = 3
	var settings = menu.page("settings")
	settings.select_category("Network")
	var panel
	for node in settings.category_pages.Network.get_children():
		if node.get_script() != null and node.get_script().resource_path.ends_with("relay_preferences_panel.gd"): panel = node
	check(panel != null, "real Settings Network mounts actual preferences panel")
	check(not settings.controls.has("network.relay_address") and not settings.controls.has("network.relay_port"), "legacy migration fields are not presented as effective connection controls")
	check(panel.has_method("edit_entry"), "Network panel provides selected-row endpoint editing")
	cert.save("user://ui-origin.crt")
	panel.host_input.text = "127.0.0.1"
	panel.identity_input.text = service.relay_id
	panel.tls_port.value = service.local_port
	panel.certificate_input.text = "user://ui-origin.crt"
	button(panel, "Trust directory certificate for address above").pressed.emit()
	check(network.directory_trust.entries.any(func(entry): return entry.relay_id == service.relay_id), "actual certificate-import UI persists explicitly selected origin trust")
	panel.identity_input.text = "invalid"
	button(panel, "Trust directory certificate for address above").pressed.emit()
	check(network.directory_trust.entries.size() == 1 and not network.last_session_error.is_empty(), "invalid trust UI submission preserves existing certificate store")
	panel.identity_input.text = ""
	var muted_before = save.voice.is_muted()
	panel.host_input.grab_focus()
	for code in [KEY_E, KEY_V, KEY_B]:
		var typed = InputEventKey.new()
		typed.keycode = code
		typed.physical_keycode = code
		typed.unicode = code
		typed.pressed = true
		root.push_input(typed, true)
		await process_frame
	check(save.voice.is_muted() == muted_before and menu.visible, "typing E/V/B in actual relay field does not toggle microphone or dismiss menu")
	panel.host_input.release_focus()
	browser._on_request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	check(not menu.find_children("*", "AcceptDialog", true, false).any(func(dialog): return dialog.visible), "catalog failure remains nonmodal while local instance UI works")
	await screenshot("network-before-edit")
	panel.label_input.text = "Unrelated fallback"
	panel.host_input.text = "127.0.0.1"
	panel.port_input.value = 19998
	button(panel, "Add relay").pressed.emit()
	await process_frame
	check(network.current_session_id == original and network.peer.is_authenticated and network.gameplay_tunnel != null,
		"adding unrelated relay through actual Settings preserves live federated membership")
	var preferences = network.get_relay_preferences()
	var added: Dictionary = preferences.snapshot().entries.back()
	panel.edit_entry(added.entry_id)
	panel.port_input.value = 19997
	button(panel, "Save selected relay edit").pressed.emit()
	check(preferences.snapshot().entries.back().port == 19997 and network.current_session_id == original, "actual endpoint edit saves effective list without disconnecting current play")
	preferences.move_entry(added.entry_id, 0)
	await process_frame
	check(network.current_session_id == original, "reordering preferences preserves live federated membership")
	preferences.remove_entry(added.entry_id)
	await process_frame
	check(network.current_session_id == original, "removing unrelated fallback preserves live federated membership")
	var prefs_path: String = preferences.path
	check(preferences.save_preferences().ok, "actual UI preferences persist before reload")
	var restored = load("res://scripts/multiplayer/federation/relay_preferences.gd").new()
	restored.configure(prefs_path)
	check(restored.load_preferences().ok and restored.snapshot() == preferences.snapshot(), "reopened store retains exact user order and independent blocks")
	# Stage mismatch fails before transport switching and keeps live membership.
	var wrong_hash = same_summary.duplicate(true)
	wrong_hash.world_revision = "f".repeat(64)
	# Use another origin marker to exercise remote preflight instead of same-origin
	# transport reuse. Advertised content hash still must be validated first.
	wrong_hash.origin_relay_id = "e".repeat(64)
	directory.links[service.relay_id].instances.append(wrong_hash)
	check(not await network.join_remote_instance(wrong_hash) and network.current_session_id == original, "invalid pinned content fails staging without discarding current membership")
	directory.links[service.relay_id].instances.erase(wrong_hash)
	if soak_seconds > 0:
		var deadline = Time.get_ticks_msec() + soak_seconds * 1000
		var rounds = 0
		while Time.get_ticks_msec() < deadline:
			preferences.add_entry({"entry_id": "soak", "label": "Soak fallback", "host": "127.0.0.1", "port": 19996, "relay_id": ""})
			preferences.move_entry("soak", 0)
			preferences.remove_entry("soak")
			menu.current_tab = 2 if rounds % 2 == 0 else 3
			await create_timer(1.0).timeout
			if network.current_session_id != original or not network.peer.is_authenticated:
				check(false, "soak preserved actual membership")
				break
			rounds += 1
		check(network.current_session_id == original and service.tunnels.size() <= 1 and relay.sessions.size() == 1,
			"%ss actual UI/TLS membership soak with %s add/reorder/remove cycles and bounded route state" % [soak_seconds, rounds])
	preferences.set_blocked(service.relay_id, true)
	await process_frame
	check(network.current_session_id.is_empty() and not network.peer.is_connected_to_relay, "blocking active origin still disconnects immediately")
	await test_pointer_navigation(settings)
	# Connection timing is independent from directory refresh timing: no null
	# dereference or directory timeout while the browser has no peer yet.
	var old_peer = network.peer
	network.peer = null
	browser._attach_peer()
	browser.refreshing = true
	browser.connecting = true
	browser.refresh_started = Time.get_ticks_msec() - 11000
	browser._process(0)
	check(browser.connecting and not browser.legacy_timed_out, "offline connection wait is not treated as a directory timeout")
	browser.connecting = false
	browser.refreshing = false
	network.peer = old_peer
	await screenshot("network-after-edit")
	# Release the resource-cache override while still inside the live renderer.
	await cleanup(network)
	var file = FileAccess.open("user://ui-timeline.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(timeline, "  "))
	file.close()
	print("\nReal UI acceptance: %s passed, %s failed; display=%s" % [passed, failed, DisplayServer.get_name()])
	print("Signal-level membership edits plus hit-tested Network navigation; no two-window gameplay/soak claim.")
	quit(1 if failed else 0)

func test_pointer_navigation(settings):
	menu.current_tab = 3
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for scenario in [{"size": Vector2i(640, 480), "scale": 1.0}, {"size": Vector2i(1000, 700), "scale": 1.0}, {"size": Vector2i(1440, 900), "scale": 1.5}]:
		var dimensions: Vector2i = scenario.size
		root.size = dimensions
		root.content_scale_factor = scenario.scale
		settings.select_category("Assets")
		await process_frame
		await process_frame
		await create_timer(0.05).timeout
		var control: Control = settings.category_buttons.Network
		var logical = control.get_global_rect().get_center()
		# push_input consumes viewport coordinates directly; unlike OS input it
		# must not be rescaled through the physical-window final transform.
		var physical = logical
		var motion = InputEventMouseMotion.new()
		motion.position = physical
		motion.global_position = physical
		root.push_input(motion, true)
		await process_frame
		for pressed in [true, false]:
			var event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = physical
			event.global_position = physical
			event.pressed = pressed
			root.push_input(event, true)
			await process_frame
		check(settings.selected_category == "Network", "hit-tested pointer selects real Network tab at %s scale %s" % [dimensions, scenario.scale])
		await screenshot("network-pointer-%sx%s" % [dimensions.x, dimensions.y])
	root.content_scale_factor = 1.0

func cleanup(network):
	# Hidden avatar preview viewports still allocate render targets on a real GPU.
	# Release texture consumers before their SubViewports and flush one frame.
	if menu != null:
		for container in menu.find_children("*", "SubViewportContainer", true, false):
			for viewport in container.get_children():
				if viewport is SubViewport:
					viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
					viewport.size = Vector2i(2, 2)
		await process_frame
	if menu != null: menu.queue_free()
	if network.gameplay_tunnel != null: network.gameplay_tunnel.close(); network.gameplay_tunnel = null
	if network.peer != null:
		if network.peer.connection != null: network.peer.connection.destroy(); network.peer.connection = null
		network.peer.disconnected_from_relay()
	if network.directory_browser != null: network.directory_browser.stop()
	if network.lan_discovery != null: network.lan_discovery.stop()
	var actors = network.get("animation_controller")
	if is_instance_valid(actors):
		actors.queue_free()
		network.animation_controller = null
	host.connection.destroy()
	host.connection = null
	service.stop()
	service = null
	relay.connection.destroy()
	relay.free()
	relay = null
	if current_scene != null: current_scene.queue_free()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless": await create_timer(0.25).timeout
