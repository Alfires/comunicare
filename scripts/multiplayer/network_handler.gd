extends Node

var peer: NodeTunnelPeer
var player_scene = preload("res://scenes/player/remote_player.tscn")
var players = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

@rpc("any_peer", "call_local", "unreliable")
func sync_position(peer_id: int, pos: Vector3):
	# Server relays to all others
	if multiplayer.is_server():
		for peer in multiplayer.get_peers():
			if peer != peer_id:
				sync_position.rpc_id(peer, peer_id, pos)
	else:
		var player_node = find_child(str(peer_id), false, false)
		if player_node:
			player_node.position = pos

func create_session():
	await create_relay_connection()
	var error = peer.host_room(true,"")
	if error:
		print("coud not start room: ",error)
		return error
	print("Hosting room...")
	await peer.room_connected
	print("Connected to room: ", peer.room_id)
	
func _on_peer_connected(peer_id):
	print("Client connected: %d" % peer_id)
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	add_child(player)
	players[peer_id] = player
	#authenticate_user.rpc_id(2, SaveData.keypair.save_to_string(true), peer_id)

func _on_peer_disconnected(peer_id):
	print("Client disconnected: %d" % peer_id)
	if players.has(peer_id):
		players[peer_id].queue_free()
		players.erase(peer_id)
	
# Join Session part
	
func join_session(room_id: String):
	await create_relay_connection()
	var error = peer.join_room(room_id,"SaveData.keypair.save_to_string(true)")
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	

@rpc("call_remote")
func authenticate_user(public_key_pem: String, username: String):
	print("name:",username,public_key_pem)

# usefull functions
func create_relay_connection():
	multiplayer.multiplayer_peer = null
	peer = NodeTunnelPeer.new()
	peer.connect_to_relay("127.0.0.1:7374","comunicare")
	multiplayer.multiplayer_peer = peer
	print("Authenticating")
	await peer.authenticated
	print("Authenticated!")
	
func spawn_player(peer_id: int,player_scene):
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	add_child(player)
	
	# IMPORTANT: Set the owner so peer_id controls it
	player.set_multiplayer_authority(peer_id)
