extends Node

var server := ENetMultiplayerPeer.new()
var sessions := []  # [ {"session_id":"IDw21","owners":[],"peers": [],"mode":1 }  ]
var peers: Dictionary[int,ENetPacketPeer] # peer_id
var key_mapping := []
var availabil_peer_ids: Array = range(255,-1,-1)

var connection: ENetConnection


func _ready() -> void:
	start_relay()
	
func start_relay():
	connection = ENetConnection.new()
	var error = connection.create_host_bound("0.0.0.0", 7374)
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
				on_packed(peer.get_meta("id"),peer.get_packet())
				
				
		packed_event = connection.service()
		event_type = packed_event[0]


func peer_connected(peer: ENetPacketPeer):
	var peer_id: int = availabil_peer_ids.pop_back()
	peer.set_meta("id",peer_id)
	peers[peer_id] = peer
	print("Peer connected with assingned id: ",peer_id)
	if sessions.size() > 0:
		var current_peers = sessions[0][0]["peers"]
		if not current_peers.has(peer_id):
			current_peers.append(peer_id)
			sessions[0][0]["peers"] = current_peers
	
	
func peer_disconnected(peer: ENetPacketPeer):
	var peer_id: int = peer.get_meta("id")
	availabil_peer_ids.push_back(peer_id)
	peers.erase(peer_id)
	print("Peer disconnected with assingned id: ",peer_id)

	var affected_sessions: Array[int] = []
	for i in range(sessions.size()):
		var session_peers: Array = sessions[i][0]["peers"]
		if peer_id in session_peers:
			session_peers.erase(peer_id)
			affected_sessions.append(i)
			if session_peers.is_empty():
				sessions.remove_at(i)
				# adjust indices of later affected sessions
				for j in range(affected_sessions.size()):
					if affected_sessions[j] > i:
						affected_sessions[j] -= 1

	for i in affected_sessions:
		if i >= sessions.size():
			continue
		var session_peers: Array = sessions[i][0]["peers"]
		for p in session_peers:
			if peers.has(p):
				GetSessionPeers.create(session_peers.duplicate()).sent(peers[p])


func on_packed(peer_id: int, data: PackedByteArray):
	var packed_type: int = data.decode_u8(0)
	match packed_type:
		PacketInfo.PACKET_TYPE.CREATE_SESSION:
			var session = CreateSession.create_from_data(data)
			sessions.append([{
				"session_id":generate_code(),
				"owners":[peer_id],
				"peers": [peer_id],
				"mode":session.mode
				}])
			print("session created: ",peer_id)
			print(sessions)
				
		PacketInfo.PACKET_TYPE.JOIN_SESSOIN:
			var join_data: JoinSession = JoinSession.create_from_data(data)
			var user_session: int = get_user_in_session(peer_id) 
			if user_session != -1:
				remove_user_from_session(peer_id,user_session)
			var session_index = get_session_index(join_data.session_id)
			if session_index == -1:
				return
			
			sessions[session_index][0]["peers"].append(peer_id)
			
			var session_peers = sessions[session_index][0]["peers"]
			#session_peers.erase(peer)
			for peer in sessions[session_index][0]["peers"]:
				GetSessionPeers.create(session_peers).sent(peers[peer])
					
		
		PacketInfo.PACKET_TYPE.GET_SESSION_PEERS:
			var user_session = get_user_in_session(peer_id)
			if user_session == -1:
				return
			var session_peers = sessions[user_session][0]["peers"]
			GetSessionPeers.create(session_peers).sent(peers[peer_id])
		
		PacketInfo.PACKET_TYPE.PLAYER_DATA:
			var user_session = get_user_in_session(peer_id)
			if user_session == -1: return
			for peer in sessions[user_session][0]["peers"]:
				if peer != peer_id:
					var user_pose = PlayerData.create_from_data(data)
					PlayerData.create(peer_id,user_pose.possition).sent(peers[peer])
		
		
		_:
			push_error("Packed type was unknown: ",packed_type)

# tools 

func remove_user_from_session(peer_id: int, session_index: int):
	sessions[session_index][0]["peers"].erase(peer_id)
	if sessions[session_index][0]["peers"].size() == 0:
		sessions.remove_at(session_index)


func generate_code() -> String:
	var characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	var code = ""
	
	for i in range(5):
		code += characters[randi_range(0, characters.length() - 1)]
	
	return code

## Gets the session index position in the session aray when you the session id. 
func get_session_index(session_id: String) -> int:
	for i in range(sessions.size()):
		var session = sessions[i][0]
		if session["session_id"] == session_id:
			return i
	return -1


## Get a useer from a session
func get_user_in_session(peer_id: int) -> int:
	for i in range(sessions.size()):
		if peer_id in sessions[i][0]["peers"]:
			return i
	return -1
