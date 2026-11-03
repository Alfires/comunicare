extends RefCounted
var pressed_before := false

func reset():
	pressed_before = false

func menu_toggle(left_pressed: bool, right_pressed: bool, suppressed: bool) -> bool:
	var pressed = left_pressed or right_pressed
	var rising = pressed and not pressed_before
	pressed_before = pressed
	return rising and not suppressed
