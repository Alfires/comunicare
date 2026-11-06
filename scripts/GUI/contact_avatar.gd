extends Control
## Round contact avatar: initial letter on a calm color derived from the account
## fingerprint, plus a presence dot. Drawn as RenderingServer commands on this
## control's canvas item (no child nodes), so long friend lists stay cheap.

const SIZE := 40.0

var display_name := "":
	set(value):
		display_name = value
		queue_redraw()
var fingerprint := "":
	set(value):
		fingerprint = value
		queue_redraw()
## "online", "do_not_disturb", "offline" or "" for no dot (requests, contacts).
var presence := "":
	set(value):
		presence = value
		queue_redraw()

func _init():
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _notification(what: int):
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()

## Stable, muted hue per account; saturation/value stay low to fit every preset.
func base_color() -> Color:
	var hue = float(hash(fingerprint) & 0xffff) / 65535.0
	return Color.from_hsv(hue, 0.32, 0.62)

func _draw():
	var item = get_canvas_item()
	var radius = minf(size.x, size.y) * 0.5
	var center = size * 0.5
	RenderingServer.canvas_item_add_circle(item, center, radius, base_color(), true)
	var letter = display_name.strip_edges().left(1).to_upper()
	if letter.is_empty():
		letter = "?"
	var font: Font = get_theme_font("font", "HeaderLabel")
	var font_size := int(radius)
	var line = TextLine.new()
	line.add_string(letter, font, font_size)
	var text_size = line.get_size()
	line.draw(item, center - text_size * 0.5, get_theme_color("letter", "ContactAvatar"))
	if presence.is_empty():
		return
	var dot_center = center + Vector2(radius, radius) * 0.68
	var row: StyleBox = get_theme_stylebox("panel", "ListRow")
	var ring = row.bg_color if row is StyleBoxFlat else get_theme_color("background", "PreviewStage")
	RenderingServer.canvas_item_add_circle(item, dot_center, radius * 0.3, ring, true)
	RenderingServer.canvas_item_add_circle(item, dot_center, radius * 0.21, get_theme_color(presence, "Presence"), true)
