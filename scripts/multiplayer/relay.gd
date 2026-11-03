extends Node

var server := ENetMultiplayerPeer.new()
var sessions := []  # [ {"session_id":"IDw21","owners":[],"peers": [],"mode":1 }  ]
var peers: Dictionary[int,ENetPacketPeer] # peer_id
const Identity = preload("res://scripts/profile/profile_identity.gd")
var authenticator = preload("res://scripts/profile/identity_authenticator.gd").new()
var key_mapping: Dictionary = {}
var public_profiles: Dictionary = {}
var instance_results: Dictionary = {}
var instance_rates: Dictionary = {}
var admissions: Dictionary = {}
var social = FriendRouter.new()
var animations = AnimationRouter.new()
var availabil_peer_ids: Array = range(255,-1,-1)

var connection: ENetConnection


func _ready() -> void:
	start_relay()
	
func start_relay():
	connection = ENetConnection.new()
	var error = connection.create_host_bound("0.0.0.0", 7374)
	if error:
		print("Failed to start relay")
		return
	print("Relay stated")
	

func _process(_delta):
	if connection == null: return
	handle_events()
	

func handle_events() -> void:
	animations.tick()
	social.tick(self)
	_expire_admissions()
	var packed_event: Array = connection.service()
	var event_type: ENetConnection.EventType = packed_event[0]
	
	while event_type != ENetConnection.EVENT_NONE:
		var peer: ENetPacketPeer = packed_event[1]
		
		match event_type:
			ENetConnection.EVENT_ERROR:
				push_warning("Package resulted in an unknown error")
				return
				
			ENetConnection.EVENT_CONNECT:
				peer_connected(peer)
				
			ENetConnection.EVENT_DISCONNECT:
				peer_disconnected(peer)
				
			ENetConnection.EVENT_RECEIVE:
				on_packed(peer.get_meta("id"),peer.get_packet())
				
				
		packed_event = connection.service()
		event_type = packed_event[0]


func peer_connected(peer: ENetPacketPeer):
	if availabil_peer_ids.is_empty():
		peer.peer_disconnect()
		return
	var peer_id: int = availabil_peer_ids.pop_back()
	peer.set_meta("id",peer_id)
	peers[peer_id] = peer
	peer.set_timeout(5, 5000, 10000)
	
	
func peer_disconnected(peer: ENetPacketPeer):
	if not peer.has_meta("id"):
		return
	var peer_id: int = peer.get_meta("id")
	if not peers.has(peer_id) or peers[peer_id] != peer:
		return
	peer.remove_meta("id")
	var fingerprint: String = key_mapping.get(peer_id, {}).get("fingerprint", "")
	animations.disconnect_peer(self, peer_id)
	social.disconnect_peer(self, peer_id)
	availabil_peer_ids.push_back(peer_id)
	peers.erase(peer_id)
	authenticator.disconnect_peer(peer_id)
	key_mapping.erase(peer_id)
	public_profiles.erase(peer_id)
	# Other users' deduplication payloads may identify the departed account.
	instance_results.clear()
	instance_rates.erase(peer_id)
	for token in admissions.keys():
		var pending: Dictionary = admissions[token]
		if pending.candidate == peer_id:
			_finish_admission(token, false, "Candidate disconnected")
		elif peer_id in pending.admins:
			_finish_admission(token, false, "Moderator disconnected; retry admission")

	for i in range(sessions.size() - 1, -1, -1):
		var session: Dictionary = sessions[i][0]
		session.get("bans", {}).erase(fingerprint)
		for field in ["name", "description"]:
			if session.get(field + "_author", -1) == peer_id:
				session[field] = "Active instance" if field == "name" else ""
				session.erase(field + "_author")
				session.revision = int(session.get("revision", 0)) + 1
		if peer_id in sessions[i][0]["peers"]:
			remove_user_from_session(peer_id, i)
		else:
			notify_session(i)


func on_packed(peer_id: int, data: PackedByteArray):
	if data.is_empty():
		return
	var packed_type: int = data.decode_u8(0)
	if packed_type == PacketInfo.PACKET_TYPE.ANIMATION_DATA:
		if data.size() <= 16 * 1024:
			animations.handle(self, peer_id, AccountPacket.parse(data))
		return
	if packed_type == PacketInfo.PACKET_TYPE.INSTANCE_LOOKUP:
		var lookup = AccountPacket.parse(data) if data.size() <= 1024 else {}
		if key_mapping.has(peer_id) and lookup.get("session_id") is String:
			var index = get_session_index(lookup.session_id)
			if index == -1 or not _session_access(peer_id, sessions[index][0]) \
				or sessions[index][0].get("bans", {}).has(key_mapping[peer_id].fingerprint):
				send_result(peer_id, "resolve", lookup.session_id, false, "Instance unavailable or access denied")
			else:
				send_result(peer_id, "resolve", lookup.session_id, true, "", sessions[index][0].world_url)
		return
	if packed_type == PacketInfo.PACKET_TYPE.JOIN_DECISION:
		if data.size() <= 2048:
			_join_decision(peer_id, AccountPacket.parse(data))
		return
	if packed_type == PacketInfo.PACKET_TYPE.SOCIAL_DATA:
		if data.size() <= 48 * 1024:
			social.handle(self, peer_id, AccountPacket.parse(data))
		return
	if packed_type == PacketInfo.PACKET_TYPE.ADMISSION_REPLY:
		if data.size() <= 2048:
			_admission_reply(peer_id, AccountPacket.parse(data))
		return
	if packed_type == PacketInfo.PACKET_TYPE.INSTANCE_REQUEST:
		if data.size() <= 16 * 1024:
			_handle_instance_request(peer_id, AccountPacket.parse(data))
		return
	if packed_type in [PacketInfo.PACKET_TYPE.AUTH_HELLO, PacketInfo.PACKET_TYPE.AUTH_RESPONSE]:
		_handle_auth(peer_id, packed_type, AccountPacket.parse(data))
		return
	if packed_type == PacketInfo.PACKET_TYPE.PROFILE_PUBLISH:
		var profile = AccountPacket.parse(data)
		var identity: Dictionary = key_mapping.get(peer_id, {})
		if not identity.is_empty() and profile.get("public_key") == identity.public_key \
			and Identity.verify_profile(profile):
			publish_profile(peer_id, profile)
		return
	if packed_type in [PacketInfo.PACKET_TYPE.CREATE_SESSION, PacketInfo.PACKET_TYPE.JOIN_SESSOIN] \
		and not key_mapping.has(peer_id):
		var id = JoinSession.create_from_data(data).session_id if packed_type == PacketInfo.PACKET_TYPE.JOIN_SESSOIN else ""
		send_result(peer_id, "join" if packed_type == PacketInfo.PACKET_TYPE.JOIN_SESSOIN else "create", id, false, "Account authentication required")
		return
	match packed_type:
		PacketInfo.PACKET_TYPE.CREATE_SESSION:
			_cancel_candidate_admissions(peer_id)
			var session = CreateSession.create_from_data(data).session_info
			if not valid_creation(session):
				send_result(peer_id, "create", "", false, "Invalid instance metadata")
				return
			var previous = get_user_in_session(peer_id)
			if previous != -1:
				remove_user_from_session(peer_id, previous)
			sessions.append([{
				"session_id":generate_code(),
				"owners":[peer_id],
				"peers": [peer_id],
				"mode":session.mode,
				"name": session.name,
				"description": session.description,
				"world_url": session.world_url,
				"world_revision": session.get("world_revision", ""),
				"revision": 1, "bans": {},
				"name_author": peer_id, "description_author": peer_id,
				"moderation_id": Crypto.new().generate_random_bytes(32).hex_encode(),
				"moderated": false,
				}])
			var created = sessions.back()[0]
			send_result(peer_id, "create", created.session_id, true, "", created.world_url)
			notify_session(sessions.size() - 1)
				
		PacketInfo.PACKET_TYPE.JOIN_SESSOIN:
			_cancel_candidate_admissions(peer_id)
			var join_data: JoinSession = JoinSession.create_from_data(data)
			var session_index = get_session_index(join_data.session_id)
			if session_index == -1:
				send_result(peer_id, "join", join_data.session_id, false, "Instance no longer exists")
				return
			var target = sessions[session_index][0]
			if target.get("bans", {}).has(key_mapping[peer_id].fingerprint):
				send_result(peer_id, "join", join_data.session_id, false, "You are banned from this instance")
				return
			if not _session_access(peer_id, target):
				send_result(peer_id, "join", join_data.session_id, false, "Instance access denied; requires an active mutual friendship with an admin")
				return
			if not join_data.world_url.is_empty() and join_data.world_url != target.world_url:
				send_result(peer_id, "join", join_data.session_id, false, "Instance world changed; refresh the list")
				return
			if target.get("world_revision", "") != join_data.world_revision:
				send_result(peer_id, "join", join_data.session_id, false, "World revision mismatch; download the instance's pinned revision")
				return
			if (target.get("moderated", false) or target.mode == PacketInfo.MODE.REQUEST) and peer_id not in target.peers:
				_begin_admission(peer_id, target)
				return
			var user_session = get_user_in_session(peer_id)
			if user_session != -1 and user_session != session_index:
				remove_user_from_session(peer_id, user_session)
			if peer_id not in target.peers:
				target.peers.append(peer_id)
				target.revision = int(target.get("revision", 0)) + 1
			send_result(peer_id, "join", join_data.session_id, true, "", target.world_url)
			notify_session(get_session_index(join_data.session_id))
					
		
		PacketInfo.PACKET_TYPE.GET_SESSION_PEERS:
			var user_session = get_user_in_session(peer_id)
			if user_session == -1:
				return
			notify_session(user_session)
		
		PacketInfo.PACKET_TYPE.PLAYER_DATA:
			if data.size() != 26:
				return
			var user_session = get_user_in_session(peer_id)
			if user_session == -1: return
			for peer in sessions[user_session][0]["peers"]:
				if peer != peer_id:
					var user_pose = PlayerData.create_from_data(data)
					#print("data sent to: ",peers[peer])
					PlayerData.create(peer_id,user_pose.position,user_pose.rotation).sent(peers[peer])
		
		PacketInfo.PACKET_TYPE.VOICE_DATA:
			if data.size() < 2 or data.size() > 4096:
				return
			var user_session = get_user_in_session(peer_id)
			if user_session == -1: return
			var out := data.duplicate()
			out.encode_u8(1, peer_id)
			for peer in sessions[user_session][0]["peers"]:
				if peer != peer_id and peers.has(peer):
					peers[peer].send(0, out, ENetPacketPeer.FLAG_UNSEQUENCED)
			
		PacketInfo.PACKET_TYPE.GET_PUBLIC_SESSIONS:
			GetPublicSessions.create((get_public_session())).sent(peers[peer_id])
			 
		_:
			push_error("Packed type was unknown: ",packed_type)


# tools 
func remove_user_from_session(peer_id: int, session_index: int):
	animations.leave(self, peer_id)
	sessions[session_index][0].revision = int(sessions[session_index][0].get("revision", 0)) + 1
	sessions[session_index][0]["peers"].erase(peer_id)
	sessions[session_index][0]["owners"].erase(peer_id)
	if sessions[session_index][0]["peers"].size() == 0:
		sessions.remove_at(session_index)
	else:
		if sessions[session_index][0]["owners"].is_empty():
			sessions[session_index][0]["owners"].append(sessions[session_index][0]["peers"][0])
		notify_session(session_index)


func generate_code() -> String:
	var characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	var code = ""
	
	for i in range(5):
		code += characters[randi_range(0, characters.length() - 1)]
	
	return generate_code() if get_session_index(code) != -1 else code

## Gets the session index position in the session aray when you the session id. 
func get_session_index(session_id: String) -> int:
	for i in range(sessions.size()):
		var session = sessions[i][0]
		if session["session_id"] == session_id:
			return i
	return -1


## Get a useer from a session
func get_user_in_session(peer_id: int) -> int:
	for i in range(sessions.size()):
		if peer_id in sessions[i][0]["peers"]:
			return i
	return -1

func get_public_session() -> Array:
	var _sessions = []
	for i in range(sessions.size()):
		var session = sessions[i][0]
		if session.mode == PacketInfo.MODE.PUBLIC and not session.peers.is_empty():
			_sessions.append({
				"session_id": session.session_id, "world_url": session.world_url,
				"mode": session.mode, "name": session.name,
				"description": session.description, "player_count": session.peers.size(),
			})
			
	return _sessions

func notify_session(index: int):
	if index < 0 or index >= sessions.size():
		return
	var members: Array = sessions[index][0].peers
	for member in members:
		if peers.has(member) and peers[member].get_state() == ENetPacketPeer.STATE_CONNECTED:
			var others = members.duplicate()
			others.erase(member)
			GetSessionPeers.create(others).sent(peers[member])
			_send_profiles(member)
			_send_instance(member, index)

func send_result(peer_id: int, operation: String, session_id: String, success: bool, message: String, world_url: String = ""):
	if peers.has(peer_id) and peers[peer_id].get_state() == ENetPacketPeer.STATE_CONNECTED:
		var index = get_session_index(session_id)
		var revision = sessions[index][0].get("world_revision", "") if success and index >= 0 else ""
		SessionResult.create({"operation": operation, "session_id": session_id,
			"success": success, "message": message, "world_url": world_url, "world_revision": revision}).sent(peers[peer_id])

func valid_creation(value: Dictionary) -> bool:
	return InstanceState.valid_metadata(value) and WorldAddress.is_valid(value.get("world_url")) \
		and (value.get("world_revision", "") == "" or InstanceState.valid_fingerprint(value.get("world_revision")))

func _send_instance(peer_id: int, index: int):
	var session: Dictionary = sessions[index][0]
	var members: Array = []
	for id in session.peers:
		if key_mapping.has(id):
			members.append({"peer_id": id, "fingerprint": key_mapping[id].fingerprint,
				"role": "admin" if id in session.owners else "member"})
	_send_account(peer_id, PacketInfo.PACKET_TYPE.INSTANCE_SNAPSHOT, {
		"session_id": session.session_id, "revision": session.get("revision", 1),
		"world_url": session.world_url, "name": session.name,
		"description": session.description, "mode": session.mode, "members": members})

func _send_account(peer_id: int, type: int, value: Dictionary):
	if peers.has(peer_id) and peers[peer_id].get_state() == ENetPacketPeer.STATE_CONNECTED:
		AccountPacket.create(type, value).sent(peers[peer_id])

func _instance_result(peer_id: int, request: Dictionary, error: String, revision: int = -1):
	var result = {"request_id": request.request_id, "session_id": request.session_id,
		"success": error.is_empty(), "error_code": error, "message": error.replace("_", " "),
		"resulting_revision": revision}
	if not instance_results.has(peer_id):
		instance_results[peer_id] = {}
	var cache: Dictionary = instance_results[peer_id]
	if cache.size() >= 128:
		cache.erase(cache.keys()[0])
	# Do not retain arbitrary rejected payloads: they can identify absent users.
	# Successful operations contain only validated, currently connected targets.
	if error.is_empty():
		cache[request.request_id] = {"request": request.duplicate(true), "result": result}
	_send_account(peer_id, PacketInfo.PACKET_TYPE.INSTANCE_RESULT, result)

func _handle_instance_request(peer_id: int, request: Dictionary):
	if not key_mapping.has(peer_id):
		return
	if not request.get("request_id") is String or request.request_id.is_empty() or request.request_id.length() > 128 \
		or not request.get("session_id") is String or request.session_id.length() > 128:
		return
	var now = Time.get_ticks_msec()
	var rate: Dictionary = instance_rates.get(peer_id, {"start": now, "count": 0})
	if now - rate.start >= 1000:
		rate = {"start": now, "count": 0}
	rate.count += 1
	instance_rates[peer_id] = rate
	if rate.count > 30:
		return
	var cached: Dictionary = instance_results.get(peer_id, {}).get(request.request_id, {})
	if not cached.is_empty():
		if cached.request == request:
			_send_account(peer_id, PacketInfo.PACKET_TYPE.INSTANCE_RESULT, cached.result)
		return
	var index = get_user_in_session(peer_id)
	if not key_mapping.has(peer_id) or index == -1 or sessions[index][0].session_id != request.session_id:
		_instance_result(peer_id, request, "wrong_instance_or_unauthorized")
		return
	var session: Dictionary = sessions[index][0]
	for field in request:
		if field not in ["request_id", "session_id", "expected_revision", "action", "changes", "target_fingerprint", "target_peer_id"]:
			_instance_result(peer_id, request, "invalid_request")
			return
	if request.get("action") not in ["kick", "ban", "make_admin"] \
		and (request.has("target_fingerprint") or request.has("target_peer_id")):
		_instance_result(peer_id, request, "invalid_request")
		return
	if request.get("action") == "refresh":
		if request.has("changes"):
			_instance_result(peer_id, request, "invalid_request")
			return
		_send_instance(peer_id, index)
		_instance_result(peer_id, request, "", int(session.get("revision", 1)))
		return
	if peer_id not in session.owners:
		_instance_result(peer_id, request, "unauthorized")
		return
	if not InstanceState.integer(request.get("expected_revision")) or request.expected_revision != session.get("revision", 1):
		_instance_result(peer_id, request, "stale_revision")
		_send_instance(peer_id, index)
		return
	var action = request.get("action")
	if action == "update_metadata":
		var changes = request.get("changes")
		if not changes is Dictionary or changes.is_empty():
			_instance_result(peer_id, request, "invalid_metadata")
			return
		var next = session.duplicate(true)
		for field in changes:
			if field not in ["name", "description", "mode"]:
				_instance_result(peer_id, request, "immutable_field")
				return
			next[field] = changes[field]
		if not valid_creation(next):
			_instance_result(peer_id, request, "invalid_metadata_or_unsupported_mode")
			return
		for field in changes:
			session[field] = changes[field]
			if field in ["name", "description"]:
				session[field + "_author"] = peer_id
		session.revision = int(session.get("revision", 1)) + 1
	elif action in ["kick", "ban", "make_admin"]:
		var target = request.get("target_peer_id")
		if not InstanceState.integer(target, 0, 255) or int(target) == peer_id or int(target) not in session.peers \
			or not key_mapping.has(int(target)) or key_mapping[int(target)].fingerprint != request.get("target_fingerprint"):
			_instance_result(peer_id, request, "ineligible_target")
			return
		target = int(target)
		if action == "make_admin":
			if target in session.owners:
				_instance_result(peer_id, request, "already_admin")
				return
			session.owners.append(target)
			session.revision = int(session.get("revision", 1)) + 1
		else:
			if action == "ban":
				if not session.has("bans"):
					session.bans = {}
				session.bans[key_mapping[target].fingerprint] = true
				session.moderated = true
				for admin in session.owners:
					_send_account(admin, PacketInfo.PACKET_TYPE.MODERATION_POLICY, {
						"session_id": session.session_id, "moderation_id": session.moderation_id,
						"fingerprint": key_mapping[target].fingerprint})
			remove_user_from_session(target, index)
			_send_account(target, PacketInfo.PACKET_TYPE.INSTANCE_EVICTED, {
				"session_id": session.session_id, "reason": "banned" if action == "ban" else "kicked",
				"message": "You were removed from this instance. Open World Explorer to choose another instance."})
	else:
		_instance_result(peer_id, request, "unknown_action")
		return
	_instance_result(peer_id, request, "", int(session.revision))
	notify_session(index)

func _handle_auth(peer_id: int, type: int, values: Dictionary):
	if not peers.has(peer_id):
		return
	if type == PacketInfo.PACKET_TYPE.AUTH_HELLO:
		var challenge = PackedByteArray()
		if values.get("public_key") is String:
			challenge = authenticator.issue_challenge(peer_id, values.public_key)
		if not challenge.is_empty():
			AccountPacket.create(PacketInfo.PACKET_TYPE.AUTH_CHALLENGE,
				{"challenge": Marshalls.raw_to_base64(challenge)}).sent(peers[peer_id])
		else:
			AccountPacket.create(PacketInfo.PACKET_TYPE.AUTH_RESULT,
				{"success": false, "message": "Invalid key or repeated authentication"}).sent(peers[peer_id])
	else:
		if not values.get("signature") is String or values.signature.length() > 2048:
			authenticator.challenges.erase(peer_id)
		var success = values.get("signature") is String and values.signature.length() <= 2048 \
			and authenticator.verify_response(peer_id, Marshalls.base64_to_raw(values.signature))
		if success:
			authenticate_peer(peer_id, authenticator.get_identity(peer_id).public_key)
		AccountPacket.create(PacketInfo.PACKET_TYPE.AUTH_RESULT,
			{"success": success, "social_version": 1, "animation_version": 1, "world_revision_version": 1, "message": "" if success else "Invalid, expired, replayed signature or account already connected"}).sent(peers[peer_id])

func authenticate_peer(peer_id: int, verified_public_key: String):
	# Internal trust boundary; wire handlers call this only after proof verification.
	var key = Identity.canonical_key(verified_public_key)
	if key.is_empty():
		return
	key_mapping[peer_id] = {"public_key": key, "fingerprint": Identity.fingerprint(key)}

func _cancel_candidate_admissions(candidate: int):
	for token in admissions.keys():
		if admissions[token].candidate == candidate:
			_finish_admission(token, false, "Join request cancelled")

func _begin_admission(candidate: int, session: Dictionary):
	for value in admissions.values():
		if value.candidate == candidate:
			return
	var token = Crypto.new().generate_random_bytes(32).hex_encode()
	admissions[token] = {"candidate": candidate, "session_id": session.session_id,
		"admins": session.owners.duplicate(), "approved": [], "mode": int(session.mode),
		"world_url": session.world_url, "request_approved": session.mode != PacketInfo.MODE.REQUEST,
		"deadline": Time.get_ticks_msec() + (60000 if session.mode == PacketInfo.MODE.REQUEST else 5000)}
	for admin in session.owners:
		if session.get("moderated", false):
			_send_account(admin, PacketInfo.PACKET_TYPE.ADMISSION_QUERY, {"token": token,
				"session_id": session.session_id, "moderation_id": session.moderation_id,
				"fingerprint": key_mapping[candidate].fingerprint})
		else:
			admissions[token].approved.append(admin)
		if session.mode == PacketInfo.MODE.REQUEST:
			_send_account(admin, PacketInfo.PACKET_TYPE.JOIN_REQUEST, {"token": token,
				"session_id": session.session_id, "fingerprint": key_mapping[candidate].fingerprint,
				"timeout_ms": 60000})

func _session_access(candidate: int, session: Dictionary) -> bool:
	if candidate in session.peers or session.mode == PacketInfo.MODE.PUBLIC:
		return true
	if session.mode == PacketInfo.MODE.PRIVAT:
		return false
	for admin in session.owners:
		if social.mutual(candidate, admin):
			return true
		if session.mode == PacketInfo.MODE.FRIENDSP:
			for intermediate in key_mapping:
				if social.mutual(candidate, intermediate) and social.mutual(intermediate, admin):
					return true
	return false

func _join_decision(actor: int, value: Dictionary):
	var token = value.get("token")
	if not token is String or not admissions.has(token) or not value.get("allow") is bool:
		return
	var pending: Dictionary = admissions[token]
	var index = get_session_index(pending.session_id)
	if index == -1 or not key_mapping.has(actor) or actor not in sessions[index][0].owners \
		or actor not in pending.admins or pending.mode != PacketInfo.MODE.REQUEST:
		return
	if not value.allow:
		_finish_admission(token, false, "Join request declined")
		return
	pending.request_approved = true
	if pending.approved.size() == pending.admins.size():
		_finish_admission(token, true)

func _admission_reply(actor: int, value: Dictionary):
	var token = value.get("token")
	if not token is String or not admissions.has(token) or not value.get("allow") is bool:
		return
	var pending: Dictionary = admissions[token]
	var index = get_session_index(pending.session_id)
	if index == -1 or actor not in pending.admins or actor not in sessions[index][0].owners \
		or not key_mapping.has(actor):
		return
	if not value.allow:
		_finish_admission(token, false, "Admission rejected by moderator policy")
		return
	if actor not in pending.approved:
		pending.approved.append(actor)
	if pending.approved.size() == pending.admins.size() and pending.request_approved:
		_finish_admission(token, true)

func _finish_admission(token: String, allow: bool, message: String = ""):
	var pending: Dictionary = admissions[token]
	admissions.erase(token)
	for admin in pending.admins:
		_send_account(admin, PacketInfo.PACKET_TYPE.JOIN_REQUEST, {"token": token, "session_id": pending.session_id, "closed": true})
	var candidate: int = pending.candidate
	var index = get_session_index(pending.session_id)
	if not key_mapping.has(candidate):
		return
	if not allow or index == -1:
		send_result(candidate, "join", pending.session_id, false, message if not message.is_empty() else "Instance unavailable")
		return
	var target: Dictionary = sessions[index][0]
	if target.owners != pending.admins or int(target.mode) != pending.mode or target.world_url != pending.world_url \
		or not _session_access(candidate, target) or target.get("bans", {}).has(key_mapping[candidate].fingerprint):
		send_result(candidate, "join", pending.session_id, false, "Instance changed during admission; retry")
		return
	var old = get_user_in_session(candidate)
	if old != -1:
		remove_user_from_session(candidate, old)
	target.peers.append(candidate)
	target.revision += 1
	send_result(candidate, "join", target.session_id, true, "", target.world_url)
	notify_session(get_session_index(target.session_id))

func _expire_admissions():
	for token in admissions.keys():
		if Time.get_ticks_msec() >= admissions[token].deadline:
			_finish_admission(token, false, "Moderator unavailable or join request timed out")

func publish_profile(peer_id: int, fields: Dictionary) -> bool:
	if not key_mapping.has(peer_id):
		return false
	var identity: Dictionary = key_mapping[peer_id]
	if fields.has("public_key") and fields.public_key != identity.public_key:
		return false
	var normalized = Identity.normalized(fields)
	if normalized.is_empty():
		return false
	# Wire handler verifies signatures first; direct internal adapters may install
	# validated fields for tests, but unsigned profiles are never sent to clients.
	if fields.has("signature"):
		if not Identity.verify_profile(fields):
			return false
		if public_profiles.has(peer_id) and int(fields.revision) <= int(public_profiles[peer_id].get("revision", -1)):
			return false
		normalized.signature = fields.signature
		normalized.revision = int(fields.revision)
	normalized.public_key = identity.public_key
	public_profiles[peer_id] = normalized
	notify_session(get_user_in_session(peer_id))
	return true

func get_profiles_for_peer(peer_id: int) -> Array:
	var index = get_user_in_session(peer_id)
	if not key_mapping.has(peer_id) or index == -1:
		return []
	var result: Array = []
	for member in sessions[index][0].peers:
		if not key_mapping.has(member):
			continue
		var profile: Dictionary = public_profiles.get(member, Identity.defaults()).duplicate(true)
		profile.public_key = key_mapping[member].public_key
		profile.peer_id = member
		result.append(profile)
	return result

func _send_profiles(peer_id: int):
	var index = get_user_in_session(peer_id)
	if index >= 0 and peers.has(peer_id) and peers[peer_id].get_state() == ENetPacketPeer.STATE_CONNECTED:
		AccountPacket.create(PacketInfo.PACKET_TYPE.PROFILES_SNAPSHOT,
			{"session_id": sessions[index][0].session_id, "profiles": get_profiles_for_peer(peer_id)}).sent(peers[peer_id])
