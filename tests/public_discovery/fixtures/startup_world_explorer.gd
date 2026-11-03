extends "res://scripts/GUI/world_explorer.gd"

var catalog_requested := false
var catalog_callback_ready := false

# Only replace the external request. The real _ready(), _process(), peer
# attachment, scene button wiring and _exit_tree() all execute unchanged.
func _request_catalog() -> void:
	catalog_requested = true
	catalog_callback_ready = http_request.request_completed.is_connected(_on_request_completed)
