extends Node

var peer = RelayPeer.new()
var joined: Array = []
var created: int = 0
var last_session_error := ""
var current_session_id := ""

func join_session(session_id: String, world_url: String = "") -> bool:
	joined.append(session_id)
	await DataLoader.load_world_from_url(world_url)
	return true

func create_session():
	created += 1

func reset():
	current_session_id = ""
	joined.clear()
	created = 0
