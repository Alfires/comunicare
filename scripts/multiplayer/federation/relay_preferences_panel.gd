extends VBoxContainer
## Structured editor; list changes do not silently switch live membership.
var preferences
var rows: VBoxContainer
var host_input: LineEdit
var port_input: SpinBox
var label_input: LineEdit
var status: Label
var identity_input: LineEdit
var certificate_input: LineEdit
var trust_rows: VBoxContainer
var refresh_at := 0

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
	identity_input = LineEdit.new()
	identity_input.placeholder_text = "Verified relay ID (64 lowercase hex, obtain from operator)"
	identity_input.max_length = 64
	add_child(identity_input)
	certificate_input = LineEdit.new()
	certificate_input.placeholder_text = "Operator certificate file path (.crt/.pem); verify independently"
	add_child(certificate_input)
	var warning = Label.new()
	warning.text = "Trust only an operator certificate and relay ID you independently verified. The port above is the TLS federation port for certificate import, not the legacy UDP port."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(warning)
	_button(self, "Trust directory certificate for address above", _trust_directory)
	trust_rows = VBoxContainer.new()
	add_child(trust_rows)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	preferences.changed.connect(_render)
	_render()
	_render_discovery()

func _process(_delta):
	if Time.get_ticks_msec() >= refresh_at and trust_rows != null:
		refresh_at = Time.get_ticks_msec() + 3000
		_render_discovery()

func _render_discovery():
	for child in trust_rows.get_children():
		trust_rows.remove_child(child)
		child.queue_free()
	var network = get_node_or_null("/root/NetworkHandler")
	if network == null or not network.has_method("get_lan_relay_candidates"): return
	for candidate in network.get_lan_relay_candidates():
		var label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "LAN hint (not trusted): %s — %s:%s\nRelay ID: %s" % [candidate.label, candidate.host, candidate.port, candidate.relay_id]
		trust_rows.add_child(label)
		_button(trust_rows, "Use address for explicit trust/import", func():
			identity_input.text = candidate.relay_id
			host_input.text = candidate.host
			port_input.value = candidate.port
			label_input.text = candidate.label)
	if network.get("directory_trust") != null:
		for entry in network.directory_trust.entries:
			_button(trust_rows, "Remove trusted directory " + entry.relay_id.left(12), func():
				if network.directory_trust.remove(entry.relay_id):
					network.directory_browser.stop()
					network.directory_browser.trusted.erase(entry.relay_id)
					network.refresh_relay_directories()
				_render_discovery())

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
	var entry = {"entry_id": Crypto.new().generate_random_bytes(16).hex_encode(), "label": label_input.text.strip_edges(), "host": host_input.text.strip_edges(), "port": int(port_input.value), "relay_id": identity_input.text.strip_edges()}
	if entry.label.is_empty(): entry.label = entry.host
	_commit(preferences.add_entry(entry))

func _trust_directory():
	var network = get_node_or_null("/root/NetworkHandler")
	if network == null or not network.has_method("trust_relay_directory"):
		status.text = "Directory trust is unavailable in this isolated context"
		return
	var result = network.trust_relay_directory(identity_input.text.strip_edges(), host_input.text.strip_edges(), int(port_input.value), certificate_input.text.strip_edges())
	status.text = "Directory certificate trusted; public instances will refresh." if result else network.last_session_error

func _commit(result: Dictionary):
	if result.ok: result = preferences.save_preferences()
	status.text = "Relay preferences saved. Reload World Explorer when offline to connect." if result.ok else str(result.get("error", "Cannot save relay preferences"))

func _exit_tree():
	if preferences != null and preferences.changed.is_connected(_render): preferences.changed.disconnect(_render)
