extends RefCounted
## Device-local ordered preferences. Removing a row never removes a block.
const Guard = preload("res://scripts/multiplayer/federation/relay_validation.gd")
signal changed
var path := ""
var entries: Array = []
var blocked_ids: Array = []
var blocked_endpoints: Array = []
var write_blocked := false
var last_error := ""

func configure(file_path: String):
	path = file_path
	entries.clear()
	blocked_ids.clear()
	blocked_endpoints.clear()
	write_blocked = false
	last_error = ""

func _failure(message: String, preserve: bool = false) -> Dictionary:
	last_error = message
	write_blocked = write_blocked or preserve
	return Guard.failure(message)

func _valid_entry(value: Variant) -> bool:
	return value is Dictionary and Guard.keys(value, ["entry_id", "label", "host", "port", "relay_id"]) \
		and Guard.text(value.get("entry_id"), 128) and Guard.text(value.get("label"), 128) \
		and Guard.host(value.get("host")) and Guard.integer(value.get("port"), 1, 65535) \
		and (value.get("relay_id") == "" or Guard.identity(value.get("relay_id")))

func load_preferences() -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": true}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 128 * 1024: return _failure("Relay preferences unreadable or oversized; original preserved", true)
	var parser = JSON.new()
	var status = parser.parse(file.get_as_text())
	file.close()
	var value = parser.data
	if status != OK or not value is Dictionary or value.get("schema") != 1 \
		or not Guard.keys(value, ["schema", "entries", "blocked_ids", "blocked_endpoints"]) \
		or not value.get("entries") is Array or not value.get("blocked_ids") is Array \
		or not value.get("blocked_endpoints", []) is Array or value.entries.size() > 32 or value.blocked_ids.size() > 256 or value.get("blocked_endpoints", []).size() > 256:
		return _failure("Relay preferences corrupt or unsupported; original preserved", true)
	var next_entries: Array = []
	for item in value.entries:
		if not _valid_entry(item) or _duplicate(item, next_entries): return _failure("Invalid or duplicate saved relay; original preserved", true)
		next_entries.append(item.duplicate(true))
		next_entries.back().port = int(item.port)
	for id in value.blocked_ids:
		if not Guard.identity(id): return _failure("Invalid relay block; original preserved", true)
	for address in value.get("blocked_endpoints", []):
		if not Guard.text(address, 270): return _failure("Invalid endpoint block; original preserved", true)
	entries = next_entries
	blocked_ids = value.blocked_ids.duplicate()
	blocked_endpoints = value.get("blocked_endpoints", []).duplicate()
	changed.emit()
	return {"ok": true}

func snapshot() -> Dictionary:
	return {"entries": entries.duplicate(true), "blocked_ids": blocked_ids.duplicate(), "blocked_endpoints": blocked_endpoints.duplicate()}

func _duplicate(entry: Dictionary, values: Array) -> bool:
	for existing in values:
		if existing.entry_id == entry.entry_id or Guard.endpoint(existing.host, int(existing.port)) == Guard.endpoint(entry.host, int(entry.port)) \
			or (not entry.relay_id.is_empty() and existing.relay_id == entry.relay_id): return true
	return false

func add_entry(entry: Dictionary) -> Dictionary:
	if write_blocked: return _failure("Relay preferences are preserved read-only")
	if entries.size() >= 32 or not _valid_entry(entry) or _duplicate(entry, entries): return _failure("Invalid or duplicate relay (maximum 32)")
	entries.append(entry.duplicate(true))
	changed.emit()
	return {"ok": true}

func move_entry(id: String, index: int) -> Dictionary:
	if write_blocked or index < 0 or index >= entries.size(): return _failure("Invalid relay position")
	for old in entries.size():
		if entries[old].entry_id == id:
			var value = entries.pop_at(old)
			entries.insert(index, value)
			changed.emit()
			return {"ok": true}
	return _failure("Relay entry not found")

func update_entry(id: String, replacement: Dictionary) -> Dictionary:
	if write_blocked or not _valid_entry(replacement) or replacement.entry_id != id: return _failure("Invalid relay edit")
	for index in entries.size():
		if entries[index].entry_id != id: continue
		var others = entries.duplicate(true)
		others.remove_at(index)
		if _duplicate(replacement, others): return _failure("Duplicate relay identity/endpoint")
		entries[index] = replacement.duplicate(true)
		changed.emit()
		return {"ok": true}
	return _failure("Relay entry not found")

func remove_entry(id: String) -> Dictionary:
	if write_blocked: return _failure("Relay preferences are preserved read-only")
	for index in entries.size():
		if entries[index].entry_id == id:
			entries.remove_at(index)
			changed.emit()
			return {"ok": true}
	return _failure("Relay entry not found")

func set_blocked(id: String, blocked: bool) -> Dictionary:
	if write_blocked or not Guard.identity(id): return _failure("Invalid relay identity block")
	if blocked and not id in blocked_ids:
		if blocked_ids.size() >= 256: return _failure("Relay block limit reached")
		blocked_ids.append(id)
	elif not blocked: blocked_ids.erase(id)
	changed.emit()
	return {"ok": true}

func set_endpoint_blocked(hostname: String, port: int, blocked: bool) -> Dictionary:
	if write_blocked or not Guard.host(hostname) or port < 1 or port > 65535: return _failure("Invalid endpoint block")
	var address = Guard.endpoint(hostname, port)
	if blocked and not address in blocked_endpoints:
		if blocked_endpoints.size() >= 256: return _failure("Endpoint block limit reached")
		blocked_endpoints.append(address)
	elif not blocked: blocked_endpoints.erase(address)
	changed.emit()
	return {"ok": true}

func is_blocked(entry: Dictionary) -> bool:
	return entry.get("relay_id", "") in blocked_ids or Guard.endpoint(str(entry.get("host", "")), int(entry.get("port", 0))) in blocked_endpoints

func save_preferences() -> Dictionary:
	if write_blocked or path.is_empty(): return _failure("Relay preferences cannot overwrite preserved data")
	var value = snapshot()
	value.schema = 1
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return _failure("Cannot write relay preferences")
	file.store_string(JSON.stringify(value, "  "))
	file.flush()
	var status = file.get_error()
	file.close()
	if status != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK: return _failure("Cannot replace relay preferences")
	return {"ok": true}

func migrate_legacy(hostname: String, port: int) -> Dictionary:
	if write_blocked: return _failure("Relay preferences are preserved read-only")
	if not entries.is_empty() or FileAccess.file_exists(path): return {"ok": true}
	var result = add_entry({"entry_id": "legacy", "label": "Main relay", "host": hostname, "port": port, "relay_id": ""})
	return save_preferences() if result.ok else result
