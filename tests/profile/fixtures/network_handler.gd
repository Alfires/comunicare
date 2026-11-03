extends Node
signal active_instance_changed
signal participants_changed
signal instance_management_finished(result: Dictionary)
var active_instance: Dictionary = {}
var management_pending: Dictionary = {}
var instance_status := ""

func refresh_instance():
	pass

func is_instance_admin() -> bool:
	return false

var peer: RelayPeer
var current_session_id := ""
var session_busy := false
var last_session_error := ""
