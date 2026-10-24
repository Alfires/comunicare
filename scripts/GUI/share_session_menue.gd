extends Control

@onready var session_id: LineEdit = $VBoxContainer/HBoxContainer/session_id


func _ready() -> void:
	await NetworkHandler.peer.room_connected
	session_id.text = NetworkHandler.peer.room_id



func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(NetworkHandler.peer.room_id)
