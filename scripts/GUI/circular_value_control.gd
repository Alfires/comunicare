extends RefCounted
## Reusable scalar dial, independent of mirror, wheel, settings or networking.
var title := "Value"
var value := 0.0
var minimum := 0.0
var maximum := 1.0
var step := 0.01
var unit := ""
var callback: Callable

func configure(label: String, initial: float, low: float, high: float, increment: float, suffix: String, changed: Callable):
	title = label
	minimum = low
	maximum = maxf(low, high)
	step = maxf(increment, 0.0001)
	unit = suffix
	value = clampf(initial, minimum, maximum)
	callback = changed

func set_fraction(fraction: float):
	if not is_finite(fraction): return
	value = clampf(snappedf(lerpf(minimum, maximum, clampf(fraction, 0, 1)), step), minimum, maximum)
	if callback.is_valid(): callback.call(value)

func fraction() -> float:
	return inverse_lerp(minimum, maximum, value) if maximum > minimum else 0.0

func draw_on(canvas: Control, center: Vector2, radius: float):
	var ring = radius * 0.8
	var font = canvas.get_theme_default_font()
	var text = canvas.get_theme_color("label", "CircularValue")
	canvas.draw_circle(center, radius, canvas.get_theme_color("background", "CircularValue"))
	canvas.draw_arc(center, ring, -PI * 0.5, PI * 1.5, 96, canvas.get_theme_color("track", "CircularValue"), 10, true)
	canvas.draw_circle(center + Vector2.from_angle(-PI * 0.5 + fraction() * TAU) * ring, 16, canvas.get_theme_color("knob", "CircularValue"))
	canvas.draw_string(font, center + Vector2(-ring * 0.7, -30), "%s: %.2f %s" % [title, value, unit], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, text)
	canvas.draw_string(font, center + Vector2(-ring * 0.65, 4), "Drag around the ring", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text)
	canvas.draw_string(font, center + Vector2(-35, 35), "Back", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, text)
