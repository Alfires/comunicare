class_name WorldItemRouter
extends RefCounted
## Active-connection item arbitration only; no world downloads/scripts or disk IO.
var supported: Dictionary = {}
var generations: Dictionary = {}
var instances: Dictionary = {}
var rates: Dictionary = {}
var physics_supported: Dictionary = {}

func _send(server: Node, id: int, value: Dictionary):
	if supported.has(id) and server.peers.has(id) and server.peers[id].get_state() == ENetPacketPeer.STATE_CONNECTED:
		AccountPacket.create(PacketInfo.PACKET_TYPE.WORLD_DATA, value).sent(server.peers[id])

func _broadcast(server: Node, index: int, value: Dictionary):
	for id in server.sessions[index][0].peers: _send(server, id, value)

func handle(server: Node, sender: int, value: Dictionary):
	if not server.key_mapping.has(sender) or not server.peers.has(sender): return
	if value.get("op") == "hello" and value.get("version") == 1:
		if value.get("physics_version") == 1: physics_supported[sender] = true
		supported[sender] = true
		if not generations.has(sender): generations[sender] = Crypto.new().generate_random_bytes(16).hex_encode()
		_send(server, sender, {"op": "hello", "version": 1, "physics_version": 1, "peer_id": sender, "generation": generations[sender]})
		return
	if not supported.has(sender): return
	var now = Time.get_ticks_msec()
	var bucket: Dictionary = rates.get(sender, {"at": now, "count": 0})
	if now - bucket.at >= 1000: bucket = {"at": now, "count": 0}
	bucket.count += 1
	rates[sender] = bucket
	if bucket.count > 60: return
	var index = server.get_user_in_session(sender)
	if index < 0: return
	var session: Dictionary = server.sessions[index][0]
	if value.get("session_id") != session.session_id or value.get("revision") != session.get("world_revision", ""): return
	if not instances.has(session.session_id): instances[session.session_id] = {"sequence": 0, "items": {}, "senders": {}}
	var instance: Dictionary = instances[session.session_id]
	var candidates: Array = []
	for member in session.peers:
		if physics_supported.has(member): candidates.append(member)
	candidates.sort()
	var physics_owner: int = candidates[0] if not candidates.is_empty() else -1
	if value.get("op") == "snapshot":
		_send(server, sender, {"op": "snapshot", "physics_owner": physics_owner, "session_id": session.session_id, "revision": session.get("world_revision", ""), "sequence": instance.sequence, "items": instance.items.duplicate(true)})
		return
	if not value.get("entity") is String or value.entity.is_empty() or value.entity.length() > 128 \
		or not InstanceState.integer(value.get("sequence"), 1, 2147483647) \
		or value.sequence <= instance.senders.get(sender, 0) or not InstanceState.integer(value.get("epoch"), 0, 2147483646): return
	var item: Dictionary = instance.items.get(value.entity, {"holder": -1, "generation": "", "grip": "", "epoch": 0, "position": [], "rotation": []})
	if item.epoch != value.epoch:
		_result(server, sender, value, false)
		return
	match value.get("op"):
		"physics":
			if sender != physics_owner or item.holder != -1 or not instance.items.has(value.entity) or not _pose(value): return
			item.position = value.position.duplicate()
			item.rotation = value.rotation.duplicate()
		"grab":
			if item.holder != -1 or not value.get("grip") in ["left", "right", "virtual"] or (not instance.items.has(value.entity) and instance.items.size() >= 256):
				_result(server, sender, value, false)
				return
			var held = 0
			for existing in instance.items.values():
				if existing.holder == sender: held += 1
			if held >= 2:
				_result(server, sender, value, false)
				return
			item.holder = sender
			item.generation = generations[sender]
			item.grip = value.grip
			item.epoch += 1
		"release":
			if item.holder != sender:
				_result(server, sender, value, false)
				return
			item.holder = -1
			item.generation = ""
			item.grip = ""
			item.epoch += 1
		"pose":
			if item.holder != sender or not _pose(value): return
			item.position = value.position.duplicate()
			item.rotation = value.rotation.duplicate()
		_:
			return
	instance.senders[sender] = int(value.sequence)
	instance.items[value.entity] = item
	instance.sequence += 1
	var clean = item.duplicate(true)
	clean.merge({"op": "pose" if value.op in ["pose", "physics"] else "item", "physics_owner": physics_owner, "entity": value.entity, "session_id": session.session_id, "revision": session.get("world_revision", ""), "sequence": instance.sequence})
	_broadcast(server, index, clean)

func _result(server: Node, sender: int, value: Dictionary, success: bool):
	_send(server, sender, {"op": "result", "session_id": value.session_id, "revision": value.revision, "entity": value.entity, "ok": success})

func _pose(value: Dictionary) -> bool:
	if not value.get("position") is Array or value.position.size() != 3 or not value.get("rotation") is Array or value.rotation.size() != 4: return false
	for number in value.position:
		if not (number is int or number is float) or not is_finite(float(number)) or absf(number) > 10000: return false
	var length = 0.0
	for number in value.rotation:
		if not (number is int or number is float) or not is_finite(float(number)) or absf(number) > 1: return false
		length += number * number
	return absf(length - 1.0) < 0.02

func leave(server: Node, sender: int):
	var index = server.get_user_in_session(sender)
	if index < 0: return
	var session: Dictionary = server.sessions[index][0]
	if not instances.has(session.session_id): return
	var instance: Dictionary = instances[session.session_id]
	instance.senders.erase(sender)
	for id in instance.items:
		var item: Dictionary = instance.items[id]
		if item.holder != sender: continue
		item.holder = -1
		item.generation = ""
		item.grip = ""
		item.epoch += 1
		instance.sequence += 1
		var clean = item.duplicate(true)
		clean.merge({"op": "item", "entity": id, "session_id": session.session_id, "revision": session.get("world_revision", ""), "sequence": instance.sequence})
		_broadcast(server, index, clean)
	if session.peers.size() <= 1: instances.erase(session.session_id)

func disconnect_peer(server: Node, sender: int):
	leave(server, sender)
	supported.erase(sender)
	physics_supported.erase(sender)
	generations.erase(sender)
	rates.erase(sender)
