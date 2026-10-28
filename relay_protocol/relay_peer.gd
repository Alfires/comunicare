class_name RelayPeer

var relay := ENetMultiplayerPeer.new()

var peer: ENetPacketPeer

var connection: ENetConnection


signal on_connected_to_relay()
signal on_disconnected_from_relay()
signal on_packed(data: PackedByteArray)

func connect_to_relay(relay_ip: String,relay_port: int):
	var public_key = SaveData.key.save_to_string(true)
	connection = ENetConnection.new()
	var error: Error = connection.create_host(1)
	if error:
		print("Failed to connect")
	peer = connection.connect_to_host(relay_ip,relay_port)
	print("connected to server")


func create_session(join_mode) -> void:
	pass
	#var p := PackedByteArray([])
	#p.append(join_mode)

func join_session(code: String) -> void:
	pass
	#var p := PackedByteArray([PacketInfo.PACKET_TYPE,code])
	
func handle_events() -> void:
	var packed_event: Array = connection.service()
	var event_type: ENetConnection.EventType = packed_event[0]
	
	while event_type != ENetConnection.EVENT_NONE:
		var _peer: ENetPacketPeer = packed_event[1]
		
		match event_type:
			ENetConnection.EVENT_ERROR:
				push_warning("Package resulted in an unknown error")
				return
				
			ENetConnection.EVENT_CONNECT:
				connected_to_relay()
				
			ENetConnection.EVENT_DISCONNECT:
				disconnected_from_relay()
				
			ENetConnection.EVENT_RECEIVE:
				on_packed.emit(_peer.get_packet())
				
				
		packed_event = connection.service()
		event_type = packed_event[0]

func connected_to_relay():
	on_connected_to_relay.emit()

func disconnected_from_relay():
	on_disconnected_from_relay.emit()
