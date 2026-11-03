extends RelayPeer

var sent_joins: Array = []
var sent_creates: Array = []
var accepted := true
var auto_respond := true

func _init():
	is_connected_to_relay = true
	is_authenticated = true

func join_session(id: String, url: String = "") -> void:
	sent_joins.append(id)
	if auto_respond:
		respond.call_deferred("join", id, url)

func create_session(mode: int, name: String, description: String, url: String) -> void:
	sent_creates.append({"mode": mode, "name": name, "description": description, "url": url})
	if auto_respond:
		respond.call_deferred("create", "new-room", url)

func respond(operation: String, id: String, url: String):
	session_result.emit({"operation": operation, "session_id": id,
		"world_url": url, "success": accepted, "message": "Rejected" if not accepted else ""})
