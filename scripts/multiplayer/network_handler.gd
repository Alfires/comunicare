extends Node

var peer: RelayPeer
var player_scene = preload("res://scenes/player/remote_player.tscn")
var players = {}
var relay_ip := "127.0.0.1"
var relay_port := 7374

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
var active_instance: Dictionary = {}
signal active_instance_changed
signal instance_management_finished(result: Dictionary)
var management_pending: Dictionary = {}
var management_sequence := 0
var instance_status := ""
var snapshot_deadline := 0
var animation_controller: Node

func get_animation_controller() -> Node:
	if animation_controller == null:
		animation_controller = preload("res://scripts/assets/animation_controller.gd").new()
		# Do not make this a child: remote-player cleanup iterates every child.
		get_tree().root.add_child(animation_controller)
		animation_controller.configure(self, DataLoader)
	return animation_controller

func _ready() -> void:
	if "--relay" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		return
	if SaveData.get("profile") != null:
		SaveData.profile.profile_changed.connect(_publish_profile)

func _process(_delta):
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
		peer.authentication_error = "Account authentication timed out"
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


func create_peer():
	get_animation_controller()
	peer = RelayPeer.new()
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
	peer.connect_to_relay(relay_ip,relay_port)
	authentication_pending = true
	authentication_deadline = Time.get_ticks_msec() + 15000
	var success: bool = await peer.authentication_finished
	authentication_pending = false
	if not success:
		last_session_error = peer.authentication_error
		return false
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
	var expected_revision := ""
	if peer.world_revision_supported:
		_start_request("resolve", session_id)
		peer.resolve_instance(session_id)
		var resolved: Dictionary = await session_response
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
	if not peer.is_connected_to_relay:
		return _transition_failed("Relay disconnected while loading the world")
	_start_request("join", session_id)
	peer.expected_world_revision = expected_revision
	peer.join_session(session_id, world_url)
	var result: Dictionary = await session_response
	return await _finish_transition(result, staged, world_url)

func host_world(world_url: String) -> bool:
	if not _begin_transition():
		return false
	if not WorldAddress.is_valid(world_url):
		return _transition_failed("Invalid world address")
	var staged: Dictionary = await DataLoader.prepare_world_from_url(world_url)
	if staged.is_empty():
		var message = "Could not download or validate the world"
		if DataLoader.has_method("get_asset_cache"):
			message += ": " + DataLoader.get_asset_cache().last_error
		return _transition_failed(message)
	if not peer.is_connected_to_relay:
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
			player.user_name = str(profile.get("profile.username", "User"))
			var label = player.get_node_or_null("user_name")
			if label != null:
				label.text = player.user_name
	participants_changed.emit()
