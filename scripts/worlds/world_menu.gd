extends Control
## Application-created controls from validated UI data; no downloaded scripts.
signal closed
var runtime: Node
var widgets: Dictionary = {}
var refresh_elapsed := 0.0

func build(owner_runtime: Node, page: Dictionary):
	runtime = owner_runtime
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("blocks_global_shortcuts", true)
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var scroll = ScrollContainer.new()
	panel.add_child(scroll)
	var layout = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)
	var heading = Label.new()
	heading.text = "World menu · " + page.title
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(heading)
	var close = Button.new()
	close.text = "Close world menu"
	close.custom_minimum_size.y = 44
	close.pressed.connect(func(): closed.emit())
	layout.add_child(close)
	for definition in page.widgets:
		var control: Control
		match definition.type:
			"text", "list":
				control = Label.new()
				control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			"progress":
				control = ProgressBar.new()
				control.max_value = definition.get("max", 100)
			"button":
				control = Button.new()
				control.custom_minimum_size.y = 44
				control.pressed.connect(func():
					if not is_instance_valid(runtime) or not runtime.enabled: return
					runtime.dispatch_ui(definition.entity, definition.get("actions", []))
					refresh())
		layout.add_child(control)
		widgets[definition.id] = {"control": control, "definition": definition}
	close.grab_focus()
	refresh()

func refresh():
	if not is_instance_valid(runtime): return
	for widget in widgets.values():
		var definition: Dictionary = widget.definition
		var control: Control = widget.control
		var value = runtime.binding_value(definition.get("bind", ""))
		if definition.type == "progress":
			control.value = float(value) if value is int or value is float else 0.0
		elif definition.type == "list":
			var lines: Array[String] = []
			if value is Array:
				for entry in value.slice(0, 32): lines.append(str(entry).left(256))
			control.text = "\n".join(lines)
		else:
			control.text = str(value).left(2048) if definition.has("bind") else definition.get("text", "")
		if definition.type == "button":
			control.disabled = definition.has("enabled_bind") and runtime.binding_value(definition.enabled_bind) != true

func _process(delta: float):
	refresh_elapsed += delta
	if refresh_elapsed >= 0.1:
		refresh_elapsed = 0
		refresh()
