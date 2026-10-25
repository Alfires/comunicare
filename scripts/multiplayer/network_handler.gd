extends Node

var peer: NodeTunnelPeer
var player_scene = preload("res://scenes/player/remote_player.tscn")
var players = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


@rpc("any_peer", "call_local", "unreliable")
func sent_player_data_to_server( pos: Vector3,rotation: Vector3):
	if multiplayer.is_server():
		var peer_id = multiplayer.get_remote_sender_id()
		for player_peer in multiplayer.get_peers():
			sync_player_data.rpc_id(player_peer, peer_id, pos,rotation)
		sync_player_data(peer_id,pos,rotation)
		

@rpc("any_peer", "reliable")
func sent_audio_to_server(data: PackedByteArray):
	if multiplayer.is_server():
		var sender = multiplayer.get_remote_sender_id()
		for player_peer in multiplayer.get_peers():
			if sender != player_peer:
				sync_player_voice.rpc_id(player_peer, sender, data)

func create_session():
	await create_relay_connection()
	var error = peer.host_room(true,"")
	if error:
		print("coud not start room: ",error)
		return error
	print("Hosting room...")
	await peer.room_connected
	print("Connected to room: ", peer.room_id)
	peer.join_validation = func(join_metadata) -> bool:
	# 1. very if user is alowed to join (not setuped jet) #nosetup
	# 2. get players metadata an save it in players
		print(join_metadata)
		return true
	
func _on_peer_connected(peer_id):
	print("Client connected: %d" % peer_id)
	# create Player :)
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.user_name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	add_child(player)
	players[peer_id] = player
	player.set_multiplayer_authority(peer_id)
	#authenticate_user.rpc_id(2, SaveData.keypair.save_to_string(true), peer_id)


func _on_peer_disconnected(peer_id):
	print("Client disconnected: %d" % peer_id)
	if players.has(peer_id):
		players[peer_id].queue_free()
		players.erase(peer_id)
	
# Join Session part / Client

# player movement
@rpc("any_peer", "call_local", "reliable")
func sync_player_data(peer_id: int, pos: Vector3,rotation: Vector3):
	# Server relays to all others
	var player_node = find_child(str(peer_id), false, false)
	if player_node:
		player_node.position = pos
		player_node.rotation = rotation

# player voice
@rpc("any_peer", "unreliable")
func sync_player_voice(peer_id: int, data: PackedByteArray):
	# Server relays to all others
	var player_node = find_child(str(peer_id), false, false)
	if player_node:
		var audio = data.to_float32_array()
		player_node.play_audio(audio)


func join_session(room_id: String):
	if room_id == peer.room_id: return
	await create_relay_connection()
	var error = peer.join_room(room_id,"SaveData.keypair.save_to_string(true)")
	if error:
		return error
	multiplayer.multiplayer_peer = peer

# usefull functions
func create_relay_connection():
	multiplayer.multiplayer_peer = null
	peer = NodeTunnelPeer.new()
	peer.connect_to_relay("127.0.0.1:7374","comunicare")
	multiplayer.multiplayer_peer = peer
	print("Authenticating")
	await peer.authenticated
	print("Authenticated!")
	
