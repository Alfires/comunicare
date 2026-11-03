extends "res://scripts/multiplayer/relay.gd"

var results: Array = []

func send_result(peer_id: int, operation: String, session_id: String, success: bool, message: String, world_url: String = ""):
	results.append({"peer_id": peer_id, "operation": operation, "session_id": session_id,
		"success": success, "message": message, "world_url": world_url})
