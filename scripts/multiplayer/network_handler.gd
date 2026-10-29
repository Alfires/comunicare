extends Node

var peer: RelayPeer
var player_scene = preload("res://scenes/player/remote_player.tscn")
var players = {}
var relay_ip := "127.0.0.1"
var relay_port := 7374

var id: int = -1
var remote_ids: Array[int]

func _ready() -> void:
	if "--relay" in OS.get_cmdline_args(): 
		return

func _process(_delta):
	if peer == null or peer.connection == null: return
	
	peer.handle_events()


func create_peer():
	peer = RelayPeer.new()
	peer.connect_to_relay(relay_ip,relay_port)
	await peer.connected
	peer.player_data.connect(sync_player_data)
	peer.on_session_peers_update.connect(update_connected_peers)
	
func create_session():
	print("Hosting room...")
	peer.create_session(PacketInfo.MODE.PRIVAT)
	#print("Connected to room: ", peer.get_unique_id())

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
func sync_player_data(data: PlayerData):#,rotation: Vector3):
	# Server relays to all others
	var player_node = find_child(str(data.id), false, false)
	if player_node:
		player_node.position = data.possition
		#player_node.rotation = rotation

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
	
	peer.join_session(session_id)
	
	# Use yield with the node, not the signal directly
	#await peer.connected_to_session
	print("session joined")
	
func _on_join_error(code, message) -> void:
	push_error("Join error %s: %s" % [code, message])

func _on_connected_to_server():
	print("Connected to server!")
	print("sending user avatar")
	
func update_connected_peers():
	print("updating peers")
	for child in get_children():
		var peer_id = int(child.name) 
		if peer_id not in peer.session_peers:
			child.queue_free()
	
	for peer_id in peer.session_peers:
		if str(peer_id) not in get_children():
			var player = player_scene.instantiate()
			player.name = str(peer_id)
			player.user_name = str(peer_id)
			add_child(player)
