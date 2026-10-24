extends Node

var peer: NodeTunnelPeer
var players = []

func _ready() -> void:
	peer = NodeTunnelPeer.new()
	peer.connect_to_relay("127.0.0.1:7374","comunicare")
	multiplayer.multiplayer_peer = peer
	print("Authenticating")
	await peer.authenticated
	print("Authenticated!")

func create_session():
	await peer.authenticated
	var error = peer.host_room(true,"alai")
	if error:
		print("coud not start room: ",error)
		return error
	print("Hosting room...")
	await peer.room_connected
	print("Connected to room: ", peer.room_id)
	
func _on_peer_connected(peer_id):
	print("Client connected: %d" % peer_id)

func _on_peer_disconnected(peer_id):
	print("Client disconnected: %d" % peer_id)
	
	
# Join Session part


func join_session(room_id: String):
	var error = peer.join_room(room_id,"SaveData.keypair.save_to_string(true)")
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	
func _on_connected():
	# Send your user ID and public key to server
	authenticate_user.rpc_id(2, SaveData.keypair.save_to_string(true), "test")

@rpc("call_remote")
func authenticate_user(public_key_pem: String, username: String):
	print("name:",username,public_key_pem)	
