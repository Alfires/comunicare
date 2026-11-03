extends RefCounted
## Account-local virtual folders. Pagination never changes animation state.

const MAX_GROUPS = 32
const MAX_ENTRIES = 1024
const MAX_DEPTH = 4
var groups: Dictionary = defaults()
var path := ""
var last_error := ""
var writable := true

static func defaults() -> Dictionary:
	return {"root": {"name": "Emotes", "entries": [
		{"type": "emote", "id": "builtin:dance", "name": "Dance"},
		{"type": "emote", "id": "builtin:interact", "name": "Interact"},
		{"type": "emote", "id": "__cancel_emote__", "name": "Return to\nmovement"},
		{"type": "group", "id": "dances", "name": "Dances"}]},
		"dances": {"name": "Dances", "entries": []}}

func configure(file_path: String):
	path = file_path
	groups = defaults()
	writable = true
	last_error = ""
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1024 * 1024:
		_corrupt()
		return
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary \
		or parser.data.get("schema") != 1 or not valid(parser.data.get("groups")):
		_corrupt()
		return
	groups = parser.data.groups

func _corrupt():
	writable = false
	last_error = "Emote layout is unreadable or invalid. Original preserved; using default wheel."

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.has("root") or value.size() > MAX_GROUPS:
		return false
	var total := 0
	for id in value:
		var group = value[id]
		if not id is String or id.is_empty() or id.length() > 128 or not group is Dictionary \
			or not group.get("name") is String or group.name.strip_edges().is_empty() \
			or group.name.length() > 80 or not group.get("entries") is Array:
			return false
		total += group.entries.size()
		if total > MAX_ENTRIES:
			return false
		for entry in group.entries:
			if not entry is Dictionary or entry.get("type") not in ["emote", "group"] \
				or not entry.get("id") is String or entry.id.is_empty() or entry.id.length() > 256 \
				or not entry.get("name") is String or entry.name.length() > 128:
				return false
			if entry.type == "group" and not value.has(entry.id):
				return false
	# Check every component, including unreachable groups; cycles are never safe.
	for id in value:
		if not _walk(value, id, [], 0):
			return false
	return true

static func _walk(value: Dictionary, id: String, ancestors: Array, depth: int) -> bool:
	if id in ancestors or depth > MAX_DEPTH:
		return false
	var next = ancestors + [id]
	for entry in value[id].entries:
		if entry.type == "group" and not _walk(value, entry.id, next, depth + 1):
			return false
	return true

func commit(candidate: Dictionary) -> bool:
	if not writable or not valid(candidate):
		last_error = "Invalid layout: check group depth, cycles and size limits."
		return false
	if not path.is_empty():
		if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
			return false
		var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
		if file == null:
			last_error = "Cannot save emote layout."
			return false
		file.store_string(JSON.stringify({"schema": 1, "groups": candidate}))
		file.flush()
		var error = file.get_error()
		file.close()
		if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
			last_error = "Cannot commit emote layout."
			return false
	groups = candidate.duplicate(true)
	last_error = ""
	return true

func add_group(parent: String, title: String) -> String:
	if not groups.has(parent) or title.strip_edges().is_empty():
		return ""
	var id = Crypto.new().generate_random_bytes(12).hex_encode()
	var candidate = groups.duplicate(true)
	candidate[id] = {"name": title.strip_edges().left(80), "entries": []}
	candidate[parent].entries.append({"type": "group", "id": id, "name": candidate[id].name})
	return id if commit(candidate) else ""

func rename_group(id: String, title: String) -> bool:
	if not groups.has(id) or title.strip_edges().is_empty():
		return false
	var candidate = groups.duplicate(true)
	candidate[id].name = title.strip_edges().left(80)
	for group in candidate.values():
		for entry in group.entries:
			if entry.type == "group" and entry.id == id:
				entry.name = candidate[id].name
	return commit(candidate)

func delete_group(id: String) -> bool:
	if id == "root" or not groups.has(id):
		return false
	var candidate = groups.duplicate(true)
	candidate.erase(id)
	for group in candidate.values():
		group.entries = group.entries.filter(func(entry): return not (entry.type == "group" and entry.id == id))
	return commit(candidate)

func add_emote(group: String, id: String, title: String) -> bool:
	if not groups.has(group):
		return false
	var candidate = groups.duplicate(true)
	candidate[group].entries.append({"type": "emote", "id": id, "name": title.left(128)})
	return commit(candidate)

func move_entry(group: String, index: int, destination: String, position: int) -> bool:
	if not groups.has(group) or not groups.has(destination) or index < 0 or index >= groups[group].entries.size():
		return false
	var candidate = groups.duplicate(true)
	var entry: Dictionary = candidate[group].entries.pop_at(index)
	candidate[destination].entries.insert(clampi(position, 0, candidate[destination].entries.size()), entry)
	return commit(candidate)

func remove_entry(group: String, index: int) -> bool:
	if not groups.has(group) or index < 0 or index >= groups[group].entries.size():
		return false
	var candidate = groups.duplicate(true)
	candidate[group].entries.remove_at(index)
	return commit(candidate)

func page_count(group: String) -> int:
	var count = groups.get(group, {}).get("entries", []).size()
	return int(ceil(count / 5.0)) if count > 8 else 1

func sectors(group: String, page: int) -> Array:
	var result: Array = []
	result.resize(8)
	result.fill({"type": "empty", "name": ""})
	var entries: Array = groups.get(group, {}).get("entries", [])
	var pages = page_count(group)
	page = clampi(page, 0, pages - 1)
	if entries.size() <= 8:
		for i in entries.size():
			result[i] = entries[i].duplicate()
	else:
		# Clockwise from twelve o'clock: paging occupies lower-right/bottom/
		# lower-left, leaving five content wedges. No footer or ninth slot.
		var content_slots = [0, 1, 2, 6, 7]
		for i in mini(5, entries.size() - page * 5):
			result[content_slots[i]] = entries[page * 5 + i].duplicate()
		result[3] = {"type": "next", "name": "Next\nanimations", "disabled": page == pages - 1}
		result[4] = {"type": "indicator", "name": "Page %s / %s" % [page + 1, pages]}
		result[5] = {"type": "previous", "name": "Previous\nanimations", "disabled": page == 0}
	return result
