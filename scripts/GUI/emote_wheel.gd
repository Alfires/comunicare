extends Control
## Shared eight-sector renderer; desktop, viewport pointer and hand-local XR.

signal emote_selected(id: String)
signal closed
signal navigated
var layout
var catalog: Dictionary = {}
var group := "root"
var page := 0
var history: Array = []
var hovered := -1
var entries: Array = []
var message := ""
var old_mouse_mode := Input.MOUSE_MODE_VISIBLE
var old_focus: WeakRef
var capture_mouse := true
var input_owned := false
var inner := 0.28

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_meta("blocks_global_shortcuts", true)
	visibility_changed.connect(func():
		if not visible: hovered = -1)
	refresh()

func open(wheel_layout, actions: Dictionary, mouse: bool = true):
	layout = wheel_layout
	catalog = actions
	group = "root"
	page = 0
	history.clear()
	message = ""
	capture_mouse = mouse
	var save = get_node_or_null("/root/SaveData")
	if save != null and save.get("store") != null:
		var value = save.store.get_value("interface.emote_dead_zone")
		if value != null: inner = float(value)
	old_mouse_mode = Input.mouse_mode
	var focus = get_viewport().gui_get_focus_owner()
	old_focus = weakref(focus) if focus != null else null
	if mouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	input_owned = true
	show()
	grab_focus()
	refresh()

func radius() -> float:
	return maxf(80, minf(size.x, size.y) * 0.46)

func refresh():
	if layout == null:
		return
	if not layout.groups.has(group):
		group = "root"
		page = 0
		history.clear()
	page = clampi(page, 0, layout.page_count(group) - 1)
	entries = layout.sectors(group, page)
	for entry in entries:
		if entry.type == "emote" and not catalog.has(entry.id):
			entry.disabled = true
			entry.name += "\nUnavailable"
	hovered = -1
	queue_redraw()

func select_direction(direction: Vector2):
	var length = direction.length()
	if length < inner or length > 1.25:
		hovered = -1
	else:
		var angle = fposmod(direction.angle() + PI * 0.5, TAU)
		var candidate = int(floor((angle + PI / 8) / (PI / 4))) % 8
		if hovered >= 0 and candidate != hovered:
			var center_angle = hovered * PI / 4
			if absf(wrapf(angle - center_angle, -PI, PI)) < PI / 8 + 0.06:
				candidate = hovered
		hovered = candidate
	queue_redraw()

func activate_sector(index: int) -> bool:
	if index < 0 or index >= entries.size():
		return false
	var entry: Dictionary = entries[index]
	if entry.get("disabled", false):
		return false
	match entry.type:
		"emote":
			emote_selected.emit(entry.id)
			return true
		"group":
			history.append({"group": group, "page": page, "sector": index})
			group = entry.id
			page = 0
		"next": page += 1
		"previous": page -= 1
		_: return false
	refresh()
	navigated.emit()
	return false

func back():
	if history.is_empty():
		dismiss()
	else:
		var parent: Dictionary = history.pop_back()
		group = parent.group
		page = parent.page
		refresh()
		hovered = parent.sector
		queue_redraw()
		navigated.emit()

func dismiss():
	hide()
	_restore_input()
	closed.emit()

func _restore_input():
	if not input_owned: return
	input_owned = false
	if capture_mouse:
		Input.mouse_mode = old_mouse_mode
	if old_focus != null and is_instance_valid(old_focus.get_ref()):
		var focus = old_focus.get_ref()
		if focus.is_inside_tree() and focus.is_visible_in_tree(): focus.grab_focus()

func _exit_tree():
	_restore_input()

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and visible:
		dismiss()

func _gui_input(event: InputEvent):
	if event is InputEventMouseMotion:
		select_direction((event.position - size * 0.5) / radius())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select_direction((event.position - size * 0.5) / radius())
		if hovered < 0: back()
		else: activate_sector(hovered)
	elif event.is_action_pressed("ui_cancel"):
		back()
	elif event.is_action_pressed("ui_accept"):
		if hovered >= 0: activate_sector(hovered)
		else: back()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		hovered = (hovered + 1) % 8
		queue_redraw()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		hovered = posmod(hovered - 1, 8)
		queue_redraw()
	accept_event()

func _unhandled_input(event: InputEvent):
	if visible and event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		select_direction(Vector2(Input.get_joy_axis(event.device, JOY_AXIS_LEFT_X), Input.get_joy_axis(event.device, JOY_AXIS_LEFT_Y)))
		get_viewport().set_input_as_handled()

func _draw():
	var center = size * 0.5
	var outer = radius()
	var font = ThemeDB.fallback_font
	var font_size = clampi(int(outer / 13), 12, 19)
	for i in 8:
		var polygon = PackedVector2Array()
		var start = -PI * 0.5 + i * PI / 4 - PI / 8 + 0.018
		var end = start + PI / 4 - 0.036
		for step in 13:
			polygon.append(center + Vector2.from_angle(lerpf(start, end, step / 12.0)) * outer)
		for step in range(12, -1, -1):
			polygon.append(center + Vector2.from_angle(lerpf(start, end, step / 12.0)) * outer * inner)
		var entry: Dictionary = entries[i] if entries.size() == 8 else {"type": "empty", "name": ""}
		var disabled = entry.get("disabled", false) or entry.type in ["empty", "indicator"]
		var color = Color("203444") if disabled else Color("244f65")
		if i == hovered and not disabled: color = Color("278d9e")
		draw_colored_polygon(polygon, color)
		var text: String = entry.name
		if entry.type == "group": text = "▸ " + text
		var location = center + Vector2.from_angle(-PI * 0.5 + i * PI / 4) * outer * 0.65
		var lines = text.split("\n")
		for line_index in lines.size():
			var line: String = lines[line_index].left(22)
			var width = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, location + Vector2(-width * 0.5, (line_index - (lines.size() - 1) * 0.5) * (font_size + 2)), line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("8397a2") if disabled else Color.WHITE)
	var title = "Emotes" if layout == null else str(layout.groups[group].name)
	var label = title.left(16) + "\n" + ("Cancel" if history.is_empty() else "Back")
	var lines = label.split("\n")
	for i in lines.size():
		var width = font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, center + Vector2(-width * 0.5, (i - 0.5) * (font_size + 4)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	if not message.is_empty():
		# Error text stays in the center rather than adding navigation widgets.
		draw_string(font, center + Vector2(-outer * 0.8, outer * 0.15), message.left(60), HORIZONTAL_ALIGNMENT_LEFT, outer * 1.6, 12, Color("ffcc88"))
