extends Node

var server := ENetMultiplayerPeer.new()
var sessions := []  # [ {"session_id":"IDw21","owners":[],"players": [],"mode":1 }  ]
var peers: Dictionary[int,ENetPacketPeer] # peer_id
var key_mapping := []
var availabil_peer_ids: Array = range(255,-1,-1)

signal on_peer_connected(peer_id: int)
signal on_peer_disconnected(peer_id: int)
signal on_packed(peer_id: int, data: PackedByteArray)

var connection: ENetConnection


func _ready() -> void:
	start_relay()
	
func start_relay():
	connection = ENetConnection.new()
	var error = connection.create_host_bound("0.0.0.0",7374)
	if error:
		print("Failed to start relay")
		return
	print("Relay stated")
	

func _process(_delta):
	if connection == null: return
	
	handle_events()
				

func handle_events() -> void:
	var packed_event: Array = connection.service()
	var event_type: ENetConnection.EventType = packed_event[0]
	
	while event_type != ENetConnection.EVENT_NONE:
		var peer: ENetPacketPeer = packed_event[1]
		
		match event_type:
			ENetConnection.EVENT_ERROR:
				push_warning("Package resulted in an unknown error")
				return
				
			ENetConnection.EVENT_CONNECT:
				peer_connected(peer)
				
			ENetConnection.EVENT_DISCONNECT:
				peer_disconnected(peer)
				
			ENetConnection.EVENT_RECEIVE:
				on_packed.emit(peer.get_packet())
				
				
		packed_event = connection.service()
		event_type = packed_event[0]


func peer_connected(peer: ENetPacketPeer):
	var peer_id: int = availabil_peer_ids.pop_back()
	peer.set_meta("id",peer_id)
	peers[peer_id] = peer
	print("Peer connected with assingned id: ",peer_id)
	
	
	
func peer_disconnected(peer: ENetPacketPeer):
	var peer_id: int = peer.get_meta("id")
	availabil_peer_ids.push_back(peer_id)
	peers.erase(peer_id)
	print("Peer disconnected with assingned id: ",peer_id)



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
