extends RefCounted
## Client-owned JSON only. Namespace is supplied by trusted startup, never a script.
const Data = preload("res://scripts/worlds/world_data.gd")
const MAX_BYTES = 16384
var path := ""
var values: Dictionary = {}
var writable := false
var memory_only := false
var last_error := ""
var last_write_msec := -1000

func configure(owner: String, world_url: String, temporary: bool = false, directory: String = "user://world_saves") -> bool:
	var next_path = "" if temporary else directory.path_join(owner.sha256_text()).path_join(world_url.sha256_text() + ".json")
	if next_path != path or temporary != memory_only: last_write_msec = -1000
	values = {}
	writable = false
	last_error = ""
	memory_only = temporary
	if owner.is_empty() or world_url.is_empty(): return false
	path = next_path
	if not temporary and FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > MAX_BYTES:
			last_error = "Local world save unreadable or oversized; original preserved"
			return false
		var result = preload("res://scripts/worlds/world_text_parser.gd").new().parse_json(file.get_as_text())
		var parsed = result.get("value")
		if not result.ok or not parsed is Dictionary or parsed.size() > 128 or not Data.bounded(parsed, 0, [2048]):
			last_error = "Local world save corrupt; original preserved"
			return false
		values = parsed
	writable = true
	return true

func commit(candidate: Dictionary) -> bool:
	if not writable:
		last_error = "Local world save is read-only or unavailable"
		return false
	if not Data.bounded(candidate, 0, [2048]) or candidate.size() > 128:
		last_error = "Local world save exceeds data limits"
		return false
	var text = JSON.stringify(candidate)
	if text.to_utf8_buffer().size() > MAX_BYTES:
		last_error = "Local world save exceeds 16 KiB"
		return false
	if not memory_only:
		if Time.get_ticks_msec() - last_write_msec < 1000:
			last_error = "Local saves are limited to one write per second"
			return false
		if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
			last_error = "Cannot create local save directory"
			return false
		var pending = path + ".tmp-" + str(OS.get_process_id())
		var file = FileAccess.open(pending, FileAccess.WRITE)
		if file == null:
			last_error = "Cannot write local save temporary file"
			return false
		file.store_string(text)
		file.flush()
		var error = file.get_error()
		file.close()
		if error != OK or DirAccess.rename_absolute(pending, path) != OK:
			last_error = "Cannot commit local world save"
			return false
		last_write_msec = Time.get_ticks_msec()
	values = candidate.duplicate(true)
	last_error = ""
	return true
