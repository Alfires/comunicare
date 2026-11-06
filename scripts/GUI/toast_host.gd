extends Control
## Non-blocking notifications at the bottom of the content area
## (docs/roadmaps/gui-tablet-specification.md §4.7). One host per tablet shell;
## pages find it with ToastHost.find_for(self). Toasts never take focus.

const MAX_TOASTS := 3
const DURATIONS = {"info": 4.0, "success": 3.0, "warning": 6.0, "error": 8.0}
const ICONS = {"success": "check", "warning": "warning", "error": "warning", "info": "check"}

var _stack: VBoxContainer

## Nearest host above node (the shell marks itself with the "toast_host" meta).
static func find_for(node: Node) -> Control:
	while node != null:
		if node.has_meta("toast_host"):
			var host = node.get_meta("toast_host")
			return host if is_instance_valid(host) else null
		node = node.get_parent()
	return null

## Shows a toast via the nearest host; falls back to doing nothing outside a shell.
static func notify(from: Node, text: String, kind: String = "info") -> bool:
	var host = find_for(from)
	if host == null:
		return false
	host.show_message(text, kind)
	return true

func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.alignment = BoxContainer.ALIGNMENT_END
	_stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_stack.custom_minimum_size.x = 480
	_stack.offset_bottom = -16
	add_child(_stack)

func visible_toasts() -> Array:
	return _stack.get_children().filter(func(toast): return not toast.is_queued_for_deletion())

func show_message(text: String, kind: String = "info", seconds: float = -1.0) -> Control:
	if not DURATIONS.has(kind):
		kind = "info"
	while visible_toasts().size() >= MAX_TOASTS:
		var oldest: Control = visible_toasts()[0]
		_stack.remove_child(oldest)
		oldest.queue_free()
	var toast = PanelContainer.new()
	toast.theme_type_variation = "Toast"
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.focus_mode = Control.FOCUS_NONE
	toast.set_meta("kind", kind)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(row)
	var bar = ColorRect.new()
	bar.custom_minimum_size = Vector2(4, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = get_theme_color(kind, "Toast")
	row.add_child(bar)
	var icon = TextureRect.new()
	icon.texture = load("res://themes/icons/%s.svg" % ICONS[kind])
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = bar.color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	_stack.add_child(toast)
	var duration = seconds if seconds > 0 else DURATIONS[kind]
	# Bound to this host, so the connection disappears if the host is freed first.
	get_tree().create_timer(duration).timeout.connect(_expire.bind(weakref(toast)))
	return toast

func _expire(reference: WeakRef):
	var toast = reference.get_ref()
	if is_instance_valid(toast) and toast.get_parent() == _stack:
		_stack.remove_child(toast)
		toast.queue_free()
