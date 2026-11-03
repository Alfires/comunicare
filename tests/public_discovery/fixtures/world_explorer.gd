extends "res://scripts/GUI/world_explorer.gd"

# Keep the real scene, rendering, callbacks and onready references, but suppress
# automatic HTTP/ENet startup. Tests deliver snapshots through load_sessions().
func _ready() -> void:
	pass
