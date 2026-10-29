class_name RelayPeer

var relay := ENetMultiplayerPeer.new()

var peer: ENetPacketPeer

## The connection of the connected relay. Of type ENetConnection.
var connection: ENetConnection
var session_peers: Array

signal on_connected_to_relay()
signal on_disconnected_from_relay()
signal on_packed(data: PackedByteArray)
signal connected()
signal player_data()
signal on_session_peers_update()

func connect_to_relay(relay_ip: String,relay_port: int):
	var public_key = SaveData.key.save_to_string(true)
	connection = ENetConnection.new()
	var error: Error = connection.create_host(1)
	if error:
		print("Failed to connect")
	peer = connection.connect_to_host(relay_ip,relay_port)


func create_session(join_mode) -> void:
	print("data sent")
	CreateSession.create(join_mode).sent(peer)

func join_session(session_id: String) -> void:
	JoinSession.create(session_id).sent(peer)
	
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
				on_packet(_peer.get_packet())
				
				
		packed_event = connection.service()
		event_type = packed_event[0]

func connected_to_relay():
	print("connected to relay")
	connected.emit()
	
	
func disconnected_from_relay():
	on_disconnected_from_relay.emit()
	
func on_packet(data: PackedByteArray):
	var packet_type: int = data.decode_u8(0)
	
	match packet_type:
		PacketInfo.PACKET_TYPE.ID_ASSINGMENT:
			pass
		#	manage_ids(IDAssingnment.create_from_data(data)) 
	
		PacketInfo.PACKET_TYPE.PLAYER_DATA:
			player_data.emit(PlayerData.create_from_data(data))
			
		PacketInfo.PACKET_TYPE.GET_SESSION_PEERS:
			session_peers = GetSessionPeers.create_from_data(data).peers
			print("Session list updated new list is:",session_peers)
			on_session_peers_update.emit()
		_:
			push_error("Packed type with index ",data[0]," unhandled!")
