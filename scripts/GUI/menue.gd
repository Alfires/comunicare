extends TabContainer

func _input(event):
	if event.is_action_pressed("open_menue"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			_reset_menu()
		visible = !visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _reset_menu():
	$home_menue.show()
	$world_explorer.reset.emit()
