extends HFlowContainer
## Row of labelled color swatches backed by an enum setting value.
## Colors are passed in from the palette; nothing is hard-coded here.

signal value_selected(value: String)

var value := "":
	set(next):
		value = next
		_sync()
var _buttons: Array = []
var _group := ButtonGroup.new()

## options: value → label. colors: value → Array of Colors drawn left to right.
func set_options(options: Dictionary, colors: Dictionary):
	for button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	for key in options:
		var button = Button.new()
		button.theme_type_variation = "Swatch"
		button.toggle_mode = true
		button.button_group = _group
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(104, 72)
		button.tooltip_text = str(options[key])
		button.set_meta("swatch_value", key)
		var column = VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		var strip = HBoxContainer.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for color in colors.get(key, []):
			var chip = ColorRect.new()
			chip.color = color
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			strip.add_child(chip)
		column.add_child(strip)
		var label = Label.new()
		label.text = str(options[key])
		label.theme_type_variation = "CaptionLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
		button.add_child(column)
		button.pressed.connect(_choose.bind(key))
		add_child(button)
		_buttons.append(button)
	_sync()

func swatch_buttons() -> Array:
	return _buttons.duplicate()

func _choose(key: String):
	if key == value:
		return
	value = key
	value_selected.emit(key)

func _sync():
	for button in _buttons:
		button.set_pressed_no_signal(button.get_meta("swatch_value") == value)
