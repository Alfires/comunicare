extends Node

var peer: RelayPeer
var player_scene = preload("res://scenes/player/remote_player.tscn")
var players = {}
var relay_ip := "127.0.0.1"
var relay_port := 7374
var relay_preferences
var active_relay_entry: Dictionary = {}
var relay_selection_errors: Array = []
var directory_browser
var directory_trust
var lan_discovery
var directory_refresh_at := 0
var gameplay_tunnel
var current_origin := ""
signal relay_directory_changed

func get_directory_browser():
	if directory_browser != null: return directory_browser
	directory_browser = load("res://scripts/multiplayer/federation/relay_directory_client.gd").new()
	directory_trust = load("res://scripts/multiplayer/federation/relay_directory_trust.gd").new()
	directory_trust.load_trust()
	directory_trust.apply_to(directory_browser)
	directory_browser.changed.connect(func(): relay_directory_changed.emit())
	var preferences = get_relay_preferences().snapshot()
	directory_browser.set_blocks(preferences.blocked_ids, preferences.blocked_endpoints)
	lan_discovery = load("res://scripts/multiplayer/federation/lan_relay_transport.gd").new()
	var enabled = false
	var save = get_node_or_null("/root/SaveData")
	if save != null and save.get("store") != null: enabled = save.store.get_value("network.lan_discovery") != false
	lan_discovery.start(enabled, preferences.blocked_ids)
	return directory_browser

func refresh_relay_directories():
	var browser = get_directory_browser()
	for id in browser.trusted:
		if browser.links.size() >= 4 and not browser.links.has(id): break
		browser.query(id)

func get_remote_instances() -> Array:
	return directory_browser.instances() if directory_browser != null else []

func get_lan_relay_candidates() -> Array:
	return lan_discovery.model.candidates() if lan_discovery != null else []

func trust_relay_directory(id: String, host: String, port: int, certificate_path: String, common_name: String = "comunicare-relay") -> bool:
	get_directory_browser()
	if not directory_trust.add_certificate(id, host, port, certificate_path, common_name):
		last_session_error = directory_trust.last_error
		return false
	directory_trust.apply_to(directory_browser)
	refresh_relay_directories()
	return true

func revoke_relay_directory(id: String) -> bool:
	get_directory_browser()
	if not directory_trust.remove(id):
		last_session_error = directory_trust.last_error
		return false
	directory_browser.stop()
	directory_browser.trusted.erase(id)
	# Revoked trust may be an ingress for a different origin; end conservatively.
	if gameplay_tunnel != null:
		gameplay_tunnel.close()
		gameplay_tunnel = null
		if peer != null:
			if peer.peer != null: peer.peer.peer_disconnect_now()
			peer.disconnected_from_relay()
	refresh_relay_directories()
	return true

func join_remote_instance(instance: Dictionary) -> bool:
	if session_busy or connection_in_progress:
		last_session_error = "Another connection/transition is in progress"
		return false
	var browser = get_directory_browser()
	var origin = str(instance.get("origin_relay_id", ""))
	var destination = str(instance.get("instance_id", ""))
	var revision = str(instance.get("world_revision", ""))
	var policy = get_relay_preferences().snapshot()
	if origin in policy.blocked_ids: return _transition_failed("Destination relay blocked")
	var selected: Dictionary = {}
	# Prefer main/fallback list as ingress where it has explicit certificate trust;
	# directory/explicit instance access is not limited to those saved entries.
	for entry in policy.entries:
		if browser.trusted.has(entry.relay_id) and not relay_preferences.is_blocked(entry):
			selected = browser.trusted[entry.relay_id]
			break
	if selected.is_empty():
		for id in browser.links:
			if id in policy.blocked_ids: continue
			for summary in browser.links[id].instances:
				if summary.get("origin_relay_id") == origin and summary.get("origin_boot_id") == instance.get("origin_boot_id") and summary.get("instance_id") == destination:
					selected = browser.trusted[id]
					break
			if not selected.is_empty(): break
	if selected.is_empty(): return _transition_failed("No allowed certificate-trusted route to instance")
	session_busy = true
	var staged: Dictionary = await DataLoader.prepare_world_from_url(str(instance.get("world_url", "")), revision)
	if staged.is_empty(): return _transition_failed("Cannot stage exact destination world revision")
	var tunnel = load("res://scripts/multiplayer/federation/relay_game_tunnel.gd").new()
	if not tunnel.start(selected.host, int(selected.port), selected.certificate, origin, policy.blocked_ids, selected.common_name):
		return _transition_failed("Cannot start trusted relay route")
	var until = Time.get_ticks_msec() + 10000
	while not tunnel.ready and tunnel.last_error.is_empty() and Time.get_ticks_msec() < until:
		tunnel.poll()
		await get_tree().process_frame
	if not tunnel.ready:
		tunnel.close()
		return _transition_failed("Destination route unavailable or blocked")
	# Preserve the old connection while route/content preparation is still fallible.
	# Once switching transports begins, old membership ends; failures cannot claim
	# to preserve that membership. Destination still reauthenticates/admit normally.
	if gameplay_tunnel != null: gameplay_tunnel.close()
	gameplay_tunnel = tunnel
	current_origin = origin
	if peer != null and peer.peer != null: peer.peer.peer_disconnect_now()
	if peer != null: peer.disconnected_from_relay()
	relay_ip = "127.0.0.1"
	relay_port = tunnel.local_port
	connection_in_progress = true
	var success = await _connect_relay_candidate()
	connection_in_progress = false
	if not success:
		tunnel.close()
		gameplay_tunnel = null
		return _transition_failed(last_session_error)
	if origin in relay_preferences.snapshot().blocked_ids:
		tunnel.close()
		return _activation_failed("Destination relay blocked during authentication")
	peer.expected_world_revision = revision
	_start_request("join", destination)
	peer.join_session(destination, str(instance.world_url))
	var result: Dictionary = await session_response
	return await _finish_transition(result, staged, str(instance.world_url))

func get_relay_preferences():
	if relay_preferences != null: return relay_preferences
	relay_preferences = load("res://scripts/multiplayer/federation/relay_preferences.gd").new()
	relay_preferences.configure("user://relay_preferences.json")
	var loaded: Dictionary = relay_preferences.load_preferences()
	if loaded.ok:
		var save = get_node_or_null("/root/SaveData")
		var address = relay_ip
		var port = relay_port
		if save != null and save.get("store") != null:
			var configured_host = save.store.get_value("network.relay_address")
			var configured_port = save.store.get_value("network.relay_port")
			if configured_host is String: address = configured_host
			if configured_port is int or configured_port is float: port = int(configured_port)
		relay_preferences.migrate_legacy(address, port)
	relay_preferences.changed.connect(_relay_policy_changed)
	return relay_preferences

func _relay_policy_changed():
	if directory_browser != null:
		var policy = relay_preferences.snapshot()
		directory_browser.set_blocks(policy.blocked_ids, policy.blocked_endpoints)
		if lan_discovery != null: lan_discovery.model.configure({"enabled": lan_discovery.socket != null}, policy.blocked_ids)
		if gameplay_tunnel != null:
			# Conservatively end a route on block changes until all active actor
			# ingress provenance is carried by the origin membership protocol.
			gameplay_tunnel.close()
			gameplay_tunnel = null
			if peer != null: peer.disconnected_from_relay()
	if active_relay_entry.is_empty() or not relay_preferences.is_blocked(active_relay_entry): return
	if peer != null:
		if peer.peer != null: peer.peer.peer_disconnect_now()
		peer.authentication_error = "Active relay was blocked locally"
		peer.disconnected_from_relay()
	active_relay_entry.clear()

func _relay_candidates() -> Array:
	# Isolated transport callers can still use explicit relay_ip/relay_port without
	# causing preference persistence. Normal startup owns a real settings store.
	var save = get_node_or_null("/root/SaveData")
	if relay_preferences == null and save != null and save.get("store") != null: get_relay_preferences()
	if relay_preferences == null: return [{"entry_id": "explicit", "label": "Relay", "host": relay_ip, "port": relay_port, "relay_id": ""}]
	var candidates: Array = []
	for entry in relay_preferences.snapshot().entries:
		if not relay_preferences.is_blocked(entry): candidates.append(entry)
	return candidates

var id: int = -1
var remote_ids: Array[int]
var current_session_id := ""
var current_world_url := "default_wold"
var last_session_error := ""
var session_busy := false
var pending_operation := ""
var pending_id := ""
var pending_deadline := 0
signal session_response(result: Dictionary)
signal participants_changed
var authentication_pending := false
var authentication_deadline := 0
var connection_in_progress := false
signal relay_connection_finished(success: bool)
var active_instance: Dictionary = {}
signal active_instance_changed
signal instance_management_finished(result: Dictionary)
var management_pending: Dictionary = {}
var management_sequence := 0
var instance_status := ""
var snapshot_deadline := 0
var animation_controller: Node
var participant_registry = preload("res://scripts/multiplayer/client/participant_registry.gd").new()

func get_animation_controller() -> Node:
	if not is_instance_valid(animation_controller) or animation_controller.is_queued_for_deletion():
		animation_controller = preload("res://scripts/assets/animation_controller.gd").new()
	if is_inside_tree() and not animation_controller.is_inside_tree():
		# Owned outside the remote-player list, but not attached to the busy root.
		# NetworkHandler children are cleared as remote players on transitions.
		# DataLoader is a stable autoload and already ready when clients start.
		var host = get_node_or_null("/root/DataLoader")
		if host != null and animation_controller.get_parent() == null:
			host.add_child(animation_controller)
		animation_controller.configure(self, DataLoader)
	return animation_controller

func _ready() -> void:
	if "--relay" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		return
	if SaveData.get("profile") != null:
		SaveData.profile.profile_changed.connect(_publish_profile)
	if peer != null: peer.session_result_guard = _accept_session_result

func _accept_session_result(result: Dictionary) -> bool:
	if not result.get("operation") is String or not result.get("session_id") is String or not result.get("success") is bool: return false
	if not pending_operation.is_empty():
		return result.operation == pending_operation and (pending_operation == "create" or result.session_id == pending_id)
	return result.operation == "create" and not session_busy

func _process(_delta):
	if gameplay_tunnel != null:
		gameplay_tunnel.poll()
		if not gameplay_tunnel.last_error.is_empty():
			last_session_error = gameplay_tunnel.last_error
			gameplay_tunnel.close()
			gameplay_tunnel = null
			if peer != null: peer.disconnected_from_relay()
	if directory_browser != null:
		directory_browser.poll()
		if lan_discovery != null: lan_discovery.poll()
		if Time.get_ticks_msec() >= directory_refresh_at:
			directory_refresh_at = Time.get_ticks_msec() + 5000
			refresh_relay_directories()
			relay_directory_changed.emit()
	if snapshot_deadline > 0 and Time.get_ticks_msec() >= snapshot_deadline:
		snapshot_deadline = 0
		instance_status = "Active Instance unavailable: relay did not provide state. Update the relay or retry."
		active_instance_changed.emit()
	if not management_pending.is_empty() and Time.get_ticks_msec() >= management_pending.deadline:
		var expired = management_pending.duplicate()
		management_pending.clear()
		active_instance.clear()
		instance_status = "Request timed out; outcome unknown. Refreshing authoritative state."
		instance_management_finished.emit({"request_id": expired.request_id, "success": false, "message": instance_status})
		refresh_instance()
		active_instance_changed.emit()
	if authentication_pending and Time.get_ticks_msec() >= authentication_deadline:
		authentication_pending = false
		peer.authentication_error = "Relay connection/authentication timed out at %s:%s. Start the relay or check Network settings and UDP/firewall access." % [relay_ip, relay_port]
		if peer.peer != null: peer.peer.peer_disconnect_now()
		peer.authentication_finished.emit(false)
	if not pending_operation.is_empty() and Time.get_ticks_msec() >= pending_deadline:
		# The relay may have committed a request whose acknowledgement was lost.
		# Disconnect rather than keeping an unknown membership alive.
		_fail_pending("Relay request timed out; disconnected to avoid an unknown session")
		if peer != null and peer.peer != null:
			peer.peer.peer_disconnect()
		if peer != null:
			peer.disconnected_from_relay()
	if peer == null or peer.connection == null: return
	
	peer.handle_events()


func ensure_relay_connected() -> bool:
	if connection_in_progress: return await relay_connection_finished
	if peer != null and peer.is_connected_to_relay and peer.is_authenticated: return true
	return await create_peer()

func create_peer() -> bool:
	if connection_in_progress: return await relay_connection_finished
	if peer != null and peer.is_connected_to_relay and peer.is_authenticated: return true
	connection_in_progress = true
	if gameplay_tunnel != null:
		gameplay_tunnel.close()
		gameplay_tunnel = null
	relay_selection_errors.clear()
	var candidates = _relay_candidates()
	for entry in candidates:
		if not str(entry.get("relay_id", "")).is_empty():
			var browser = get_directory_browser()
			if not browser.trusted.has(entry.relay_id):
				relay_selection_errors.append(str(entry.label) + ": import the relay certificate before using its identity pin")
				continue
			var trusted: Dictionary = browser.trusted[entry.relay_id]
			var tunnel = load("res://scripts/multiplayer/federation/relay_game_tunnel.gd").new()
			if not tunnel.start(trusted.host, int(trusted.port), trusted.certificate, entry.relay_id, relay_preferences.snapshot().blocked_ids, trusted.common_name): continue
			var until = Time.get_ticks_msec() + 10000
			while not tunnel.ready and tunnel.last_error.is_empty() and Time.get_ticks_msec() < until:
				tunnel.poll()
				await get_tree().process_frame
			if not tunnel.ready:
				tunnel.close()
				continue
			gameplay_tunnel = tunnel
			current_origin = entry.relay_id
		if relay_preferences != null and relay_preferences.is_blocked(entry): continue
		relay_ip = "127.0.0.1" if gameplay_tunnel != null else entry.host
		relay_port = gameplay_tunnel.local_port if gameplay_tunnel != null else int(entry.port)
		active_relay_entry = entry.duplicate(true)
		var success = await _connect_relay_candidate()
		var still_allowed = relay_preferences == null
		if relay_preferences != null:
			for current in relay_preferences.snapshot().entries:
				if current == entry and not relay_preferences.is_blocked(entry): still_allowed = true
		if success and still_allowed:
			connection_in_progress = false
			relay_connection_finished.emit(true)
			return true
		if success and not still_allowed:
			if peer.peer != null: peer.peer.peer_disconnect_now()
			peer.disconnected_from_relay()
			last_session_error = "Relay preference changed while connecting; retry with the current list"
			break
		relay_selection_errors.append("%s:%s — %s" % [entry.host, entry.port, last_session_error])
		if gameplay_tunnel != null:
			gameplay_tunnel.close()
			gameplay_tunnel = null
		# Authentication rejection is not permission to try alternate relays to
		# circumvent account/security policy. Capacity/unreachable may fail over.
		if peer != null and peer.authentication_rejected: break
	active_relay_entry.clear()
	last_session_error = "No saved relay connected. " + "; ".join(relay_selection_errors) if not relay_selection_errors.is_empty() else "No allowed saved relays. Add or unblock one in Network settings."
	connection_in_progress = false
	relay_connection_finished.emit(false)
	return false

func _connect_relay_candidate() -> bool:
	if peer != null:
		if peer.connection != null: peer.connection.destroy()
		peer.disconnected_from_relay()
	get_animation_controller()
	peer = RelayPeer.new()
	peer.session_result_guard = _accept_session_result
	peer.account_key = SaveData.key
	if SaveData.get("friends") != null:
		peer.friend_service = SaveData.friends
	var owner = preload("res://scripts/profile/profile_identity.gd").fingerprint(SaveData.key.save_to_string(true))
	DirAccess.make_dir_recursive_absolute("user://moderation")
	peer.configure_moderation("user://moderation/".path_join(owner + ".cfg"))
	peer.player_data.connect(sync_player_data)
	peer.on_session_peers_update.connect(update_connected_peers)
	peer.voice_data.connect(sync_player_voice)
	peer.session_result.connect(_on_session_result)
	peer.on_disconnected_from_relay.connect(_on_relay_disconnected)
	peer.profiles_updated.connect(_on_profiles_updated)
	peer.instance_snapshot.connect(_on_instance_snapshot)
	peer.instance_result.connect(_on_instance_result)
	peer.instance_evicted.connect(_on_instance_evicted)
	if not peer.connect_to_relay(relay_ip,relay_port):
		last_session_error = peer.authentication_error
		return false
	authentication_pending = true
	authentication_deadline = Time.get_ticks_msec() + 15000
	var success: bool = await peer.authentication_finished
	authentication_pending = false
	if not success:
		last_session_error = peer.authentication_error
		if last_session_error.is_empty(): last_session_error = "Relay connection failed at %s:%s. Start the relay and retry Reload." % [relay_ip, relay_port]
		if peer.connection != null:
			peer.connection.destroy()
			peer.connection = null
		peer.is_connected_to_relay = false
		peer.is_authenticated = false
		return false
	last_session_error = ""
	_publish_profile("")
	return true

func create_session(world_url: String = "default_wold", mode: int = PacketInfo.MODE.PUBLIC):
	if peer == null or not peer.is_connected_to_relay or not peer.is_authenticated:
		return
	var username = str(SaveData.data.get("username", "Player"))
	if peer.world_revision_supported and world_url == "default_wold" and DataLoader.has_method("built_in_world_revision"):
		peer.expected_world_revision = DataLoader.built_in_world_revision()
	peer.create_session(mode, username.left(128), "The world from " + username, world_url)
	

func _on_peer_disconnected(peer_id):
	print("Client disconnected: %d" % peer_id) 
	if players.has(peer_id):
		players[peer_id].queue_free()
		players.erase(peer_id)
	
	
# Join Session part / Client 

# model requester
@rpc("any_peer","call_local","unreliable")
func request_player_model():
	var peer_id = multiplayer.get_remote_sender_id()
	rpc_id(peer_id, "sync_player_avatar", SaveData.data["avatar_url"])

# model loader sync
@rpc("any_peer", "call_remote", "unreliable")
func sync_player_avatar(avatar_url: String):
	var peer_id = multiplayer.get_remote_sender_id()
	print("client received avatar...")
	var player_node = find_child(str(peer_id), false, false)
	if player_node:
		print("loding model...")
		player_node.load_player_model(avatar_url)
	else:
		print("peer was not found in local players")

# player movement
func sync_player_data(data: PlayerData):#,rotation: Vector3):
	if current_session_id.is_empty() or session_busy:
		return
	# Server relays to all others
	var player_node = find_child(str(data.id), false, false)
	if player_node:
		player_node.position = data.position
		player_node.rotation = data.rotation

# player voice
func sync_player_voice(data: VoiceData): #PackedFloat32Array
	if current_session_id.is_empty() or session_busy:
		return
	# Server relays to all others
	var player_node = find_child(str(data.id), false, false)
	
	if player_node:
		player_node._play_audio(data.audio)

func join_session(session_id: String, world_url: String = "") -> bool:
	if not _begin_transition():
		return false
	var connection = peer
	var expected_revision := ""
	if peer.world_revision_supported:
		_start_request("resolve", session_id)
		peer.resolve_instance(session_id)
		var resolved: Dictionary = await session_response
		if peer != connection: return _transition_failed("Connection changed while resolving instance")
		if not resolved.get("success", false):
			return _transition_failed(str(resolved.get("message", "Instance unavailable")))
		world_url = str(resolved.get("world_url", ""))
		expected_revision = str(resolved.get("world_revision", ""))
	if world_url.is_empty():
		# Manual room codes use the same public directory, never guess a world.
		for session in peer.public_session:
			if session is Dictionary and session.get("session_id") == session_id \
				and session.get("mode") == PacketInfo.MODE.PUBLIC:
				world_url = str(session.get("world_url", ""))
				break
		if world_url.is_empty() and peer.peer != null:
			_start_request("resolve", session_id)
			peer.resolve_instance(session_id)
			var lookup: Dictionary = await session_response
			if peer != connection: return _transition_failed("Connection changed while resolving instance")
			if not lookup.get("success", false):
				return _transition_failed(str(lookup.get("message", "Instance unavailable or access denied")))
			world_url = str(lookup.get("world_url", ""))
	if not WorldAddress.is_valid(world_url):
		return _transition_failed("Instance unavailable or world address could not be resolved")
	var staged: Dictionary
	if not expected_revision.is_empty():
		staged = await DataLoader.prepare_world_from_url(world_url, expected_revision)
	else:
		staged = await DataLoader.prepare_world_from_url(world_url)
	if staged.is_empty():
		var message = "Could not download or validate the instance's world"
		if DataLoader.has_method("get_asset_cache"):
			message += ": " + DataLoader.get_asset_cache().last_error
		return _transition_failed(message)
	if peer != connection or not connection.is_connected_to_relay:
		return _transition_failed("Relay disconnected while loading the world")
	_start_request("join", session_id)
	peer.expected_world_revision = expected_revision
	peer.join_session(session_id, world_url)
	var result: Dictionary = await session_response
	if peer != connection: return _transition_failed("Connection changed before world activation")
	return await _finish_transition(result, staged, world_url)

func host_world(world_url: String) -> bool:
	if not _begin_transition():
		return false
	var connection = peer
	if not WorldAddress.is_valid(world_url):
		return _transition_failed("Invalid world address")
	var staged: Dictionary = await DataLoader.prepare_world_from_url(world_url)
	if staged.is_empty():
		var message = "Could not download or validate the world"
		if DataLoader.has_method("get_asset_cache"):
			message += ": " + DataLoader.get_asset_cache().last_error
		return _transition_failed(message)
	if peer != connection or not connection.is_connected_to_relay:
		return _transition_failed("Relay disconnected while loading the world")
	_start_request("create", "")
	peer.expected_world_revision = str(staged.get("revision", "")) if peer.world_revision_supported else ""
	create_session(world_url)
	var result: Dictionary = await session_response
	return await _finish_transition(result, staged, world_url)

func _begin_transition() -> bool:
	if session_busy:
		last_session_error = "Another world transition is in progress"
		return false
	if peer == null or not peer.is_connected_to_relay or not peer.is_authenticated:
		last_session_error = "Relay disconnected"
		return false
	session_busy = true
	management_pending.clear()
	active_instance_changed.emit()
	last_session_error = ""
	return true

func _transition_failed(message: String) -> bool:
	last_session_error = message
	session_busy = false
	active_instance_changed.emit()
	return false

func _start_request(operation: String, session_id: String):
	pending_operation = operation
	pending_id = session_id
	pending_deadline = Time.get_ticks_msec() + (65000 if operation == "join" else 10000)

func _finish_transition(result: Dictionary, staged: Dictionary, world_url: String) -> bool:
	if not result.get("success", false):
		return _transition_failed(str(result.get("message", "Instance request failed")))
	if result.get("world_url") != world_url:
		return _activation_failed("Relay returned a different world URL")
	if not result.get("world_revision", "").is_empty() and result.world_revision != staged.get("revision", ""):
		return _activation_failed("Relay acknowledged a different world revision")
	if current_session_id != result.get("session_id"):
		return _transition_failed("Instance membership ended before world activation")
	if not await DataLoader.activate_world(staged):
		return _activation_failed("World activation failed; relay disconnected")
	if not peer.is_connected_to_relay or current_session_id != result.get("session_id"):
		return _transition_failed("Relay disconnected during world activation")
	current_world_url = world_url
	session_busy = false
	active_instance_changed.emit()
	return true

func _activation_failed(message: String) -> bool:
	# Membership already changed. Disconnect rather than run the previous scene
	# while broadcasting into a different world; the existing local scene remains.
	if peer != null and peer.peer != null:
		peer.peer.peer_disconnect()
	if peer != null:
		peer.disconnected_from_relay()
	return _transition_failed(message)

func _on_session_result(result: Dictionary):
	if not result.get("operation") is String or not result.get("session_id") is String \
		or not result.get("success") is bool:
		return
	if not pending_operation.is_empty():
		if result.operation != pending_operation or (pending_operation in ["join", "resolve"] and result.session_id != pending_id):
			return
		pending_operation = ""
		if result.success and result.operation != "resolve":
			_reset_instance_state()
			current_session_id = result.session_id
			if SaveData.get("profile") != null:
				SaveData.profile.clear_remote_profiles()
			_clear_remote_players()
			snapshot_deadline = Time.get_ticks_msec() + 10000
		session_response.emit(result)
	elif result.operation == "create" and not session_busy and result.success:
		# Initial home hosting is sent by startup, outside a browser transition.
		_reset_instance_state()
		current_session_id = result.session_id
		snapshot_deadline = Time.get_ticks_msec() + 10000
		current_world_url = str(result.get("world_url", "default_wold"))
		if SaveData.get("profile") != null:
			SaveData.profile.clear_remote_profiles()

func _fail_pending(message: String):
	if pending_operation.is_empty():
		return
	pending_operation = ""
	session_response.emit({"success": false, "message": message})

func _on_relay_disconnected():
	if authentication_pending:
		authentication_pending = false
		peer.authentication_finished.emit(false)
	current_session_id = ""
	_reset_instance_state()
	if SaveData.get("profile") != null:
		SaveData.profile.clear_remote_profiles()
	participants_changed.emit()
	_clear_remote_players()
	_fail_pending("Relay disconnected")

func _clear_remote_players():
	participant_registry.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	players.clear()
	
func _on_join_error(code, message) -> void:
	push_error("Join error %s: %s" % [code, message])

func _on_connected_to_server():
	print("Connected to server!")
	print("sending user avatar")
	
func update_connected_peers():
	print("updating peers list")
	for child in get_children():
		var peer_id = int(child.name) 
		if peer_id not in peer.session_peers:
			remove_child(child)
			child.queue_free()
	
	for peer_id in peer.session_peers:
		if not has_node(str(peer_id)):
			var player = player_scene.instantiate()
			player.name = str(peer_id)
			player.user_name = str(peer_id)
			add_child(player)
	participants_changed.emit()

func _reset_instance_state():
	if is_instance_valid(animation_controller):
		animation_controller.clear()
	active_instance.clear()
	management_pending.clear()
	snapshot_deadline = 0
	instance_status = ""
	active_instance_changed.emit()

func _on_instance_snapshot(value: Dictionary):
	if current_session_id.is_empty() or value.get("session_id") != current_session_id or not InstanceState.valid(value):
		return
	if value == active_instance:
		snapshot_deadline = 0
		return
	if not active_instance.is_empty() and value.revision <= active_instance.revision:
		return
	active_instance = value.duplicate(true)
	snapshot_deadline = 0
	instance_status = ""
	active_instance_changed.emit()
	participants_changed.emit()

func is_instance_admin() -> bool:
	if SaveData.get("profile") == null or active_instance.is_empty():
		return false
	var owner = SaveData.profile.get_local_fingerprint()
	for member in active_instance.members:
		if member.fingerprint == owner:
			return member.role == "admin"
	return false

func refresh_instance():
	if peer == null or peer.peer == null or current_session_id.is_empty() or not peer.is_authenticated:
		return
	management_sequence += 1
	peer.request_instance({"request_id": "refresh-%d" % management_sequence,
		"session_id": current_session_id, "action": "refresh"})
	snapshot_deadline = Time.get_ticks_msec() + 10000

func manage_instance(action: String, target: Dictionary = {}, changes: Dictionary = {}, expected_revision: int = -1) -> String:
	if session_busy or not management_pending.is_empty() or not is_instance_admin() \
		or peer == null or peer.peer == null or not peer.is_authenticated:
		return ""
	management_sequence += 1
	var request = {"request_id": "manage-%d" % management_sequence, "session_id": current_session_id,
		"action": action, "expected_revision": active_instance.revision if expected_revision < 0 else expected_revision,
		"changes": changes}
	if not target.is_empty():
		request.target_fingerprint = target.fingerprint
		request.target_peer_id = target.peer_id
	management_pending = {"request_id": request.request_id, "session_id": current_session_id,
		"deadline": Time.get_ticks_msec() + 10000}
	peer.request_instance(request)
	active_instance_changed.emit()
	return request.request_id

func _on_instance_result(value: Dictionary):
	if management_pending.is_empty() or value.get("session_id") != current_session_id \
		or value.get("request_id") != management_pending.request_id or not value.get("success") is bool:
		return
	management_pending.clear()
	instance_status = "Saved" if value.success else str(value.get("message", "Request rejected"))
	instance_management_finished.emit(value)
	active_instance_changed.emit()

func _on_instance_evicted(value: Dictionary):
	if value.get("session_id") != current_session_id:
		return
	current_session_id = ""
	_reset_instance_state()
	instance_status = "You were %s. Open World Explorer to choose another instance." % value.get("reason", "removed")
	if SaveData.get("profile") != null:
		SaveData.profile.clear_remote_profiles()
	_clear_remote_players()
	_fail_pending(instance_status)
	session_busy = false
	active_instance_changed.emit()
	participants_changed.emit()

func _publish_profile(_owner: String):
	if peer != null and peer.is_authenticated and SaveData.get("profile") != null:
		peer.publish_profile(SaveData.profile.get_profile(SaveData.profile.get_local_fingerprint()))

func _on_profiles_updated(session: String, profiles: Array):
	if session != current_session_id or SaveData.get("profile") == null:
		return
	SaveData.profile.replace_remote_profiles(session, profiles)
	for owner in SaveData.profile.remote:
		var profile: Dictionary = SaveData.profile.remote[owner]
		var player = get_node_or_null(str(int(profile.get("peer_id", -1))))
		if player != null and player.get("user_name") != null:
			participant_registry.apply_profile(player, owner, profile)
	participants_changed.emit()
