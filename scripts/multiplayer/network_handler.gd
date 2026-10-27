extends Node

var peer: RelayPeer
var player_scene = preload("res://scenes/player/remote_player.tscn")
var players = {}
var relay= "localhost"

func _ready() -> void:
	if "--relay" in OS.get_cmdline_args(): 
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	
func _process(_delta):
	if "--relay" in OS.get_cmdline_args(): return
	print(peer.get_available_packet_count())
	if peer.get_available_packet_count() > 0:
		var array_bytes = peer.get_packet()
		print(array_bytes)
	
	
func create_peer():
	peer = RelayPeer.new()
	peer.connect_to_relay()
	

func create_session():
	print("Hosting room...")
	peer.create_session(Modes.PRIVAT)
	multiplayer.multiplayer_peer = peer
	print("Connected to room: ", peer.get_unique_id())

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
func sync_player_voice(data: PackedFloat32Array): #PackedFloat32Array
	# Server relays to all others
	var peer_id = multiplayer.get_remote_sender_id()
	print("peer: ",peer_id)
	if peer_id == peer.get_unique_id(): return
	var player_node = find_child(str(peer_id), false, false)
	print(player_node)
	if player_node:
		player_node._buffer_audio(data)


func join_session(session_id: String):
	
	#if session_id == peer: return
	print("connection...")
	peer.error_raised.connect(_on_join_error)
	
	peer.join_session(session_id)
	
	# Use yield with the node, not the signal directly
	await peer.connected_to_server
	print("session joined")
	

func _on_join_error(code, message) -> void:
	push_error("Join error %s: %s" % [code, message])

func _on_connected_to_server():
	print("Connected to server!")
	print("sending user avatar")
	
func _on_peer_connected(peer_id):
	if peer_id == 1: return
	print("Client connected: %d" % peer_id)
	# create Player :)
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.user_name = str(peer_id)
	add_child(player)
	rpc_id(peer_id, "request_player_model")
	
