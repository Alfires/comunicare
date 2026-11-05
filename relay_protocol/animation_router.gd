class_name AnimationRouter
extends RefCounted
## Ephemeral same-instance state and request-bound chunk forwarding only.

var supported: Dictionary = {}
var states: Dictionary = {}
var requests: Dictionary = {}
var rates: Dictionary = {}
var generations: Dictionary = {}
var pose_supported: Dictionary = {}
var poses: Dictionary = {}
var pose_rates: Dictionary = {}

func _send(server: Node, id: int, value: Dictionary):
	if supported.has(id) and server.peers.has(id) and server.peers[id].get_state() == ENetPacketPeer.STATE_CONNECTED:
		AccountPacket.create(PacketInfo.PACKET_TYPE.ANIMATION_DATA, value).sent(server.peers[id])

func _same(server: Node, a: int, b: int) -> bool:
	var index = server.get_user_in_session(a)
	return index >= 0 and server.get_user_in_session(b) == index

func handle(server: Node, sender: int, value: Dictionary):
	if not server.key_mapping.has(sender) or not server.peers.has(sender):
		return
	var now = Time.get_ticks_msec()
	if value.get("op") == "hello" and value.get("version") == 2:
		if not supported.has(sender):
			supported[sender] = true
			generations[sender] = Crypto.new().generate_random_bytes(16).hex_encode()
		_send(server, sender, {"op": "hello", "version": 2})
		return
	if not supported.has(sender):
		return
	if value.get("op") == "pose_hello" and value.get("version") == 1:
		pose_supported[sender] = true
		_send(server, sender, {"op": "pose_hello", "version": 1})
		return
	if value.get("op") == "pose":
		_pose(server, sender, value, now)
		return
	# At most 16 control packets or 256 KiB per second per connection.
	var bucket: Dictionary = rates.get(sender, {"at": now, "count": 0, "bytes": 0})
	if now - bucket.at >= 1000:
		bucket = {"at": now, "count": 0, "bytes": 0}
	bucket.bytes += JSON.stringify(value).length()
	if value.get("op") != "chunk":
		bucket.count += 1
	rates[sender] = bucket
	if bucket.count > 16 or bucket.bytes > 256 * 1024:
		return
	if value.get("op") == "clock" and AnimationState.integer(value.get("nonce"), 0, 9007199254740991):
		_send(server, sender, {"op": "clock", "nonce": value.nonce, "time": now})
		return
	var index = server.get_user_in_session(sender)
	if index < 0 or value.get("session_id") != server.sessions[index][0].session_id:
		return
	match value.get("op"):
		"state":
			if not AnimationState.valid(value) or value.sequence <= states.get(sender, {}).get("sequence", 0):
				return
			if value.get("builtin") in AnimationState.BUILTINS:
				var durations = AnimationState.DURATIONS
				if absf(value.duration - durations[value.builtin]) > 0.001:
					return
			for key in requests.keys():
				if requests[key].owner == sender and requests[key].hash != value.get("model_hash" if requests[key].kind == "avatar" else "hash"):
					requests.erase(key)
			var state: Dictionary = {}
			for field in ["version", "session_id", "sequence", "action", "kind", "role", "mask", "avatar_revision", "configuration_revision", "avatar_scale", "model_hash", "model_size", "offset", "speed", "loop", "duration", "builtin", "library", "hash", "size", "clip"]:
				if value.has(field):
					state[field] = value[field]
			state.merge({"op": "state", "peer_id": sender, "generation": generations[sender], "started": now})
			states[sender] = state
			for id in server.sessions[index][0].peers:
				_send(server, id, state)
		"snapshot":
			snapshot(server, sender)
		"request":
			var owner = value.get("owner")
			var kind = value.get("asset_kind", "animation")
			if kind not in ["animation", "avatar"]: return
			var hash_field = "model_hash" if kind == "avatar" else "hash"
			var size_field = "model_size" if kind == "avatar" else "size"
			if not AnimationState.integer(owner, 0, 255) or owner == sender or not _same(server, sender, int(owner)) \
				or not states.has(int(owner)) or states[int(owner)].get(hash_field, "") != value.get("hash") \
				or not InstanceState.valid_fingerprint(value.get("hash")) or not states[int(owner)].has(size_field) \
				or requests.size() >= 256:
				return
			var key = "%s:%s:%s" % [sender, int(owner), kind]
			if requests.has(key):
				return
			requests[key] = {"requester": sender, "owner": int(owner), "hash": value.hash, "kind": kind, "next": 0,
				"size": states[int(owner)][size_field], "expires": now + 900000, "session_id": value.session_id}
			_send(server, int(owner), {"op": "request", "asset_kind": kind, "requester": sender, "hash": value.hash, "session_id": value.session_id})
		"chunk":
			var target = value.get("target")
			if not AnimationState.integer(target, 0, 255):
				return
			var kind = value.get("asset_kind", "animation")
			var key = "%s:%s:%s" % [int(target), sender, kind]
			if not requests.has(key):
				return
			var request: Dictionary = requests[key]
			if not _same(server, sender, int(target)) or value.get("hash") != request.hash \
				or value.get("offset") != request.next or not value.get("bytes") is String \
				or value.bytes.length() > 10924:
				return
			var bytes = Marshalls.base64_to_raw(value.bytes)
			if bytes.is_empty() or bytes.size() > AnimationState.CHUNK_BYTES or bytes.size() > request.size - request.next:
				return
			_send(server, int(target), {"op": "chunk", "asset_kind": kind, "owner": sender, "hash": request.hash,
				"offset": request.next, "bytes": value.bytes, "session_id": request.session_id})
			request.next += bytes.size()
			if request.next == request.size:
				requests.erase(key)

func snapshot(server: Node, recipient: int):
	for owner in states:
		if owner != recipient and _same(server, owner, recipient):
			_send(server, recipient, states[owner])
	if pose_supported.has(recipient):
		for owner in poses:
			if owner != recipient and _same(server, owner, recipient) and Time.get_ticks_msec() - poses[owner].at < 1000:
				_send(server, recipient, poses[owner])

func _pose(server: Node, sender: int, value: Dictionary, now: int):
	if not pose_supported.has(sender) or not TrackingPose.valid(value): return
	var index = server.get_user_in_session(sender)
	if index < 0 or value.get("session_id") != server.sessions[index][0].session_id: return
	if value.sequence <= poses.get(sender, {}).get("sequence", 0): return
	var rate: Dictionary = pose_rates.get(sender, {"at": now, "count": 0})
	if now - rate.at >= 1000: rate = {"at": now, "count": 0}
	rate.count += 1
	pose_rates[sender] = rate
	if rate.count > 30: return
	var clean = {"op": "pose", "version": 1, "peer_id": sender, "session_id": value.session_id,
		"generation": generations[sender], "sequence": value.sequence, "avatar_revision": value.avatar_revision,
		"calibration_revision": value.calibration_revision, "targets": value.targets.duplicate(true), "at": now}
	poses[sender] = clean
	for id in server.sessions[index][0].peers:
		if id != sender and pose_supported.has(id): _send(server, id, clean)

func leave(server: Node, sender: int):
	var index = server.get_user_in_session(sender)
	var session_id = server.sessions[index][0].session_id if index >= 0 else ""
	states.erase(sender)
	poses.erase(sender)
	for key in requests.keys():
		if requests[key].owner == sender or requests[key].requester == sender:
			requests.erase(key)
	for id in supported:
		if id != sender and _same(server, sender, id):
			_send(server, id, {"op": "left", "peer_id": sender, "generation": generations.get(sender, ""), "session_id": session_id})

func disconnect_peer(server: Node, sender: int):
	leave(server, sender)
	supported.erase(sender)
	rates.erase(sender)
	generations.erase(sender)
	pose_supported.erase(sender)
	pose_rates.erase(sender)

func tick():
	for owner in poses.keys():
		if Time.get_ticks_msec() - poses[owner].at > 1000: poses.erase(owner)
	for key in requests.keys():
		if requests[key].expires <= Time.get_ticks_msec():
			requests.erase(key)
