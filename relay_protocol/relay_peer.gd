class_name RelayPeer
extends MultiplayerPeerExtension

var udp := PacketPeerUDP.new()
var uid := 0
var target := 0
var queue := []
var last := 0
var world := ""
var is_connected = false

var relay_ip = "127.0.0.1"
var relay_port = 7374


func connect_to_relay():
	var public_key = SaveData.key.save_to_string(true)
	udp.bind(0)
	udp.connect_to_host(relay_ip, relay_port)
	if ! udp.is_socket_connected():
		printerr("coud not connect to relay")
		return
	print("connected to relay")
	var p := PackedByteArray([])
	#udp.put_packet(p)
	p.append_array(public_key.to_utf8_buffer())
	_send(NetProtocol.CONNECT, p)

func create_session(join_mode) -> void:
	var p := PackedByteArray([])
	p.append(join_mode)
	_send(NetProtocol.CREATE, p)

func join_session(code: String) -> void:
	var p := PackedByteArray([NetProtocol.JOIN,code])
	_send(NetProtocol.JOIN, p)

	
func _send(kind: int, body: PackedByteArray) -> void:
	var p := PackedByteArray()
	p.append(kind)
	p.append_array(body)
	udp.put_packet(p)

func _send_to_peer(to: int, kind: int, body: PackedByteArray) -> void:
	var p := PackedByteArray()
	p.encode_u16(7, to)
	p.append(kind)
	p.append_array(body)
	udp.put_packet(p)

func _poll() -> void:
	while udp.get_available_packet_count() > 0:
		var p := udp.get_packet()
		print(p)
		print(p.decode_u16(0))
		if p.size() < NetProtocol.HEADER:
			continue
		var body := p.slice(NetProtocol.HEADER)
		if body.is_empty():
			continue
		if p[9] == NetProtocol.CONTROL:
			if body[0] == NetProtocol.CONNECTED:
				uid = body.decode_u16(1)
		else:
			queue.append([p.decode_u16(5), body])
