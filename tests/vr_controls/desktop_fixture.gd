extends "res://scripts/player/player_desktop_movment.gd"

func _ready():
	set_physics_process(false)
	set_process(false)

func _process(_delta): pass

# Headless display cannot capture a pointer. Exercise all other production gates.
func _movement_blocked() -> bool:
	return not focused or SaveData.voice.input_blocked or NetworkHandler.session_busy \
		or not get_tree().get_nodes_in_group("emote_wheel_input").is_empty()

func _exit_tree(): pass
