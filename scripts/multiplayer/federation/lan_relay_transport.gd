extends RefCounted
## Local-interface multicast hints only. Advertisements never authorize login/routes.
const Model = preload("res://scripts/multiplayer/federation/lan_relay_discovery.gd")
const GROUP = "239.255.73.74"
const PORT = 37374
var socket: PacketPeerUDP
var model = Model.new()
var advertisement: Dictionary = {}
var interfaces: Array = []
var next_send := 0
var last_error := ""

func start(enabled: bool, blocked: Array = [], announcement: Dictionary = {}, port: int = PORT, group: String = GROUP) -> bool:
	stop()
	model.configure({"enabled": enabled}, blocked)
	if not enabled: return true
	socket = PacketPeerUDP.new()
	if socket.bind(port, "0.0.0.0", 64 * 1024) != OK:
		last_error = "Cannot bind LAN relay discovery socket (another process or firewall may own it)"
		socket = null
		return false
	for interface in IP.get_local_interfaces():
		var name: String = interface.get("name", "")
		if name.is_empty(): continue
		if socket.join_multicast_group(group, name) == OK: interfaces.append({"group": group, "name": name})
	advertisement = announcement.duplicate(true)
	socket.set_dest_address(group, port)
	next_send = 0
	return true

func poll():
	if socket == null: return
	var now = Time.get_ticks_msec()
	for index in 32:
		if socket.get_available_packet_count() == 0: break
		var bytes = socket.get_packet()
		var source = socket.get_packet_ip()
		# Source IP is authoritative for local addressing; ads need no knowledge
		# of which LAN interface was used to send them.
		if bytes.size() > 1024: continue
		var parser = JSON.new()
		if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary: continue
		var value: Dictionary = parser.data
		if value.get("host") == "source": value.host = source
		model.observe(JSON.stringify(value).to_utf8_buffer(), source, now)
	model.expire(now)
	if not advertisement.is_empty() and now >= next_send:
		next_send = now + 3000
		var bytes = JSON.stringify(advertisement).to_utf8_buffer()
		if bytes.size() <= 1024: socket.put_packet(bytes)

func stop():
	if socket != null:
		for interface in interfaces: socket.leave_multicast_group(interface.group, interface.name)
		socket.close()
	socket = null
	interfaces.clear()
	advertisement.clear()
