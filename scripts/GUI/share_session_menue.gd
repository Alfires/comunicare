extends Control

@onready var session_id: LineEdit = $VBoxContainer/HBoxContainer/session_id
@onready var player_list: VBoxContainer = $VBoxContainer/ScrollContainer/player_list


func _ready() -> void:
	multiplayer.peer_connected.connect(player_connected)
	multiplayer.peer_disconnected.connect(player_disconnected)
	load_id()
	
func player_connected(peer_id):
	create_player_menue("player",peer_id)

func player_disconnected(peer_id):
	var player_node = player_list.find_child(str(peer_id))
	if player_node:
		player_node.queue_free()

func load_id():
	pass
	#while not (NetworkHandler.peer.connected):
	#	await get_tree().process_frame
	#session_id.text = NetworkHandler.peer.

func create_player_menue(player_name: String,peer_id: int):
	var hb = HBoxContainer.new()
	var label = Label.new()
	label.text = player_name+" "+str(peer_id)
	hb.add_child(label)
	if multiplayer.is_server(): 
		var kick = Button.new()
		kick.text = "Kick"
		hb.add_child(kick)
		kick.pressed.connect(Callable(self, "kick_player").bind(peer_id))
	player_list.add_child(hb)

func kick_player(peer_id):
	print("kicked: ", peer_id)
	multiplayer.multiplayer_peer.disconnect_peer(peer_id,true)
	await get_tree().process_frame
	print("Peers after kick: ", multiplayer.get_peers())

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(NetworkHandler.tube_client.session_id)
