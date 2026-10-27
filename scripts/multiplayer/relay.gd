extends Node

var server := UDPServer.new()
var sessions := []  # [ {"session_id":"IDw21","owners":[],"players": [],"mode":1 }  ]
var peers := []
var key_mapping := []

func _ready() -> void:
	server.listen(7374)

func _process(_delta):
	server.poll()
	if server.is_connection_available():
		var peer = server.take_connection()
		#var packet = peer.get_packet()
		print("Peer connected: %s:%s" % [peer.get_packet_ip(), peer.get_packet_port()])
		peers.append(peer)
	
	for i in peers:
		var packet = i.get_packet()
		if ! packet.is_empty():
			if packet[0] == NetProtocol.CONNECT:
				packet.remove_at(0)
				key_mapping.append([{"peer":i},{"public_key":packet.get_string_from_utf8()}])
			
			elif packet[0] == NetProtocol.CREATE:
				packet.remove_at(0)
				var code = generate_code()
				sessions.append({"session_id":code,"owners":[i],"players":[i],"mode":packet})
				_send(i,NetProtocol.CONNECTED,code.to_utf8_buffer())

			elif packet[0] == NetProtocol.JOIN:
				packet.remove_at(0)
				var idx = get_session_index(packet)
				sessions[idx]["players"].append(i)
				
				

func _send(peer, kind: int, body: PackedByteArray) -> void:
	var p := PackedByteArray()
	p.append(kind)
	p.append_array(body)
	peer.put_packet(p)


# tools 
func generate_code() -> String:
	var characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	var code = ""
	
	for i in range(5):
		code += characters[randi_range(0, characters.length() - 1)]
	
	return code


func get_session_index(session_id: String) -> int:
	for i in range(sessions.size()):
		if sessions[i]["session_id"] == session_id:
			return i
	return -1
