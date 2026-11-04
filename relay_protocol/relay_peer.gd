class_name RelayPeer

var relay := ENetMultiplayerPeer.new()

var peer: ENetPacketPeer

var public_session := []
var is_connected_to_relay := false
var is_authenticated := false
var account_key: CryptoKey
var authentication_error := ""
var profiles: Array = []
var current_session_id := ""
var active_instance: Dictionary = {}
var moderation_policy: Dictionary = {}
var moderation_path := ""
var moderation_error := ""
var friend_service
var social_hello_deadline := 0
var join_requests: Dictionary = {}
var animation_supported := false
var tracking_supported := false
var world_revision_supported := false
var expected_world_revision := ""
signal animation_data(value: Dictionary)

func send_animation(value: Dictionary):
	if is_authenticated and peer != null and animation_supported:
		AccountPacket.create(PacketInfo.PACKET_TYPE.ANIMATION_DATA, value).sent(peer)
signal join_requests_changed

func _send_social(value: Dictionary):
	if is_authenticated and peer != null:
		AccountPacket.create(PacketInfo.PACKET_TYPE.SOCIAL_DATA, value).sent(peer)

func configure_moderation(path: String):
	moderation_path = path
	moderation_policy.clear()
	moderation_error = ""
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 4 * 1024 * 1024:
			moderation_error = "Moderation policy unreadable or oversized; original file preserved"
			return
		file.close()
		var config = ConfigFile.new()
		if config.load(path) != OK or account_key == null \
			or config.get_value("policy", "owner", "") != account_key.save_to_string(true) \
			or not config.get_value("policy", "instances") is Dictionary:
			moderation_error = "Moderation policy unreadable or wrong account; original file preserved"
			return
		moderation_policy = config.get_value("policy", "instances")
		if moderation_policy.size() > 4096:
			moderation_error = "Moderation policy exceeds limits"
		for id in moderation_policy:
			if not InstanceState.valid_fingerprint(id) or not moderation_policy[id] is Dictionary:
				moderation_error = "Invalid moderation policy"
				break
			for banned in moderation_policy[id]:
				if not InstanceState.valid_fingerprint(banned) or moderation_policy[id][banned] != true:
					moderation_error = "Invalid moderation policy"
		if not moderation_error.is_empty():
			moderation_policy.clear()

func _save_moderation() -> bool:
	if moderation_path.is_empty():
		return true # Transport-only peers may opt for memory-only client policy.
	if not moderation_error.is_empty() or account_key == null:
		return false
	var config = ConfigFile.new()
	config.set_value("policy", "owner", account_key.save_to_string(true))
	config.set_value("policy", "instances", moderation_policy)
	var error = config.save(moderation_path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(moderation_path + ".tmp", moderation_path)
	if error != OK:
		moderation_error = "Could not save local moderation policy"
	return error == OK
signal instance_snapshot(value: Dictionary)
signal instance_result(value: Dictionary)
signal instance_evicted(value: Dictionary)

## The connection of the connected relay. Of type ENetConnection.
var connection: ENetConnection
var session_peers: Array

signal on_disconnected_from_relay()
signal connected()
signal player_data(data: PlayerData)
signal on_session_peers_update()
signal voice_data(data: VoiceData)
signal on_public_session(sessions: Array)
signal session_result(result: Dictionary)
signal authentication_finished(success: bool)
signal profiles_updated(session_id: String, profiles: Array)

func connect_to_relay(relay_ip: String,relay_port: int):
	connection = ENetConnection.new()
	var error: Error = connection.create_host(1)
	if error:
		print("Failed to connect")
	peer = connection.connect_to_host(relay_ip,relay_port)


func create_session(join_mode: int,name: String,description: String , world_url: String) -> void:
	if not is_authenticated:
		return
	
	CreateSession.create({
		"mode": join_mode,
		"name":name,
		"description": description, 
		"world_url": world_url,
		"world_revision": expected_world_revision,
	}).sent(peer)

func join_session(session_id: String, world_url: String = "") -> void:
	if not is_authenticated:
		return
	JoinSession.create(session_id, world_url, expected_world_revision).sent(peer)

func resolve_instance(session_id: String):
	if is_authenticated and peer != null:
		AccountPacket.create(PacketInfo.PACKET_TYPE.INSTANCE_LOOKUP, {"session_id": session_id}).sent(peer)

func decide_join(token: String, allow: bool):
	if is_authenticated and peer != null and join_requests.has(token):
		AccountPacket.create(PacketInfo.PACKET_TYPE.JOIN_DECISION, {"token": token, "allow": allow}).sent(peer)
	
func handle_events() -> void:
	for token in join_requests.keys():
		if Time.get_ticks_msec() >= join_requests[token].deadline:
			join_requests.erase(token)
			join_requests_changed.emit()
	if friend_service != null:
		friend_service.tick()
	var packed_event: Array = connection.service()
	var event_type: ENetConnection.EventType = packed_event[0]
	
	while event_type != ENetConnection.EVENT_NONE:
		var _peer: ENetPacketPeer = packed_event[1]
		
		match event_type:
			ENetConnection.EVENT_ERROR:
				push_warning("Package resulted in an unknown error")
				return
				
			ENetConnection.EVENT_CONNECT:
				connected_to_relay()
				
			ENetConnection.EVENT_DISCONNECT:
				disconnected_from_relay()
				
			ENetConnection.EVENT_RECEIVE:
				on_packet(_peer.get_packet())
				
				
		packed_event = connection.service()
		event_type = packed_event[0]

func connected_to_relay():
	is_connected_to_relay = true
	print("connected to relay")
	connected.emit()
	if account_key != null and not account_key.is_public_only():
		AccountPacket.create(PacketInfo.PACKET_TYPE.AUTH_HELLO,
			{"public_key": account_key.save_to_string(true)}).sent(peer)
	
	
func disconnected_from_relay():
	animation_supported = false
	tracking_supported = false
	world_revision_supported = false
	expected_world_revision = ""
	join_requests.clear()
	join_requests_changed.emit()
	if friend_service != null:
		friend_service.disconnect_transport()
	is_connected_to_relay = false
	is_authenticated = false
	profiles.clear()
	active_instance.clear()
	current_session_id = ""
	public_session.clear()
	session_peers.clear()
	on_disconnected_from_relay.emit()
	
func on_packet(data: PackedByteArray):
	if data.is_empty():
		return
	var packet_type: int = data.decode_u8(0)
	
	match packet_type:
		PacketInfo.PACKET_TYPE.ANIMATION_DATA:
			if is_authenticated and data.size() <= 16 * 1024:
				var value = AccountPacket.parse(data)
				if value.get("op") == "hello" and value.get("version") == 2:
					animation_supported = true
				if value.get("op") == "pose_hello" and value.get("version") == 1: tracking_supported = true
				animation_data.emit(value)
		PacketInfo.PACKET_TYPE.JOIN_REQUEST:
			var value = AccountPacket.parse(data)
			if is_authenticated and value.get("session_id") == current_session_id \
				and InstanceState.valid_fingerprint(value.get("token")):
				if value.get("closed", false):
					join_requests.erase(value.token)
				elif InstanceState.valid_fingerprint(value.get("fingerprint")) and join_requests.size() < 256:
					value.deadline = Time.get_ticks_msec() + 60000
					join_requests[value.token] = value
				join_requests_changed.emit()
		PacketInfo.PACKET_TYPE.SOCIAL_DATA:
			var value = AccountPacket.parse(data)
			if is_authenticated and friend_service != null and account_key != null \
				and friend_service.owner == preload("res://scripts/profile/profile_identity.gd").fingerprint(account_key.save_to_string(true)):
				if value.get("op") == "capabilities" and value.get("version") == 1:
					if not friend_service.supported:
						friend_service.attach(_send_social, true)
				else:
					friend_service.receive(value)
		PacketInfo.PACKET_TYPE.MODERATION_POLICY:
			var value = AccountPacket.parse(data)
			if is_authenticated and value.get("session_id") == current_session_id \
				and InstanceState.valid_fingerprint(value.get("moderation_id")) \
				and InstanceState.valid_fingerprint(value.get("fingerprint")):
				if not moderation_policy.has(value.moderation_id):
					moderation_policy[value.moderation_id] = {}
				moderation_policy[value.moderation_id][value.fingerprint] = true
				_save_moderation()
		PacketInfo.PACKET_TYPE.ADMISSION_QUERY:
			var value = AccountPacket.parse(data)
			if is_authenticated and value.get("session_id") == current_session_id \
				and InstanceState.valid_fingerprint(value.get("token")) \
				and InstanceState.valid_fingerprint(value.get("moderation_id")) \
				and InstanceState.valid_fingerprint(value.get("fingerprint")):
				var policy: Dictionary = moderation_policy.get(value.get("moderation_id"), {})
				var allow = moderation_error.is_empty() and moderation_policy.has(value.get("moderation_id")) \
					and not policy.has(value.get("fingerprint"))
				AccountPacket.create(PacketInfo.PACKET_TYPE.ADMISSION_REPLY, {"token": value.token, "allow": allow}).sent(peer)
		PacketInfo.PACKET_TYPE.ID_ASSINGMENT:
			pass
		#	manage_ids(IDAssingnment.create_from_data(data)) 
	
		PacketInfo.PACKET_TYPE.PLAYER_DATA:
			if not current_session_id.is_empty() and data.size() == 26:
				player_data.emit(PlayerData.create_from_data(data))
			
		PacketInfo.PACKET_TYPE.VOICE_DATA:
			if not current_session_id.is_empty() and data.size() >= 2 and data.size() <= 4096:
				voice_data.emit(VoiceData.create_from_data(data))
			
		PacketInfo.PACKET_TYPE.GET_SESSION_PEERS:
			session_peers = GetSessionPeers.create_from_data(data).peers
			print("Session list updated new list is:",session_peers)
			on_session_peers_update.emit()
			
		PacketInfo.PACKET_TYPE.GET_PUBLIC_SESSIONS:
			public_session = GetPublicSessions.create_from_data(data).sessions
			on_public_session.emit(public_session)
		PacketInfo.PACKET_TYPE.SESSION_RESULT:
			var result = SessionResult.create_from_data(data).result
			if result.get("success", false) and result.get("operation") in ["join", "create"]:
				join_requests.clear()
				join_requests_changed.emit()
				current_session_id = str(result.get("session_id", ""))
				profiles.clear()
				active_instance.clear()
			session_result.emit(result)
		PacketInfo.PACKET_TYPE.INSTANCE_SNAPSHOT:
			var value = AccountPacket.parse(data)
			if is_authenticated and value.get("session_id") == current_session_id and InstanceState.valid(value) \
				and (active_instance.is_empty() or value.revision > active_instance.revision or value == active_instance):
				active_instance = value.duplicate(true)
				instance_snapshot.emit(value)
		PacketInfo.PACKET_TYPE.INSTANCE_RESULT:
			var value = AccountPacket.parse(data)
			if is_authenticated and value.get("session_id") == current_session_id:
				instance_result.emit(value)
		PacketInfo.PACKET_TYPE.INSTANCE_EVICTED:
			var value = AccountPacket.parse(data)
			if is_authenticated and value.get("session_id") == current_session_id and value.get("reason") in ["kicked", "banned"]:
				current_session_id = ""
				join_requests.clear()
				join_requests_changed.emit()
				active_instance.clear()
				session_peers.clear()
				profiles.clear()
				instance_evicted.emit(value)
		PacketInfo.PACKET_TYPE.AUTH_CHALLENGE:
			var values = AccountPacket.parse(data)
			if values.get("challenge") is String and values.challenge.length() < 4096 and account_key != null:
				var bytes = Marshalls.base64_to_raw(values.challenge)
				var challenge = JSON.parse_string(bytes.get_string_from_utf8())
				var identity = preload("res://scripts/profile/profile_identity.gd")
				if not challenge is Array or challenge.size() != 4 or challenge[0] != "comunicare/auth/v1" \
					or challenge[2] != identity.fingerprint(account_key.save_to_string(true)):
					return
				var digest = preload("res://scripts/profile/profile_identity.gd").digest(bytes)
				AccountPacket.create(PacketInfo.PACKET_TYPE.AUTH_RESPONSE,
					{"signature": Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256, digest, account_key))}).sent(peer)
		PacketInfo.PACKET_TYPE.AUTH_RESULT:
			var values = AccountPacket.parse(data)
			is_authenticated = values.get("success", false) == true
			world_revision_supported = is_authenticated and values.get("world_revision_version") == 1
			if is_authenticated and values.get("animation_version") == 2:
				AccountPacket.create(PacketInfo.PACKET_TYPE.ANIMATION_DATA, {"op": "hello", "version": 2}).sent(peer)
				if values.get("tracking_version") == 1:
					AccountPacket.create(PacketInfo.PACKET_TYPE.ANIMATION_DATA, {"op": "pose_hello", "version": 1}).sent(peer)
			if is_authenticated and friend_service != null:
				friend_service.attach(_send_social, false)
				if values.get("social_version") == 1:
					_send_social({"op": "hello"})
			authentication_error = str(values.get("message", "Authentication failed"))
			authentication_finished.emit(is_authenticated)
		PacketInfo.PACKET_TYPE.PROFILES_SNAPSHOT:
			var values = AccountPacket.parse(data)
			if is_authenticated and not current_session_id.is_empty() \
				and values.get("session_id") == current_session_id and values.get("profiles") is Array:
				profiles = values.profiles
				profiles_updated.emit(current_session_id, profiles)
		_:
			push_error("Packed type with index ",data[0]," unhandled!")

func publish_profile(profile: Dictionary):
	if is_authenticated:
		AccountPacket.create(PacketInfo.PACKET_TYPE.PROFILE_PUBLISH, profile).sent(peer)

func request_instance(value: Dictionary):
	if is_authenticated and is_connected_to_relay and peer != null:
		AccountPacket.create(PacketInfo.PACKET_TYPE.INSTANCE_REQUEST, value).sent(peer)
