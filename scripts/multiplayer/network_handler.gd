extends Node

var peer: NodeTunnelPeer
var player_scene = preload("res://scenes/player/remote_player.tscn")
var players = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

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
	

func _on_peer_disconnected(peer_id):
	print("Client disconnected: %d" % peer_id)
	if players.has(peer_id):
		players[peer_id].queue_free()
		players.erase(peer_id)
	
# Join Session part / Client 

# model requester
@rpc("any_peer","call_local","unreliable")
func request_player_model():
	var peer_id = multiplayer.get_remote_sender_id()
	rpc_id(peer_id, "sync_player_avatar", SaveData.data["avatar_url"])


# model loader sync
@rpc("any_peer", "call_remote", "unreliable")
func sync_player_avatar(avatar_url: String):
	var peer_id = multiplayer.get_remote_sender_id()
	print("client received avatar...")
	var player_node = find_child(str(peer_id), false, false)
	if player_node:
		print("loding model...")
		player_node.load_player_model(avatar_url)
	else:
		print("peer was not found in local players")

# player movement
@rpc("any_peer", "call_remote", "unreliable")
func sync_player_data(pos: Vector3,rotation: Vector3):
	var peer_id = multiplayer.get_remote_sender_id()
	# Server relays to all others
	var player_node = find_child(str(peer_id), false, false)
	if player_node:
		player_node.position = pos
		player_node.rotation = rotation

# player voice
@rpc("any_peer", "call_remote", "unreliable")
func sync_player_voice(data: PackedByteArray):
	# Server relays to all others
	var peer_id = multiplayer.get_remote_sender_id()
	print("peer: ",peer_id)
	if peer_id == peer.get_unique_id(): return
	var player_node = find_child(str(peer_id), false, false)
	print(player_node)
	if player_node:
		player_node.play_audio(data)


func join_session(room_id: String):
	if room_id == peer.room_id: return
	await create_relay_connection()
	var error = peer.join_room(room_id,"SaveData.keypair.save_to_string(true)")
	if error:
		return error
	multiplayer.multiplayer_peer = peer


func _on_connected_to_server():
	print("Connected to server!")
	print("sending user avatar")
	
func _on_peer_connected(peer_id):
	print("Client connected: %d" % peer_id)
	# create Player :)
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.user_name = str(peer_id)
	add_child(player)
	rpc_id(peer_id, "request_player_model")
	
	#authenticate_user.rpc_id(2, SaveData.keypair.save_to_string(true), peer_id)

# usefull functions
func create_relay_connection():
	multiplayer.multiplayer_peer = null
	peer = NodeTunnelPeer.new()
	peer.connect_to_relay("147.185.221.216:32649","comunicare")
	multiplayer.multiplayer_peer = peer
	print("Authenticating")
	await peer.authenticated
	print("Authenticated!")
	
