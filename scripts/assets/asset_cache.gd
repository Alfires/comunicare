extends Node
## Client-local immutable source storage. Callers validate before publication and
## retain a lease for as long as a loaded object depends on a revision.

signal revision_available(source: String, previous: String, revision: String)
signal status_changed

const SCHEMA = 1
const LIMITS = {"avatar": 64 * 1024 * 1024, "world": 128 * 1024 * 1024, "animation": 16 * 1024 * 1024}
const MAX_JOBS = 4
const MAX_WAITERS = 32
var directory := "user://asset_cache"
var quota_bytes: int = 4 * 1024 * 1024 * 1024
var refresh_seconds := 900
var automatic_refresh := true
var allow_http := false
var enabled := true
var last_error := ""
var records: Dictionary = {}
var pins: Dictionary = {}
var jobs: Dictionary = {}
var failures: Dictionary = {}
var waiters := 0
var initialized := false
var writable := true
var serial := 0

class Lease extends RefCounted:
	var owner: WeakRef
	var revision: String
	func _notification(what):
		if what == NOTIFICATION_PREDELETE and owner != null:
			var cache = owner.get_ref()
			if is_instance_valid(cache):
				cache.release(revision)

func initialize(root_path: String = "") -> bool:
	if initialized:
		return enabled and writable
	initialized = true
	if not root_path.is_empty():
		directory = root_path.trim_suffix("/")
	if "--relay" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		enabled = false
		return false
	for child in ["blobs/sha256", "derived/worlds", "staging"]:
		if DirAccess.make_dir_recursive_absolute(directory.path_join(child)) != OK:
			return _error("Cannot create asset cache folder.")
	var index = directory.path_join("index.json")
	if FileAccess.file_exists(index):
		var file = FileAccess.open(index, FileAccess.READ)
		if file == null or file.get_length() > 16 * 1024 * 1024:
			writable = false
			return _error("Asset cache index unreadable; original preserved.")
		var parser = JSON.new()
		var error = parser.parse(file.get_as_text())
		var value = parser.data
		if error != OK or not value is Dictionary or value.get("schema") != SCHEMA or not value.get("sources") is Dictionary:
			writable = false
			return _error("Asset cache index corrupt or unsupported; original preserved.")
		for key in value.sources:
			if not key is String or not _valid_record(value.sources[key]):
				writable = false
				return _error("Invalid asset cache entry; original preserved.")
		records = value.sources
	# Only managed staging children are disposable. Never follow symlinks.
	_clear_directory(directory.path_join("staging"))
	return true

func _valid_record(value: Variant) -> bool:
	return value is Dictionary and LIMITS.has(value.get("kind")) \
		and valid_hash(value.get("hash")) and value.get("size") is float \
		and value.size > 0 and value.size <= LIMITS[value.kind] \
		and value.get("checked") is float and value.get("accessed") is float \
		and value.get("etag", "") is String and value.get("modified", "") is String \
		and value.get("pinned", false) is bool and value.get("no_cache", false) is bool

static func valid_hash(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character in value:
		if not character in "0123456789abcdef":
			return false
	return true

func blob_path(revision: String) -> String:
	return directory.path_join("blobs/sha256/" + revision) if valid_hash(revision) else ""

func world_path(revision: String) -> String:
	return directory.path_join("derived/worlds/" + revision + "-1/content/") if valid_hash(revision) else ""

func _key(source: String, kind: String) -> String:
	return (kind + "\n" + source).sha256_text()

func _hash_file(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

func _usable(record: Dictionary) -> bool:
	if not valid_hash(record.get("hash")):
		return false
	var path = blob_path(record.hash)
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	return file != null and file.get_length() == int(record.get("size", -1)) and _hash_file(path) == record.hash

func retain(revision: String) -> RefCounted:
	if not valid_hash(revision):
		return null
	pins[revision] = int(pins.get(revision, 0)) + 1
	var lease = Lease.new()
	lease.owner = weakref(self)
	lease.revision = revision
	return lease

func release(revision: String):
	if pins.has(revision):
		pins[revision] -= 1
		if pins[revision] <= 0:
			pins.erase(revision)

func _result(record: Dictionary, stale: bool = false) -> Dictionary:
	return {"path": blob_path(record.hash), "hash": record.hash,
		"stale": stale, "lease": retain(record.hash)}

func fetch(source: String, kind: String, validator: Callable, force: bool = false) -> Dictionary:
	if not initialize() or not enabled or not writable or not LIMITS.has(kind) or not validator.is_valid():
		return {}
	if not _allowed_url(source):
		_error("Asset URL must be HTTPS (HTTP requires the development option).")
		return {}
	var key = _key(source, kind)
	if waiters >= MAX_WAITERS:
		_error("Too many pending asset requests.")
		return {}
	waiters += 1
	# A completed job holds a lease until every coalesced consumer receives it.
	if jobs.has(key):
		var job: Dictionary = jobs[key]
		while not job.done:
			await get_tree().process_frame
		waiters -= 1
		return job.result.duplicate()
	while jobs.size() >= MAX_JOBS:
		await get_tree().process_frame
	var job = {"done": false, "result": {}}
	jobs[key] = job
	var result = await _fetch(source, kind, key, validator, force)
	job.result = result
	job.done = true
	jobs.erase(key)
	waiters -= 1
	status_changed.emit()
	return result

func _fetch(source: String, kind: String, key: String, validator: Callable, force: bool) -> Dictionary:
	var record: Dictionary = records.get(key, {}).duplicate(true)
	var usable = _usable(record)
	var previous_lease = retain(record.hash) if usable else null
	var now = Time.get_unix_time_from_system()
	if usable and not force and not record.get("no_cache", false) and (not automatic_refresh or now - record.checked < refresh_seconds):
		records[key].accessed = now
		return _result(record)
	if not force and now < failures.get(key, {}).get("retry_at", 0):
		return _result(record, true) if usable else {}
	serial += 1
	var stage = directory.path_join("staging/%s-%s" % [Time.get_ticks_usec(), serial])
	var request = HTTPRequest.new()
	request.timeout = 30
	request.use_threads = true
	request.body_size_limit = LIMITS[kind]
	request.max_redirects = 0 # Do not silently follow a peer-controlled redirect.
	request.download_file = stage
	add_child(request)
	var headers = PackedStringArray()
	if usable and not force:
		if not record.get("etag", "").is_empty():
			headers.append("If-None-Match: " + record.etag)
		if not record.get("modified", "").is_empty():
			headers.append("If-Modified-Since: " + record.modified)
	var response: Array = []
	if request.request(source, headers) == OK:
		response = await request.request_completed
	request.queue_free()
	if response.size() != 4 or response[0] != HTTPRequest.RESULT_SUCCESS:
		_remove_file(stage)
		return _fallback(key, record, usable, "Asset download failed; cached revision retained.")
	var fields = _headers(response[2])
	var policy = fields.get("cache-control", "").to_lower()
	if response[1] == 304 and usable:
		_remove_file(stage)
		record.checked = now
		record.accessed = now
		record.no_cache = record.get("no_cache", false) or "no-cache" in policy
		records[key] = record
		_save()
		failures.erase(key)
		return _result(record)
	if response[1] != 200:
		_remove_file(stage)
		return _fallback(key, record, usable, "Asset server returned HTTP %s; cached revision retained." % response[1])
	var file = FileAccess.open(stage, FileAccess.READ)
	var size = file.get_length() if file != null else 0
	file = null
	if size <= 0 or size > LIMITS[kind] or not await validator.call(stage):
		_remove_file(stage)
		return _fallback(key, record, usable, "Downloaded asset failed validation; cached revision retained.")
	var revision = _hash_file(stage)
	if "no-store" in policy:
		# A transient file is owned by a lease, not the persistent index.
		var transient = TemporaryFile.new()
		transient.path = stage
		return {"path": stage, "hash": revision, "stale": false, "lease": transient, "temporary": true}
	var lease = retain(revision)
	if not _make_room(0):
		_remove_file(stage)
		return _fallback(key, record, usable, "Asset cache quota exceeded by active or pinned content.")
	var destination = blob_path(revision)
	if _hash_file(destination) != revision:
		if DirAccess.rename_absolute(stage, destination) != OK:
			_remove_file(stage)
			return _fallback(key, record, usable, "Cannot save downloaded asset.")
	else:
		_remove_file(stage)
	var previous: Dictionary = records.duplicate(true)
	records[key] = {"kind": kind, "hash": revision, "size": size, "checked": now,
		"accessed": now, "etag": fields.get("etag", ""), "modified": fields.get("last-modified", ""),
		"pinned": false, "no_cache": "no-cache" in policy}
	if not _save():
		records = previous
		return _fallback(key, record, usable, "Cannot commit asset cache index.")
	failures.erase(key)
	last_error = ""
	if record.get("hash", "") != revision:
		revision_available.emit(source, record.get("hash", ""), revision)
	return {"path": destination, "hash": revision, "stale": false, "lease": lease}

class TemporaryFile extends RefCounted:
	var path: String
	func _notification(what):
		if what == NOTIFICATION_PREDELETE and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func import_file(path: String, kind: String, validator: Callable) -> Dictionary:
	if not initialize() or not writable or not LIMITS.has(kind):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > LIMITS[kind]:
		_error("Import file is unreadable, empty or oversized.")
		return {}
	file = null
	serial += 1
	var stage = directory.path_join("staging/import-%s-%s" % [Time.get_ticks_usec(), serial])
	if DirAccess.copy_absolute(path, stage) != OK:
		return {}
	if not await validator.call(stage):
		_remove_file(stage)
		return {}
	var revision = _hash_file(stage)
	var lease = retain(revision)
	var size = FileAccess.open(stage, FileAccess.READ).get_length()
	if not _make_room(0):
		_remove_file(stage)
		return {}
	if _hash_file(blob_path(revision)) != revision:
		if DirAccess.rename_absolute(stage, blob_path(revision)) != OK:
			_remove_file(stage)
			return {}
	else:
		_remove_file(stage)
	var key = _key("import:" + revision, kind)
	var old = records.duplicate(true)
	var now = Time.get_unix_time_from_system()
	records[key] = {"kind": kind, "hash": revision, "size": size, "checked": now,
		"accessed": now, "pinned": true, "etag": "", "modified": "", "no_cache": false}
	if not _save():
		records = old
		return {}
	return {"path": blob_path(revision), "hash": revision, "lease": lease, "stale": false}

func _fallback(key: String, record: Dictionary, usable: bool, message: String) -> Dictionary:
	_error(message)
	var attempts = mini(int(failures.get(key, {}).get("attempts", 0)) + 1, 8)
	failures[key] = {"attempts": attempts, "retry_at": Time.get_unix_time_from_system() + minf(900, 5 * pow(2, attempts))}
	return _result(record, true) if usable else {}

func _allowed_url(source: String) -> bool:
	if source.length() > 4096 or "\n" in source or "\r" in source or " " in source or "\\" in source:
		return false
	if not source.begins_with("https://") and not (allow_http and source.begins_with("http://")):
		return false
	var authority = source.split("://", true, 1)[1].split("/")[0].split("?")[0].split("#")[0]
	return not authority.is_empty() and not "@" in authority

func _headers(lines: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for line in lines:
		var separator = line.find(":")
		if separator > 0:
			result[line.left(separator).to_lower().strip_edges()] = line.substr(separator + 1).strip_edges()
	return result

func _save() -> bool:
	var path = directory.path_join("index.json")
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return _error("Cannot write asset cache index.")
	file.store_string(JSON.stringify({"schema": SCHEMA, "sources": records}))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return _error("Cannot replace asset cache index.")
	return true

func usage_bytes() -> int:
	return _directory_size(directory) if initialized else 0

func _make_room(additional: int) -> bool:
	if usage_bytes() + additional <= quota_bytes:
		return true
	var candidates = records.keys()
	candidates.sort_custom(func(a, b): return records[a].accessed < records[b].accessed)
	for key in candidates:
		var record: Dictionary = records[key]
		if record.get("pinned", false) or pins.has(record.hash):
			continue
		records.erase(key)
		_delete_unreferenced(record.hash)
		if usage_bytes() + additional <= quota_bytes:
			return _save()
	_save()
	return false

func clear_unused() -> bool:
	if not initialize() or not writable or not jobs.is_empty():
		return false
	for key in records.keys():
		var record: Dictionary = records[key]
		if not record.get("pinned", false) and not pins.has(record.hash):
			records.erase(key)
			_delete_unreferenced(record.hash)
	status_changed.emit()
	return _save()

func _delete_unreferenced(revision: String):
	if pins.has(revision):
		return
	for record in records.values():
		if record.hash == revision:
			return
	_remove_file(blob_path(revision))
	var derived = world_path(revision).get_base_dir().trim_suffix("/content")
	_clear_directory(derived)
	if DirAccess.dir_exists_absolute(derived):
		DirAccess.remove_absolute(derived)

func _directory_size(path: String) -> int:
	var folder = DirAccess.open(path)
	if folder == null:
		return 0
	var total := 0
	for child in folder.get_files():
		if not folder.is_link(child):
			var file = FileAccess.open(path.path_join(child), FileAccess.READ)
			if file != null:
				total += file.get_length()
	for child in folder.get_directories():
		if not folder.is_link(child):
			total += _directory_size(path.path_join(child))
	return total

func _clear_directory(path: String):
	if not path.begins_with(directory + "/"):
		return
	var folder = DirAccess.open(path)
	if folder == null:
		return
	for child in folder.get_files():
		if not folder.is_link(child):
			_remove_file(path.path_join(child))
	for child in folder.get_directories():
		if not folder.is_link(child):
			_clear_directory(path.path_join(child))
			DirAccess.remove_absolute(path.path_join(child))

func _remove_file(path: String):
	if path.begins_with(directory + "/") and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _error(message: String) -> bool:
	last_error = message
	status_changed.emit()
	return false
