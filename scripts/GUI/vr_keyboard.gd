extends PanelContainer
## Pointer-operable text editor for the current viewport; never handles secrets globally.
var target: WeakRef
var shifted := false

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -250
	z_index = 200
	set_meta("blocks_global_shortcuts", true)
	var column = VBoxContainer.new()
	add_child(column)
	for row_text in ["1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm", ":/._-?=&@"]:
		var row = HBoxContainer.new()
		column.add_child(row)
		for character in row_text:
			_button(row, character, type_text.bind(character))
	var actions = HBoxContainer.new()
	column.add_child(actions)
	_button(actions, "Shift", func(): shifted = not shifted)
	_button(actions, "Space", type_text.bind(" "))
	_button(actions, "←", func(): _move(-1))
	_button(actions, "→", func(): _move(1))
	_button(actions, "Delete", backspace)
	_button(actions, "Enter", submit)
	_button(actions, "Close", close)
	hide()

func _button(parent: Node, label: String, callback: Callable):
	var button = Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(46, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)

func edit(field: Control):
	if not field is LineEdit and not field is TextEdit: return
	target = weakref(field)
	show()

func _field():
	var field = target.get_ref() if target != null else null
	return field if is_instance_valid(field) and field.is_inside_tree() else null

func type_text(text: String):
	var field = _field()
	if field == null: close(); return
	if field is LineEdit:
		if not field.editable: return
		field.insert_text_at_caret(text.to_upper() if shifted else text)
	elif not field.readonly:
		field.insert_text_at_caret(text.to_upper() if shifted else text)

func backspace():
	var field = _field()
	if field is LineEdit:
		if field.editable: field.delete_char_at_caret()
	elif field is TextEdit and not field.readonly:
		field.backspace()

func _move(direction: int):
	var field = _field()
	if field is LineEdit: field.caret_column = clampi(field.caret_column + direction, 0, field.text.length())

func submit():
	var field = _field()
	if field is LineEdit: field.text_submitted.emit(field.text)
	elif field is TextEdit: type_text("\n")
	close()

func close():
	target = null
	hide()
