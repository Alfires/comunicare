extends VBoxContainer
## Structured editor; list changes do not silently switch live membership.
var preferences
var rows: VBoxContainer
var host_input: LineEdit
var port_input: SpinBox
var label_input: LineEdit
var status: Label

func configure(store):
	preferences = store
	var explanation = Label.new()
	explanation.text = "Top relay is default; unavailable relays fall back in order. Remove is not Block. Changes apply on the next connection; blocking the active endpoint disconnects it."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(explanation)
	rows = VBoxContainer.new()
	add_child(rows)
	label_input = LineEdit.new()
	label_input.placeholder_text = "Relay label"
	label_input.max_length = 128
	add_child(label_input)
	host_input = LineEdit.new()
	host_input.placeholder_text = "Hostname or IP (no URL scheme)"
	host_input.max_length = 253
	add_child(host_input)
	port_input = SpinBox.new()
	port_input.min_value = 1
	port_input.max_value = 65535
	port_input.value = 7374
	add_child(port_input)
	_button(self, "Add relay", _add)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	preferences.changed.connect(_render)
	_render()

func _button(parent: Node, title: String, callback: Callable):
	var button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _render():
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var snapshot: Dictionary = preferences.snapshot()
	for index in snapshot.entries.size():
		var entry: Dictionary = snapshot.entries[index]
		var box = VBoxContainer.new()
		rows.add_child(box)
		var label = Label.new()
		label.text = "%s%s — %s:%s%s" % ["Main: " if index == 0 else "Fallback: ", entry.label, entry.host, entry.port, " (blocked)" if preferences.is_blocked(entry) else ""]
		box.add_child(label)
		var actions = HBoxContainer.new()
		box.add_child(actions)
		_button(actions, "Make main", func(): _commit(preferences.move_entry(entry.entry_id, 0)))
		_button(actions, "Down", func(): _commit(preferences.move_entry(entry.entry_id, mini(index + 1, snapshot.entries.size() - 1))))
		_button(actions, "Remove", func(): _commit(preferences.remove_entry(entry.entry_id)))
		_button(actions, "Unblock" if preferences.is_blocked(entry) else "Block", func():
			if not str(entry.relay_id).is_empty(): _commit(preferences.set_blocked(entry.relay_id, not preferences.is_blocked(entry)))
			else: _commit(preferences.set_endpoint_blocked(entry.host, int(entry.port), not preferences.is_blocked(entry))))
	# Removed endpoints stay manageable independently of the preference rows.
	for endpoint in snapshot.blocked_endpoints:
		_button(rows, "Unblock endpoint: " + endpoint, func():
			var separator: int = endpoint.rfind(":")
			_commit(preferences.set_endpoint_blocked(endpoint.substr(0, separator), int(endpoint.substr(separator + 1)), false)))
	for id in snapshot.blocked_ids:
		_button(rows, "Unblock relay identity: " + id, func(): _commit(preferences.set_blocked(id, false)))
	if preferences.write_blocked: status.text = preferences.last_error

func _add():
	var entry = {"entry_id": Crypto.new().generate_random_bytes(16).hex_encode(), "label": label_input.text.strip_edges(), "host": host_input.text.strip_edges(), "port": int(port_input.value), "relay_id": ""}
	if entry.label.is_empty(): entry.label = entry.host
	_commit(preferences.add_entry(entry))

func _commit(result: Dictionary):
	if result.ok: result = preferences.save_preferences()
	status.text = "Relay preferences saved. Reload World Explorer when offline to connect." if result.ok else str(result.get("error", "Cannot save relay preferences"))

func _exit_tree():
	if preferences != null and preferences.changed.is_connected(_render): preferences.changed.disconnect(_render)
