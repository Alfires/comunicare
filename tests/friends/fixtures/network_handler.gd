extends Node
var peer: RelayPeer
var current_session_id := ""
var session_busy := false
var last_session_error := ""
var join_calls: Array = []
var join_result := true

func join_session(id: String, url: String = "") -> bool:
	join_calls.append({"session_id": id, "world_url": url})
	if not join_result:
		last_session_error = "Fixture admission denied"
		return false
	current_session_id = id
	return true
