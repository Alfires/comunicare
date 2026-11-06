extends Node
## Direct, opt-in editing transport. No gameplay packet IDs or relay persistence.
signal changed
signal status_changed(message: String)
const Identity = preload("res://scripts/profile/profile_identity.gd")
const Document = preload("res://addons/comunicare_world_tools/authoring_document.gd")
const MAX_PACKET = 256 * 1024
var connection: ENetConnection
var server_peer: ENetPacketPeer
var key: CryptoKey
var authority = preload("res://scripts/editor/edit_authority.gd").new()
var hosting := false
var authenticated := false
var owner_fingerprint := ""
var generation := ""
var document: Dictionary = {}
var pending: Dictionary = {}
var members: Dictionary = {}
var challenge: Dictionary = {}
var sent_sequence := 0
var received_sequence: Dictionary = {}
var role := ""
var last_error := ""
var rates: Dictionary = {}
var deadlines: Dictionary = {}

func host(source: Dictionary, account: CryptoKey, port: int = 0, bind_ip: String = "127.0.0.1") -> bool:
	close()
	if not Document.new().validate(source).ok or account == null or account.is_public_only(): return false
	if JSON.stringify(source).to_utf8_buffer().size() > 64 * 1024: return false
	connection = ENetConnection.new()
	if connection.create_host_bound(bind_ip, port, 8, 1) != OK:
		close()
		return false
	key = account
	owner_fingerprint = Identity.fingerprint(key.save_to_string(true))
	generation = Crypto.new().generate_random_bytes(16).hex_encode()
	authority.configure(source, owner_fingerprint, generation)
	document = source.duplicate(true)
	hosting = true
	authenticated = true
	role = "owner"
	changed.emit()
	return true

func join(host_ip: String, port: int, owner_fingerprint: String, account: CryptoKey) -> bool:
	close()
	if owner_fingerprint.length() != 64 or account == null or account.is_public_only(): return false
	for character in owner_fingerprint:
		if character not in "0123456789abcdef": return false
	connection = ENetConnection.new()
	if connection.create_host(1, 1) != OK: close(); return false
	server_peer = connection.connect_to_host(host_ip, port, 1)
	if server_peer == null: close(); return false
	key = account
	self.owner_fingerprint = owner_fingerprint
	challenge = {"nonce": Crypto.new().generate_random_bytes(32).hex_encode()}
	deadlines[server_peer] = Time.get_ticks_msec() + 30000
	return true

func approve(fingerprint: String, access: String) -> bool:
	if not hosting or access not in ["viewer", "editor"]: return false
	for peer in pending.keys():
		if pending[peer].get("fingerprint") == fingerprint and pending[peer].get("verified", false):
			var now = Time.get_ticks_msec()
			if pending[peer].expires <= now or deadlines.get(peer, 0) <= now: return false
			if members.values().any(func(member): return member.fingerprint == fingerprint): return false
			if not authority.admit(owner_fingerprint, fingerprint, access).ok: return false
			members[peer] = pending[peer]
			deadlines.erase(peer)
			pending.erase(peer)
			_send(peer, {"op": "snapshot", "document": document, "role": access})
			changed.emit()
			return true
	return false

func revoke(fingerprint: String):
	if not hosting: return
	authority.revoke(owner_fingerprint, fingerprint)
	for peer in members.keys():
		if members[peer].fingerprint == fingerprint:
			_send(peer, {"op": "revoked"})
			_remove(peer)
			peer.peer_disconnect()
	changed.emit()

func move_entity(entity: String, position: Array) -> bool:
	if not authenticated or role not in ["owner", "editor"]: return false
	var operation = {"id": Crypto.new().generate_random_bytes(16).hex_encode(), "generation": generation,
		"revision": document.get("revision", 0), "op": "set_transform", "entity": entity, "position": position}
	if hosting: return _apply(owner_fingerprint, operation)
	_send(server_peer, {"op": "edit", "operation": operation})
	return true

func _apply(sender: String, operation: Dictionary) -> bool:
	var result = authority.submit(sender, operation)
	if not result.ok:
		last_error = result.error
		status_changed.emit(last_error)
		return false
	document = authority.document.duplicate(true)
	for peer in members: _send(peer, {"op": "snapshot", "document": document, "role": authority.roles.get(members[peer].fingerprint, "viewer")})
	changed.emit()
	return true

func _send(peer: ENetPacketPeer, body: Dictionary):
	if peer == null or peer.get_state() != ENetPacketPeer.STATE_CONNECTED: return
	sent_sequence += 1
	var text = JSON.stringify(body)
	var envelope = {"protocol": "comunicare/editor/v1", "generation": generation, "sequence": sent_sequence,
		"body": text, "public_key": key.save_to_string(true)}
	var bytes = JSON.stringify([envelope.protocol, generation, sent_sequence, text]).to_utf8_buffer()
	envelope.signature = Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256, Identity.digest(bytes), key))
	var packet = JSON.stringify(envelope).to_utf8_buffer()
	if packet.size() <= MAX_PACKET: peer.send(0, packet, ENetPacketPeer.FLAG_RELIABLE)

func _receive(peer: ENetPacketPeer, bytes: PackedByteArray):
	if bytes.size() > MAX_PACKET: peer.peer_disconnect(); return
	var now = Time.get_ticks_msec()
	var rate = rates.get(peer, {"at": now, "count": 0})
	if now - rate.at >= 1000: rate = {"at": now, "count": 0}
	rate.count += 1
	rates[peer] = rate
	if rate.count > 30: peer.peer_disconnect(); return
	var parsed = preload("res://scripts/worlds/world_text_parser.gd").new().parse_json(bytes.get_string_from_utf8())
	if not parsed.ok or not parsed.value is Dictionary: return
	var packet: Dictionary = parsed.value
	if packet.get("protocol") != "comunicare/editor/v1" or not packet.get("body") is String \
		or not packet.get("generation") is String or not packet.get("public_key") is String \
		or not packet.get("signature") is String or packet.signature.length() > 2048 \
		or not preload("res://scripts/worlds/world_data.gd").integer(packet.get("sequence"), 1, 2147483647): return
	var fingerprint = Identity.fingerprint(packet.public_key)
	if fingerprint.is_empty(): return
	if not hosting and fingerprint != owner_fingerprint: return
	if hosting and members.has(peer) and members[peer].fingerprint != fingerprint: return
	if packet.sequence <= received_sequence.get(peer, 0): return
	var public_key = CryptoKey.new()
	if public_key.load_from_string(packet.public_key, true) != OK: return
	var signed = JSON.stringify([packet.protocol, packet.generation, int(packet.sequence), packet.body]).to_utf8_buffer()
	if not Crypto.new().verify(HashingContext.HASH_SHA256, Identity.digest(signed), Marshalls.base64_to_raw(packet.signature), public_key): return
	var decoded = preload("res://scripts/worlds/world_text_parser.gd").new().parse_json(packet.body)
	if not decoded.ok or not decoded.value is Dictionary: return
	var body: Dictionary = decoded.value
	received_sequence[peer] = packet.sequence
	if hosting:
		if fingerprint == owner_fingerprint: return
		if body.get("op") == "hello" and not members.has(peer) and body.get("nonce") is String and body.nonce.length() == 64:
			var nonce = Crypto.new().generate_random_bytes(32).hex_encode()
			pending[peer] = {"fingerprint": fingerprint, "public_key": packet.public_key, "nonce": nonce, "expires": now + 30000}
			_send(peer, {"op": "challenge", "echo": body.nonce, "nonce": nonce})
		elif body.get("op") == "proof" and pending.has(peer) and packet.generation == generation and pending[peer].fingerprint == fingerprint and pending[peer].nonce == body.get("nonce"):
			pending[peer].verified = true
			status_changed.emit("Access requested by " + fingerprint)
			changed.emit()
		elif members.has(peer) and packet.generation == generation and body.get("op") == "edit" and body.get("operation") is Dictionary:
			if not _apply(fingerprint, body.operation): _send(peer, {"op": "error", "message": last_error})
	else:
		if body.get("op") == "challenge" and body.get("echo") == challenge.get("nonce") and body.get("nonce") is String and packet.generation.length() == 32:
			generation = packet.generation
			_send(peer, {"op": "proof", "nonce": body.nonce})
			status_changed.emit("Authenticated host; waiting for owner_fingerprint approval")
		elif packet.generation == generation:
			if body.get("op") == "snapshot" and Document.new().validate(body.get("document")).ok and body.get("role") in ["viewer", "editor"]:
				document = body.document
				role = body.role
				authenticated = true
				deadlines.erase(peer)
				changed.emit()
			elif body.get("op") == "revoked": close(); status_changed.emit("Editing access revoked")
			elif body.get("op") == "error": status_changed.emit(str(body.get("message", "Edit rejected")))

func _process(_delta: float):
	if connection == null: return
	for peer in deadlines.keys():
		if deadlines[peer] <= Time.get_ticks_msec():
			if hosting: peer.peer_disconnect(); _remove(peer)
			else: close(); status_changed.emit("Editing join timed out; request approval again"); return
	for peer in pending.keys():
		if pending[peer].expires < Time.get_ticks_msec(): peer.peer_disconnect(); _remove(peer)
	for i in 64:
		if connection == null: return
		var event = connection.service()
		match event[0]:
			ENetConnection.EVENT_NONE: return
			ENetConnection.EVENT_CONNECT:
				deadlines[event[1]] = Time.get_ticks_msec() + 30000
				if not hosting: _send(server_peer, {"op": "hello", "nonce": challenge.nonce})
			ENetConnection.EVENT_RECEIVE: _receive(event[1], event[1].get_packet())
			ENetConnection.EVENT_DISCONNECT:
				if hosting: _remove(event[1])
				else: close(); status_changed.emit("Editing host disconnected; local draft retained in panel")

func _remove(peer):
	if members.has(peer): authority.revoke(owner_fingerprint, members[peer].fingerprint)
	members.erase(peer)
	pending.erase(peer)
	rates.erase(peer)
	received_sequence.erase(peer)
	deadlines.erase(peer)
	changed.emit()

func close():
	var was_active = connection != null
	if connection != null:
		if server_peer != null and server_peer.get_state() == ENetPacketPeer.STATE_CONNECTED: server_peer.peer_disconnect_now()
		for peer in members:
			if peer.get_state() == ENetPacketPeer.STATE_CONNECTED: peer.peer_disconnect_now()
		connection.flush()
		connection.destroy()
	connection = null
	server_peer = null
	hosting = false
	authenticated = false
	role = ""
	key = null
	pending.clear()
	members.clear()
	rates.clear()
	deadlines.clear()
	received_sequence.clear()
	sent_sequence = 0
	authority.roles.clear()
	authority.seen.clear()
	document.clear()
	authority.document.clear()
	authority.owner = ""
	authority.generation = ""
	generation = ""
	owner_fingerprint = ""
	challenge.clear()
	last_error = ""
	if was_active: changed.emit()

func _exit_tree(): close()
