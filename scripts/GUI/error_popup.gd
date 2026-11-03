extends Control

var message_label: Label
var accept_button: Button
var previous_focus: WeakRef

static func show_error(parent: Node, message: String) -> Control:
	var popup = parent.get_node_or_null("ErrorPopup")
	if popup == null:
		popup = load("res://scripts/GUI/error_popup.gd").new()
		popup.name = "ErrorPopup"
		parent.add_child(popup)
	popup.present(message)
	return popup

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	set_meta("blocks_global_shortcuts", true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	center.add_child(panel)
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title = Label.new()
	title.text = "Error"
	column.add_child(title)
	message_label = Label.new()
	message_label.custom_minimum_size.x = 240
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message_label)
	accept_button = Button.new()
	accept_button.text = "OK"
	accept_button.custom_minimum_size.y = 44
	accept_button.pressed.connect(dismiss)
	column.add_child(accept_button)
	hide()

func present(message: String):
	if not visible:
		var focus = get_viewport().gui_get_focus_owner()
		previous_focus = weakref(focus) if focus != null else null
	message_label.text = message if not message.is_empty() else "The operation failed. Please try again."
	show()
	accept_button.grab_focus()

func dismiss():
	hide()
	if previous_focus != null:
		var focus = previous_focus.get_ref()
		if is_instance_valid(focus) and focus is Control and focus.is_visible_in_tree():
			focus.grab_focus()
	previous_focus = null

func _input(event: InputEvent):
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		# Modal keyboard handling: don't let V or gameplay shortcuts escape.
		if event.is_action_pressed("ui_accept"):
			dismiss()
		get_viewport().set_input_as_handled()
