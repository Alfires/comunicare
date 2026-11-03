extends Node

var peer
var current_session_id := ""
var session_busy := false
var controller: Node

func get_animation_controller() -> Node:
	if controller == null:
		controller = preload("res://scripts/assets/animation_controller.gd").new()
		add_child(controller)
		controller.configure(self, get_node("/root/DataLoader"))
	return controller
