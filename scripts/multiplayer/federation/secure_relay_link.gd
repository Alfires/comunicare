extends RefCounted
## Length-framed TLS stream. Remote trust is an explicit certificate, never unsafe TLS.
const MAX_FRAME = 65536
var tcp: StreamPeerTCP
var tls: StreamPeerTLS
var input := PackedByteArray()
var output := PackedByteArray()
var messages: Array = []
var deadline := 0
var last_activity := 0
var last_error := ""
var server_side := false
var started := false
var options: TLSOptions
var hostname := ""

func connect_to(host: String, port: int, certificate: X509Certificate, common_name: String = "comunicare-relay") -> bool:
	if certificate == null or port < 1 or port > 65535: return _fail("Trusted relay certificate and valid port required")
	tcp = StreamPeerTCP.new()
	if tcp.connect_to_host(host, port) != OK: return _fail("Cannot open relay TCP connection")
	options = TLSOptions.client(certificate, common_name)
	hostname = common_name
	deadline = Time.get_ticks_msec() + 10000
	last_activity = Time.get_ticks_msec()
	return true

func accept_connection(stream: StreamPeerTCP, key: CryptoKey, certificate: X509Certificate) -> bool:
	if stream == null or key == null or certificate == null: return _fail("Invalid TLS server configuration")
	tcp = stream
	server_side = true
	options = TLSOptions.server(key, certificate)
	deadline = Time.get_ticks_msec() + 10000
	last_activity = Time.get_ticks_msec()
	return true

func poll():
	if tcp == null or not last_error.is_empty(): return
	tcp.poll()
	if tcp.get_status() == StreamPeerTCP.STATUS_ERROR or tcp.get_status() == StreamPeerTCP.STATUS_NONE:
		_fail("Relay TLS transport closed")
		return
	if not started and Time.get_ticks_msec() > deadline:
		_fail("Relay TCP connection timed out")
		return
	if not started and tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		tls = StreamPeerTLS.new()
		var result = tls.accept_stream(tcp, options) if server_side else tls.connect_to_stream(tcp, hostname, options)
		if result != OK:
			_fail("Cannot start TLS handshake")
			return
		started = true
	if tls == null: return
	tls.poll()
	var status = tls.get_status()
	if status in [StreamPeerTLS.STATUS_ERROR, StreamPeerTLS.STATUS_ERROR_HOSTNAME_MISMATCH, StreamPeerTLS.STATUS_DISCONNECTED]:
		_fail("Relay TLS verification/connection failed")
		return
	if status != StreamPeerTLS.STATUS_CONNECTED:
		if Time.get_ticks_msec() > deadline: _fail("Relay TLS handshake timed out")
		return
	# Work and memory are bounded per poll, independently of peer-provided lengths.
	var available = tls.get_available_bytes()
	if input.size() + available > 2 * MAX_FRAME + 8:
		_fail("Relay input queue exceeded")
		return
	if available > 0:
		var received = tls.get_partial_data(mini(available, MAX_FRAME))
		if received[0] != OK:
			_fail("Relay read failed")
			return
		input.append_array(received[1])
		last_activity = Time.get_ticks_msec()
	for iteration in 16:
		if input.size() < 4: break
		var count = input.decode_u32(0)
		if count == 0 or count > MAX_FRAME:
			_fail("Invalid relay frame length")
			return
		if input.size() < count + 4: break
		if messages.size() >= 64:
			_fail("Relay message queue exceeded")
			return
		var parser = JSON.new()
		if parser.parse(input.slice(4, 4 + count).get_string_from_utf8()) != OK or not parser.data is Dictionary:
			_fail("Invalid relay JSON frame")
			return
		messages.append(parser.data)
		input = input.slice(4 + count)
	if not output.is_empty():
		var sent = tls.put_partial_data(output.slice(0, MAX_FRAME))
		if sent[0] != OK:
			_fail("Relay write failed")
			return
		output = output.slice(int(sent[1]))

func connected() -> bool:
	return last_error.is_empty() and tls != null and tls.get_status() == StreamPeerTLS.STATUS_CONNECTED

func send(value: Dictionary) -> bool:
	var bytes = JSON.stringify(value).to_utf8_buffer()
	if bytes.is_empty() or bytes.size() > MAX_FRAME or output.size() + bytes.size() + 4 > 4 * MAX_FRAME: return _fail("Relay output queue exceeded")
	var header = PackedByteArray()
	header.resize(4)
	header.encode_u32(0, bytes.size())
	output.append_array(header)
	output.append_array(bytes)
	return true

func drain() -> Array:
	var result = messages
	messages = []
	return result

func close():
	if tls != null: tls.disconnect_from_stream()
	if tcp != null: tcp.disconnect_from_host()
	tls = null
	tcp = null
	input.clear()
	output.clear()
	messages.clear()

func _fail(message: String) -> bool:
	last_error = message
	close()
	return false
