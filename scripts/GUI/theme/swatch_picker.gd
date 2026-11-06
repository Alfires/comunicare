extends HFlowContainer
## Row of labelled color swatches backed by an enum setting value.
## Each swatch is one Button whose color chips and caption are recorded directly
## on its canvas item through RenderingServer/TextServer, instead of 5-8 child
## nodes. Changing colors (for example the accent row after a color scheme
## switch) only updates data and redraws; no nodes are rebuilt.

signal value_selected(value: String)

const SWATCH_SIZE := Vector2(104, 72)
const PADDING := 8.0

var value := "":
	set(next):
		value = next
		_sync()
var _buttons: Array = []
var _group := ButtonGroup.new()
var _colors: Dictionary = {}
var _shapes: Dictionary = {}

## options: value → label. colors: value → Array of Colors drawn left to right.
## shapes (optional): value → corner radius; draws one rounded preview tile instead of chips.
func set_options(options: Dictionary, colors: Dictionary, shapes: Dictionary = {}):
	_shapes = shapes.duplicate()
	if _buttons.map(func(button): return button.get_meta("swatch_value")) == options.keys():
		set_colors(colors)
		for button in _buttons:
			button.tooltip_text = str(options[button.get_meta("swatch_value")])
		return
	for button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	_colors = colors.duplicate()
	for key in options:
		var button = Button.new()
		button.theme_type_variation = "Swatch"
		button.toggle_mode = true
		button.button_group = _group
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = SWATCH_SIZE
		button.tooltip_text = str(options[key])
		button.set_meta("swatch_value", key)
		button.draw.connect(_draw_swatch.bind(button))
		button.pressed.connect(_choose.bind(key))
		add_child(button)
		_buttons.append(button)
	_sync()

## Updates swatch colors in place and redraws.
func set_colors(colors: Dictionary):
	_colors = colors.duplicate()
	for button in _buttons:
		button.queue_redraw()

func swatch_buttons() -> Array:
	return _buttons.duplicate()

func _draw_swatch(button: Button):
	var item = button.get_canvas_item()
	var chips: Array = _colors.get(button.get_meta("swatch_value"), [])
	var font: Font = button.get_theme_font("font", "CaptionLabel")
	var font_size: int = button.get_theme_font_size("font_size", "CaptionLabel")
	var caption_height = font.get_height(font_size)
	var strip = Rect2(Vector2(PADDING, PADDING), button.size - Vector2(PADDING * 2, PADDING * 2 + caption_height + 4))
	var key = button.get_meta("swatch_value")
	if _shapes.has(key) and not chips.is_empty() and strip.size.x > 0 and strip.size.y > 0:
		var tile = StyleBoxFlat.new()
		tile.bg_color = chips[0]
		tile.set_corner_radius_all(int(_shapes[key]))
		tile.anti_aliasing = true
		tile.draw(item, strip)
	elif not chips.is_empty() and strip.size.x > 0 and strip.size.y > 0:
		var width = strip.size.x / chips.size()
		for index in chips.size():
			RenderingServer.canvas_item_add_rect(item, Rect2(strip.position + Vector2(width * index, 0), Vector2(width, strip.size.y)), chips[index])
	var line = TextLine.new()
	line.add_string(button.tooltip_text, font, font_size)
	line.width = button.size.x - PADDING * 2
	line.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.draw(item, Vector2(PADDING, button.size.y - PADDING - caption_height), button.get_theme_color("font_color", "CaptionLabel"))

func _choose(key: String):
	if key == value:
		return
	value = key
	value_selected.emit(key)

func _sync():
	for button in _buttons:
		button.set_pressed_no_signal(button.get_meta("swatch_value") == value)
