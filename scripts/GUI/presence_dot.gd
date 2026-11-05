extends Control
## Small status dot; color comes from the theme's Presence colors.

var state := "online":
	set(value):
		state = value
		queue_redraw()

func _notification(what: int):
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()

func _draw():
	draw_circle(size * 0.5, minf(5.0, minf(size.x, size.y) * 0.5), get_theme_color(state, "Presence"), true, -1.0, true)
