extends RayCast3D

func _process(delta):
	if is_colliding():
		var collider = get_collider()
		if collider is VRViewport2D:
			var screen_pos = collider.raycast_to_viewport_point(
				global_position,
				-global_transform.basis.z
			)
			
			# On trigger press:
			var click_event = InputEventMouseButton.new()
			click_event.button_index = MOUSE_BUTTON_LEFT
			click_event.pressed = true
			collider.inject_input(click_event, screen_pos)
