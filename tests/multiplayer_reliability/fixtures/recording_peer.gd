extends RelayPeer
var joins: Array = []
var creates: Array = []

func _init():
	is_connected_to_relay = true
	is_authenticated = true

func join_session(id: String, url: String = "") -> void:
	joins.append(id)
	# Only replace transport. Production on_packet still installs/dispatches result.
	on_packet.call_deferred(SessionResult.create({"operation": "join", "session_id": id,
		"world_url": url, "success": true, "message": ""}).encode())

func create_session(mode: int, title: String, description: String, url: String) -> void:
	creates.append({"mode": mode, "name": title, "description": description, "world_url": url})
