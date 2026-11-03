extends TabContainer

func _ready():
	# TabContainer adds theme padding outside the Home page. Remove only the
	# right content inset so its microphone button meets the menu's outer edge.
	var panel = get_theme_stylebox("panel").duplicate()
	panel.content_margin_right = 0.0
	panel.content_margin_left = 0.0
	add_theme_stylebox_override("panel", panel)

func _input(event):
	if event.is_action_pressed("open_menue"):
		if get_viewport().gui_get_focus_owner() != null and get_viewport().gui_get_focus_owner().get_meta("blocks_global_shortcuts", false):
			return
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			_reset_menu()
		visible = !visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _reset_menu():
	$home_menue.reset_home()
	$world_explorer.reset.emit()
