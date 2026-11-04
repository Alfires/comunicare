extends RefCounted
## Live TLS public-directory exchange; no user login or durable session cache.
const Link = preload("res://scripts/multiplayer/federation/secure_relay_link.gd")
const Directory = preload("res://scripts/multiplayer/federation/federation_directory.gd")
const Guard = preload("res://scripts/multiplayer/federation/relay_validation.gd")
var listener: TCPServer
var key: CryptoKey
var certificate: X509Certificate
var relay_id := ""
var boot_id := ""
var local_port := 0
var links: Array = []
var peers: Dictionary = {}
var blocks: Array = []
var directory = Directory.new()
var local_summaries: Array = []
var last_error := ""
var publish_at := 0
var sequence := 0
var trusted_origins: Dictionary = {}
var gameplay_port := 0
var tunnels: Dictionary = {}
var reconnects: Dictionary = {}

func set_gameplay_port(port: int):
	gameplay_port = port if port > 0 and port <= 65535 else 0
signal changed

func start(private_key: CryptoKey, cert: X509Certificate, port: int = 0, bind_address: String = "127.0.0.1") -> bool:
	if private_key == null or cert == null or private_key.is_public_only():
		last_error = "Relay infrastructure private key/certificate required"
		return false
	key = private_key
	certificate = cert
	relay_id = _fingerprint(private_key.save_to_string(true))
	boot_id = Crypto.new().generate_random_bytes(16).hex_encode()
	listener = TCPServer.new()
	if listener.listen(port, bind_address) != OK:
		last_error = "Cannot bind secure relay directory listener"
		return false
	local_port = listener.get_local_port()
	directory.configure({"max_instances": 1024, "ttl_ms": 15000}, blocks)
	trusted_origins[relay_id] = private_key.save_to_string(true)
	return true

func trust_peer(public_key: String, cert: X509Certificate) -> String:
	var id = _fingerprint(public_key)
	if id.is_empty() or cert == null: return ""
	var parsed = CryptoKey.new()
	if parsed.load_from_string(public_key, true) != OK: return ""
	peers[id] = {"key": parsed, "certificate": cert}
	trusted_origins[id] = parsed.save_to_string(true)
	return id

func connect_peer(host: String, port: int, id: String, common_name: String = "comunicare-relay") -> bool:
	if not peers.has(id) or id in blocks or links.size() >= 16: return false
	for record in links:
		if record.id == id and record.outgoing: return true
	var link = Link.new()
	if not link.connect_to(host, port, peers[id].certificate, common_name):
		last_error = link.last_error
		return false
	links.append({"link": link, "id": id, "outgoing": true, "ready": false, "authenticated": false,
		"challenge": "", "challenge_at": Time.get_ticks_msec(), "last_ping": 0, "rate_at": 0, "rate": 0})
	reconnects[id] = {"host": host, "port": port, "common_name": common_name, "at": Time.get_ticks_msec() + 5000, "delay": 5000}
	return true

func set_local_instances(values: Array) -> bool:
	if values.size() > 256: return false
	for value in values:
		if not Directory.valid_summary(value, relay_id, boot_id): return false
	if values != local_summaries:
		local_summaries = values.duplicate(true)
		publish_at = 0
	return true

func set_blocked(id: String, blocked: bool):
	if blocked and not id in blocks: blocks.append(id)
	elif not blocked: blocks.erase(id)
	directory.set_blocked(id, blocked)
	if blocked:
		for token in tunnels.keys():
			if id in tunnels[token].path or tunnels[token].origin == id: _close_tunnel(token)
		for record in links:
			if record.id == id: record.link.close()
	changed.emit()

func poll():
	var now = Time.get_ticks_msec()
	for id in reconnects.keys():
		if id in blocks or now < reconnects[id].at: continue
		var present = false
		for record in links:
			if record.id == id and record.outgoing: present = true
		if not present:
			var entry: Dictionary = reconnects[id].duplicate()
			connect_peer(entry.host, entry.port, id, entry.common_name)
			reconnects[id].delay = mini(int(entry.delay) * 2, 60000)
			reconnects[id].at = now + reconnects[id].delay
	if listener != null:
		for index in 4:
			if not listener.is_connection_available(): break
			var tcp = listener.take_connection()
			if links.size() >= 16:
				tcp.disconnect_from_host()
				continue
			var link = Link.new()
			link.accept_connection(tcp, key, certificate)
			links.append({"link": link, "id": "", "outgoing": false, "ready": false, "authenticated": false,
				"challenge": Crypto.new().generate_random_bytes(32).hex_encode(), "challenge_at": now, "last_ping": 0, "rate_at": now, "rate": 0})
	for index in range(links.size() - 1, -1, -1):
		var record: Dictionary = links[index]
		record.link.poll()
		if not record.link.last_error.is_empty() or (not record.authenticated and not record.get("directory_only", false) and now - record.challenge_at > 10000) or now - record.link.last_activity > 10000:
			_drop(index)
			continue
		if not record.link.connected(): continue
		if not record.ready:
			record.ready = true
			if not record.outgoing: record.link.send({"op": "challenge", "nonce": record.challenge, "relay_id": relay_id, "boot_id": boot_id})
		for message in record.link.drain():
			if now - record.rate_at >= 1000:
				record.rate_at = now
				record.rate = 0
				record.data_rate = 0
				record.byte_rate = 0
			record.byte_rate = int(record.get("byte_rate", 0)) + JSON.stringify(message).length()
			if message.get("op") == "tunnel_data":
				record.data_rate = int(record.get("data_rate", 0)) + 1
				if record.data_rate > 512 or record.byte_rate > 1024 * 1024:
					record.link.close()
					break
				_receive(record, message, now)
				continue
			record.rate += 1
			if record.rate > 32:
				record.link.close()
				break
			_receive(record, message, now)
		if record.authenticated and now - record.last_ping >= 2000:
			record.last_ping = now
			record.link.send({"op": "ping"})
	if now >= publish_at:
		publish_at = now + 5000
		sequence += 1
		var body = JSON.stringify({"origin": relay_id, "boot": boot_id, "sequence": sequence, "instances": local_summaries}).to_utf8_buffer()
		var message = {"op": "directory", "body": Marshalls.raw_to_base64(body), "signature": _sign(body), "path": [relay_id]}
		for record in links:
			if record.authenticated: record.link.send(message)
	var before = directory.snapshot()
	directory.expire(now)
	if before != directory.snapshot(): changed.emit()
	_poll_tunnels(now)

func _receive(record: Dictionary, message: Dictionary, now: int):
	if str(message.get("op", "")).begins_with("tunnel_"):
		_tunnel_message(record, message, now)
		return
	# Directory-only clients are anonymous and get only bounded public summaries.
	# Their server certificate must be verified before calling this connection.
	if message.get("op") == "public_query" and not record.outgoing:
		if not message.get("nonce") is String or message.nonce.length() > 128: return
		record.directory_only = true
		record.challenge = ""
		record.link.send({"op": "public_directory", "nonce": message.nonce, "relay_id": relay_id, "boot_id": boot_id, "instances": public_instances()})
		return
	if message.get("op") == "challenge" and record.outgoing and not record.authenticated:
		if message.get("relay_id") != record.id or not Guard.text(message.get("nonce"), 64):
			record.link.close()
			return
		var proof = JSON.stringify(["comunicare/relay-link/v1", message.nonce, record.id, relay_id]).to_utf8_buffer()
		record.link.send({"op": "authenticate", "relay_id": relay_id, "signature": _sign(proof)})
		return
	if message.get("op") == "authenticate" and not record.outgoing and not record.authenticated:
		if record.get("directory_only", false): record.link.close(); return
		var id = message.get("relay_id", "")
		if not id is String or not peers.has(id) or id in blocks or now - record.challenge_at > 10000:
			record.link.close()
			return
		var proof = JSON.stringify(["comunicare/relay-link/v1", record.challenge, relay_id, id]).to_utf8_buffer()
		if not _verify(peers[id].key, proof, message.get("signature")):
			record.link.close()
			return
		record.id = id
		record.authenticated = true
		record.challenge = ""
		record.link.send({"op": "authenticated", "relay_id": relay_id})
		publish_at = 0
		return
	if message.get("op") == "authenticated" and record.outgoing and message.get("relay_id") == record.id:
		record.authenticated = true
		publish_at = 0
		return
	if not record.authenticated: return
	if message.get("op") == "ping": return
	if message.get("op") != "directory" or not message.get("body") is String or message.body.length() > 60000 or not message.get("path") is Array: return
	var path: Array = message.path
	if path.is_empty() or path.size() > 4 or path.back() != record.id or relay_id in path: return
	for hop in path:
		if not Guard.identity(hop) or hop in blocks: return
	var body = Marshalls.base64_to_raw(message.body)
	var parser = JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK or not parser.data is Dictionary: return
	var value: Dictionary = parser.data
	if not value.get("origin") is String or not trusted_origins.has(value.origin) or path.front() != value.origin \
		or not value.get("instances") is Array or not Guard.integer(value.get("sequence"), 1, 2147483647) or not Guard.text(value.get("boot"), 128): return
	var origin_key = CryptoKey.new()
	if origin_key.load_from_string(trusted_origins[value.origin], true) != OK or not _verify(origin_key, body, message.get("signature")): return
	var route = path.duplicate()
	route.reverse() # Directory policy expects immediate ingress first, origin last.
	var result = directory.ingest(value.origin, value.boot, int(value.sequence), value.instances, route, now)
	if not result.ok: return
	changed.emit()
	if path.size() < 4:
		var forwarded = message.duplicate(true)
		forwarded.path.append(relay_id)
		for target in links:
			if target.authenticated and not target.id in forwarded.path: target.link.send(forwarded)

func _drop(index: int):
	var record: Dictionary = links[index]
	for token in tunnels.keys():
		if tunnels[token].upstream == record or tunnels[token].get("downstream", {}) == record: _close_tunnel(token)
	var lost = record.id
	record.link.close()
	links.remove_at(index)
	# Withdraw every path dependent on a failed link, not just its direct origin.
	var replacement = false
	for link in links:
		if link.id == lost and link.authenticated: replacement = true
	if not replacement and not lost.is_empty():
		for origin in directory.origins.keys():
			if lost in directory.origins[origin].path: directory.origins.erase(origin)
	changed.emit()

func public_instances() -> Array:
	return local_summaries.duplicate(true) + directory.snapshot()

func stop():
	for token in tunnels.keys(): _close_tunnel(token)
	for record in links: record.link.close()
	links.clear()
	reconnects.clear()
	if listener != null: listener.stop()
	directory.configure({"max_instances": 1024}, blocks)
	local_summaries.clear()

func _tunnel_message(record: Dictionary, message: Dictionary, now: int):
	var token = message.get("token")
	if not Guard.text(token, 64): return
	if message.get("op") == "tunnel_open":
		if not record.authenticated:
			var owned = 0
			for existing in tunnels.values():
				if existing.upstream == record: owned += 1
			if owned >= 1: return
		if tunnels.size() >= 32 or not Guard.identity(message.get("origin")) or message.origin in blocks or not message.get("path") is Array: return
		var path: Array = message.path.duplicate()
		if path.size() >= 4 or relay_id in path: return
		for hop in path:
			if not Guard.identity(hop) or hop in blocks: return
		if not path.is_empty() and (not record.authenticated or path.back() != record.id): return
		path.append(relay_id)
		var local_token = Crypto.new().generate_random_bytes(16).hex_encode()
		var route = {"upstream": record, "upstream_token": token, "origin": message.origin, "path": path, "expires": now + 10000,
			"at": now, "count": 0, "ready": false}
		if message.origin == relay_id:
			if gameplay_port == 0:
				record.link.send({"op": "tunnel_error", "token": token})
				return
			var udp = PacketPeerUDP.new()
			if udp.bind(0, "127.0.0.1", 128 * 1024) != OK: return
			udp.set_dest_address("127.0.0.1", gameplay_port)
			route.udp = udp
			route.ready = true
			tunnels[local_token] = route
			record.directory_only = true
			record.link.send({"op": "tunnel_ready", "token": token, "path": path})
		else:
			var next = ""
			for candidate in links:
				if candidate.authenticated and candidate.id == message.origin: next = message.origin
			if next.is_empty() and directory.origins.has(message.origin): next = directory.origins[message.origin].path.front()
			if next.is_empty() or next in blocks or next in path:
				record.link.send({"op": "tunnel_error", "token": token})
				return
			for downstream in links:
				if downstream.id == next and downstream.authenticated:
					route.downstream = downstream
					tunnels[local_token] = route
					record.directory_only = true
					downstream.link.send({"op": "tunnel_open", "token": local_token, "origin": message.origin, "path": path})
					return
			record.link.send({"op": "tunnel_error", "token": token})
		return
	var local_token = ""
	var from_upstream = false
	for id in tunnels:
		var value: Dictionary = tunnels[id]
		if value.upstream == record and value.upstream_token == token:
			local_token = id
			from_upstream = true
			break
		if id == token and value.get("downstream", {}) == record:
			local_token = id
			break
	if local_token.is_empty(): return
	var route: Dictionary = tunnels[local_token]
	if now - route.at >= 1000: route.at = now; route.count = 0
	route.count += 1
	if route.count > 512: return
	route.expires = now + 10000
	if message.op in ["tunnel_close", "tunnel_error"]:
		_close_tunnel(local_token)
		return
	if message.op == "tunnel_ready" and not from_upstream:
		if not message.get("path") is Array or message.path.size() > 4 or message.path.back() != route.origin: return
		for hop in message.path:
			if hop in blocks: _close_tunnel(local_token); return
		route.path = message.path.duplicate()
		route.ready = true
		route.upstream.link.send({"op": "tunnel_ready", "token": route.upstream_token, "path": route.path})
		return
	if message.op == "tunnel_keepalive" and from_upstream:
		if route.has("downstream"): route.downstream.link.send({"op": "tunnel_keepalive", "token": local_token})
		return
	if message.op != "tunnel_data" or not route.ready or not message.get("bytes") is String or message.bytes.length() > 2000: return
	var bytes = Marshalls.base64_to_raw(message.bytes)
	if bytes.is_empty() or bytes.size() > 1500: return
	if from_upstream:
		if route.has("udp"): route.udp.put_packet(bytes)
		else: route.downstream.link.send({"op": "tunnel_data", "token": local_token, "bytes": message.bytes})
	else:
		route.upstream.link.send({"op": "tunnel_data", "token": route.upstream_token, "bytes": message.bytes})

func _poll_tunnels(now: int):
	for token in tunnels.keys():
		var route: Dictionary = tunnels[token]
		if now >= route.expires:
			_close_tunnel(token)
			continue
		if not route.has("udp"): continue
		for index in 64:
			if route.udp.get_available_packet_count() == 0: break
			var bytes = route.udp.get_packet()
			if route.udp.get_packet_ip() != "127.0.0.1" or route.udp.get_packet_port() != gameplay_port or bytes.size() > 1500: continue
			route.upstream.link.send({"op": "tunnel_data", "token": route.upstream_token, "bytes": Marshalls.raw_to_base64(bytes)})

func _close_tunnel(token: String):
	if not tunnels.has(token): return
	var route: Dictionary = tunnels[token]
	if route.has("udp"): route.udp.close()
	if route.has("downstream"): route.downstream.link.send({"op": "tunnel_close", "token": token})
	route.upstream.link.send({"op": "tunnel_error", "token": route.upstream_token})
	tunnels.erase(token)

func _fingerprint(public_key: String) -> String:
	return _digest(public_key.to_utf8_buffer()).hex_encode()

func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish()

func _sign(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256, _digest(bytes), key))

func _verify(public_key: CryptoKey, bytes: PackedByteArray, signature: Variant) -> bool:
	return signature is String and signature.length() <= 2048 and Crypto.new().verify(HashingContext.HASH_SHA256, _digest(bytes), Marshalls.base64_to_raw(signature), public_key)
