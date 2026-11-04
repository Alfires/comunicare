extends RefCounted
## Local UDP ↔ certificate-verified TLS tunnel. ENet/account admission stays end-to-end.
const Link = preload("res://scripts/multiplayer/federation/secure_relay_link.gd")
var link
var socket: PacketPeerUDP
var local_port := 0
var origin := ""
var token := ""
var remote_port := 0
var ready := false
var last_error := ""
var blocked: Array = []
var ping_at := 0

func start(host: String, port: int, cert: X509Certificate, destination: String, blocks: Array = [], common_name: String = "comunicare-relay") -> bool:
	close()
	origin = destination
	blocked = blocks.duplicate()
	if origin in blocked: return false
	link = Link.new()
	if not link.connect_to(host, port, cert, common_name): return false
	socket = PacketPeerUDP.new()
	if socket.bind(0, "127.0.0.1", 128 * 1024) != OK:
		last_error = "Cannot create local gameplay tunnel"
		close()
		return false
	local_port = socket.get_local_port()
	token = Crypto.new().generate_random_bytes(16).hex_encode()
	return true

func poll():
	if link == null: return
	link.poll()
	if not link.last_error.is_empty():
		last_error = link.last_error
		close()
		return
	if link.connected() and ping_at == 0:
		link.send({"op": "tunnel_open", "token": token, "origin": origin, "path": []})
		ping_at = Time.get_ticks_msec() + 2000
	if link.connected() and Time.get_ticks_msec() >= ping_at:
		ping_at = Time.get_ticks_msec() + 2000
		link.send({"op": "tunnel_keepalive", "token": token})
	for message in link.drain():
		if message.get("op") == "challenge": continue
		if message.get("token") != token: continue
		if message.get("op") == "tunnel_ready":
			if not message.get("path") is Array or message.path.is_empty() or message.path.back() != origin: continue
			var allowed = true
			for id in message.path:
				if id in blocked: allowed = false
			if not allowed:
				last_error = "Gameplay route contains blocked relay"
				close()
				return
			ready = true
		elif message.get("op") == "tunnel_data" and ready and remote_port > 0:
			var bytes = _decode(message.get("bytes"))
			if bytes.is_empty(): continue
			socket.set_dest_address("127.0.0.1", remote_port)
			socket.put_packet(bytes)
		elif message.get("op") == "tunnel_error":
			last_error = "Relay gameplay route unavailable or blocked"
			close()
			return
	if socket == null or not ready: return
	for index in 64:
		if socket.get_available_packet_count() == 0: break
		var bytes = socket.get_packet()
		if socket.get_packet_ip() != "127.0.0.1" or bytes.size() > 1500: continue
		if remote_port == 0: remote_port = socket.get_packet_port()
		if socket.get_packet_port() != remote_port: continue
		link.send({"op": "tunnel_data", "token": token, "bytes": Marshalls.raw_to_base64(bytes)})

func _decode(value: Variant) -> PackedByteArray:
	if not value is String or value.length() > 2000: return PackedByteArray()
	var bytes = Marshalls.base64_to_raw(value)
	return bytes if bytes.size() <= 1500 else PackedByteArray()

func close():
	if link != null:
		if link.connected(): link.send({"op": "tunnel_close", "token": token}); link.poll()
		link.close()
	if socket != null: socket.close()
	link = null
	socket = null
	ready = false
	remote_port = 0
	ping_at = 0
